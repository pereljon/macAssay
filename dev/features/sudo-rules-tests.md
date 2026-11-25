# Test plan: privileged checks through per-command sudo rules

This file holds the test cases, review findings, and results for `sudo-rules.md`. It does not repeat the design.

Two kinds of test cover version 1.2:
- `dev/test.sh` runs the logic functions on fixtures, without root and without the network. It is the regression suite.
- Manual runs on the Mac mini cover the parts that need the real system. Reports go to the session temp folder and are never committed.

## Before code

- B1. Record the 1.1 baseline: `bash -n mac-audit.sh`, `shellcheck mac-audit.sh` (10 findings), and `./mac-audit.sh --quick --offline --skip-du -o $TMP/base.md`.

## dev/test.sh (fixture tests)

`dev/test.sh` runs in Bash 3.2. It sources the script with `MACASSAY_LIB=1` and runs each case as a function. A watchdog stops the whole suite after 60 seconds, so a hang fails instead of stalling. It exits non-zero if any case fails.

- F1. `gen_rules` with a normal account list produces a file that `visudo -c -f` accepts. It has rules for root and each other account, none for the granted user, and `Defaults!MACASSAY always_set_home` after the alias.
- F2. `gen_rules` output has no `*`, no `ALL` in a command field, and no shell, interpreter, editor, or `sqlite3`.
- F3. `gen_rules` skips hostile inputs and warns for each: account names with a space, `,`, `*`, `:`, `=`, `(`, `\`, or a leading `-`; home paths with `..`, or outside `/Users/NAME` and `/var/root`; `sudoers.d` names with a `.`, `*`, `[`, or a space. The output still passes `visudo -c -f`.
- F4. `gen_rules` refuses a granted user that is root, has a UID below 501, or is missing from the account list. It also refuses a user named `ALL` or `ADMIN_1`, which read as sudoers alias names (CR-11), and accepts `bob`.
- F5. `classify_refusal` reports a refusal for `sudo: a password is required` with exit 1, and for an `is not allowed to execute` message. It reports success for exit 0, and for a command's own failure with a non-sudo message.
- F6. `classify_sudoers` rates NOPASSWD rules whose command list contains `ALL` MEDIUM, including `NOPASSWD:ALL`, `NOPASSWD: SETENV: ALL`, a list ending in `ALL`, and a `#UID` rule. Other NOPASSWD rules are LOW. It ignores comments, `#includedir`, and Defaults, and joins continued lines.
- F7. `filter_bputil` and `filter_profiles` keep the allowed lines from a fixture, and drop lines with a dashed UUID or a 32-character hex string.
- F8. `rc_hits` reports file, line number, and pattern name for each pattern, including the new ones. Its output never contains the fixture's line text or a token planted on the matching line.
- F9. `ssh_accepts_password` flags `password` and `keyboard-interactive`, and does not flag `publickey` alone.
- F10. `clean_field` removes newlines, tabs, carriage returns, pipes, and backticks. A finding text with an embedded newline and a severity word yields one report row.
- F11. `redact_ids` replaces dashed UUIDs in upper and lower case.
- F12. `crontab_summary` shows schedule and command name, names variables without values, and hides commands with inline variables. No planted secret appears.
- F13. `chain_writable` rates a program owned by the test user HIGH.
- F14. `rollback_rules`, with `RULES` in a test folder and a stub `sudoers_ok` that fails while the rules file holds a bad line (CR-5): with no backup, it removes the bad file and succeeds; when the backup cannot be installed, it removes the bad file, returns 2, and leaves no `.macassay.new` file behind; when sudo still does not parse, it returns 1.

## Manual runs without rules installed

- T1. `bash -n macassay` passes. `shellcheck macassay` reports no finding that the 1.1 baseline lacks.
- T2. `./macassay -h` prints the whole header block, including the examples and the install steps, and stops before the code. The usage line says `macassay`.
- T3. `./macassay --print-sudoers` prints the rule file without root, and `visudo -c -f` accepts it.
- T4. `./macassay --quick --offline --skip-du -o $TMP/r1.md`:
  - It finishes without a password prompt and without a privacy prompt.
  - The header says `Privileged checks: 0 ran, N skipped`. Limitations lists each skipped check with the reason "macassay sudo rules not installed".
  - `log show --last 5m --predicate 'process == "sudo"'` shows no entry from the run.
  - No `sudo:` line, no shell startup line text, and no dashed UUID appear in the report.
  - The root-run program check flags `com.cloudflare.cloudflared.plist` as HIGH, and daemons under `/Applications` as MEDIUM.
  - Section 7 shows the effective `sshd` settings from `sshd -G`, and the SSH password flag cites `sshd -G`.
  - Apart from the expected changes, the flags match the B1 baseline.
- T5. `sudo ./macassay --quick` exits 2 with the message that the audit does not run as root. The user runs this, because sudo asks for the password.

## Manual runs with rules installed

These cases need the rules installed on the Mac mini. The user runs the install, because sudo asks for the user's password. Before T7, ask the user to confirm, with this impact: one new file, `/etc/sudoers.d/macassay`, that gives the audit user password-free use of the listed commands. Undo: `sudo rm /etc/sudoers.d/macassay`.

- T6. `./macassay --install-sudoers` without root exits non-zero with a message that it needs root.
- T7. `sudo ./macassay --install-sudoers` installs the file as root:wheel, mode 0440. It reports the `includedir` result, passes the verification step, and prints the undo command. `visudo -c` passes afterward.
- T8. A full run, `./macassay -o $TMP/r2.md`:
  - The header says every privileged check ran.
  - Section 15 shows the sudoers contents, the `bputil` lines, the device profiles, the other accounts, the crontab listing, `lsof`, and `pf`.
  - The existing NOPASSWD rules in `/etc/sudoers` (`httpd`, `kill`, `killall`) are flagged LOW.
  - The UUID check from T4 passes.
  - The raw root output of `profiles list -type configuration` holds names and identifiers only, with no payload fields (code review finding CR-4). This needs a Mac with a device profile installed.
- T9. Compare the `bputil -d` and `profiles` lines in the report with the raw output, which the user runs with sudo. Update the F7 fixtures from the real output.
- T10. A second `sudo ./macassay --install-sudoers` prints "already installed" and leaves the file unchanged.
- T11. Commands outside the rules are refused without a password prompt: `sudo -n -k /bin/cat /etc/master.passwd`, `sudo -n -k /usr/sbin/lsof -nP`, `sudo -n -k /usr/bin/du -h -d 1 -x /`, and `sudo -n -k /bin/ls -ln /var/root`.

## Flag conflicts and interface changes

- T12. `./macassay --sudo` exits 2 with "Unknown option".
- T13. `./macassay --print-sudoers --install-sudoers` exits 2.
- T14. `./macassay --print-sudoers -o x.md` prints the rules and does not create `x.md`.
- T15. `./macassay --print-sudoers=nosuchuser` and `--print-sudoers=root` exit non-zero with a message.
- T16. `./macassay -o` and `./macassay --host` exit 2 with a usage error, within one second.
- T17. A fake `awk` placed first in `PATH`, which writes a marker file, is never run: `./macassay --quick --offline --skip-du -o $TMP/r3.md` leaves no marker.

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

Code review before merge, 2026-11-24 (opus, high effort). Each line gives the finding, the outcome, and the reason.

- CR-1 `#UID` rules hidden, and some `NOPASSWD: ALL` forms rated LOW: fixed. Breaks the design (Sudoers contents) and has a trigger; F6 covers it.
- CR-2 The user's crontab is copied into the report: fixed. Breaks the No secrets principle; `crontab_summary` and F12.
- CR-3 Remote mode runs as root: fixed. Breaks decision A1; root is refused for every mode except a local install.
- CR-4 The standing `profiles show` rule may print payload secrets: fixed after the user's decision. The rule is now `profiles list -type configuration`; T8 checks its output.
- CR-5 The rollback message can claim a restore that failed, and a failed backup copy is unchecked: fixed after the user's decision. Critical impact (sudo lockout path); `rollback_rules` re-checks with `visudo -c`, and F14 covers it.
- CR-6 Absolute paths do not stop a remote `~/.zshenv` alias from capturing the sudo password: dropped for code, design text corrected. No requirement and not Critical; it needs a compromised remote account.
- CR-7 Group-writable items rated MEDIUM for any group, some cases missed: fixed. Requirement 12 with a trigger; MEDIUM only for `admin`, ACL and interpreter scripts covered, decision recorded.
- CR-8 Signer cells and the login hook reach the report uncleaned: fixed. Breaks the design (1.1 fixes) and the Security Context.
- CR-9 sudo warnings reach the report and can misclassify a run: dropped. No requirement and not Critical.
- CR-10 sudoers.d names that sudo reads but the rules cannot cover: dropped. No requirement and not Critical.
- CR-11 A granted user named `ALL` or like a User_Alias passes validation: fixed after the user's decision; F4 covers it.
- CR-12 Design text differs from the code: fixed in the design doc.
- CR-13 A remote install logs the script as the sudo command line: listed as a side effect. Breaks the Read-only rule (every side effect listed).
- PM-1 When the rollback cannot restore the old file, it leaves the new file that failed `visudo -c` in place: fixed after the user's decision; the rollback removes the file, and F14 covers it. Critical (sudo lockout path); no realistic trigger beyond an I/O failure; no requirement.
- PM-2 `dev/HANDOFF.md` side effects use the old names: fixed. Breaks the Read-only rule (every side effect listed).
- PM-3 `docs/ISSUES.md` lists bugs this branch fixed as open: fixed. Breaks the Change Checklist.
- PM-4 The writable-folder check runs only at install time: dropped. No requirement, not Critical; the actor who loosens another home's permissions is outside the Security Context.
- PM-5 The SSH password flag uses `sshd -G`, which ignores `Match` blocks: dropped. No requirement, not Critical; `sshd -T` without `-C` had the same limit.
- PM-6 A certificate label carries a 32-character hex identifier: dropped for 1.2, recorded in `docs/ISSUES.md`. Present in 1.1; No secrets names serials and UUIDs only.
- T9-1 The secure boot flag read the `Security Mode (CSEC): 1` line, which never says Full, so a Full Security Mac would get the MEDIUM flag: fixed. Breaks the design (Secure boot policy) and fires on every Full Security Mac; `bputil_mode` reads the `smb0` line, and F7 covers both modes.

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
- Q3-14 1.2 gaps (`sudoers.d` name validation, `..` in homes, granted-user validation, macassay's own INFO flag, refusal wording, `always_set_home`): fixed. Breaks the Least privilege rule.
- Q3-15 No size check on the encoded remote command: dropped. No requirement and not Critical; the script uses about 43 KB of an SSH limit of about 256 KB.
- Q2 Additional checks: the root-run program check is in 1.2 (user decision B2). The rest are planned for 1.3 in `docs/ISSUES.md`.
- ShellCheck SC2035 (`du` glob): fixed. Breaks the Security Context.

## Results

Run on the Mac mini, 2026-11-24, macOS 27.2.1.

- B1: 1.1 baseline recorded: 41 flags (HIGH 0, MEDIUM 14, LOW 19, INFO 8); ShellCheck 10 findings.
- F1 to F14: pass (`dev/test.sh`), rerun after the CR-4, CR-5, CR-11, `sshd -G`, and PM-1 changes.
- T4 after those changes: pass. Privileged checks 0 ran, 15 skipped; section 7 shows the `sshd -G` settings, and the SSH password flag cites `sshd -G`.
- T1: pass. ShellCheck leaves the 3 historical `ls` findings and nothing new; 3 verified false positives are suppressed inline with reasons.
- T2, T3, T6, T12 to T16: pass.
- T4: pass. Privileged checks 0 ran, 18 skipped, each listed in Limitations; no sudo log entry; no `sudo:` line, startup line text, or dashed UUID. Cloudflared HIGH, 9 `/Applications` daemons MEDIUM. Flags otherwise match the baseline; the DDPM listener and SMB share differences came from the Mac's state between runs, confirmed by later runs.
- T4 privacy prompts: not observed; dialogs are not visible from the session.
- T17: pass; the fake `awk` never ran.
- T18: pass; the encoded remote command gives the same report.
- Full run (all checks): 3 minutes 10 seconds.
- T5: pass on the message; the user ran it. The exit status was not shown.
- T7: pass; the user ran it. The file is root:wheel 0440, the verification step passed, and no includedir warning appeared.
- T8: pass. Full run 4 minutes 45 seconds; privileged checks 17 ran, 0 skipped. Section 15 shows every listed part; `httpd`, `kill`, and `killall` NOPASSWD rules are LOW; no dashed UUID or `sudo:` line. The device profile check found none installed, so CR-4's output check is still open.
- T9: the raw output was read through the installed rules. It found finding T9-1 below; the F7 fixture now follows the real format. `filter_bputil` drops the chip ID, UUIDs, and hashes.
- T11: pass. All four commands were refused with `sudo: a password is required` and no prompt; `pfctl -s info` ran.
- T10: pass; the user ran it. It printed "already installed", and the file kept its 17:12 timestamp.
- Not run yet: T19 (no second Mac).
