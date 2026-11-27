# Test plan: report formats, run comparison, and managed Macs

This file holds the test cases, review findings, results, and research sources for `report-1.5.md`. It does not repeat the design.

Two kinds of test cover version 1.5:
- `dev/test.sh` runs the new functions on fixtures, without root and without the network. The new cases are P1 to P16.
- Manual runs on the development Mac and the MacBook cover real output. Reports go to the session temp folder and are never committed.

## Before code

- B1. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay` on `master`, and record the counts.

## dev/test.sh (fixture tests)

A fixture run folder holds `meta.tsv`, `findings.tsv`, `skipped.tsv`, and `body.md`. Its hostile values are used in P1 to P8:
- A finding text with `<script>alert(1)</script>`, `"`, `'`, `&`, and `\`.
- A text that starts with `=HYPERLINK(` and one that starts with `-`.
- Invalid UTF-8 bytes, a dashed UUID, and non-ASCII text (`é`).
- An evidence line with `<img src=x onerror=alert(1)>`, `**bold**` around attacker text, and `[link](http://x)`.

Cases:

- P1. Normalize, run under `LC_ALL=C.UTF-8`:
  - The output files hold valid UTF-8, no dashed UUID, and the non-ASCII text unchanged.
  - Lines after an invalid byte are kept, and a UUID on such a line is redacted.
  - A UUID split by an invalid byte (`12345678<0xFF>-1234-...`) is redacted after `iconv -c` joins it.
  - When the redaction step fails, no report file is written and the exit status is 1.
- P2. Markdown:
  - The 1.4 layout holds, with the Source column and the Management line.
  - The Guidance list holds one line per ID present.
  - With an empty `findings.tsv`, the report reads `No automatic findings.`
- P3. JSON:
  - `osascript` `JSON.parse` and `plutil -convert xml1 -o /dev/null` accept the output. (`plutil -lint` rejects every JSON file; changed 2026-11-26 after the plan review, PR2.)
  - Each hostile text round-trips unchanged after normalization.
  - `schema` is `macassay-report/1`, and the counts match the fixture.
- P4. OCSF:
  - Each line parses as JSON.
  - Each event holds the required 1.10.0 attributes with the mapped values.
  - A skipped check maps to `compliance.status_id` 2, and an accepted finding to `status_id` 3.
- P5. HTML:
  - No `<script`, `<img`, or `href="http` appears outside the fixed page text, and no tag carries an event handler attribute (`on...=`). (The escaped text `onerror=` may appear; changed 2026-11-26 after the plan review, PR4.)
  - The escaped forms (`&lt;script&gt;`) appear.
  - The CSP meta tag is the first element in `<head>`.
  - Each finding row links to an existing section anchor.
- P6. `md_html` converts each construct that macAssay writes: headings, a bold line, a fenced block, a list item, a table with inline code, and a plain line. A fence inside text stays text.
- P7. CSV:
  - Each field is quoted, and inner quotes are doubled.
  - `=HYPERLINK(` and `-` gain a leading `'`.
  - Field counts are equal on every line.
- P8. Formats and paths:
  - `--format md,json,html` with `-o base` writes `base.md`, `base.json`, and `base.html`.
  - One format with `-o file.txt` writes `file.txt`.
  - `--stdout` with two formats exits 2.
  - An unknown format name exits 2.
- P9. Accepted risks:
  - A line with an ID only accepts every finding with that ID.
  - A match text accepts only a finding whose whole text equals it. A finding whose text only contains it stays open.
  - A match text with regex characters (`.*`) matches as a fixed string.
  - A syntactically valid ID that `GUIDANCE` does not list exits 2.
  - A reason with a pipe, a backtick, or `<script>` reaches each format escaped.
  - Comments and blank lines are ignored.
  - A bad ID exits 2 before any audit work.
  - Accepted findings leave the open counts and the exit status.
- P10. Comparison: fixture old and new JSON files give the expected groups.
  - An ID only in the new file is New, and an ID only in the old file is Resolved.
  - An ID only in the old file that a skipped check in the new run lists is Not checked, not Resolved.
  - A file without the schema key exits 2.
  - A dashed UUID in the old file is redacted in `changes.tsv`.
  - An old file with invalid UTF-8, or a text with a tab or newline, gives one clean line per finding in `changes.tsv`.
  - A hostile text in the old file is escaped in the Markdown and HTML output.
- P11. Exit status: the fixture has one MEDIUM and one LOW finding.
  - `--fail-on medium` exits 3, and `--fail-on high` exits 0.
  - An accepted MEDIUM with `--fail-on medium` exits 0.
  - A bad level exits 2.
- P12. Bundle:
  - A round trip of the fixture folder through the bundle writer and `read_bundle` gives identical files.
  - Each of these is rejected with exit 1: a wrong first line, too few or too many lines, trailing data without a newline, and a line with characters outside base64 (such as `abc$%`).
  - No file appears outside the temporary folder.
- P12a. Validation, on a fixture folder with hostile values:
  - A `meta.tsv` count of `a[$(touch PWNED)]` is dropped, and no `PWNED` file appears.
  - An unknown meta key, a repeated key, and a `host` of `../x` are dropped.
  - A findings line with an unknown severity, an unlisted ID, a section number of 15, or a source other than `local` or `managed` is dropped.
  - The Limitations section states the count of dropped lines per file.
  - The output path does not change with the meta `host` value.
- P13. Managed settings, on a fixture `MANAGED_DIR`:
  - A device-level key gives `VALUE (managed)`, and the finding's source is `managed`.
  - A user-level key gives the same.
  - No managed file gives the 1.4 line.
  - A managed boolean `false` gives `0` and `true` gives `1`, so a forced `LSQuarantine` of `false` gives MA-PLATFORM-015.
  - A managed file with an identifier key never prints that key's value.
- P14. Enrollment: fixture `profiles status` output with `Yes`, `No`, and a failure gives `dep` and `mdm` values, or `unknown` with a skip record. With `unknown`, a managed force-installed extension gives MA-APPS-005 HIGH with `(enrollment state unknown)`.
- P15. Guidance: every ID in `docs/CHECKS.md` has one `GUIDANCE` line, and no line names an unknown ID.
- P16. Version marker V1: the rule in the design holds for the working tree. Fixture comparisons check each case: an unchanged script with the tag's version; a changed script with `TAG+dev`; a changed script with an untagged higher version (the release commit); and a changed script with the tag's version, which fails.
- P17. Option combinations: each usage error in the design's Option combinations list exits 2 before any audit work. `-o report.md --format md,json` writes `report.md` and `report.json`.
- P18. OCSF uid: two MA-SHARING-026 findings and two skipped checks give four distinct `finding_info.uid` values, and `compliance.control` keeps the bare ID.
- P19. `SKIP_IDS`: every literal skip label in `macassay` has a row, and every ID in it is a known ID.
- P20. `finding` writes six fields: the section number from `h2`, and the source, `local` by default.
- P21. `write_meta` writes the 16 keys of the design's `meta.tsv` table, each once.
- P22. `readable` passes an absent or readable path and records one skip, with its IDs, for a path that exists but cannot be read.

The 1.4 cases stay. F15, F16, and D1 cover the new optional SOURCE argument to `finding`.

## Manual tests

- M1. On the development Mac, run `./macassay --quick --skip-du --format md,json,ocsf,html,csv -o <session temp folder>/m1`. Pass:
  - Five files are written.
  - The Markdown matches a 1.4 run section for section, apart from the 1.5 changes.
  - The HTML opens in Safari with no console error, and the filter hides rows.
  - The JSON and OCSF parse.
- M2. Under `--offline`, `nettop` shows no traffic from the audit's processes, as in 1.4 test M2.
- M3. Run `--compare` against M1's JSON with one accepted ID. The Changes section is empty, and the accepted finding moves to Accepted risks.
- M4. A run with `--fail-on low` exits 3 on the development Mac. Record the exit status.
- M5. Remote mode against the MacBook with `--format md,json` writes both files on this Mac, and they match a local run's layout. If no second Mac is reachable, record the skip (T19 and X1 in `docs/ISSUES.md`).
- M6. Open the HTML in Safari's print preview: evidence sections print open.
- M7. Without Full Disk Access for the terminal app, run a quick audit. Each case in "Unreadable evidence" that applies shows `unreadable` and a skip record, not a clean value.
- M7a. Before relying on an exit status, record each Unreadable evidence command's exit status in the failure case and the no-data case. Include `tmutil destinationinfo` on a Mac with no Time Machine destination, which must still give MA-BACKUPS-001.
- M8. On hold until an enrolled Mac is available: the enrolled-Mac test in `docs/ISSUES.md` (requirement A14).

## Review findings

Architecture review of the design, 2026-11-26, by an Opus subagent. Each line gives the finding, the outcome, and the reason.

- AR1 Normalize order leaks UUIDs: `redact_ids` under a UTF-8 locale stops at an invalid byte; 1.4 then ships the unredacted report (`macassay:1538`). Fixed in the design: `iconv -c` first, then `LC_ALL=C redact_ids`, and stop on failure. Critical; breaks `AGENTS.md` (No secrets). Verified under `/bin/bash` 3.2 with `C.UTF-8`. The 1.4 bug is recorded in `docs/ISSUES.md`.
- AR2 Bundle contents unvalidated: a meta value reaches shell arithmetic, which runs a command in an array subscript. Fixed: Validation section, fixed-shape checks, local `clean_field`, base64 character check, no path from meta. Critical; breaks `AGENTS.md` Security Context. Arithmetic injection verified under `/bin/bash` 3.2.
- AR3 Accepted-risk "contains" match lets a name on disk accept a finding; "valid ID" undefined. Fixed: whole-text match, ID must be in `GUIDANCE`, reasons through `clean_field`. Breaks the SKELETON invariant on names deciding severity, with a trigger.
- AR4 `--compare` reports skipped checks as resolved; the Changed group is noise. Fixed: Not checked group from `skipped.tsv` IDs (`SKIP_IDS`); Changed group deleted, since `docs/ISSUES.md` asks for new and resolved only. Breaks requirement 9, with a trigger.
- AR5 Managed booleans read `true`/`false`, so 0/1 tests never fire; `pref_line` return contract ambiguous. Fixed: map to 1/0; `pref` sets `PV` and `PSRC` globals. Breaks requirement 7, with a trigger.
- AR6 Status lines cannot count open findings only. Fixed: the rule covers the header and the final line; status lines count all findings. Internal contradiction.
- AR7 OCSF `finding_info.uid` not unique. Fixed: `HOST:ID:N`. Breaks requirement 1, with a trigger.
- AR8 Version test V1 fails at the untagged release commit. Fixed: allow an untagged higher version; compare the version number only. Breaks decision A15 and the release gate.
- AR9 `changes.tsv` and old-JSON handling unspecified. Fixed: format defined; `iconv -c` on OLD.json; JXA strips tabs, newlines, and control characters. Breaks D3.
- AR10 `unknown` enrollment has no mapping in `forced_ext_finding`. Fixed: `unknown` gives MA-APPS-005 HIGH with a note. Breaks requirement 9.
- AR11 Option combinations unspecified. Fixed: Option combinations section; `--stdout` now works with `--host`. Breaks requirement 12.
- AR12 Exit-status detection may turn a no-data result into a skip, such as MA-BACKUPS-001 on a Mac without Time Machine. Fixed: the build verifies each command's exit status in both cases (M7a) before relying on it. Breaks requirement 9; uncertain trigger, kept because the cost of a check is low.
- Suggestion: fixed-order bundle without names. Adopted (decision in the design).
- Suggestion: JXA writes the CSV and HTML table too. Declined: `md_html` must escape in `awk` anyway (decision in the design).

## Plan review

Review of `docs/superpowers/plans/2026-11-26-report-1.5.md`, 2026-11-26, by an Opus subagent that ran the plan's code under `/bin/bash` 3.2. No finding was Critical. Each line gives the finding, the outcome, and the reason. A plan defect that would fail the suite or ShellCheck breaks the `../AGENTS.md` commit gate; a test that cannot fail breaks the testing rules.

- PR1 `jx` helper: `eval` in JXA cannot see `d`, so every JSON check fails. Fixed: `new Function("d", ...)`. Suite gate.
- PR2 `plutil -lint` rejects all JSON. Fixed: `plutil -convert xml1 -o /dev/null`; P3 wording changed. Suite gate.
- PR3 1.5 fixtures collide with the 1.3.1 files at `$T/p1` to `$T/p8`, and case names collide. Fixed: fixtures under `$V`, check names prefixed `1.5 `. Suite gate.
- PR4 "no `onerror=`" fails on correctly escaped text. Fixed: test for an event handler inside a tag; P5 wording changed. Suite gate.
- PR5 P19 label count needs 20, the script has 19. Fixed: `-ge 19`. Suite gate.
- PR6 two `finding MA-APPS-005` call sites fail F16. Fixed: one call with `forced_ext_note`, tested as a function. F16; Stable finding IDs.
- PR7 unused variables give SC2034. Fixed: `M_EPOCH` and `M_LAPTOP` dropped; each option default moves to the task that reads it. Lint gate.
- PR8 the master copy is not executable. Fixed: run with `/bin/bash`. Task 5 step.
- PR9 P12 file-name check cannot fail (BSD grep rejects an empty alternative). Fixed: optional group. Testing rules.
- PR10 usage-error tests pass on "Unknown option" before the option exists. Fixed: `p17` requires no `Unknown option`. Testing rules.
- PR11 weak P9 checks. Fixed: anchored on the reason, a real partial text, and a check that the regex line accepts nothing. P9.
- PR12 D1 turns vacuous once `GUIDANCE` lists every ID. Fixed: D1 skips the constant tables. Stable finding IDs (D1).
- PR13 UUIDs in the `--compare` file are never redacted. Fixed: `compare_load` uses `normalize_file`; design Comparison step 1 updated; P10 case added. Requirement 14.
- PR14 `read_bundle` accepts trailing data without a newline. Fixed: a partial last line fails; P12 case added. Design Remote mode 3.
- PR15 partial coverage of P3, P12a, P13, P14, P17. Fixed: all three hostile texts round-trip; invalid `skipped.tsv` lines; a managed finding's source; `read_enrollment` with a failed `profiles`; every P17 combination and `-o report.md --format md,json`. Approved test plan (A5).
- PR16 Task 4 gives no guidance text; Task 14 gives prose for several branches. Task 14 fixed with exact code for both variants of each branch that Step 1 decides; Activation Lock stays outside the Find My check. Task 4 kept as rules plus examples, with a note on the F15 pattern: the 135 sentences are the task's deliverable, and the task reviewer checks each one.
- PR17 Task 14 verifies only the success case. Fixed: failure cases for `log show` and `brew outdated`; the text-matched checks named as independent of exit status; a non-zero status is relied on only when the no-data case exits 0. Design requirement 9; M7a.
- PR18 small items. Fixed: JXA constraint reworded (it writes fixed names), P23 mention dropped, `skip_row` output silenced in P19, the plan is committed before Task 0. Dropped: "Stealth mode enabled/disabled" text on older macOS (uncertain, training knowledge; an unknown text gives a skip, not a pass, so requirement 9 holds).

## Task reviews

Per-task reviews during the build, 2026-11-26, from the ledger `.superpowers/sdd/2026-11-26-report-1.5/progress.md`. Each line gives the finding, its outcome, and the reason. Lines marked "deferred to the pre-merge review" are re-judged in the pre-merge review.

- T0-1 The `$V` fixture folder is unused until Task 2: dropped; the brief requires it and no requirement covers it.
- T0-1 P16 uses the nearest reachable `v*` tag: dropped; the brief defines it and history is linear.
- T2 `iconv -c` passes `F4 90..` and `F5..FF` sequences, so the output is not valid UTF-8: fixed (e916b0c, decision A4); trigger: text from the audited Mac; breaks design Rendering step 1.
- T2 A truncated multibyte sequence at the end of a file aborts the run: dropped; it fails closed, every data file ends with a newline, and no requirement covers it.
- T2 The fail-closed test does not stub `iconv` or check the `.u` removal: dropped; coverage depth, no trigger.
- T2 `iconv -c` exits 1 when a truncated multibyte sequence ends a file; a sentinel line avoids it: deferred to the pre-merge review; no trigger today, because every data file ends with script-written text.
- T2 The dev-only decoder check may fail without Command Line Tools python3: dropped; the development Mac has it, no trigger.
- T3 MA-BACKUPS-004 missing from the unreadable Time Machine settings skip row: fixed (5cf6831); trigger: `--compare` after a run without Full Disk Access; breaks the `SKIP_IDS` purpose.
- T3 P21 checks the key count, not each key and value: dropped; no trigger.
- T3 The P19 scan does not read `privblk` labels: dropped; none are literal today.
- T3 No test for `SECT_N` unset: dropped; no finding exists before the first `h2`.
- T4 Guidance commands that were wrong or understated the change (MA-ACCOUNTS-013, MA-PERSISTENCE-005, MA-PLATFORM-016, MA-BACKUPS-005, MA-BACKUPS-002), uncertain labels (MA-BACKUPS-004, MA-SHARING-011, MA-UPDATES-004), repeats of finding text, and the P15 word and dash rule: fixed (c7dcf68); breaks design Guidance text and `../AGENTS.md` (cheap-check rule).
- T4 Spelling "recognise": dropped; no rule, no trigger.
- T4 `sshd_config.d` file order may override a new file: dropped; uncertain, no verified trigger.
- T4 MA-UPDATES-011 guidance gives `brew reinstall --cask` without a cask name placeholder: deferred to the pre-merge review.
- T4 MA-TRUST-002 guidance says "login keychain", but a user trust setting may name a certificate in another keychain: deferred to the pre-merge review.
- T5 `valid_meta` counts accept leading zeros (`09`): deferred to the pre-merge review; harmless while no count reaches shell arithmetic.
- T5 With several formats, a failed `cp` of a later format leaves the earlier files written, though a comment says no file is written unless every format rendered: deferred to the pre-merge review.
- T5 P12a covers one injection payload: dropped; coverage, no trigger.
- T5 A ShellCheck comment names `check_formats` before Task 6 adds it: dropped; plan text, no trigger.
- T6 `check_formats` accepted a trailing empty name (`md,`), which starts a full audit: fixed (c987c17); trigger: a user typing the option; breaks design exit 2 on a bad format.
- T6 Glob characters in `--format` expand against the working directory: dropped; the result is a valid name or a rejection.
- T6 P7 does not test `+` and `@` formula starts: dropped; checked by hand.
- T7 OCSF lines keep raw U+2028, U+2029, and U+0085 from the audited Mac: deferred to the pre-merge review; the lines are valid JSONL, but a consumer that splits on Unicode line breaks loses the event.
- T7 OCSF output with no findings and no skips is one blank line: deferred to the pre-merge review.
- T7 `REPORT_JS` `read()` treats an unreadable `rows.tsv` as empty: dropped; `render_all` just wrote it, no trigger.
- T7 P3 and P4 coverage gaps, and a P18 comment that says four uids while it asserts five: dropped; no trigger.
- T8 `render_html` returns its last `printf` status, so a failed `awk` stage mid-page counts as rendered: deferred to the pre-merge review.
- T8 HTML hostile-input coverage gaps: dropped; the reviewer checked by hand, no trigger.
- T8 `md_html` table edge cases: dropped; unreachable, because `clean_field` removes pipes.
- T9 `load_accepted` used plain `iconv -c`, so an invalid byte made `sed` fail and the match empty, which accepts every finding with the ID; a directory as the file loaded as empty: fixed (95402b3); trigger: an accepted-risk file with an invalid byte; breaks design Accepted risks ("fails loudly").
- T9 `--accepted ""` is ignored: dropped; the safe direction, findings stay open.
- T9 A finding text that contains `#` cannot be matched, because `#` starts the reason: documented in `docs/FORMATS.md`; ID-only acceptance is the way around it.
- T9 P9 parsing coverage: dropped; verified by hand.
- T10 `c()` left C1 controls and U+2028 and U+2029 in values from the old file: fixed (a517612); trigger: a hand-edited or hostile old file; breaks design Comparison (strip control characters).
- T10 `clean_field` and `clean_tsv` strip only ASCII controls, so C1 controls and U+2028 and U+2029 from the audited Mac pass into every format: deferred to the pre-merge review; 1.4 behavior.
- T10 `--compare` with only `csv` or `ocsf` output shows no changes and no notice: deferred to the pre-merge review; the design is silent.
- T10 An ID repeated in the old file lists once per finding: dropped; it matches listing each finding.
- T10 The HTML Changes heading shows an empty host or date where Markdown says `unknown`: dropped; no requirement.
- T10 P10 coverage gaps: dropped; verified by hand.
- T11 `--fail-on ""` silently turned the gate off: fixed (51b3272); trigger: a scheduled job with an unset variable; breaks design Exit status (LEVEL is one of four words).
- T11 `--fail-on` is case-sensitive: dropped; the design names lowercase words.
- T11 P11 coverage gaps: dropped; verified by hand.
- T12 A NUL byte passed the bundle reader's trailing-data check: fixed (d338b1c); trigger: remote shell startup files; breaks design Remote mode step 3.
- T12 The P12 rejection input fails both the length and alphabet checks, so neither is tested alone: dropped; no trigger.
- T12 An empty `meta.tsv` or `body.md` is accepted: dropped; no requirement, and a hostile remote controls the content anyway.
- T12 No permanent `remote_mode` test, because `/usr/bin/ssh` cannot be stubbed: dropped; the reviewer's stub run covered it once (M5).
- T12 An unreadable file prints "integer expression expected" before `read_bundle` rejects it: dropped; the caller passes its own temporary file.
- T13 An empty managed string prints a blank `(managed)` value and hides a local login hook: dropped; no requirement, and the managed value wins by design.
- T13 The `(managed)` branches of sections 4, 6, 8, 9, and 10 have no end-to-end test: dropped; the brief's test list matched.
- T13 `plutil` raw output for a dict or array under a boolean key gives a nonsense value: dropped; a wrong-type profile, no requirement.
- T13 The browser-policy loop hardcodes `/Library/Managed Preferences` instead of `MANAGED_DIR`: dropped; no trigger.
- T14 P22 "unreadable 1" also matches status 127: dropped; the one-skip and IDs checks still pin the case.
- T14 The browser policies line shows found extensions when other policy files are unreadable: dropped; the skip is in Limitations, so it is not a clean value.
- T14 The screen lock pattern `*[Oo]ff*` could match an error text with "off": dropped; no trigger seen, same patterns as `screen_lock_sev`.
- T14 The `TMRC` constant 0 leaves the `tmutil` failed branch dead, and `(UTC)` follows `unreadable`: dropped; Time Machine variant B is a decision, and the suffix is cosmetic.

## Pre-merge review

Whole-branch review on 2026-11-26 by an Opus subagent, at `d29589e`. Verdict: ready after fixes. Fixes in `feb8165` (fixtures "1.5 PM") and the A5 commit after it; a scoped re-review found every fix in `feb8165` holds and no new defect.

- N1 Under a UTF-8 locale, `clean_field`'s `sed` printed nothing for text with an invalid byte, so `valid_findings` dropped the finding from every format and from `--fail-on`: fixed; Critical; trigger: a file name on the audited Mac; breaks the SKELETON invariant that a name on disk never decides a severity. The controller reproduced it on the old code.
- N2 `clean_tsv` deleted controls and backticks after redaction, so a UUID split by one was rejoined: fixed by replacing with a space; trigger: a hostile remote bundle; breaks the `AGENTS.md` No secrets rule.
- N3 A `\u` escape in the `--compare` file decoded to a UUID after redaction: fixed by redacting in `c()`; trigger: a hand-edited old file; breaks the `AGENTS.md` No secrets rule and decision A1.
- T10 (with T7's Unicode case) C1 controls and U+2028/2029 passed `clean_field` and `clean_tsv` into every format: fixed by replacing them with a space under `LC_ALL=C`; trigger: a file name on the audited Mac; breaks the design's `findings.tsv` field 4.
- T10 `--compare` with only `csv` or `ocsf` gave no comparison and no notice: fixed as a usage error (decision A5, approved by the user); breaks requirement 5.
- T4 MA-UPDATES-011 guidance gave `brew reinstall --cask` with no name: fixed (`NAME`); a reader running it gets a usage error.
- T4 MA-TRUST-002 guidance said "login keychain", but user trust settings can name a certificate in any keychain: fixed ("in Keychain Access").
- `docs/FORMATS.md` said a failed format leaves no report, but a failed copy of a later format leaves earlier ones, and `render_html` returns only its last write's status: fixed in the doc; `../AGENTS.md` requires docs to describe current behavior.
- T2 `iconv -c` exits 1 on a truncated sequence at the end of a file: dropped; the run then writes no report, and only a hostile remote or the user's own file can trigger it.
- T5 `valid_meta` counts accept leading zeros: dropped; no count reaches shell arithmetic, and JXA and `[ -eq ]` read them as decimal.
- T5 A failed copy of a later format leaves earlier format files written: dropped; no requirement (the doc now states it).
- T7 OCSF output with no findings and no skips is one blank line: dropped; documented, no requirement.
- T8 `render_html` returns its last `printf` status: dropped; no known way for awk to fail mid-page on normalized input (the doc now states it).

## Sources

- OCSF current version: https://schema.ocsf.io/api/version (1.10.0).
- Compliance Finding 1.10.0: https://schema.ocsf.io/classes/compliance_finding, with the `compliance`, `finding_info`, `metadata`, `device`, and `remediation` object pages.
- Compliance Finding 1.3.0: https://schema.ocsf.io/1.3.0/classes/compliance_finding (requires `cloud` and `osint`).
- AWS Security Lake accepts OCSF 1.3 and earlier for custom sources: https://docs.aws.amazon.com/security-lake/latest/userguide/custom-sources.html (search snippet, not read in full).
- `/usr/bin/jq` first shipped in macOS 15: search snippets only.
- Code survey of settings reads and silent failures in `macassay` 1.4.0: a research subagent, 2026-11-26. Its line numbers refer to commit `7ab6930`.

## Results

- B1 (2026-11-26, `master` at `7ab6930`): `bash -n` passes; `dev/test.sh` 339 cases pass; ShellCheck baseline 1 SC2010 and 2 SC2012 (3 findings). An earlier record of 2 and 3 counted the wiki-link lines too; the controller verified 3 findings on `master` and on the branch, 2026-11-26.
- M7a (Task 14, 2026-11-26, development Mac, `/bin/bash`): `tmutil destinationinfo`, `xprotect version`, `sysadminctl -screenLock status`, and `socketfilterfw --getstealthmode` each exit 0; one destination is listed, stealth mode prints `Firewall stealth mode is off`, the screen lock prints `screenLock delay is 900 seconds`. `brew outdated --quiet --formula` exits 0; with `--no-such-flag` it exits 1. `log show` with a no-match predicate exits 0; with a bad predicate it exits 64, also through `exit "${PIPESTATUS[0]}"` in a command substitution. All values match the earlier record. `tmutil destinationinfo` on a Mac with no destination was not run (variant B keeps the 1.4 behavior). Note: in zsh `log` is a shell built-in, so run these under `/bin/bash` or as `/usr/bin/log`; zsh gives a false exit status 1.
- M7 (Task 14, 2026-11-26, `--quick --offline --skip-du`, agent session in tmux without Full Disk Access): Time Machine backup age and encryption showed `unreadable (needs Full Disk Access for the terminal app)` on the backup age, count, and encryption lines, with a skip record and no MA-BACKUPS-001 to 004 finding. The other cases did not apply on this Mac: the DiagnosticReports folders (Jetsam, kernel panics) and `com.apple.FindMyMac.plist` are readable here; Remote Management is not listening; no browser policy file exists; `xprotect version`, `sysadminctl`, and `socketfilterfw` gave a known state; `--offline` and `--quick` skip the Homebrew and log checks under their own labels. The no-answer paths for those cases have no live M7 evidence.
- M5 (2026-11-26): skipped. `ssh localhost` fails host key verification, and the SSH settings were left alone (same cause as X1 in `docs/ISSUES.md`). The Task 12 reviewer ran `remote_mode` against a stub `ssh`. A good bundle wrote one report with exit 0. `--fail-on medium` with an open MEDIUM finding exited 3. An ssh exit of 255 gave exit 1 with no report. A banner line, an empty result, and trailing data each gave exit 1, "Remote audit returned a malformed result.", and no report.
- M8: on hold until an enrolled Mac is available.
- M1 (2026-11-27, `138dbbd`, run by the user in iTerm with Full Disk Access): five files written. The JSON and every OCSF line parse (`plutil`). Every output is valid UTF-8 (Python strict decoder), and no dashed UUID appears in any of them. The HTML starts with the CSP meta tag. The Markdown section headings match a quick run of `master`. The other differences come from the 1.5 guidance lines, the online run (Homebrew and `softwareupdate` blocks), and Full Disk Access (outbound connections, backup age, Chrome extensions). The Safari part (no console error, the filter hides rows) is on hold with M6.
- M2 (2026-11-27, `138dbbd`, user in iTerm, `nettop -P -x -L 40 -s 1` logged to a file during an `--offline` run): pass. The only processes the audit started that had traffic were the `nc` and `curl` probes of the Mac's own listeners, the same as in 1.4. No `softwareupdate`, `brew`, or `syspolicyd` traffic. `trustd` grew by about 250 and 130 bytes over 40 seconds, evenly before, during, and after the run, so that is background.
- M3 (2026-11-27, `138dbbd`, user in iTerm, `--compare m1.json --accepted` with an ID-only line for MA-HEALTH-003): pass. The New, Resolved, and Not checked groups are each 0. MA-HEALTH-003 left Findings and is listed under Accepted risks with its reason, and the header reads 2 HIGH and 1 accepted.
- M4 (2026-11-27, `138dbbd`, user in iTerm, `--quick --offline --skip-du --fail-on low`): pass. Exit 3, 64 findings.
- M6: on hold; the user was away from the development Mac on 2026-11-27. Open `m1.html` in Safari, check print preview (evidence sections open) and the severity filter (rows hide, no console error).
