# Test plan: report by theme and new checks

This file holds the test cases, review findings, and results for `checks-1.3.md`. It does not repeat the design.

Two kinds of test cover version 1.3:
- `dev/test.sh` runs the parsers on fixtures, without root and without the network. It is the regression suite.
- Manual runs on the Mac mini cover the parts that need the real system. Reports go to the session temp folder and are never committed.

## Before code

- B1. Record the 1.2 baseline: run `./macassay --quick --offline --skip-du` on `master` and keep the report in the session temp folder for R1.
- B2. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay`; record the counts.

## Reorder (commit 1)

- R0. Commit 1 script comparison: sort the non-heading lines of the 1.2 script and the commit 1 script and diff. Only headings and section-number references may differ.
- R1. Commit 1 report comparison: run 1.2 twice and record the lines that differ (run-to-run noise). Then compare 1.2 and commit 1, sorted with headings stripped, in two runs: `--quick --offline --skip-du` without the sudo rules, and a full run with the rules installed. No difference beyond the noise.
- R2. The report has the 14 sections of the outline, in order, then the Findings and Limitations sections in their 1.2 place. No "Privileged checks" section. Every `h3`, `block`, and `run` label appears under the section that the placement table names. The full run shows no "unbound variable" output and no empty value in a moved block.
- R3. Commit 2 mechanical diff: every changed line is a `finding` call, a report string that said "flags", or the findings table. A test in `dev/test.sh` reads every `finding` call in `macassay`, including calls with a computed severity, and checks that its label is one of the 14 labels.
- R4. No finding text cites a section number that no longer holds the cited content.
- R5. A list of every finding call with its old category, new label, and ID is reviewed by hand before commit 2.
- R6. Every ID in `macassay` is a literal matching `MA-<LABEL>-[0-9]{3}`, where LABEL is one of the 14 labels in capitals, including IDs that `classify_sudoers` prints. Two call sites share an ID only when they report the same risk (reviewed in R5).
- R7. Commit 4 (changes to 1.2 findings): each change in the design list gives its new severity on a fixture or a manual case.

## dev/test.sh (fixture tests)

Each case that touches secret-bearing input plants fake values (`SECRET_A`, `SECRET_B`, ...) and asserts that none appears in the output.

- G1. `mask_hex`: a 32-character and a 64-character hex run become `<ID>`; a 31-character run stays. Separately, `redact_ids` still turns a dashed UUID into `<UUID>`.
- G2. User-domain trust parser: names are kept and masked; `Policy String` lines with an IP address are dropped.
- G3. Credential files: fixtures for each of the eight files, with and without an inline secret, and a Docker config with only `credsStore`, a symlinked file (mode of the target), and an `.npmrc` value of `${NPM_TOKEN}` (no secret). Output shows presence, mode, and inline-secret state; no fake value or profile name appears.
- G4. SSH private key header: an OpenSSH key with cipher `none`, one with `aes256-ctr`, a PEM key with and without `ENCRYPTED`, an OpenSSH key written as one line, and a non-key file. Also a PKCS#8 `BEGIN ENCRYPTED PRIVATE KEY` file, and a private key named `x.pub`, which the public-key check must skip. Fixture keys are generated in the test folder with `ssh-keygen -N` and never leave it. The check never runs `ssh-keygen` on a private key: the test greps the private-key function's source (`type`) for `ssh-keygen`, because the script calls tools by absolute path and a fake on `PATH` would not catch a call.
- G5. SSH client config: `ForwardAgent yes` under `Host *`, under a named host, before the first `Host`, and in an `Include` file outside `~/.ssh`; `StrictHostKeyChecking off` and `StrictHostKeyChecking=no`; host names do not appear in the output.
- G6. Git config: `hooksPath` found; a `[url]` section with a token in the URL does not leak.
- G7. Sudoers content: `NOPASSWD: ALL`, `Defaults !authenticate`, NOPASSWD for `/usr/bin/python3`, NOPASSWD through a `Cmnd_Alias` that holds `/bin/sh`, NOPASSWD for `/usr/bin/ssh-keygen` (not on the list), `Defaults env_keep += "DYLD_LIBRARY_PATH"`; each gives one finding at its severity, with the ID for its risk. The full rule text stays in the finding, as in 1.2.
- G8. Debug-port parser: a fake `ps` line with `--remote-debugging-port=9222` and a token argument gives the program name only; a program name with spaces; `--remote-debugging-pipe` and `--inspect-port` give nothing; `--inspect-brk=0.0.0.0:9229` and `--inspect-wait` match; a launch item with a token argument prints its label and program only; the check's own `grep` or `awk` is not counted.
- G9. Screen-lock parser: `immediate`, `5 seconds`, `900 seconds`, `7200 seconds`, and `off` give the designed severities.
- G10. Boot arguments: empty, `-v`, and `amfi_get_out_of_my_way=1` give none, LOW, and HIGH.
- G11. Update settings: missing keys print the macOS default line; `AutoInstallProductKeys` never appears.
- G12. Native-messaging manifest: a host path in `/tmp` gives MEDIUM, a missing path gives LOW, and a normal path gives nothing.
- G13. Forced extensions: lists in system and per-user managed preferences, in local preferences, and in a Firefox `policies.json`, with the Mac enrolled and not enrolled; each gives the severity in the design table.
- G15. One finding per item: screen lock off gives one finding (not the 1.2 one too); a `NOPASSWD: ALL` rule gives one finding; a `.git-credentials` file gives one finding; an unsigned, user-writable authorization plugin gives one HIGH finding; a PAM module outside `/usr/lib/pam` that the user can write gives one HIGH finding; a debug port running and set in a launch item gives one finding.
- G18. Include loops: an `~/.ssh/config` that includes itself, and two PAM files that include each other, finish and read each file once; an `Include` pattern with `$(touch x)` text creates no file.
- G19. Printer sharing from fixture `cupsd.conf` files: `Listen localhost:631` gives off; `Port 631` and `Listen *:631` give on.
- G16. PAM parser: a bracketed control field, an absolute module path outside `/usr/lib/pam`, and an `include` of another `/etc/pam.d` file.
- G17. User trust: a `TrustRoot` entry, an entry with no result type, and a certificate with zero trust settings count; `Deny` and `Unspecified` entries do not. The admin-domain parser gives the same counts.
- G20. `chain_writable` and NOPASSWD: an admin-writable folder under `/Applications` gives MEDIUM and one under `/Library` gives HIGH; a NOPASSWD rule for a script in a user-writable folder gives HIGH; a home folder and an rc file writable by `staff` give HIGH.
- G21. Recent installs: an install by softwareupdated and an install older than the cutoff are skipped; a nested package list does not break the entry.
- G22. Sudo file owner and mode: stock owner and modes give nothing; another owner, a group write bit, and a sudo without setuid each give a finding.
- G23. Remote-support tools: Apple's screen sharing server (AppleVNCServer) does not count; TeamViewer and vncserver do; sshd does not.
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

- A-SEV The severity review recommends changes to existing and new severities: asked the user; all 25 decisions (A1 to A10, B1 to B14, C1) adopted, itemized in the design doc's decision record.
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


Delta review of the changes after the architecture review, 2026-11-24 (opus, high effort).

- D-1.1 Trust counting misses settings with no result type or zero settings, and the admin domain uses another rule: fixed (SDK default rule for both domains); requirement 8.
- D-1.2 G7 contradicted the design (rule text, `secure_path`): fixed; requirement 8.
- D-1.3 `Include` and PAM include following had no loop guard, and glob expansion was unspecified: fixed (files-read list, depth 16, `compgen -G`, no `%` or `$` patterns); `AGENTS.md` Security Context.
- D-1.4 Launch item output and another account's debug port bind address unspecified: fixed (label and program only; privileged listener list or "unknown", MEDIUM); requirements 7, 8.
- D-1.5 Key header details (31-character cut, PKCS#8 encrypted header, `ENCRYPTED` in the first lines): fixed; requirement 7.
- D-1.6 G4's fake `ssh-keygen` could not catch an absolute-path call; a private key named `*.pub`: fixed in G4.
- D-1.7 Read `cupsd.conf` instead of running `cupsctl`: fixed (simpler, no side effect); requirement 6. How `Port` and `Listen` lines look with printer sharing on is from training knowledge; G19 and a manual check cover it.
- D-2.1 Decisions not itemized with rejected options: fixed (decision record in the design doc); development `AGENTS.md` (Decisions).
- D-2.2 `chain_writable` gives MEDIUM for admin-group write anywhere, while C1 says MEDIUM only for default macOS permissions: asked the user; MEDIUM only under `/Applications`, HIGH elsewhere (decision G3).
- D-2.3 Group-write severities ignore that the default group `staff` holds every user, and root-owned rc files gave HIGH: root-owned files fixed (no finding); group-writable home folders and rc files asked the user; HIGH when the group has other members (decision G1).
- D-2.4 NOPASSWD for a program the user can write stays LOW: asked the user; HIGH (decision G2).
- D-2.5 Two findings for one item still possible: fixed (one item, one finding, at the highest severity; G15 cases); requirement 8.
- D-2.6 Firefox `policies.json` had no severity: fixed (same as managed preferences); requirement 8.
- D-3.1 Category map contradicted the placement table: fixed (label from the check's section, R5 list); requirement 2.
- D-3.2 Comparisons underspecified once rename and IDs land: fixed (commit 1 moves only; commit 2 renames with a mechanical diff); requirement 1.
- D-3.3 R3 and R6 checks would match nothing or miss computed severities and IDs: fixed (literal IDs everywhere; test reads every `finding` call); requirements 2, 10.
- D-3.4 Sorted comparisons miss ordering errors and the privileged blocks: fixed (full run with rules; unbound-variable check); requirement 1.
- D-3.5 The ID definition was undefined for multi-risk call sites, a split finding, and repeated findings: fixed (one ID per risk; split part gets a new ID; per-occurrence export ID; label kept on move); requirement 10.
- D-3.6 Screen lock gap between commits; the other-accounts loop was unplaced: fixed (removal in the Platform commit; loop moves whole to Persistence); requirements 1, 3.
- D-3.7 Report strings still say "flags", and the docs called the Findings section "the Summary": fixed (strings renamed in commit 2; docs say Findings section); `AGENTS.md` Terminology.

## Results

- R0, R1, R2 (commit 1): pass.
- R1 reviewed by hand as noise: process lists, memory and CPU rows, and established outbound connections (live state).
- R1 reviewed by hand as environment: the quick run lists 11 listener rows against 17 in the baseline, and no UDP 69 line. Inferred, not verified: unprivileged `netstat` no longer lists root-owned listeners on this Mac. A rerun of the 1.2 script without the sudo rules matched commit 1.
- R1 reviewed by hand as Mac state: the full run lists new Google Drive and launchd listener rows and no UDP 69 TFTP finding.
- R7 (commit 4), quick and full runs against the commit 3 full run: pass. Changed rows by ID and severity: MA-HEALTH-001 MEDIUM to LOW; MA-PLATFORM-006 LOW to MEDIUM; MA-NETWORK-003 INFO to LOW; the three missing-program firewall rows moved from MA-PLATFORM-008 MEDIUM to MA-PLATFORM-011 LOW. MA-PLATFORM-009 stays MEDIUM (Reduced). No row for MA-PLATFORM-003, MA-BACKUPS-002, MA-APPS-001, MA-PERSISTENCE-006, -009 or -011, MA-ACCOUNTS-005 or -008, or MA-TRUST-001 fired on this Mac. The three MA-ACCOUNTS-006 rows stay LOW. The full run read the other accounts' startup files and gave no finding.
- Final checks on the built branch: `bash -n` passes; ShellCheck gives the same 3 historical findings (SC2010, SC2012) as at the start of Task 16; `dev/test.sh` runs 215 passing cases and no failure.
- M1 (full run, sudo rules installed): pass on time and output. The run took 310 s against 311 s for a full 1.2 run in the same session (the B1 baseline was a quick run, so the 1.2 full time was measured in Task 16). Privileged checks: 17 ran, 0 skipped. Other skipped checks: 3 (the Time Machine settings file, the user TCC database, the system TCC database), all Full Disk Access limits that 1.2 also has. No "unbound variable" or permission-denied text in the run log or report. The new checks print a value or a macOS default line (spot-checked: battery, boot arguments, signed system volume, library validation, quarantine, screen lock, StartupItems, forced extensions, debug ports, SSH options, hooksPath). Not verified: whether a privacy prompt appeared, because the run was headless.
- M2: pass. Each expected row is present at the expected severity: Codex authorization plugin (MA-PERSISTENCE-014) LOW; hidden admin account (MA-ACCOUNTS-013) MEDIUM; world-writable app (MA-PLATFORM-017) MEDIUM; user-domain trust (MA-TRUST-002) MEDIUM with 4 certificates; private keys without a passphrase (MA-CREDENTIALS-004) LOW; screen lock 900 s (MA-PLATFORM-010) LOW; `StrictHostKeyChecking no` for specific hosts (MA-CREDENTIALS-009) LOW; swap (MA-HEALTH-001) LOW; Reduced secure boot (MA-PLATFORM-009) MEDIUM; cloudflared tunnel (MA-NETWORK-003) LOW. The native-messaging finding (MA-APPS-009, LOW) names only Dropbox and Chrome remote-desktop hosts; the Codex folder reports 0 hosts and no host under a Claude folder appears. Totals: HIGH 2, MEDIUM 20, LOW 34, INFO 14. HIGH rows: data volume 98% used (MA-HEALTH-003) and a root daemon whose program is owned by the user (MA-PERSISTENCE-004).
- M3: pass. No `AutoInstallProductKeys` text, no 32-character hex run, and no credential key name followed by a value in the report. A certificate label with a long hex ID shows `<ID>`; UUIDs show `<UUID>`. The IP-address grep gave 40 lines, none in the trust section: 2 version strings (a mount path and a system-extension entry), 3 DNS server lines in Network (existing 1.2 content), 2 `last` login lines in Accounts (existing 1.2 content), the HTTP-probe line in the listener intro, and 32 LAN or loopback rows in the listener and connection tables.
- M4: pass. The battery line reads `none`.
- S1: pass. The full run places the privileged checks in topic sections (packet filter in 4, listeners in 7, background items in 8, sudo files and sudoers contents in 10) and has no "Privileged checks" section. `--print-sudoers` differs from 1.2 only in the version comment line.
- R2 on the final full report: the 14 sections in order after Findings and Limitations; no MISPLACED and no UNLISTED line.
- X1: skipped (SSH to this Mac not available): `ssh -o BatchMode=yes localhost true` failed host key verification, and no setting was changed. Open in `docs/ISSUES.md` with T19.
- L1: open; needs a laptop.

## Task reviews

- Task 1 review, Minor 1: Results line stated an inferred cause as fact and named lsof instead of netstat: fixed; root AGENTS.md (say what was verified).
- Task 1 review, Minor 2: listener row counts disagreed (10 and 11): fixed with Minor 1; no requirement, fixed in the same line.
- Task 1 review, Minor 3: commit trailer names Opus, reviewer expected Sonnet: dropped; the controller specified that trailer, no requirement broken.
- Task 2 review, Minor 1: F15 does not check that a label matches its ID prefix: dropped; no requirement, and the design lets an ID keep its label after its check moves.
- Task 2 review, Minor 2: the F15 call count and the F16 shared-ID list are loose guards: dropped; no requirement.
- Task 3 review, Minor 1: no code comment says why the Drives block is masked: dropped; the commit message holds the reason, no requirement.
- Task 3 review, Minor 2: no test checks that callers apply mask_hex: dropped; the M3 privacy check on a real report covers it, no requirement.
- Task 4 review, Important 1: the startup-pattern split, the Permissive case, and the AppTranslocation exclusion had no fixture or manual case: fixed with rc_pattern_sevs, boot_policy_sev, temp_program and fixture cases; test plan R7.
- Task 4 review, Minor 2: a PASSWD-tagged item after NOPASSWD joins the programs list, so a writable program there can raise the finding: dropped; it over-reports and no requirement is broken; Task 12 replaces the parser.
- Task 4 review, Minor 3: group_has_others reads only the first group with a given GID: dropped; two groups sharing a GID is unusual, no requirement.
- Task 4 review, Minor 4: G20 mocks group_has_others and stat, so the real dscl path has no fixture: dropped; the reviewer ran it by hand, no requirement.
- Tasks 5 and 6 review, Minor 1: the Time Machine exclusion value is printed through say without mdesc: dropped; it is the first word of tmutil output, like the TMENC and LASTBK lines beside it, no requirement.
- Tasks 5 and 6 review, Minor 2: an odd Maximum Capacity value reads as 0% and an absent one as "unknown%": dropped; no requirement, L1 verifies the fields on a laptop.
- Task 8 review, Minor 1: screen_lock_sev treats any text containing "off" as off: dropped; same as the 1.2 check, no requirement.
- Task 8 review, Minor 2: the csrutil "disabled" match is loose on older macOS: dropped; no false HIGH on this macOS, no requirement.
- Task 9 review, Important 1: the vncserver pattern matched Apple's AppleVNCServer: fixed with remote_support_names and G23.
- Task 9 review, Minor 2: an unreadable cupsd.conf was reported as printer sharing off: fixed; root AGENTS.md (unread input).
- Task 9 review, Minor 3: the Listen localhost exclusion is case-sensitive: dropped; CUPS writes lowercase, no requirement.
- Task 12 review, Important 1: a command with its own Runas spec after the first NOPASSWD item was missed: fixed in classify_sudoers with G7 cases; design (one rule, one finding at its highest severity).
- Task 12 review, Important 2: commands after a PASSWD tag counted as passwordless: fixed with Important 1 (same loop); requirement 8 (severities).
- Task 12 review, Minor 3: a wildcard command such as /usr/bin/* stays LOW: dropped; same as 1.2, no requirement.
- Task 12 review, Minor 4: an inline # comment containing NOPASSWD is not stripped: dropped; no wrong severity seen, no requirement.
- Task 12 re-review, Finding 1: a Runas list with a comma, `(root, operator) NOPASSWD: /bin/sh`, was split at the comma and the shell was missed: fixed in classify_sudoers with a G7 case; design (one rule, one finding at its highest severity).
- Task 13 review, Minor 1: a CRLF private key named *.pub reached ssh-keygen -l because the header kept its CR; breaks the no-ssh-keygen-on-private-key constraint: fixed in ssh_key_state, with a G4 fixture.
- Task 13 review, Minor 2: quoted values and `Host * !x` in ssh config are not parsed: dropped; no requirement.
- Task 13 review, Minor 3: passwords that start with `$` are not detected: dropped; no requirement.
- Task 13 review, Minor 4: SSH_SEEN dedupe across scopes: dropped; no requirement.
- Task 7 review: the G11 regex misses an indirect whole-domain read; an empty cutoff would list every install (date -v works on stock macOS); "0 days ago" when the date fails to parse: dropped; no requirement.
- Task 10 review: MA-PERSISTENCE-023 is nearly unreachable (flagged for the final review); a `/usr/lib/pam/../` path is skipped; an unclosed bracket control is not parsed; a PAMD environment variable redirects includes: dropped; no requirement.
- Task 11 review: the Firefox plist key path may be `EnterprisePolicies.*` (to be added to the design assumptions in Task 16); nmh_risk misses the /var/folders and /var/tmp forms; debug_pids matches the flag text in any process's arguments: dropped; no requirement.
- Task 14 review: Minor 1 (a same-line `[core] hooksPath = x` header is not matched, and an inline `# comment` stays in the printed value): dropped; no requirement, and the brief's code has these limits.
- Task 15 review: no findings.

## Pre-merge review

- I1 digest and option specs before a sudoers command hide a code-loading program: fixed; requirement 8, decision B8.
- I2 MA-ACCOUNTS-008 took MEDIUM from chain_writable for admin-group write under /Applications: fixed to HIGH; decision G2.
- I3 ISSUES.md marked `secure_path`, `launchctl print`, and "readable" as built: fixed; AGENTS.md docs describe the code as built.
- M1 MA-PERSISTENCE-023 is unreachable: under the two find roots, a hidden folder above the app puts login items beyond `-maxdepth 5`; dropped, no trigger; its HIGH row in the Severities table gives no coverage.
- M2 auth plugins, PAM modules, debug ports, hidden accounts and home folders give one finding per item while other checks collapse into one: asked the user; kept per item, design decision 2026-11-25 clarifies the rule.
- M3 "flag" used for a finding (SECURITY.md, `ssh_methods_flag`): fixed; AGENTS.md Terminology.
- M4 Firefox key path: confirmed by Mozilla's docs; `EnterprisePoliciesEnabled` not tested: dropped, no requirement; recorded in the design assumptions.
- MA-PLATFORM-008 path with a 13-digit folder number: no finding; not a timestamp, hardware ID, account ID, or secret, and the user needs the path.
- The reviewer saw one piped `dev/test.sh` invocation take over 120 s, cause not found: dropped as uncertain; the suite passed in every run.
- Task 12 re-review notes (nested parentheses, a comma inside parentheses in an argument): the final review agrees with the drop.
- Re-review of the fixes: items 1 to 5 addressed, no new Critical or Important breakage.
- Re-review Minor, the `(ok)` conviction on the 2026-11-25 decision: no change; the controller gave that wording, from the user's "Agreed" to the recommendation.
- Re-review note, an escaped space inside an option value (`CWD=/tmp\ x`) is not stripped: dropped as uncertain; not verified as valid sudoers, and no requirement covers it.
- Re-review note, sudo-rules.md says the renamed function "decides the SSH authentication flag": dropped; a 1.2 design doc that records past design.
