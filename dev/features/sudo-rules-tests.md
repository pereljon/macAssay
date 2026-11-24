# Test plan: privileged checks through per-command sudo rules

This file holds the test cases, review findings, and results for `sudo-rules.md`. It does not repeat the design.

Two kinds of test cover version 1.2:
- `dev/test.sh` runs the logic functions on fixtures, without root and without the network. It is the regression suite.
- Manual runs on the Mac mini cover the parts that need the real system. Reports go to the session temp folder and are never committed.

## Before code

- B1. Record the 1.1 baseline: `bash -n mac-audit.sh`, `shellcheck mac-audit.sh` (10 findings), and `./mac-audit.sh --quick --offline --skip-du -o $TMP/base.md`.

## dev/test.sh (fixture tests)

`dev/test.sh` runs in Bash 3.2. It sources the script with `MAC_AUDIT_LIB=1` and runs each case as a function. A watchdog stops the whole suite after 60 seconds, so a hang fails instead of stalling. It exits non-zero if any case fails.

- F1. `gen_rules` with a normal account list produces a file that `visudo -c -f` accepts. It has rules for root and each other account, none for the granted user, and `Defaults!MACAUDIT always_set_home` after the alias.
- F2. `gen_rules` output has no `*`, no `ALL` in a command field, and no shell, interpreter, editor, or `sqlite3`.
- F3. `gen_rules` skips hostile inputs and warns for each: account names with a space, `,`, `*`, `:`, `=`, `(`, `\`, or a leading `-`; home paths with `..`, or outside `/Users/NAME` and `/var/root`; `sudoers.d` names with a `.`, `*`, `[`, or a space. The output still passes `visudo -c -f`.
- F4. `gen_rules` refuses a granted user that is root, has a UID below 501, or is missing from the account list.
- F5. `classify_refusal` reports a refusal for `sudo: a password is required` with exit 1, and for an `is not allowed to execute` message. It reports success for exit 0, and for a command's own failure with a non-sudo message.
- F6. `classify_sudoers` finds `NOPASSWD: ALL` (MEDIUM) and other NOPASSWD rules (LOW). It ignores comments, ignores the mac-audit file, and handles a `Cmnd_Alias` that spans lines.
- F7. `filter_bputil` and `filter_profiles` keep the allowed lines from a fixture, and drop lines with a dashed UUID or a 32-character hex string.
- F8. `rc_hits` reports file, line number, and pattern name for each pattern, including the new ones. Its output never contains the fixture's line text or a token planted on the matching line.
- F9. `ssh_methods_flag` flags `password` and `keyboard-interactive`, and does not flag `publickey` alone.
- F10. `clean_field` removes newlines, tabs, carriage returns, pipes, and backticks. A finding text with an embedded newline and a severity word yields one report row.

## Manual runs without rules installed

- T1. `bash -n mac-audit.sh` passes. `shellcheck mac-audit.sh` reports no finding that the 1.1 baseline lacks.
- T2. `./mac-audit.sh -h` prints the whole header block, including the examples and the install steps, and stops before the code. The usage line says `mac-audit.sh`.
- T3. `./mac-audit.sh --print-sudoers` prints the rule file without root, and `visudo -c -f` accepts it.
- T4. `./mac-audit.sh --quick --offline --skip-du -o $TMP/r1.md`:
  - It finishes without a password prompt and without a privacy prompt.
  - The header says `Privileged checks: 0 ran, N skipped`. Limitations lists each skipped check with the reason "mac-audit sudo rules not installed".
  - `log show --last 5m --predicate 'process == "sudo"'` shows no entry from the run.
  - No `sudo:` line, no shell startup line text, no UUID, and no 32-character hex string appear in the report.
  - The root-run program check flags `com.cloudflare.cloudflared.plist` as HIGH.
  - Apart from the expected changes, the flags match the B1 baseline.
- T5. `sudo ./mac-audit.sh --quick` exits 2 with the message that the audit does not run as root. The user runs this, because sudo asks for the password.

## Manual runs with rules installed

These cases need the rules installed on the Mac mini. The user runs the install, because sudo asks for the user's password. Before T7, ask the user to confirm, with this impact: one new file, `/etc/sudoers.d/mac-audit`, that gives the audit user password-free use of the listed commands. Undo: `sudo rm /etc/sudoers.d/mac-audit`.

- T6. `./mac-audit.sh --install-sudoers` without root exits non-zero with a message that it needs root.
- T7. `sudo ./mac-audit.sh --install-sudoers` installs the file as root:wheel, mode 0440. It reports the `includedir` result, passes the verification step, and prints the undo command. `visudo -c` passes afterward.
- T8. A full run, `./mac-audit.sh -o $TMP/r2.md`:
  - The header says every privileged check ran.
  - Section 15 shows the sudoers contents, the `bputil` lines, the device profiles, the other accounts, the crontab listing, `lsof`, `sshd -T`, and `pf`.
  - The existing NOPASSWD rules in `/etc/sudoers` (`httpd`, `kill`, `killall`) are flagged LOW.
  - The root-run program check flags cloudflared. Record how many other daemons it flags, and whether admin-group write needs a lower severity.
  - The UUID and hex checks from T4 pass.
- T9. Compare the `bputil -d` and `profiles` lines in the report with the raw output, which the user runs with sudo. Update the F7 fixtures from the real output.
- T10. A second `sudo ./mac-audit.sh --install-sudoers` prints "already installed" and leaves the file unchanged.
- T11. Commands outside the rules are refused without a password prompt: `sudo -n -k /bin/cat /etc/master.passwd`, `sudo -n -k /usr/sbin/lsof -nP`, `sudo -n -k /usr/bin/du -h -d 1 -x /`, and `sudo -n -k /bin/ls -ln /var/root`.

## Flag conflicts and interface changes

- T12. `./mac-audit.sh --sudo` exits 2 with "Unknown option".
- T13. `./mac-audit.sh --print-sudoers --install-sudoers` exits 2.
- T14. `./mac-audit.sh --print-sudoers -o x.md` prints the rules and does not create `x.md`.
- T15. `./mac-audit.sh --print-sudoers=nosuchuser` and `--print-sudoers=root` exit non-zero with a message.
- T16. `./mac-audit.sh -o` and `./mac-audit.sh --host` exit 2 with a usage error, within one second.
- T17. A fake `awk` placed first in `PATH`, which writes a marker file, is never run: `./mac-audit.sh --quick --offline --skip-du -o $TMP/r3.md` leaves no marker.

## Remote mode

- T18. Run the encoded remote command locally, as in the v1.1 test, and compare the report with T4.
- T19. Remote install and a remote audit against a second Mac. Untested unless the user names a second Mac that accepts a key from this one.

## Checked by code review only

These paths need a broken or unsafe system state, so they are reviewed, not run:

- The installer stops when `visudo -c` fails before it starts.
- The rollback after a failed `visudo -c`.
- The refusal when the granted user can write a folder on a rule path.
- The verification warning when a later `/etc/sudoers` line overrides the rule.

## Review findings

Architecture review, 2026-11-24 (opus, high effort). Each line gives the finding, the outcome, and the reason.

- Q1-A1 Root mode keeps parsers as root: fixed by design. User decision A1 removes root audits.
- Q1-A2 `cat` rules expose other accounts' secrets and follow symlinks: fixed by design. User decision A2.
- Q1-A3 No mode dispatch before the installer: fixed by design. User decision A3.
- Q1-A4 Unprivileged skips (Time Machine plist, TCC) are silent: fixed by design. Requirement 7 and user decision A3.
- Q1-A5 No tests for the rule generator: fixed by design (`dev/test.sh`). User decision A3.
- Q1-A6 sudo logs every call, and the doc claimed no side effect: fixed. Breaks the Read-only rule; the priv helper skips when the rules file is absent, and the side effect is listed.
- Q1-A7 The hex deny-list misses dashed UUIDs: fixed. Breaks the No secrets rule; allow-lists replace it.
- Q3-1 Startup lines copied into the report: fixed. Breaks the No secrets rule.
- Q3-2 A root run writes the report through a symlink: resolved by A1. The audit no longer runs as root.
- Q3-3 Remote `sudo bash` uses the remote `PATH`: fixed. Breaks the Security Context; remote commands use absolute paths.
- Q3-4 A root run reads `~/.curlrc` and `~/.sqliterc` through the kept `HOME`: resolved by A1, and `always_set_home` covers the rule commands.
- Q3-5 `brew outdated` auto-updates Homebrew: kept by user decision (2026-11-24, `docs/ISSUES.md`); listed as a side effect.
- Q3-6 The SSH flag misses keyboard-interactive: fixed. User decision B1.
- Q3-7 The SSH `nobody` attempt and possible `du` privacy prompts are not listed: fixed. Breaks the Read-only rule; listed, and T4 checks for prompts.
- Q3-8 Startup scan misses files and patterns: fixed. User decision B1.
- Q3-9 Root crontab shown as the user's: resolved by A1.
- Q3-10 A missing option value loops forever: fixed. User decision B1.
- Q3-11 Untrusted text can add report rows or address an LLM reviewer: fixed. Breaks the Security Context.
- Q3-12 `kmutil` UUIDs and the `awk \s` bug: fixed. Breaks the No secrets rule.
- Q3-13 Truncation has no marker: fixed. User decision B1.
- Q3-14 1.2 gaps (`sudoers.d` name validation, `..` in homes, granted-user validation, mac-audit's own INFO flag, refusal wording, `always_set_home`): fixed. Breaks the Least privilege rule.
- Q3-15 No size check on the encoded remote command: dropped. No requirement and not Critical; the script uses about 43 KB of an SSH limit of about 256 KB.
- Q2 Additional checks: the root-run program check is in 1.2 (user decision B2). The rest are planned for 1.3 in `docs/ISSUES.md`.
- ShellCheck SC2035 (`du` glob): fixed. Breaks the Security Context.

## Results

None yet.
