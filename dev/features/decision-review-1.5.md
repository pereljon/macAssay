---
kind: investigation
status: run 2026-11-27 after the v1.5.0 release; A13 to A16 approved by the user 2026-11-27 and applied
---

# Post-release decision review, releases 1.2 to 1.5.0

This file holds the results of the post-release decision review: which recorded decisions the evidence from releases 1.2 to 1.5.0 calls into question. It does not change any decision. A change becomes a new dated entry in the file that owns the decision, after the user approves it.

## Result

One decision has a named premise that the evidence undercuts, and one more goes to the user as a question. The other 59 decisions that an incident touches stand.

- The review found 47 incidents: 15 shipped bugs, 19 late bugs caught before a release, 4 test failures or surprising facts, and 9 things that could not be tested.
- The sources hold 88 decisions. Incidents touch 62 of them: 59 stand, 1 is reopened (R1), 1 is a question for the user (Q1), and 1 was already superseded.
- 26 decisions are untested: no incident touches them, so the review has no evidence about them.
- Every shipped bug traces to a coverage gap or a process issue, not to a wrong decision. The one exception is the `--compare` redaction premise (R1).

## Method

The development session suggested the method, and the user adopted it on 2026-11-27.

1. List the incidents first: shipped bugs, late bugs, test failures, surprising facts, and tests that could not run.
2. Trace each incident to the decisions and the assumptions it touches.
3. Reopen a decision only under the rule in `../AGENTS.md` (Working Rules): new evidence undercuts an assumption the decision names, or its conviction is `ok` or `delegated`.
4. Treat a bug that undercuts no named assumption as a coverage gap or a process issue, not as a wrong decision.
5. Record "none named" for a decision that names no assumption. Strong evidence against such a `firm` decision becomes a question for the user, with no recommendation to reverse it.

An Opus subagent built the incident list and the trace from the Decisions sections of `dev/features/*.md` and `docs/ISSUES.md`, the Key Invariants in `dev/SKELETON.md`, the Design Principles in `AGENTS.md`, `CHANGELOG.md`, the test plans, `dev/HANDOFF.md`, and `git log`. The controller checked R1, Q1, and two "nothing records" claims (I24 and P4) against their sources.

Limits of the review:
- Review rounds produced about 200 fixed findings. Rows I16 to I32 group them by round and theme, and cite each finding ID.
- Two calls are the subagent's judgment: counting N3's "so ... covers it too" as a named assumption, and treating the "Enforced by" line as part of the side-effect decision.
- Version 1.2 has no tag, so whether I1 and I3 shipped in 1.2 is uncertain.
- The premise of decision A2 in `report-1.5.md:46`, "nobody uses macAssay yet", has no evidence either way.

## Questions for the user

### A13. R1: `--compare` redaction premise (reopen)

- Decision (`report-1.5.md:48`, plan review A1, `firm`): the `--compare` file passes through `normalize_file`, "so UUID redaction covers it too".
- Evidence: pre-merge finding N3 (`report-1.5-tests.md:228`). A `\u` escape in the old JSON decodes to a UUID after `normalize_file`, when `JSON.parse` reads it. The fix redacts again in `c()` inside `REPORT_JS` (`macassay:1126`).
- Assumption undercut: that `normalize_file` alone covers redaction for the compare file.
- Still stale: Comparison step 1 (`report-1.5.md:260`) and the No secrets invariant in `dev/SKELETON.md` name only `normalize_file`.
- Recommended: add a dated decision that supersedes the premise (redaction also runs in `c()` after `JSON.parse`), and correct Comparison step 1 and the SKELETON No secrets rule and its "Enforced by" line. The code needs no change.

### A14. Q1: side effects enforced by review only (question)

- Decision (`dev/SKELETON.md:37-50`, `firm`, no named assumption): a run has only the listed side effects. "Enforced by: review."
- Evidence: two unlisted side effects passed every review and shipped.
  - I7: Gatekeeper assessment sent traffic to Apple from 1.1 to 1.3.2, also under `--offline` (`CHANGELOG.md:45`). `nettop` byte counters found it.
  - I6: each privileged check wrote a login record from 1.2 to 1.3.1 (`CHANGELOG.md:60`). Agent test runs have no terminal, so they could not show it.
  - Reviews caught four others before release: Q1-A6, Q3-7, CR-13 (`sudo-rules-tests.md`) and R4 (`fixes-1.3.2-tests.md`).
- Question: should measured side-effect checks become a standing test before each release, named in "Enforced by"? The checks would be the `last` row count after a run under `script`, and `nettop` during an `--offline` run (manual test M2 in 1.4 and 1.5). The rule itself stays unchanged.
- Recommended: yes. The rule failed twice under review alone, and both checks already exist as manual tests.

## Follow-ups that nothing records

The trace found these gaps with no open item in `docs/ISSUES.md`. None of them changes a decision. Each is a candidate for `docs/ISSUES.md`, for the user to accept or drop.

- I24: MA-PERSISTENCE-023 cannot fire, because a hidden folder above the app puts login items beyond `-maxdepth 5`. The 1.3 pre-merge review dropped the finding, but `docs/CHECKS.md` still lists the check as HIGH.
- I12: the `sfltool` block still truncates after the 1.3.1 fix. `docs/ISSUES.md:46` calls it "a 1.4 candidate", but no open item holds it.
- I34 and P7: no test keeps `.gitignore` in step with the `--format` extensions. `../AGENTS.md` (Testing) asks for a cheap test for such files.
- I35: the empty outbound list after unprivileged `netstat` has no note in the report, and it is not in the 1.5 Unreadable evidence table.
- I45: no item tracks checking the remote-access tool names on a real install.
- I47: privacy prompts during a run cannot be observed from a headless session, and no item tracks it.
- P1: test runs from the agent's shell differ from the user's terminal (no terminal, no Full Disk Access). This missed I6. `AGENTS.md` (Workflow) states no rule about where a release test runs.
- P2: several bugs surfaced only on a second Mac (I8, I9, I11, I12, I14, I33). No standing step runs a release candidate on a second Mac.
- P6: locale and byte bugs recur (I1, I3, I4, I30, I31, I32). Targeted fixtures force a UTF-8 locale, but the suite as a whole runs under the caller's locale.

## Evidence

The tables below are the subagent's trace, kept as written. IDs: I = incident, P = process issue, R = reopen, Q = question. Line numbers refer to the files at `d8052e0` (v1.5.0).

### Incidents

| ID | What happened | Release | Evidence | Kind |
|---|---|---|---|---|
| I1 | `redact_ids` ran under the user's locale; BSD `sed` stopped at an invalid byte, and the unredacted report was written | 1.3.0 to 1.4.0 (same code at `v1.3.0:macassay:243,1336` and `v1.4.0:macassay:250,1538`); 1.2 untagged, uncertain | `CHANGELOG.md:11`; `docs/ISSUES.md:15`; AR1 `report-1.5-tests.md:123` | shipped bug |
| I2 | Checks that could not read evidence reported a clean value; failed `profiles status` turned MA-APPS-007 INFO into MA-APPS-005 HIGH; `socketfilterfw` error text suppressed MA-PLATFORM-004 | 1.1 to 1.4.0 | `CHANGELOG.md:12`; `docs/ISSUES.md:16` (failures inferred, code paths read) | shipped bug |
| I3 | Finding text with an invalid UTF-8 byte lost its text (`clean_field` final `sed` without `LC_ALL=C`, `v1.4.0:macassay:72`); on the 1.5 branch the finding was dropped from every format and from `--fail-on` (N1, Critical) | shipped 1.3.0 to 1.4.0; late part on 1.5 branch | `CHANGELOG.md:13`; N1 `report-1.5-tests.md:226` | shipped bug, plus late bug |
| I4 | C1 controls and U+2028, U+2029 passed `clean_field` and `clean_tsv` into every format | 1.4 behavior | `CHANGELOG.md:14`; T7 `report-1.5-tests.md:188`; T10 `:200`, `:229` | shipped bug |
| I5 | All TCP listeners block sorted the `lsof` header into the list (`sort -u`, `v1.3.0:macassay:959`) | 1.3.0 to 1.3.2 | `CHANGELOG.md:52`; `docs/ISSUES.md:13`; `checks-1.4-tests.md:93` | shipped bug |
| I6 | Each privileged check wrote a login record: sudo 1.9.14+ `use_pty` default plus `set_utmp`. Agent test runs had no terminal, so they could not show it | 1.2 to 1.3.1 | `CHANGELOG.md:60`; `docs/ISSUES.md:61`; `fixes-1.3.2.md:30-36`; B2 `fixes-1.3.2-tests.md:63`; M0 `:70` | shipped bug, surprising fact |
| I7 | MA-APPS-002 (`spctl` per app) sent traffic to Apple, also under `--offline`; side effect not listed | 1.1 to 1.3.2 | `docs/ISSUES.md:7`; `checks-1.4.md:194`; `CHANGELOG.md:45` | shipped bug |
| I8 | Non-Apple installs list counted Apple installs (15 against a true 7) | 1.3.0 to 1.3.1 | `CHANGELOG.md:61`; `docs/ISSUES.md:62` | shipped bug |
| I9 | MacBook 1.3.1 run: memory names cut at a space, `.diag` crash kinds not grouped, error text in another account's blocks, bold titles joined to list items | 1.3.0 to 1.3.1 | `CHANGELOG.md:62-65`; `docs/ISSUES.md:63-66` | shipped bug |
| I10 | NOPASSWD for `httpd`, `apachectl` and others rated LOW, not HIGH (`loads_code` incomplete); pre-merge F4 found seven more missing | 1.3.0 | `CHANGELOG.md:71`; `docs/ISSUES.md:41`, `:57` | shipped bug |
| I11 | MA-PERSISTENCE-020 counted Apple's own audio plug-in | 1.3.0 | `CHANGELOG.md:72`; `docs/ISSUES.md:42` | shipped bug |
| I12 | Second-Mac 1.3 run: persistence `?`, NMH repeats, empty install names, empty XProtect versions, `sfltool` repeats, outbound names cut, lost quoting, empty code blocks. `sfltool` block still truncates after the fix | 1.3.0 | `CHANGELOG.md:73-80`; `docs/ISSUES.md:43-50`, `:46`, `:131` | shipped bug |
| I13 | Long hex IDs (a Cloudflare account ID) in certificate labels; found in 1.2 pre-merge, shipped knowingly in 1.2 | 1.1 to 1.2 | `CHANGELOG.md:96`; `docs/ISSUES.md:12`; PM-6 `sudo-rules-tests.md:108` | shipped bug |
| I14 | MA-SHARING-013 matched running processes only; a run missed an installed Chrome Remote Desktop host | 1.3.x | `docs/ISSUES.md:70` | shipped bug (coverage) |
| I15 | Both full reports of 2026-11-26 ran 1.4 code and named 1.3.2 | 1.4 pre-release | `docs/ISSUES.md:79`; `checks-1.4-tests.md:93` | surprising fact |
| I16 | 1.2 reviews: 1.1 bugs (root crontab, `du` glob, startup lines copied, `kmutil` UUIDs, remote `PATH`, option loop) and 1.2 code defects CR-1, CR-2, CR-7, CR-8, CR-12, Q1-A1 to Q1-A7, Q3-1 to Q3-14 | 1.2 branch | `docs/ISSUES.md:8-11`; `sudo-rules-tests.md:90-136` | late bug caught |
| I17 | 1.2 reviews found unlisted side effects: sudo logging (Q1-A6), SSH `nobody` and `du` prompts (Q3-7), remote install logs the script (CR-13), old names (PM-2) | 1.2 branch | `sudo-rules-tests.md:118`, `:126`, `:102`, `:104` | late bug caught |
| I18 | 1.2 sudo safety: remote mode ran as root (CR-3), rollback claimed a failed restore (CR-5), user named `ALL` (CR-11), rollback left a bad file (PM-1) | 1.2 branch | `sudo-rules-tests.md:92`, `:94`, `:100`, `:103` | late bug caught |
| I19 | Secure boot flag read the CSEC line, so every Full Security Mac would get MEDIUM (T9-1); found from real `bputil` output | 1.2 branch | `sudo-rules-tests.md:109`, `:155` | late bug, surprising fact |
| I20 | The handoff's probe `sudo -n -k -l` passes every check for a user with `(ALL) ALL` | 1.2 design | `sudo-rules.md:59` | surprising fact |
| I21 | 1.3 design reviews: 25 severity changes (A-SEV), private-key and argument leaks in the design (A2-1 to A2-3), `cupsctl` side effect (A3-1), parser gaps (A4-1 to A4-8), placement (A5-1 to A5-4), delta review D-1.1 to D-3.7 | 1.3 design | `checks-1.3-tests.md:83-126` | late bug caught |
| I22 | 1.3 task reviews: untested pattern split (T4 I1), `vncserver` matched AppleVNCServer (T9 I1), unreadable `cupsd.conf` read as off (T9 M2), `classify_sudoers` misses (T12 I1, I2, re-review), CRLF private key reached `ssh-keygen` (T13 M1) | 1.3 branch | `checks-1.3-tests.md:154`, `:162`, `:163`, `:165-169`, `:170` | late bug caught |
| I23 | 1.3 pre-merge: digest specs hid a code-loading program (I1), MA-ACCOUNTS-008 MEDIUM for admin write (I2), ISSUES marked unbuilt items built (I3), per-item findings (M2), "flag" wording (M3) | 1.3 branch | `checks-1.3-tests.md:182-187` | late bug caught |
| I24 | MA-PERSISTENCE-023 cannot fire (beyond `-maxdepth 5`); dropped, no trigger; `docs/CHECKS.md:171` still lists it as HIGH | 1.3.0 to 1.5.0 | M1 `checks-1.3-tests.md:185` | surprising fact |
| I25 | 1.3.1 pre-merge: `block` blank test took about a minute under a UTF-8 locale (F1); P4 assertion ran outside `check` (F2) | 1.3.1 branch | `docs/ISSUES.md:54-55` | late bug, test failure |
| I26 | 1.3.2 review: `drop_enoent` hid a crafted file name (R1), Rosetta prompt installs (R2), `Defaults!MACASSAY` also covers an admin's own commands (R4), Q6 skipped `privblk` (R5), CRLF in `ssh-keygen` errors (M3a), Account heading (M3b) | 1.3.2 branch | `fixes-1.3.2-tests.md:48-52`, `:57-58` | late bug caught |
| I27 | 1.4 review: taps path wrong on Intel (F1), matches missing from report (F2), R8 and R4 could not fail (F4), `splashtop` matched viewers and GoTo matched nothing (F5), unverified cause in MA-UPDATES-011 (F6) | 1.4 branch | `checks-1.4-tests.md:74-79` | late bug caught |
| I28 | 1.5 architecture review: bundle meta reached shell arithmetic (AR2, Critical), contains-match acceptance (AR3), skipped read as resolved (AR4), managed booleans never fire (AR5), OCSF uid (AR7), V1 at release commit (AR8), unknown enrollment (AR10), no-data exit status (AR12) | 1.5 design | `report-1.5-tests.md:124-134` | late bug caught |
| I29 | 1.5 plan review: plan code that would fail the suite or could not fail (PR1 to PR12, PR14 to PR17); `--compare` file not redacted (PR13) | 1.5 plan | `report-1.5-tests.md:142-159` | late bug caught |
| I30 | macOS `iconv -c` keeps `F4 90..` and `F5..FF` sequences, so its output is not valid UTF-8 (T2), contrary to the verified fact at `report-1.5.md:62` | 1.5 branch | `report-1.5-tests.md:167` | surprising fact |
| I31 | 1.5 task reviews: MA-BACKUPS-004 missing from a skip row (T3), wrong guidance commands (T4), `md,` accepted (T6), an invalid byte in `--accepted` accepted every finding with the ID (T9), `c()` kept C1 controls (T10), `--fail-on ""` turned the gate off (T11), NUL byte passed the bundle reader (T12) | 1.5 branch | `report-1.5-tests.md:172`, `:176`, `:185`, `:195`, `:199`, `:205`, `:208` | late bug caught |
| I32 | 1.5 pre-merge: `clean_tsv` deletion rejoined a split UUID (N2); a `\u` escape in the `--compare` file decoded to a UUID after redaction (N3); `--compare` with only csv or ocsf gave nothing; two guidance lines; `docs/FORMATS.md` claim | 1.5 branch | `report-1.5-tests.md:227-233` | late bug caught |
| I33 | Every remote run reported its own `bash -c` process as MA-APPS-004, because the script text holds guidance naming `--remote-debugging-port`. Found by M5, the first run against a second Mac. A 1.3 review finding on the same mechanism was dropped | 1.5 branch | M5 `report-1.5-tests.md:259`; `report-1.5.md:53`; commit `0d964ae`; dropped finding `checks-1.3-tests.md:176` | late bug caught |
| I34 | `.gitignore` missed the new 1.5 report formats (A7 in M5). No report was committed (`git log --all` over the report patterns: no commit) | 1.5 branch | `report-1.5-tests.md:259`; commit `0d964ae` | late bug caught |
| I35 | Unprivileged `netstat` lists no sockets on the development Mac; listeners fall back to the user's own `lsof`, and the outbound list comes out empty without a note | 1.2 to 1.5.0, open | `docs/ISSUES.md:14`; `checks-1.3-tests.md:132` | surprising fact, open |
| I36 | Activation Lock read `Disabled` with Find My on, on a formerly ABM-assigned MacBook; the design assumed `Enabled` | 1.4 | `checks-1.4.md:63`; M3 `checks-1.4-tests.md:92`; `docs/ISSUES.md:134` | surprising fact |
| I37 | Piping `dev/test.sh` waits about 60 s (watchdog `sleep` holds the pipe). 1.3 pre-merge dropped the symptom as uncertain | 1.3 to 1.5.0, open | `docs/ISSUES.md:120`; `checks-1.3-tests.md:190` | test failure |
| I38 | Sudo rule `/bin/cat /etc/sudoers.d/macassay` is unused: the audit skips that file | 1.2 to 1.5.0 | `docs/ISSUES.md:98` | surprising fact |
| I39 | Remote mode against a second Mac not run for 1.2 to 1.4 (T19, X1, first M5 attempt) | 1.2 to 1.4 | `sudo-rules-tests.md:158`; `checks-1.3-tests.md:142`; `report-1.5-tests.md:260`; resolved `docs/ISSUES.md:121` | untestable (resolved 2026-11-27) |
| I40 | Root `profiles list` output with a device profile installed never checked (CR-4, T8) | 1.2 to 1.5.0 | `sudo-rules-tests.md:154`; `docs/ISSUES.md:20` | untestable |
| I41 | Enrolled-Mac test M8 not run | 1.5 | `docs/ISSUES.md:139`; `report-1.5-tests.md:261` | untestable |
| I42 | Safari test M6 and the CSS `:has()` filter not run | 1.5 | `docs/ISSUES.md:116`; `report-1.5-tests.md:266` | untestable |
| I43 | `tmutil destinationinfo` exit status with no destination not checked | 1.5 | `docs/ISSUES.md:118`; `report-1.5.md:50`, `:92` | untestable |
| I44 | Of the unreadable-evidence cases, only Time Machine settings was seen live (M7) | 1.5 | `docs/ISSUES.md:119`; `report-1.5-tests.md:258` | untestable |
| I45 | Remote-access tool names from training knowledge and web research; none checked on an install | 1.4 | `checks-1.4.md:64`; `checks-1.4-tests.md:68` | untestable |
| I46 | Open 1.3 assumptions: `DiscoverableMode` `Everyone` and `Off`, Chromium key paths, `nvram boot-args` on Intel | 1.3 | `checks-1.3.md:95-97`; `docs/ISSUES.md:122` | untestable |
| I47 | Privacy prompts during a run cannot be observed from a headless session | 1.2, 1.3 | `sudo-rules-tests.md:148`; `checks-1.3-tests.md:136` | untestable |

Excluded from the list: `docs/ISSUES.md:128` (`[h]` folder rename, a chore) and `:97` (`[-]` export moved to 1.5, a scope move). Neither describes something that went wrong.

### Decisions touched by an incident

Conviction "firm*" means no level is recorded, so it counts as firm.

| Decision (source) | Date | Decision | Conviction | Named assumptions | Incidents | Outcome |
|---|---|---|---|---|---|---|
| `sudo-rules.md:35` | 2026-11-24 | Approach B, per-command rules | ok | "B keeps root away from the code that parses untrusted input"; A rejected "for needing a reinstall on every script update" | I6, I38 | stands: I6 was a sudo default fixed by `!set_utmp`; one reinstall in five releases (`CHANGELOG.md:56`) does not undercut the A comparison |
| `sudo-rules.md:36` | 2026-11-24 | Run each command with `sudo -n -k`; classify refusals | firm* | probe "parses verbose output, and it costs a second sudo call" | I20, I6 | stands: I20 supports it |
| `sudo-rules.md:37` | 2026-11-24 | Rules name each file; no regex | firm* | regex needs "sudo 1.9.10 or later, and older macOS versions are unverified" | I38 | stands: the unused rule is a read of a policy file |
| `sudo-rules.md:39` | 2026-11-24 | A1: audit refuses root | ok | none named | I16, I18 | stands: the 1.1 root bugs support it |
| `sudo-rules.md:40` | 2026-11-24 | A2: other accounts, metadata only | ok | `cat` rules "give standing password-free read access to files that often hold tokens" | I9 | stands: I9 (error text) was an output filter miss |
| `sudo-rules.md:41` | 2026-11-24 | A3: dispatch, skip record for every check, `dev/test.sh` | ok | none named | I2, I22 | stands: coverage gap (checks that failed silently never called `skip`) |
| `sudo-rules.md:42` | 2026-11-24 | B1, B2: 1.1 fixes plus root-run program check | ok | none named | I16 | stands |
| `sudo-rules.md:43` | 2026-11-24 | Root-run program check MEDIUM for admin-group write anywhere | ok | HIGH for all "buried the one direct case" | I16 (CR-7), I21 (D-2.2), I23 (I2) | superseded by `checks-1.3.md:55` (G3) and `:43` (C1) |
| `sudo-rules.md:44` | 2026-11-24 | Own crontab: schedule and command name only | firm* | none named | I16 (CR-2) | stands |
| `sudo-rules.md:45` | 2026-11-24 | Root refused for every mode except local install | firm* | none named | I18 (CR-3) | stands |
| `sudo-rules.md:46` | 2026-11-24 | Report replaces every dashed UUID | firm* | none named | I1, I32 | stands: implementation and test miss (F11 tested case only, `sudo-rules-tests.md:27`) |
| `sudo-rules.md:50` | 2026-11-24 | `profiles list` instead of `show` | ok | "That `list` prints no payload contents is not yet verified" | I40 | stands, unverified |
| `sudo-rules.md:51` | 2026-11-24 | Installer stops on failed backup; recovery without sudo | ok | none named (recovery relies on `sudo-rules.md:85`, untested) | I18 | stands |
| `sudo-rules.md:52` | 2026-11-24 | Granted user must not look like an alias or `ALL` | ok | "A rule for user `ALL` grants the commands to every account" | I18 | stands |
| `sudo-rules.md:53` | 2026-11-24 | Rollback removes the file when it cannot restore | firm* | none named | I18 | stands |
| `checks-1.3.md:34` (and `docs/ISSUES.md:179`) | 2026-11-24 | 1.3 takes every check group in one release | firm* | splitting "repeats the design and review cycle for the lowest-risk checks" | I8, I10, I11, I12 | stands: the 1.3.1 and 1.3.2 bugs came from single-Mac testing (process issue P2), not from the bundle |
| `checks-1.3.md:36` | 2026-11-24 | Reorganize by theme | firm* | "The reorder is mechanical because all privileged data is collected before section 1" | I21 | stands |
| `checks-1.3.md:38` | 2026-11-24 | Inventory: count and unusual items; collapse repeats | firm* | none named | I12, I23 (M2) | stands; clarified by `:46` |
| `checks-1.3.md:39` | 2026-11-24 | Secret presence from key names and headers only | firm* | none named | I21, I22 (T13 M1) | stands |
| `checks-1.3.md:42` (record `:52-57`) | 2026-11-24 | Review severities adopted (A1 to C1, G1 to G3, R1) | firm* | none named | I10 (B8), I23, I2 (B3) | stands: I10 was an incomplete list; I2 was missing-evidence handling |
| `checks-1.3.md:43` | 2026-11-24 | C1 passwordless root scale | firm* | HIGH for both "gives 9 HIGH findings on this Mac" | I21, I23 | stands |
| `checks-1.3.md:44` | 2026-11-24 | Stable IDs `MA-<LABEL>-NNN` | firm* | none named | I24, I29 (PR6, PR12) | stands |
| `checks-1.3.md:45` | 2026-11-24 | `flag` renamed `finding` | firm* | none named | I21 (D-3.7), I23 (M3) | stands |
| `checks-1.3.md:46` | 2026-11-25 | One finding per item when each needs its own fix | ok | none named | I23 (M2) | stands |
| `fixes-1.3.2.md:84` | 2026-11-25 | `!set_utmp`, keep `use_pty` | firm | whether `set_utmp` works in a command-scoped Defaults (`fixes-1.3.2.md:51`); verified by M2, M4 | I6, I26 (R4) | stands |
| `fixes-1.3.2.md:85` | 2026-11-25 | Installer folder check in one sudo call | firm | none named | I6 | stands |
| `fixes-1.3.2.md:86` | 2026-11-25 | Apple install only by Apple process or App Store/Rosetta with `com.apple.` ID | firm* | "any package can claim a `com.apple.` ID" (`:64`) | I8, I26 (R2) | stands |
| `checks-1.4.md:39` | 2026-11-26 | A5: no cask notarization check | ok | "MA-APPS-002 already runs `spctl -a -t exec` on every app" | I7 | stands |
| `checks-1.4.md:40` | 2026-11-26 | A8: taps and casks from local files | ok | "`brew info` can download API data when its local copy is stale" | I27 (F1) | stands: F1 was a path bug |
| `checks-1.4.md:41` | 2026-11-26 | A7, A9: network promise; skip MA-APPS-002 offline | ok | "MA-APPS-002 ... sends traffic to Apple" | I7 | stands: 1.5 M2 pass (`report-1.5-tests.md:263`) |
| `report-1.5.md:39` | 2026-11-26 | Collect and render separately; remote renders locally | firm (A5) | the accepted-risk file and old JSON "live on the local Mac" | I28 (AR2), I29 (PR14), I31 (T12), I39 | stands: M5 pass |
| `report-1.5.md:40` | 2026-11-26 | OCSF Compliance Finding, 1.10.0 | firm (A5) | 1.3.0 "requires the `cloud` and `osint` attributes" | I28 (AR7) | stands |
| `report-1.5.md:41` | 2026-11-26 | JSON and OCSF via JXA `JSON.stringify` | firm (A5) | "`JSON.stringify` escapes every character correctly by construction" | I4 (T7) | stands: raw U+2028 is valid JSON; the fix was in `clean_field` |
| `report-1.5.md:42` | 2026-11-26 | HTML and CSV via `awk`, one escaper each | firm (A5) | "`md_html` must escape the evidence in `awk` anyway" | I32 (FORMATS claim) | stands |
| `report-1.5.md:43` | 2026-11-26 | Bundle is five fixed lines | firm (A5) | none named | I29 (PR14), I31 (T12) | stands |
| `report-1.5.md:44` | 2026-11-26 | Managed values from `/Library/Managed Preferences` files | firm (A5) | `defaults read DOMAIN` "does not merge managed values" (verified) | I28 (AR5), I41 | stands; device-level path unverified (`report-1.5.md:90`) |
| `report-1.5.md:46` | 2026-11-26 | A2: no 1.4.1 for the redaction bug | firm | "nobody uses macAssay yet" | I1 | stands: no evidence on usage either way (uncertain); moot after 1.5.0 |
| `report-1.5.md:47` | 2026-11-26 | A3: unreadable evidence is a skip, not INFO | ok | "an unreadable file is a limit of the audit" | I2, I35, I44 | stands |
| `report-1.5.md:48` | 2026-11-26 | Plan review A1: `--compare` file through `normalize_file` | firm | "so UUID redaction covers it too" | I29 (PR13), I32 (N3) | **reopen**: N3 shows the premise false for JSON escapes (section 4) |
| `report-1.5.md:49` | 2026-11-26 | A4: remove sequences `iconv -c` keeps | firm | "the added steps keep every valid character up to U+10FFFF and still join a split UUID" (verified) | I30, I32 (N2) | stands: N2 was a later step that rejoined a UUID |
| `report-1.5.md:50` | 2026-11-26 | Time Machine destinations keep 1.4 behavior | firm* | "the exit status of `tmutil destinationinfo` with no destination is unverified" | I43, I28 (AR12) | stands, pending verification |
| `report-1.5.md:51` | 2026-11-26 | Time Machine settings skip lists MA-BACKUPS-002 to 004 | firm* | none named | I31 (T3), I44 | stands |
| `report-1.5.md:52` | 2026-11-26 | A5: `--compare` with only csv or ocsf is exit 2 | firm | none named | I32 | stands |
| `report-1.5.md:53` | 2026-11-27 | A6: debug port check skips own process tree | firm | "any later script text could trip the check again" | I33 | stands |
| `report-1.5.md:54` | 2026-11-26 | A4: `--fail-on` opt-in, exit 3 | ok | "exit 2 already means a usage error" | I31 (T11) | stands |
| `docs/ISSUES.md:181` | 2026-11-25 | HTML: no JavaScript, CSS only, blocking CSP | ok | "a script turns an escaping bug into code execution" | I42 | stands, unverified in Safari |
| `docs/ISSUES.md:182` | 2026-11-25 | 1.3.1 patch before 1.4 | firm | none named | I10, I11, I12 | stands |
| `docs/ISSUES.md:183` | 2026-11-25 | 1.3.2 patch before 1.4 | firm* | none named | I6, I8, I9 | stands |
| `docs/ISSUES.md:189` | 2026-11-26 | `docs/CHECKS.md` reference, fixture D1 | firm* | none named | I24, I29 (PR12) | stands |
| `dev/SKELETON.md:37-50` | invariant | Only the listed side effects; "Enforced by: review" | firm* | none named (Reason: users depend on the Macs) | I6, I7, I17, I26 (R4) | **question for the user** on the enforcement line (section 4); the rule itself stands |
| `dev/SKELETON.md:52-58` | 2026-11-26 | Network promise | firm* | none named | I7 | stands |
| `dev/SKELETON.md:60-66` | invariant | Text from the audited Mac is data | firm* | none named | I3, I4, I28 (AR3), I33 | stands |
| `dev/SKELETON.md:68-81` | invariant | No secrets in the report | firm* | none named | I1, I13, I16, I21, I32 | stands |
| `dev/SKELETON.md:83-89` | invariant | Least privilege | firm* | none named | I16 (Q3-14), I18, I38 | stands |
| `dev/SKELETON.md:91-97` | invariant | Data files untrusted until validated | firm* | none named | I28 (AR2), I29 (PR14), I31 (T12) | stands |
| `dev/SKELETON.md:99-105` | invariant | Stock macOS only | firm* | none named (Reason: "must run on any Mac without an install") | I1, I3, I25 (F1), I30, I31 (T9), I32 (N2) | stands; recurring cost noted under P6 |
| `dev/SKELETON.md:107-113` | invariant | Stable finding IDs | firm* | none named | I24, I29 | stands |
| `AGENTS.md:9` | principle | Read-only | firm* | none named | I6, I7, I17 | stands |
| `AGENTS.md:10` | principle | Stock macOS only | firm* | none named | as SKELETON `:99` | stands |
| `AGENTS.md:11` | principle | No secrets in the report | firm* | none named | as SKELETON `:68` | stands |
| `AGENTS.md:12` | principle | Least privilege | firm* | none named | as SKELETON `:83` | stands |

### Coverage gaps and process issues

#### Per incident (all incidents except the N3 part of I32 trace to no named assumption)

| Incident | Classification | Follow-up recorded |
|---|---|---|
| I1 | coverage gap: test miss (no invalid byte under a UTF-8 locale in F11) | fixed; fixture P1 (`docs/ISSUES.md:15`, `dev/SKELETON.md:81`) |
| I2 | coverage gap: implementation miss of `sudo-rules.md:41` | fixed; live evidence open at `docs/ISSUES.md:118`, `:119`; diagnostic log idea `:100` |
| I3 | coverage gap: implementation miss | fixed; fixture N1 (`dev/test.sh:1241`) |
| I4 | coverage gap: implementation miss | fixed (`report-1.5-tests.md:229`) |
| I5 | coverage gap: test miss (visible only in a full run with sudo rules) | fixed (`docs/ISSUES.md:13`) |
| I6 | coverage gap: test miss (no terminal in agent runs); process P1, P3 | fixed (`docs/ISSUES.md:61`); no standing test: nothing records |
| I7 | coverage gap: side effect never measured; process P3 | fixed (`docs/ISSUES.md:7`); M2 per release only: nothing records a standing rule |
| I8, I9, I11 | coverage gap: test miss (data seen only on another Mac); process P2 | fixed (`docs/ISSUES.md:62-66`, `:42`) |
| I10 | coverage gap: implementation miss (incomplete list) | fixed (`docs/ISSUES.md:41`, `:57`) |
| I12 | coverage gap: test miss; process P2 | fixed (`docs/ISSUES.md:43-50`); the remaining `sfltool` truncation ("a 1.4 candidate", `:46`) is in no open item: nothing records |
| I13 | coverage gap, shipped knowingly in 1.2 | fixed (`docs/ISSUES.md:12`) |
| I14 | coverage gap: design scope | fixed in 1.4 (`docs/ISSUES.md:70`) |
| I15 | process issue: no version marker between releases | fixed by A15 (`docs/ISSUES.md:79`, fixture V1) |
| I16, I18, I21, I22, I23, I26, I28, I31 | coverage gaps caught by review before release | fixed; recorded in each tests doc |
| I17 | process P3 (review caught these) | fixed (`sudo-rules-tests.md`) |
| I19 | coverage gap: fixture built from a guessed format | fixed; F7 now follows real output (`sudo-rules-tests.md:155`) |
| I20 | surprising fact; handled by `sudo-rules.md:36` | n/a |
| I24 | coverage gap: dead check | dropped; `docs/CHECKS.md:171` still lists it as HIGH: nothing records |
| I25 | F1 implementation miss; F2 test defect (process P5) | fixed (`docs/ISSUES.md:54-55`) |
| I27 | implementation misses; F4 test defect (process P5) | fixed; tool names still unchecked (I45) |
| I29 | coverage gap: plan defects, caught by running the plan code | fixed |
| I30 | surprising fact (a verified fact was incomplete); led to `report-1.5.md:49` | fixed |
| I32 | coverage gaps caught pre-merge; N3 part is R1 above | fixed |
| I33 | coverage gap: remote mode untested until M5; process P2, P4 | fixed (A6, fixture G8) |
| I34 | process issue P7 | fixed in `0d964ae`; no test keeps `.gitignore` in step with `--format`: nothing records |
| I35 | coverage gap, open | `docs/ISSUES.md:14` records the bug. No item ties the empty outbound list to requirement 9; it is not in the Unreadable evidence table (`report-1.5.md:356-370`) |
| I36 | coverage gap: design assumption from training knowledge; no code impact | resolved (`docs/ISSUES.md:134`) |
| I37 | test harness defect; process P4 (dropped as uncertain in 1.3) | open (`docs/ISSUES.md:120`) |
| I38 | coverage gap: generator adds a rule the audit never uses | deferred to the next rules change (`docs/ISSUES.md:98`) |
| I39 | untestable; process P2 | resolved (`docs/ISSUES.md:121`); no standing second-Mac step: nothing records |
| I40 | untestable | only inside resolved item `docs/ISSUES.md:20`; no open item |
| I41 | untestable | `[h]` `docs/ISSUES.md:139` |
| I42 | untestable | `[h]` `docs/ISSUES.md:116` |
| I43 | untestable | `[h]` `docs/ISSUES.md:118` |
| I44 | untestable; process P1 | `[h]` `docs/ISSUES.md:119` |
| I45 | untestable | none: `checks-1.4.md:64` says a miss shows only on a Mac with the tool; nothing records |
| I46 | untestable | open `docs/ISSUES.md:122` |
| I47 | untestable | nothing records |

#### Process issues

- P1. Test runs from the agent's shell differ from the user's terminal: no terminal, no Full Disk Access, tmux. This missed I6 and limited I44; I35's cause may also be the process tree (open). Later tests moved to `script` (`fixes-1.3.2-tests.md:33`) and to the user's iTerm (`report-1.5-tests.md:262-265`). `AGENTS.md` Workflow (`:39-44`) states no rule: nothing records.
- P2. Testing on one development Mac. I8, I9, I11, I12, and I14 surfaced only in runs on another Mac. I33 surfaced on the first run against a second Mac. I27 F1 (Intel path) was found by review only. No standing pre-release run on a second Mac: nothing records.
- P3. Side effects enforced by review only. This is Q1 above.
- P4. Review findings dropped under the triage rule (`../AGENTS.md`, Review findings) later surfaced:
  - `debug_pids` matching flag text in any process (`checks-1.3-tests.md:176`) became I33.
  - The piped `dev/test.sh` delay (`:190`) became I37.
  - The unreachable MA-PERSISTENCE-023 (`:185`) is I24.
  - One of about 60 dropped findings became a bug, and it was caught before release. This is weak evidence, so it is not a question item. Nothing records it.
- P5. Tests that could not fail: 1.3.1 F2 (`docs/ISSUES.md:55`), 1.4 F4 (`checks-1.4-tests.md:77`), and PR9, PR10 (`report-1.5-tests.md:150-151`). Review caught each one. 1.4 used a mutation run, but no standing practice is recorded.
- P6. Locale and byte handling under bash 3.2 with BSD tools recurs in I1, I3, I4, I25 (F1), I30, I31 (T9), and I32 (N2). Targeted fixtures force a UTF-8 locale (`dev/test.sh:855`, `:1236`). The suite as a whole runs under the caller's locale. Whether other text functions still fail under a UTF-8 locale is uncertain. Nothing records a suite-wide UTF-8 run.
- P7. `.gitignore` had to be updated by hand for each new report format (I34). `../AGENTS.md` (Testing) asks for a cheap test that keeps such files in step. Nothing records one.
- Working as intended: docs drift caught at review (PM-3, CR-12, 1.3 I3, 1.4 F9, the 1.5 `docs/FORMATS.md` claim). The Change Checklist gate caught each one; no follow-up is needed.

### Untested decisions and unverified assumptions

Untested (touched by no incident), by file:

- `sudo-rules.md`: 4 (`:38`, `:47`, `:48`, `:49`). `:48` was superseded by the 1.3 severities (`checks-1.3.md:231`).
- `checks-1.3.md`: 4 (`:35`, `:37`, `:40`, `:41`). `:40` was superseded by `:42` where they differ.
- `fixes-1.3.2.md`: 0.
- `checks-1.4.md`: 4 (`:35`, `:36`, `:37`, `:38`).
- `report-1.5.md`: 2 (`:38`, `:45`).
- `docs/ISSUES.md`: 11 (`:174`, `:175`, `:176`, `:177`, `:178`, `:180`, `:184`, `:185`, `:186`, `:187`, `:188`). `:180` was superseded by `:184`.
- `dev/SKELETON.md`: 1 (status line, `:115-121`).
- `AGENTS.md`: 0.

None of the 26 untested decisions has an assumption marked unverified. The docs mark these assumptions unverified for touched decisions:

- `sudo-rules.md:37`: regex arguments on older macOS ("unverified").
- `sudo-rules.md:50`: `profiles list` prints no payload contents (T8 needs a device profile).
- `sudo-rules.md:51`: the `osascript` recovery path works when sudoers fails to parse (`sudo-rules.md:85`, training knowledge, not tested).
- `report-1.5.md:44`: device-level managed preferences path (`:90`) and firewall payload keys (`:93`); waits for an enrolled Mac (M8).
- `report-1.5.md:47`: failure exit status of the four state commands (`:92`).
- `report-1.5.md:50`: `tmutil destinationinfo` exit status with no destination (`docs/ISSUES.md:118`).
- `report-1.5.md:40`: one OCSF event per line is training knowledge (`:95`); object facts were not re-read during the build (`:79`).
- `docs/ISSUES.md:181`: CSS `:has()` in Safari (`report-1.5.md:89`, `:94`; M6).
- `checks-1.3.md:42` (B3): Chromium forced-extension key paths (`:96`); Firefox `EnterprisePoliciesEnabled` not tested (`:98`).

Design assumptions marked unverified that belong to no Decisions entry: `DiscoverableMode` `Everyone` and `Off`, and `nvram boot-args` on Intel (`checks-1.3.md:95`, `:97`); remote-access tool names (`checks-1.4.md:64`); `du` privacy prompts (`sudo-rules.md:87`).
