# Test plan: report by theme and new checks

This file holds the test cases, review findings, and results for `checks-1.3.md`. It does not repeat the design.

Two kinds of test cover version 1.3:
- `dev/test.sh` runs the parsers on fixtures, without root and without the network. It is the regression suite.
- Manual runs on the Mac mini cover the parts that need the real system. Reports go to the session temp folder and are never committed.

## Before code

- B1. Record the 1.2 baseline: run `./macassay --quick --offline --skip-du` on `master` and keep the report in the session temp folder for R1.
- B2. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay`; record the counts.

## Reorder (commit 1)

- R1. Normalized comparison: strip section numbers, headings, and category labels from the B1 report and the reordered report, sort both, and diff. Only values that change between runs may differ.
- R2. The report has the 14 sections of the outline, in order, then the Summary and Limitations. No "Privileged checks" section.
- R3. Every flag category is one of the 14 labels. A test in `dev/test.sh` greps `macassay` for `flag (HIGH|MEDIUM|LOW|INFO) ` and checks each category against the label list.
- R4. No flag text cites a section number that no longer holds the cited content.

## dev/test.sh (fixture tests)

Each case that touches secret-bearing input plants fake values (`SECRET_A`, `SECRET_B`, ...) and asserts that none appears in the output.

- G1. `mask_hex`: a 32-character and a 64-character hex run become `<ID>`; a 31-character run stays; a dashed UUID still becomes `<UUID>`.
- G2. User-domain trust parser: names are kept and masked; `Policy String` lines with an IP address are dropped.
- G3. Credential files: fixtures for each of the eight files, with and without an inline secret, and a Docker config with only `credsStore`. Output shows presence, mode, and inline-secret state; no fake value or profile name appears.
- G4. SSH private key header: an OpenSSH key with cipher `none`, one with `aes256-ctr`, a PEM key with and without `ENCRYPTED`, and a non-key file. Fixture keys are generated in the test folder with `ssh-keygen -N` and never leave it. The check never runs `ssh-keygen` on a private key (asserted with a fake `ssh-keygen` earlier on `PATH` that records its arguments).
- G5. SSH client config: `ForwardAgent yes` under `Host *`, under a named host, and in an `Include` file; host names do not appear in the output.
- G6. Git config: `hooksPath` and `helper = store` found; a `[url]` section with a token in the URL does not leak.
- G7. Sudoers content: `NOPASSWD: ALL`, `!authenticate`, NOPASSWD for `/usr/bin/python3`, `Defaults env_keep += "DYLD_LIBRARY_PATH"`, no `secure_path`; each gives its severity. A rule line with a host name and a file path does not appear in this check's output. (The 1.2 block that lists non-comment sudoers lines is unchanged.)
- G8. Debug-port parser: a fake `ps` line with `--remote-debugging-port=9222` and a token argument gives the program name only; the check's own `grep` or `awk` is not counted.
- G9. Screen-lock parser: `immediate`, `5 seconds`, `900 seconds`, `7200 seconds`, and `off` give the designed severities.
- G10. Boot arguments: empty, `-v`, and `amfi_get_out_of_my_way=1` give none, MEDIUM, and HIGH.
- G11. Update settings: missing keys print the macOS default line; `AutoInstallProductKeys` never appears.
- G12. Native-messaging manifest: a host path in `/tmp` and a missing path give MEDIUM; a normal path gives nothing.
- G13. Forced extensions: a list in a managed preferences fixture gives INFO; the same list in a local preferences fixture gives HIGH.
- G14. Hidden accounts: a hidden admin and a hidden non-admin fixture give MEDIUM and LOW; system accounts under UID 500 are ignored.

## Manual runs (no sudo rules)

- M1. Full run: every new check runs or prints a skip reason; no new privacy prompt; run time within 30 s of the B1 run.
- M2. Expected flags on this Mac: the Codex authorization plugin (MEDIUM), the hidden admin account (MEDIUM), FileMaker Pro world-writable (MEDIUM), user-domain trusted certificates (MEDIUM), private keys without a passphrase (LOW), screen lock 15 minutes (LOW). No HIGH from the new checks.
- M3. Privacy: grep the report for `AutoInstallProductKeys`, AirDrop UUID values, the destination ID from `tmutil`, any 32-character hex run, any IP address from the user trust settings, and every credential file's secret key names with values. None may appear.
- M4. Battery line reads `none` on this desktop.

## Manual runs (sudo rules installed)

- S1. Full run: the privileged checks now show in their topic sections; the sudoers content check runs through the existing rule; no new rule is needed (`--print-sudoers` output unchanged from 1.2).

## Remote mode

- X1. `--host` run against this Mac over SSH gives the same sections and flags as M1.

## Laptop (needs another Mac)

- L1. Battery condition and maximum capacity are read on a laptop. Not runnable here; verifies the battery assumption.

## Checked by code review only

- No check reads a credential file except through `has_key` and `stat`.
- No check copies a secret-bearing file into the temporary folder.
- No new `priv` call and no change to the rule list.
- Severities match the design table.

## Review findings

None yet. The architecture review must cover every severity, existing and new, for consistency and correctness.

## Results

None yet.
