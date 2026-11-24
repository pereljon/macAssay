# Test plan: privileged checks through per-command sudo rules

This file holds the test cases and review findings for `sudo-rules.md`. It does not repeat the design.

The project has no test suite. Each case is a manual run on the Mac mini, with the command and the expected result. Reports go to the session temp folder and are never committed.

## Before code

- B1. Run `bash -n mac-audit.sh` and a v1.1 baseline: `./mac-audit.sh --quick --offline --skip-du -o $TMP/base.md`. Later cases compare against this baseline.

## Happy path, without rules installed

- T1. `bash -n mac-audit.sh` passes.
- T2. `./mac-audit.sh -h` prints the whole header block, including the examples and the install steps, and stops before the `VERSION` line. The usage line says `mac-audit.sh`, not `scripts/mac-audit.sh`.
- T3. `./mac-audit.sh --print-sudoers` prints the rule file without root. `visudo -c -f` on that output reports `parsed OK`. The file has rules for root and for the other local user (UID 501), none for the audit user, and no `*` in any argument.
- T4. `./mac-audit.sh --quick --offline --skip-du -o $TMP/r1.md` with no rules installed:
  - It finishes without asking for a password.
  - The header says `Privileged checks: 0 ran, N skipped`, and Limitations lists each skipped label.
  - Section 15 appears, with one "skipped" line per check.
  - No `sudo:` error line appears anywhere in the report.
  - Apart from the expected changes, its flags match the B1 baseline.

## Happy path, with rules installed

These cases need the rules installed on the Mac mini. The user runs the install, because sudo asks for the user's password. Before T6, ask the user to confirm, with this impact: one new file, `/etc/sudoers.d/mac-audit`, that gives the audit user password-free read access to the listed commands. Undo: `sudo rm /etc/sudoers.d/mac-audit`.

- T5. `./mac-audit.sh --install-sudoers` without root exits non-zero with a message that it needs root.
- T6. `sudo ./mac-audit.sh --install-sudoers` installs the file as root:wheel, mode 0440. It reports the `includedir` check result, passes the verification step, and prints the undo command. `visudo -c` passes afterward.
- T7. A second `sudo ./mac-audit.sh --install-sudoers` prints "already installed" and leaves the file unchanged.
- T8. With the rules installed, a full run `./mac-audit.sh -o $TMP/r2.md`:
  - The header says every privileged check ran.
  - Section 15 shows sudoers contents, `bputil` lines, device profiles, the other accounts, `lsof`, `sshd -T`, and `pf`.
  - The existing NOPASSWD rules in `/etc/sudoers` (`httpd`, `kill`, `killall`) are flagged LOW.
  - No serial number, UUID, or 32-character hex string appears: `grep -E '[0-9A-F]{8}-[0-9A-F]{4}-|[0-9a-fA-F]{32}'` finds nothing.
- T9. Compare the `bputil -d` and `profiles` lines in the report with the raw output, which the user runs with sudo. The filters keep the security settings and drop the identifiers.

## Edge cases and rule limits

- T10. Commands outside the rule list are refused without a password prompt: `sudo -n -k /bin/cat /etc/master.passwd`, `sudo -n -k /usr/sbin/lsof -nP`, and `sudo -n -k /usr/bin/du -h -d 1 -x /`.
- T11. A `PATH` change cannot redirect tools. Put a fake `awk` that writes a marker file first in `PATH`, then run `./mac-audit.sh --quick --offline --skip-du -o $TMP/r3.md`. The marker file does not appear.
- T12. In the T8 report, the `sudoers.d` coverage check raises no flag, because the rules cover every file present. The uncovered-file case needs a second `sudoers.d` file, which needs root and the user's approval. It is skipped unless the user asks for it.

## Flag conflicts and interface changes

- T13. `./mac-audit.sh --sudo` exits 2 with "Unknown option".
- T14. `./mac-audit.sh --print-sudoers --install-sudoers` exits 2.
- T15. `./mac-audit.sh --print-sudoers -o x.md` prints the rules and does not create `x.md`.
- T16. `./mac-audit.sh --print-sudoers=nosuchuser` exits non-zero with a message that the user does not exist.

## Remote mode

- T17. Run the encoded remote command locally, as in the v1.1 test, and compare the report with T4.
- T18. Remote install and a remote audit against a second Mac. Untested unless the user names a second Mac that accepts a key from this one.

## Checked by code review only

These paths need a broken or unsafe system state, so they are reviewed, not run:

- The installer stops when `visudo -c` fails before it starts.
- The rollback after a failed `visudo -c`.
- The refusal when the granted user can write a folder on a rule path.
- The skip and warning for an account name or home path that fails validation.

## Review findings

None yet.

## Results

None yet.
