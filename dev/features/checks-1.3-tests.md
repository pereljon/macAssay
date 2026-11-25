# Test plan: report by theme and new checks

This file holds the test cases, review findings, and results for `checks-1.3.md`. It does not repeat the design.

Two kinds of test cover version 1.3:
- `dev/test.sh` runs the parsers on fixtures, without root and without the network. It is the regression suite.
- Manual runs on the Mac mini cover the parts that need the real system. Reports go to the session temp folder and are never committed.

## Before code

- B1. Record the 1.2 baseline: run `./macassay --quick --offline --skip-du` on `master` and keep the report in the session temp folder for R1.
- B2. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay`; record the counts.

## Reorder (commit 1)

- R0. Script comparison: sort the non-heading lines of the 1.2 script and the commit 1 script, apply the category map, and diff. Only moved headings, labels, and section-number references may differ.
- R1. Report comparison: run 1.2 twice and record the lines that differ (run-to-run noise). Then normalize and sort the 1.2 and commit 1 reports and diff. No difference beyond the noise.
- R2. The report has the 14 sections of the outline, in order, then the Summary and Limitations. No "Privileged checks" section. Every `h3`, `block`, and `run` label appears under the section that the placement table names.
- R3. Every finding category is one of the 14 labels. A test in `dev/test.sh` greps `macassay` for `flag (HIGH|MEDIUM|LOW|INFO) ` and checks each category against the label list.
- R4. No finding text cites a section number that no longer holds the cited content.
- R5. A list of every finding text with its new label and ID is reviewed by hand before commit 1.
- R6. Every `finding` call has an ID matching `MA-<LABEL>-[0-9]{3}`, where LABEL is one of the 14 labels in capitals. Two call sites share an ID only when they are the same check (reviewed in R5).
- R7. Commit 3 (changes to 1.2 findings): each change in the design list gives its new severity on a fixture or a manual case; the 1.2 screen lock finding is gone.

## dev/test.sh (fixture tests)

Each case that touches secret-bearing input plants fake values (`SECRET_A`, `SECRET_B`, ...) and asserts that none appears in the output.

- G1. `mask_hex`: a 32-character and a 64-character hex run become `<ID>`; a 31-character run stays. Separately, `redact_ids` still turns a dashed UUID into `<UUID>`.
- G2. User-domain trust parser: names are kept and masked; `Policy String` lines with an IP address are dropped.
- G3. Credential files: fixtures for each of the eight files, with and without an inline secret, and a Docker config with only `credsStore`, a symlinked file (mode of the target), and an `.npmrc` value of `${NPM_TOKEN}` (no secret). Output shows presence, mode, and inline-secret state; no fake value or profile name appears.
- G4. SSH private key header: an OpenSSH key with cipher `none`, one with `aes256-ctr`, a PEM key with and without `ENCRYPTED`, an OpenSSH key written as one line, and a non-key file. Fixture keys are generated in the test folder with `ssh-keygen -N` and never leave it. The check never runs `ssh-keygen` on a private key (asserted with a fake `ssh-keygen` earlier on `PATH` that records its arguments).
- G5. SSH client config: `ForwardAgent yes` under `Host *`, under a named host, before the first `Host`, and in an `Include` file outside `~/.ssh`; `StrictHostKeyChecking off` and `StrictHostKeyChecking=no`; host names do not appear in the output.
- G6. Git config: `hooksPath` and `helper = store` found; a `[url]` section with a token in the URL does not leak.
- G7. Sudoers content: `NOPASSWD: ALL`, `Defaults !authenticate`, NOPASSWD for `/usr/bin/python3`, NOPASSWD through a `Cmnd_Alias` that holds `/bin/sh`, NOPASSWD for `/usr/bin/ssh-keygen` (not on the list), `Defaults env_keep += "DYLD_LIBRARY_PATH"`, no `secure_path`; each gives one finding at its severity. A rule line with a host name and a file path does not appear in this check's output. (The 1.2 block that lists non-comment sudoers lines is unchanged.)
- G8. Debug-port parser: a fake `ps` line with `--remote-debugging-port=9222` and a token argument gives the program name only; a program name with spaces; `--remote-debugging-pipe` and `--inspect-port` give nothing; the check's own `grep` or `awk` is not counted.
- G9. Screen-lock parser: `immediate`, `5 seconds`, `900 seconds`, `7200 seconds`, and `off` give the designed severities.
- G10. Boot arguments: empty, `-v`, and `amfi_get_out_of_my_way=1` give none, MEDIUM, and HIGH.
- G11. Update settings: missing keys print the macOS default line; `AutoInstallProductKeys` never appears.
- G12. Native-messaging manifest: a host path in `/tmp` and a missing path give MEDIUM; a normal path gives nothing.
- G13. Forced extensions: lists in system and per-user managed preferences, in local preferences, and in a Firefox `policies.json`, with the Mac enrolled and not enrolled; each gives the severity in the design table.
- G15. One finding per risk: screen lock off gives one finding (not the 1.2 one too); a `NOPASSWD: ALL` rule gives one finding; a `.git-credentials` file gives one finding.
- G16. PAM parser: a bracketed control field, an absolute module path outside `/usr/lib/pam`, and an `include` of another `/etc/pam.d` file.
- G17. User trust: a `TrustRoot` entry counts; a "Never Trust" entry does not.
- G14. Hidden accounts: a hidden admin and a hidden non-admin fixture give MEDIUM and LOW; system accounts under UID 500 are ignored.

## Manual runs (no sudo rules)

- M1. Full run: every new check runs or prints a skip reason; no new privacy prompt; run time within 30 s of the B1 run.
- M2. Expected new or changed findings on this Mac: Codex authorization plugin LOW if signed with a team ID; hidden admin account MEDIUM; FileMaker Pro world-writable MEDIUM; user-domain trusted certificates MEDIUM; private keys without a passphrase LOW; screen lock 15 minutes LOW; `StrictHostKeyChecking no` from the colima include LOW (specific hosts) or MEDIUM (every host); swap LOW instead of MEDIUM; Reduced Security stays MEDIUM; cloudflared LOW. Native-messaging hosts under `~/.claude` and `~/.codex` give no finding.
- M3. Privacy: grep the report for `AutoInstallProductKeys`, AirDrop UUID values, the destination ID from `tmutil`, any 32-character hex run, any IP address from the user trust settings, and every credential file's secret key names with values. None may appear.
- M4. Battery line reads `none` on this desktop.

## Manual runs (sudo rules installed)

- S1. Full run: the privileged checks now show in their topic sections; the sudoers content check runs through the existing rule; no new rule is needed (`--print-sudoers` output unchanged from 1.2).

## Remote mode

- X1. `--host` run against this Mac over SSH gives the same sections and findings as M1, except the privacy permissions (TCC) check, which can read differently over SSH.

## Laptop (needs another Mac)

- L1. Battery condition and maximum capacity are read on a laptop. Not runnable here; verifies the battery assumption.

## Checked by code review only

- No check reads a credential file except through `has_key` and `stat`.
- No check copies a secret-bearing file into the temporary folder.
- No new `priv` call and no change to the rule list.
- Severities match the design table.

## Review findings

Architecture review of the design, 2026-11-24 (opus, high effort). Triage per the development `AGENTS.md`.

- A-SEV The severity review recommends 26 changes to existing and new severities: asked the user; all adopted (decisions A1 to A10, B1 to B14, C1), see the design doc.
- A2-1 Decoding line 2 of a one-line OpenSSH key decodes private material: fixed in the design (fixed-prefix compare); requirement 7.
- A2-2 Splitting `comm=,command=` can print arguments: fixed (PID-based lookup); requirement 7.
- A2-3 `ssh-keygen -l` prints the key comment: fixed (bits and type only); `AGENTS.md` No secrets. Key file names stay in the report, with the reason recorded.
- A2-4 The sudoers "names only" rule protects nothing, and a raised severity would give two findings per rule: fixed (extend `classify_sudoers`, one finding per rule; claim removed); requirement 8.
- A3-1 `cupsctl` can start cupsd: fixed (run only when cupsd is running; listener list first); requirement 6.
- A4-1 Forced extensions miss per-user managed preferences and Firefox `policies.json`: fixed; requirement 4.
- A4-2 SSH config parser misses `off`, `Key=value`, options before `Host`, outside `Include`, and system config: fixed; requirement 4.
- A4-3 Symlinked keys report the link mode: fixed (`stat -L`); requirement 8.
- A4-4 `--inspect` matches `--inspect-port`: fixed (word-bounded); requirement 4.
- A4-5 Credential patterns miss four keys and count `${VAR}`: fixed; requirement 4.
- A4-6 Sudoers parsing misses `Cmnd_Alias`, exact names, and `Defaults !authenticate`: fixed; requirement 4.
- A4-7 PAM bracketed control fields and includes: fixed; requirement 4.
- A4-8 User trust counts "Never Trust" entries: fixed (TrustRoot and TrustAsRoot only); requirement 8.
- A5-1 Five 1.2 items have no section: fixed (placed); requirements 1 and 3.
- A5-2 A quick run skips moved blocks: fixed (script comparison R0, noise baseline R1); requirement 1.
- A5-3 Normalizing categories hides a wrong label: fixed (R5 hand review); requirement 2.
- A5-4 Sorting hides misplacement: fixed (placement table in R2); requirement 1.
- A6 Test plan gaps (G1 split, cases for G3, G4, G5, G7, G8, G13, one-finding-per-risk, X1 differences): fixed.
- Running from `/private/var/folders` is HIGH for App Translocation paths, a normal Gatekeeper location: asked the user; fixed by decision A10.

## Results

None yet.
