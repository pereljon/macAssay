# Test plan: report fixes from the MacBook run

This file holds the test cases, review findings, and results for `fixes-1.3.2.md`. It does not repeat the design.

Two kinds of test cover version 1.3.2:
- `dev/test.sh` runs the changed functions on fixtures, without root and without the network. The new cases are Q1 to Q7.
- Manual runs on the development Mac cover the sudo behavior. Reports go to the session temp folder and are never committed.

## Before code

- B1. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay` on `master`, and record the counts. ShellCheck should show the three historical findings (SC2010, SC2012).
- B2. Record `last | head -5` on the development Mac, for M1 and M2.

## dev/test.sh (fixture tests)

- Q1. `gen_rules`: the Defaults line reads `Defaults!MACASSAY always_set_home, !set_utmp`, it follows the `Cmnd_Alias`, and `visudo -c -f` accepts the file. The existing F1 and F2 checks still pass.
- Q2. `WRITABLE_SH` run as the current user with `/bin/sh -c "$WRITABLE_SH" sh DIR...`:
  - It prints a writable test folder, and it skips `/System` and a missing path.
  - It prints a folder whose name holds spaces, a leading `-`, and `$(touch PWNED)` unchanged, and no `PWNED` file appears.
  - It prints nothing when it gets no arguments.
- Q3. `recent_installs` on a fixture with one record for each case:
  - Dropped: `appstoreagent` with `com.apple.pkg.Numbers16`; `appstored` with `com.apple.pkg.Xcode`; `XProtectUpdateService` with no package ID; `softwareupdated`, `softwareupdate`, and `bootinstalld` records.
  - Kept: `appstoreagent` with a third-party package ID; `installer` with `com.apple.pkg.Fake`; an `Installer` record with an empty `displayName` (shows its package ID, as in P2).
- Q4. `top_mem` on fake `ps` lines: a path with two spaces prints in full; a path with no spaces prints as before; the MB and CPU columns match the 1.3.1 format.
- Q5. `crash_kinds` on file names: `WindowServer_2026-11-24-094451_host.cpu_resource.diag` and `WindowServer_2026-11-21-193818_host.cpu_resource.diag` count as 2 under `WindowServer`; `avconferenced-2026-11-20-101010.ips` still groups under `avconferenced`; a name with no date stays as it is.
- Q6. The `privblk` filter: input holding only a "No such file or directory" line prints `- TITLE: none`; input with a key fingerprint and the error line keeps only the fingerprint; "is not a public key file" stays.
- Q7. Blank line before titles: after `say "- a: b"`, both `block` and `run` leave a blank line between `- a: b` and `**TITLE**` in the report body.

## Manual tests on the development Mac

Before M1, confirm with the user. Installing the rules changes `/etc/sudoers.d/macassay` on this Mac. Undo: `sudo rm /etc/sudoers.d/macassay`, or reinstall the rules from 1.3.1.

- M0. Control, before M1: run one rule command under `script -q /dev/null /usr/bin/sudo -n -k /sbin/pfctl -s info` with the old rules. Pass: `last` gains one row. Without a terminal, sudo allocates no pty and writes no record, so a run from the agent's shell would pass M2 whether or not the fix works. M2 runs under `script` for that reason.
- M1. Run `sudo ./macassay --install-sudoers`. The diff shows only the Defaults line and the version comment. `last` gains at most two rows, both for root.
- M2. Run `script -q /dev/null ./macassay --quick --offline --skip-du -o <session temp folder>/m2.md`. Pass: `last` gains no row during the run, and the report's Recent logins block shows no row from the run. This test settles the design's open assumption that `set_utmp` works in a command-scoped Defaults line.
- M3. In the M2 report, check each report fix:
  - The memory list shows full paths with spaces.
  - Crash kinds group `.diag` reports by program.
  - The other-account blocks for root and any second account print "none" where the file is missing.
  - No line that starts with `**` follows a non-blank line: `awk 'prev != "" && /^\*\*/ {n++} {prev = $0} END {print n+0}'` prints 0.
  - The non-Apple installs list holds no App Store Apple app and no XProtect update.
- M4. After merge, the user reinstalls the rules on the MacBook and runs a full audit. Pass: the Recent logins block shows no row from the run, and the non-Apple installs list holds only non-Apple installs.

## Review findings

Pre-merge review (2026-11-26, opus, high), one line per finding:

- R1 `drop_enoent` dropped any line ending in the error text, so a LaunchAgents file named `x: No such file or directory` hid its own line: fixed; the filter now prints "none" only when the whole output is one `ls:` or `ssh-keygen:` error line (Q6); untrusted input reached it and requirement 6 covers only missing files.
- R2 a Rosetta install from `CoreServicesUIAgent` (the Rosetta prompt) still counted as non-Apple: fixed; that process with a `com.apple.` package ID counts as Apple's (Q3); seen on the development Mac, requirement 3.
- R3 the HANDOFF count of installer login records left out the user's own `sudo` row: fixed in `dev/HANDOFF.md`; M1 shows two root rows plus the user's row.
- R4 `Defaults!MACASSAY` also applies when an admin types an exact rule command outside macassay, so that command writes no login record: fixed by listing it in `dev/HANDOFF.md`; the AGENTS.md rule that every side effect is listed.
- R5 Q6 piped into `drop_enoent` directly and did not test `privblk`: fixed as part of R1; Q6 now runs `privblk` with a stub `priv`.
- R6 the installer's folder check passes when sudo itself fails: dropped; 1.3.1 behaved the same per folder, and no requirement or trigger applies.

Found in M3, before the review:

- M3a ssh-keygen ends its error lines with `\r\n`, so the first `drop_enoent` pattern missed them: fixed (R1 rewrite; Q6 case with CR LF).
- M3b the `**Account NAME**` heading is written by `say`, not `block`, and followed a list line: fixed with a blank line before it; requirement 7.

## Results

- B1 (2026-11-25, `master` at `4598245`): `dev/test.sh` 241 cases pass; `bash -n` passes; ShellCheck shows the three historical findings (one SC2010, two SC2012).
- B2: the newest `last` rows date from 2026-11-24 17:24. The agent's 1.3.1 quick runs on 2026-11-25 left no rows, because the agent's shell has no terminal.
- Fixtures: Q1 to Q7 pass; 267 cases in all after the review fixes. ShellCheck on `macassay` shows only the three historical findings; two new verified false positives (SC2016, SC2024) are suppressed inline with their reasons.
- Rules diff: the rules that 1.3.1 and 1.3.2 generate for the development Mac differ only in the Defaults line.
- M1 (2026-11-26): the installer's diff showed only the version comment and the Defaults line. `last` gained two root rows from the installer and one row for the user's own `sudo` command. Before 1.3.2, an install wrote nine or ten.
- M2: a `--quick --offline --skip-du` run under `script` ran 15 privileged checks and added no `last` row. This settles the design's open assumption: `set_utmp` takes effect in a command-scoped Defaults line.
- M3 (after the review fixes): no bold title follows a non-blank line; no "No such file" text; the other-account blocks print "none"; no Apple install in the non-Apple list; no `.diag` date left in the crash kinds; the memory list shows full paths.
- M4 (2026-11-26, MacBook, full run with 16 privileged checks after a reinstall at 11:32): pass. Recent logins shows two root rows at 11:32, the installer's two documented records, and one row for the user's terminal. The run itself added none; the 1.3.1 install and run on 2026-11-25 left about ten. The install and the run fall in the same minute, so the attribution rests on the row count (inferred). The non-Apple installs list holds only non-Apple installs.
- M0: one `sudo -n -k /sbin/pfctl -s info` under `script`, with the rules installed on 2026-11-24, added one `last` row (2026-11-25 23:40). This confirms the cause in the design doc.
