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
  - `osascript` `JSON.parse` and `plutil -lint` accept the output.
  - Each hostile text round-trips unchanged after normalization.
  - `schema` is `macassay-report/1`, and the counts match the fixture.
- P4. OCSF:
  - Each line parses as JSON.
  - Each event holds the required 1.10.0 attributes with the mapped values.
  - A skipped check maps to `compliance.status_id` 2, and an accepted finding to `status_id` 3.
- P5. HTML:
  - No `<script`, `onerror=`, `<img`, or `href="http` appears outside the fixed page text.
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
  - An old file with invalid UTF-8, or a text with a tab or newline, gives one clean line per finding in `changes.tsv`.
  - A hostile text in the old file is escaped in the Markdown and HTML output.
- P11. Exit status: the fixture has one MEDIUM and one LOW finding.
  - `--fail-on medium` exits 3, and `--fail-on high` exits 0.
  - An accepted MEDIUM with `--fail-on medium` exits 0.
  - A bad level exits 2.
- P12. Bundle:
  - A round trip of the fixture folder through the bundle writer and `read_bundle` gives identical files.
  - Each of these is rejected with exit 1: a wrong first line, too few or too many lines, and a line with characters outside base64 (such as `abc$%`).
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

## Sources

- OCSF current version: https://schema.ocsf.io/api/version (1.10.0).
- Compliance Finding 1.10.0: https://schema.ocsf.io/classes/compliance_finding, with the `compliance`, `finding_info`, `metadata`, `device`, and `remediation` object pages.
- Compliance Finding 1.3.0: https://schema.ocsf.io/1.3.0/classes/compliance_finding (requires `cloud` and `osint`).
- AWS Security Lake accepts OCSF 1.3 and earlier for custom sources: https://docs.aws.amazon.com/security-lake/latest/userguide/custom-sources.html (search snippet, not read in full).
- `/usr/bin/jq` first shipped in macOS 15: search snippets only.
- Code survey of settings reads and silent failures in `macassay` 1.4.0: a research subagent, 2026-11-26. Its line numbers refer to commit `7ab6930`.
