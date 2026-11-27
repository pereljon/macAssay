---
kind: feature
lifecycle: building
status: drafted 2026-11-26; architecture review findings applied 2026-11-26; approved by the user 2026-11-26 (A5); built on feature/report-1.5 (Tasks 0 to 15); pre-merge review fixed 2026-11-26; manual tests M1 to M4 pass 2026-11-27; M5 layout pass 2026-11-27, rerun pending after the A6 fix; M6 (Safari) on hold
---

# Report formats, run comparison, and managed Macs (version 1.5)

This doc is the plan of record for version 1.5. It changes how the report is built and written, and how settings are read on managed Macs. It adds no new check. Test cases and review findings live in `report-1.5-tests.md`. New checks wait for version 1.6 (decision A10 in `docs/ISSUES.md`).

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64) and `macassay` 1.4.0 at commit `7ab6930`, on 2026-11-26. OCSF facts come from schema.ocsf.io, read by research subagents on 2026-11-26 (sources in `report-1.5-tests.md`).

## Goal

Write the audit's results in the formats that people, LLMs, and tools each need, from one set of data files. Compare a run with an earlier one. Report settings that an MDM sets as managed, and never show unreadable evidence as a clean result.

## Requirements

Each requirement traces to a `docs/ISSUES.md` item (Version 1.5), a user decision, or `AGENTS.md`.

1. Output formats: Markdown (the default), JSON, OCSF, HTML, and CSV. One run can write more than one format. Source: `docs/ISSUES.md` (Report formats; CSV).
2. Every format is built at the end of the run from the same data files. Source: `docs/ISSUES.md`.
3. The design defines the format of `findings.tsv` and `skipped.tsv`. Source: decision D3.
4. Text from the audited Mac is escaped correctly in JSON, HTML, and CSV, with stock tools only. Source: `docs/ISSUES.md`; `AGENTS.md` (Security Context, Stock macOS only).
5. `--compare OLD.json` reports new and resolved findings by their stable IDs. Source: `docs/ISSUES.md`; register I085.
6. An exit status by severity, for scheduled runs. Source: `docs/ISSUES.md`; register I083.
7. The audit works on a Mac assigned in Apple Business Manager, on one enrolled in an MDM, and on one with neither. The report states the enrollment state. A setting that a profile manages reads as managed, with its value. Source: user requirement 2026-11-26; decision A14; register I081.
8. A report from unreleased code says so in its version. Source: decision A15.
9. A check that ran but could not read its evidence never reads as a pass. Source: decision A10; register I079.
10. An accepted-risk list moves accepted findings out of the findings table. Source: decision A10; register I078.
11. Each finding carries a short guidance line. The audit never runs a fix. Source: decision A10; register I080.
12. Remote mode supports every option above. Source: `AGENTS.md` (Project: the audit runs locally or over SSH).
13. No new sudo rule, no new side effect, no new network traffic, `/bin/bash` 3.2 and stock tools only. Source: `AGENTS.md` (Design Principles); decisions A7 and A9.
14. No secret or hardware identifier reaches any format. Source: `AGENTS.md` (No secrets in the report).

## Decisions

- 2026-11-26: Version 1.5 is one release, through review (the user's goal for this session). Rejected: managed Macs and the version marker as 1.5, then the formats as 1.6. Conviction: `firm`.
- 2026-11-26: The audit collects data and renders it in two separate steps. Remote mode moves the data files to the local Mac, and the local Mac renders them. Rejected: rendering on the audited Mac, because the accepted-risk file and the old JSON for `--compare` live on the local Mac. Remote mode would then need to send them to the audited Mac.
- 2026-11-26: The OCSF format uses the Compliance Finding class (class_uid 2003) of OCSF 1.10.0. Rejected: OCSF 1.3.0, the newest version that AWS Security Lake custom sources accept, because 1.3.0 requires the `cloud` and `osint` attributes, which have no meaning for a Mac. Rejected: Detection Finding (2004), which is for alerts from detection engines, and Vulnerability Finding (2002), which requires a `vulnerabilities` array.
- 2026-11-26: JSON and OCSF are written by a fixed JXA script with `JSON.stringify`. Rejected: a hand-written JSON escaper in `awk`. `JSON.stringify` escapes every character correctly by construction, and `--compare` needs JXA's `JSON.parse` anyway.
- 2026-11-26: HTML and CSV are written by `awk`, with one escaping function each (`html_esc`, `csv_field`). Rejected: writing the CSV and the HTML findings table from the JXA script, as the review suggested, to have one escaping engine. `md_html` must escape the evidence in `awk` anyway, so the HTML page would still need two engines.
- 2026-11-26: The remote bundle is five fixed lines with no file names. Rejected: named lines, as first drafted. Fixed positions remove name parsing (review suggestion).
- 2026-11-26: Managed values come from the files in `/Library/Managed Preferences`, as the browser-policy check already reads them. Rejected: `defaults read DOMAIN`, which does not merge managed values (verified below). Rejected: CFPreferences through JXA, because its values need Core Foundation bridging that JXA does not do for `CFPreferencesCopyAppValue` (verified below).
- 2026-11-26 (A5): the user approved the design and the test plan, which makes every decision above part of the plan of record. Conviction: `firm`.
- 2026-11-26 (A2): no 1.4.1 release for the redaction bug that the review found (AR1). The fix ships in 1.5. Reason, from the user: nobody uses macAssay yet. Conviction: `firm`.
- 2026-11-26 (A3): unreadable evidence records a skip under Limitations, not an INFO finding. Findings are judged risks with stable IDs; an unreadable file is a limit of the audit. Rejected: an INFO finding, as register I079 words it. Conviction: `ok`.
- 2026-11-26 (plan review A1): the `--compare` file passes through `normalize_file`, so UUID redaction covers it too (Comparison step 1). Rejected: `iconv -c` alone, as first designed, which let a UUID from the old file reach every format. Conviction: `firm` (the user: "yes").
- 2026-11-26 (A4): normalization removes the invalid sequences that macOS `iconv -c` keeps (lead bytes `F5` to `FF`, and `F4` followed by `90` to `BF`), then runs `iconv -c` again (Rendering, Steps 1.1). Verified on the development Mac: those sequences pass `iconv -c` unchanged, and the added steps keep every valid character up to U+10FFFF and still join a split UUID. Rejected: `iconv -c` alone, which lets text from the audited Mac make the report invalid UTF-8; a UTF-16 round trip, which turns each bad sequence into `?` and so can split a UUID that redaction then misses. Conviction: `firm` (the user: "A4 approved").
- 2026-11-26: Time Machine destinations keep the 1.4 behavior, as Unreadable evidence says for an unverified command. Neither available Mac lacks a destination, so the exit status of `tmutil destinationinfo` with no destination is unverified. `brew outdated` exits 0 with packages outdated (verified), so its failure is detected from the exit status.
- 2026-11-26: `Time Machine settings` (the settings file is missing while a destination exists) records a skip that lists MA-BACKUPS-002, 003, and 004, and the report prints `unreadable (settings file missing)`. MA-BACKUPS-004 is listed because `AutoBackup` is read from the same file; this matches the Task 3 fix to the `Time Machine backup age and encryption` row. Rejected: the 1.4 value `unknown` with no skip, which reads as a clean result (requirement 9).
- 2026-11-26 (A5): `--compare` with only `csv` or `ocsf` output is a usage error (exit 2) before the audit starts. Found by the pre-merge review: the run gave no comparison and no notice. Rejected: a notice on stderr while the run goes on, because the user asked for a comparison that the run cannot give. Conviction: `firm` (the user approved the recommendation).
- 2026-11-27 (A6): the debug port check skips the audit's own process and its descendants. Found by M5: in remote mode the audit's command line is the script text, and the 1.5 guidance names `--remote-debugging-port`, so every remote run reported itself. Rejected: rewording the guidance, because any later script text could trip the check again. Conviction: `firm` (the user approved the recommendation).
- 2026-11-26 (A4): `--fail-on LEVEL` is opt-in and exits 3. Rejected: exit 2 for a HIGH finding, as `docs/ISSUES.md` suggested, because exit 2 already means a usage error. Conviction: `ok`.

## Verified facts

Checked on the development Mac, 2026-11-26, as the user without sudo:

- `profiles status -type enrollment` runs without root, exits 0, and prints two lines: `Enrolled via DEP: No` and `MDM enrollment: No`.
- `/usr/bin/jq` exists (`jq-1.7.1-apple`). It is not used, because macOS releases before 15 lack it (search snippets only, not Apple release notes).
- `iconv -c -f UTF-8 -t UTF-8` drops invalid UTF-8 bytes and keeps valid ones.
- JXA reads a file with `NSString.stringWithContentsOfFileEncodingError` and UTF-8. It returns nil for a file with invalid UTF-8, so input passes through `iconv -c` first.
- `JSON.stringify` in JXA escapes quotes, backslashes, and non-ASCII text correctly. One run over a fixture takes 0.04 s.
- `/Library/Managed Preferences/USER/` holds a plist for one managed domain on this Mac, which has no MDM. `defaults read DOMAIN` answers `Domain ... not found` for it. `CFPreferencesAppValueIsForced` returns true for its key. So the file is what macOS treats as forced, and the domain form of `defaults read` misses it.
- That managed plist holds a device identifier key. Managed files can hold identifiers, so the audit reads named keys only and never prints a whole managed file.
- `CFPreferencesCopyAppValue` returns an opaque `Ref` in JXA that `ObjC.deepUnwrap` does not convert.
- `osascript` startup takes about 0.04 s per call.

OCSF facts (schema.ocsf.io, read 2026-11-26):

- The current release is 1.10.0.
- Compliance Finding (2003) describes "results of evaluations run against resources to check compliance with frameworks or security standards".
- In 1.10.0, the required attributes are `activity_id`, `category_uid` (2), `class_uid` (2003), `compliance`, `finding_info`, `metadata`, `severity_id`, `time` (epoch milliseconds), and `type_uid` (`class_uid * 100 + activity_id`).
- `finding_info.uid` is required. `metadata` requires `product` and `version`, where `version` is the OCSF schema version.
- `severity_id`: 1 Informational, 2 Low, 3 Medium, 4 High. `compliance.status_id`: 1 Pass, 2 Warning ("did not yield a result due to missing information"), 3 Fail.
- `remediation.desc` holds remediation text. `device` takes `type_id` (2 Desktop, 3 Laptop) and `hostname`.

OCSF object facts (`https://schema.ocsf.io/api/1.10.0/objects/<name>`, read 2026-11-26 while writing the plan; not re-read during the build):

- `compliance` has no required attribute, and `status_details` is an array of strings.
- `finding_info` requires `uid`.
- `metadata` requires `product` and `version`, and `product` needs `name` or `uid`.
- `device` requires `type_id` and one of `hostname`, `ip`, `name`, or the other identifiers.
- `remediation` requires `desc`.

## Assumptions to verify during the build

- Verified during the build: `plutil -extract KEY raw` prints a boolean as `true` or `false`, and `managed_val` maps it to `1` or `0` (fixture P13). Each `valid_*` function drops the hostile values of fixture P12a, and `read_bundle` rejects every malformed bundle of P12, including a NUL byte (Task 12 review). Unverified: the CSS `:has()` filter in Safari (test M6) and `ssh` remote mode against a second Mac (test M5, skipped).
- An MDM profile writes device-level settings to `/Library/Managed Preferences/DOMAIN.plist` and user-level settings to `/Library/Managed Preferences/USER/DOMAIN.plist` (training knowledge; one user-level file seen). Verify on an enrolled Mac (test M8, on hold).
- Declarative device management (DDM) may set some settings outside these files. The report's Limitations say so.
- Each command in the Unreadable evidence table exits non-zero on failure and zero when there is simply no data. Verified on 2026-11-26 (test M7a, development Mac) for the success and failure cases of `brew outdated` (0, and 1 with a bad flag) and `log show` (0 for no match, 64 for a bad predicate), and for the success case of `tmutil destinationinfo`, `xprotect version`, `sysadminctl -screenLock status`, and `socketfilterfw --getstealthmode` (each exit 0). Not verified: `tmutil destinationinfo` on a Mac with no destination (on hold in `docs/ISSUES.md`), and the failure case of the four state commands. The `log` command must run as `/usr/bin/log` or under `/bin/bash`: zsh's `log` built-in gives a false status.
- The firewall payload keys are `EnableFirewall`, `EnableStealthMode`, and `BlockAllIncoming` in domain `com.apple.security.firewall` (training knowledge).
- The CSS `:has()` selector, used by the HTML severity filter, works in current Safari, Chrome, and Firefox (training knowledge). A browser without it shows every finding.
- No OCSF source states whether a file holds a JSON array or one event per line. Newline-delimited JSON is the convention of log shippers (training knowledge).

## Data files

The audit writes four data files in its temporary folder. Every format is built from them. All four are UTF-8 text with one record per line and fields separated by tabs.

`meta.tsv` holds run facts, one `KEY<TAB>VALUE` per line:

| Key | Value |
|---|---|
| `host` | LocalHostName |
| `user` | the audit's user name |
| `date` | local date and time, as the header shows it now |
| `epoch` | Unix time of the run's start, in seconds |
| `version` | the `VERSION` string |
| `quick`, `offline`, `skip_du` | `0` or `1` |
| `priv_ran`, `priv_skipped`, `other_skipped` | counts |
| `rules` | `1` when `/etc/sudoers.d/macassay` exists |
| `brew` | `1` when Homebrew is installed |
| `dep`, `mdm` | `Yes`, `No`, or `unknown`, from `profiles status -type enrollment` |
| `laptop` | `1` when the Mac has an internal battery |

`findings.tsv` holds one finding per line, with six fields:
1. Severity: `HIGH`, `MEDIUM`, `LOW`, or `INFO`.
2. ID: `MA-<LABEL>-NNN`.
3. Section label, such as `Sharing`.
4. Text, already passed through `clean_field`: no tab, newline, pipe, backtick, or control character.
5. Section number, 1 to 14, taken from the section that `h2` last started.
6. Source: `local`, or `managed` when the finding judges a value that a profile set.

Fields 1 to 4 keep their 1.4 order, so the existing `awk` readers need no change. `finding ID SEVERITY LABEL TEXT [SOURCE]` writes the line; SOURCE defaults to `local`.

`skipped.tsv` holds one skipped check per line, with four fields:
1. Kind: `priv` or `other`.
2. Label.
3. Reason.
4. IDs: the finding IDs that the skipped check could have given, separated by spaces, or empty.

Fields 1 to 3 keep their 1.4 order. `skip` and `priv` fill field 4 from `SKIP_IDS`, a constant table from skip label to IDs. A fixture test checks that every literal skip label in `macassay` has a row. Unreadable evidence adds `other` records (requirement 9).

`changes.tsv` exists only with `--compare`. It holds one line per changed finding, with five fields: group (`new`, `resolved`, or `not_checked`), ID, severity, section, and text. The JXA script strips tabs, newlines, and control characters from every value it writes.

`body.md` holds the evidence sections, as in 1.4.

## Rendering

### Steps

After the last section, `render_all` runs these steps in order:

1. Normalize:
   1. Pass each data file through `iconv -c`, then remove the byte sequences that macOS `iconv -c` keeps although they are not valid UTF-8 (lead bytes `F5` to `FF`, and `F4` followed by `90` to `BF`), then pass it through `iconv -c` again, which drops the orphaned continuation bytes. Then pass it through `LC_ALL=C redact_ids`. (Added 2026-11-26 after the Task 2 review, decision A4.)
   2. Stop with exit 1 when either command fails, and write no report.
   3. Every format then starts from valid UTF-8 with no dashed UUID.
2. Validate: check every field against its shape (see Validation). In remote mode, this is where untrusted bundle data is checked.
3. Accept: read the accepted-risk file, if given, and split the findings into open and accepted.
4. Compare: with `--compare`, the JXA script reads the old JSON and writes `changes.tsv`.
5. Write each requested format.
6. Set the exit status (requirement 6).

The order in step 1 matters. BSD `sed` under a UTF-8 locale stops at an invalid byte with `illegal byte sequence` (verified with `/bin/bash` 3.2, `C.UTF-8`). Also, `iconv -c` can join the two halves of a UUID that an invalid byte split, so redaction must come after it.

The steps read only the data files and the two user files. A fixture test runs them on a fixture folder, with no audit.

### Validation

`render_all` trusts no data file, because in remote mode all four come from the audited Mac. Before any value is used:
- Each `meta.tsv` key must be one of the known keys, each at most once. Counts and `epoch` must match `^[0-9]{1,12}$`. Flags must be `0` or `1`. `dep` and `mdm` must be `Yes`, `No`, or `unknown`. `host` and `user` must match `valid_name`.
- Each `findings.tsv` line must have six fields: a known severity, an ID that `GUIDANCE` lists, a section number from 1 to 14, and a source of `local` or `managed`. Fields 3 and 4 pass through `clean_field` again.
- Each `skipped.tsv` line must have four fields: kind `priv` or `other`, then label, reason, and IDs. The text fields pass through `clean_field` again.
- A line that fails is dropped, and the Limitations section says how many lines were dropped from which file.
- A value from a data file never reaches shell arithmetic, `[[ ]]`, or a path before it passes this check. Bash 3.2 runs a command substitution inside an array subscript in `$(( ))` (verified).
- The output path never uses a value from `meta.tsv`. In remote mode, the default path uses `--host`, as in 1.4.

### Options

- `--format LIST`: a comma-separated list of `md`, `json`, `ocsf`, `html`, and `csv`. The default is `md`.
- `-o PATH`: with one format, the output file, as now. With several formats, a base path: each format adds its own extension (`.md`, `.json`, `.ocsf.jsonl`, `.html`, `.csv`). Option combinations, below, say how a trailing extension is handled.
- Without `-o`, the base path is `./macassay-<host>-<date>`, as now.
- `--stdout` works with one format only. With several, the audit stops with a usage error, exit 2.
- `--compare FILE`, `--accepted FILE`, and `--fail-on LEVEL` are described below.

The option names follow GNU style. `--format` matches the GNU table's `--format`.

### Markdown

The Markdown report keeps the 1.4 layout, with these changes:
- The header gains `- Management: enrolled via Apple Business Manager: VALUE; MDM enrollment: VALUE`.
- The Findings table gains a fifth column, `Source`, that reads `managed` or is empty.
- A `### Guidance` list follows the table, with one line per ID present: the ID, then its guidance text.
- With `--compare`, a `## Changes since the previous run` section follows Findings (see Comparison).
- With `--accepted`, an `## Accepted risks` section follows, with each accepted finding and the reason from the file.
- The header counts and the final `Report written` line count open findings only. The header adds `N accepted` when N is above 0.
- The per-section status lines on stderr still count all findings. They print during collection, before the accepted-risk file is read, and in remote mode the audited Mac prints them.

### JSON

The JSON format is macAssay's own schema, documented in `docs/FORMATS.md` (new). One object per run:

```json
{
  "schema": "macassay-report/1",
  "tool": {"name": "macassay", "version": "1.5.0 (2026-12-01)"},
  "host": "mini", "user": "alice", "date": "2026-12-01 10:00 PST", "epoch": 1764612000,
  "options": {"quick": false, "offline": false, "skip_du": false},
  "management": {"dep": "No", "mdm": "No"},
  "privileged": {"ran": 17, "skipped": 0},
  "counts": {"HIGH": 0, "MEDIUM": 2, "LOW": 3, "INFO": 1, "accepted": 1},
  "findings": [{"id": "MA-SHARING-026", "severity": "LOW", "section": "Sharing", "section_number": 6,
                "text": "...", "source": "local", "accepted": false, "guidance": "..."}],
  "accepted": [{"id": "...", "reason": "..."}],
  "skipped": [{"kind": "priv", "label": "...", "reason": "..."}],
  "limitations": ["..."],
  "changes": {"compared_with": {"host": "...", "date": "..."}, "new": [], "resolved": [], "not_checked": []}
}
```

`changes` appears only with `--compare`. The evidence sections are not part of the JSON: they are free text for a person or an LLM, and the Markdown and HTML formats hold them.

### OCSF

The OCSF format writes one Compliance Finding event per finding, and one per skipped check, as newline-delimited JSON (`.ocsf.jsonl`).

| OCSF attribute | Finding | Skipped check |
|---|---|---|
| `activity_id`, `type_uid` | 1 (Create), 200301 | same |
| `category_uid`, `class_uid` | 2, 2003 | same |
| `severity_id` | HIGH 4, MEDIUM 3, LOW 2, INFO 1 | 1 |
| `time` | `epoch` × 1000 | same |
| `metadata` | `version` `1.10.0`; `product` name `macAssay`, version `VERSION` | same |
| `finding_info` | `uid` `HOST:ID:N`, `title` the text | `uid` `HOST:MA-SKIP:N`, `title` the label |
| `compliance` | `status_id` 3 (Fail), `control` the ID | `status_id` 2 (Warning), `status_details` the reason |
| `remediation.desc` | the guidance text | absent |
| `device` | `hostname`, `type_id` 3 (laptop) or 2 | same |
| `status_id` | 1 (New), or 3 (Suppressed) when accepted | absent |
| `unmapped` | section, section number, source | kind |

`finding_info.uid` must be unique, and consumers deduplicate on it. One ID can give several findings, such as MA-SHARING-026 once per tool. So the uid joins the host, the ID, and N, the finding's position among this run's findings with that ID. `compliance.control` keeps the bare ID.

An INFO finding is still a Fail in `compliance.status_id`: it is a judged result, and its severity says how much it matters. The evidence sections are not included.

### HTML

The HTML format is one self-contained page with no JavaScript:
- A Content-Security-Policy meta tag: `default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'`. It blocks every script, image, frame, and form.
- Inline CSS gives each severity a color and adds print styles.
- A severity filter of four radio buttons hides rows with the CSS `:has()` selector.
- Each finding links to its evidence section by section number (`#section-6`).
- Evidence sections sit in `<details open>` blocks, so they print.

`md_html`, an `awk` function, converts `body.md` to HTML. It handles only the Markdown that macAssay writes: `##` and `###` headings, a line in `**bold**`, fenced `text` blocks, `- ` list items, pipe tables, inline code, and plain lines.
1. It escapes `&`, `<`, `>`, `"`, and `'` in every line first.
2. It then converts the markup.
3. It never makes a link from text, so text from the audited Mac cannot add a link or an attribute.

`html_esc` is the one escaping function for every other value on the page, including the header values and the finding text.

### CSV

The CSV format holds the findings table: severity, ID, section, finding, source, accepted, guidance. It follows RFC 4180: every field in double quotes, and a quote inside a field doubled. A field that starts with `=`, `+`, `-`, `@`, or a tab gets a leading `'`, so a spreadsheet does not run it as a formula (OWASP CSV injection guidance, training knowledge).

## Comparison

`--compare OLD.json` compares this run with an earlier JSON report.

1. OLD.json passes through `normalize_file` (`iconv -c`, then `LC_ALL=C redact_ids`) into the temporary folder, so no UUID from it reaches a format (requirement 14; added 2026-11-26 after the plan review, PR13).
2. The JXA script reads that copy with `JSON.parse`. A file without `"schema": "macassay-report/1"` stops the run before the audit starts, with exit 2.
3. The script compares the two runs by ID only, and sorts IDs into three groups:
   - New: the ID is in this run and absent from the old run.
   - Resolved: the ID is in the old run and absent from this run, and this run's skipped checks do not list it.
   - Not checked: the ID is in the old run, absent from this run, and listed by one of this run's skipped checks. Examples: a `--quick` run after a full run, or a run without the sudo rules.
4. The report lists each group with severity, ID, and text.
5. The section heading names the old run's host and date, and the options of both runs when they differ. A different host is allowed, and the heading shows it.

Accepted findings take part in the comparison like open ones. The old file is treated as untrusted text: the JXA script strips tabs, newlines, and control characters from its values, and the renderers escape them like this run's.

The comparison has no group for an ID whose text changed. Texts often hold counts, sizes, or ages that change on every run, so such a group would be mostly noise. `docs/ISSUES.md` asks for new and resolved findings only.

## Accepted risks

`--accepted FILE` names a text file. Each line holds a finding ID, an optional match text, and an optional reason after `#`:

```text
MA-SHARING-026 TeamViewer   # IT support tool, approved 2026-11
MA-UPDATES-009              # tap kept for testing
```

- A line with no match text accepts every finding with that ID, including new ones in later runs.
- With a match text, a finding is accepted only when its whole text equals the match text, compared as a fixed string. A partial match is not used, because finding text holds names on disk, and an attacker could create a file whose name holds the match text.
- Blank lines and lines that start with `#` are ignored.
- A line whose first word is not an ID that `GUIDANCE` lists stops the run before the audit starts, with exit 2. A typo then fails loudly instead of accepting nothing.
- Reasons pass through `clean_field` before they reach any format.
- The file is never run or sourced. It stays on the local Mac in remote mode.

There is no default file, so a scheduled run must name it.

## Exit status

`--fail-on LEVEL` takes `high`, `medium`, `low`, or `info`. The run then exits 3 when an open finding at or above LEVEL exists. Without the option, a finished audit exits 0, as now.

| Exit | Meaning |
|---|---|
| 0 | The audit finished, and no open finding reaches `--fail-on` |
| 1 | An error, such as a failed remote audit |
| 2 | A usage error, such as an unknown option |
| 3 | The audit finished, and an open finding reaches `--fail-on` |

`docs/ISSUES.md` suggested exit 2 for a HIGH finding. Exit 2 already means a usage error, so 1.5 uses 3.

## Guidance text

`GUIDANCE` is a constant in `macassay`, with one line per finding ID: the ID, a tab, and one sentence on what to check next. The text never tells the user to run a command that changes the Mac without saying what it changes. A fixture test checks that every ID in `docs/CHECKS.md` has one line, and that no line names an unknown ID. The script owns the text, because remote mode runs the script without the docs.

## Managed Macs

### Enrollment state

`profiles status -type enrollment` runs once, without root. Its two lines become the `dep` and `mdm` keys in `meta.tsv`, and the header's Management line. A failed command gives `unknown` and a skip record. The browser-policy check reads `ENROLLED` from the same result instead of running the command again.

`forced_ext_finding` takes a third enrollment value, `unknown`. A force-installed extension from a managed source then gives MA-APPS-005 HIGH, as on an unenrolled Mac, with `(enrollment state unknown)` in the text. Missing evidence must not lower a severity (requirement 9).

A Mac assigned in Apple Business Manager but not enrolled cannot be detected without root. `profiles show -type enrollment` needs root and contacts Apple, which breaks requirement 13. On Apple silicon, the existing `bputil -d` output shows `DEP-allowed MDM Control` when the sudo rules are installed. The Limitations section says that assignment without enrollment is not reported.

### Managed settings

`managed_val DOMAIN KEY` prints the managed value of a key, or nothing. It reads `"$MANAGED_DIR/DOMAIN.plist"`, then `"$MANAGED_DIR/$TUSER/DOMAIN.plist"`, with `plutil -extract KEY raw`. `MANAGED_DIR` is `/Library/Managed Preferences`; the fixture tests point it at a fixture folder.

`plutil -extract KEY raw` prints a boolean as `true` or `false`, while `defaults read` prints `1` or `0` (verified by the review). `managed_val` maps `true` to `1` and `false` to `0`, so the existing tests against `0` and `1` keep working.

`pref DOMAIN KEY LOCALVALUE` sets two globals and prints nothing. It must be called directly, never inside `$( )`, so the globals survive:
- `PV`: the managed value when one exists, otherwise LOCALVALUE.
- `PSRC`: `managed` or `local`.

`pref_line LABEL DEFAULT` then prints the line from `PV` and `PSRC`:
- With `PSRC=managed`, it prints `- LABEL: VALUE (managed)`.
- Otherwise it prints what `default_line` prints now.

The check then judges `PV`. A finding that judges a managed value passes `PSRC` as the fifth argument of `finding`. On a Mac with no managed files, every line and finding reads as in 1.4.

The settings that `pref_line` covers (from the code survey in `report-1.5-tests.md`):

| Domain | Keys | Findings |
|---|---|---|
| `com.apple.SoftwareUpdate` | `AutomaticCheckEnabled`, `AutomaticDownload`, `AutomaticallyInstallMacOSUpdates`, `CriticalUpdateInstall`, `ConfigDataInstall` | MA-UPDATES-003, 004, 006, 007 |
| `com.apple.commerce` | `AutoUpdate` | MA-UPDATES-006 |
| `com.apple.TimeMachine` | `AutoBackup` | MA-BACKUPS-004 |
| `com.apple.loginwindow` | `autoLoginUser`, `GuestEnabled`, `LoginHook` | MA-PLATFORM-006, MA-ACCOUNTS-004, MA-PERSISTENCE-005 |
| `com.apple.security.libraryvalidation` | `DisableLibraryValidation` | MA-PLATFORM-016 |
| `com.apple.LaunchServices` | `LSQuarantine` | MA-PLATFORM-015 |
| `com.apple.FindMyMac` | `FMMEnabled` | MA-PLATFORM-019 |
| `com.apple.RemoteManagement` | `ARD_AllLocalUsers`, `VNCLegacyConnectionsEnabled`, `allowInsecureDH`, `ScreenSharingReqPerm` | MA-SHARING-004, 005, 006 |
| `com.apple.sharingd` | `DiscoverableMode` | MA-SHARING-022 |
| `com.apple.AssetCache` | `Activated` | MA-SHARING-025 |
| `com.apple.security.firewall` | `EnableFirewall`, `EnableStealthMode`, `BlockAllIncoming` | MA-PLATFORM-003, 004 |

Effective-state commands (`fdesetup`, `csrutil`, `spctl --status`, `socketfilterfw`, `sysadminctl`) already report the real state, so their values do not change. For the firewall, a managed key adds `(managed)` to the line and the finding, and the value still comes from `socketfilterfw`.

## Unreadable evidence

Each check below records a skip with the reason, and prints `unreadable (REASON)` instead of a clean value. The list comes from the code survey; cases the survey marked theoretical are left out.

| Check | Failure | 1.4 shows |
|---|---|---|
| Time Machine settings | plist absent while a destination exists | `unknown`, no skip |
| Time Machine destinations | `tmutil destinationinfo` fails | `none`, and MA-BACKUPS-001 fires |
| Kernel panics, Jetsam reports | DiagnosticReports folder unreadable | count 0 |
| 7-day log searches | `log show` fails | counts of 0 |
| Homebrew outdated | `brew outdated` fails | 0, `none` |
| XProtect version | `xprotect version` missing | `unknown`, no skip |
| Enrollment state | `profiles status` fails | `ENROLLED=0`, so MA-APPS-005 HIGH replaces MA-APPS-007 INFO |
| Browser policies | a managed plist exists but cannot be read | `none` |
| Remote Management settings | plist unreadable | `none`, no findings |
| Find My | plist unreadable | `not set` |
| Stealth mode | `socketfilterfw` error text contains `on` | MA-PLATFORM-004 suppressed |
| Screen lock | `sysadminctl` error | no finding |

`readable PATH LABEL` is the shared test: it succeeds when the file is absent or readable, and records a skip when the file exists but cannot be read.

A command failure is detected from its exit status, kept in a variable before the output is used. Some commands may also exit non-zero when there is simply no data, such as `tmutil destinationinfo` on a Mac with no destination. The build verifies the exit status of each command in the table, in both the failure case and the no-data case, before it relies on it. A command whose two cases share an exit status keeps its 1.4 behavior, and the doc records why.

## Version marker

Between releases, `VERSION` reads `1.4.0+dev`, which means code after 1.4.0. The release procedure replaces it with the release version and date. The `+dev` form needs no guess at the next version number.

A fixture test, V1, enforces the rule. It compares only the version number, the first word of `VERSION`, never the date.
1. It finds the latest `v*` tag.
2. When `macassay` matches the tag, the version must equal the tag's version.
3. When `macassay` differs from the tag, the version must be `TAG+dev`, or a release version above the tag that has no tag yet. The second form covers the release commit, which is tested before it is tagged.
The test skips with a note when the folder is not a git checkout.

## Remote mode

1. The local Mac runs the remote copy with `--bundle` and the collection options (`--quick`, `--offline`, `--skip-du`). `--format`, `-o`, `--stdout`, `--compare`, `--accepted`, and `--fail-on` stay local.
2. With `--bundle`, the remote run skips rendering and prints a bundle on stdout, exactly five lines:
   1. `macassay-bundle 1`.
   2. `meta.tsv`, `findings.tsv`, `skipped.tsv`, and `body.md`, in that order, each as base64 text without line breaks.
3. `read_bundle` on the local Mac reads the bundle:
   - It requires the first line and exactly four more lines.
   - Each base64 line must match `^[A-Za-z0-9+/]*={0,2}$` before `base64 -D` decodes it. `base64 -D` exits 0 on some invalid input (verified by the review), so its exit status alone is not enough.
   - Each line decodes into a fixed path in the temporary folder. No name or path comes from the bundle.
   - On any failure, it stops with `Remote audit returned a malformed result.` and exit 1.
4. The local Mac then runs `render_all`, as in a local run. Its Validate step checks every value (see Validation).

The bundle comes from the audited Mac, so its contents are untrusted, like all text from that Mac. An attacker who can write the remote user's `~/.zshenv` controls the whole remote stdout, because zsh reads that file for `ssh host command`. `--bundle` is listed in the help text as an option for remote mode's own use.

### Option combinations

These combinations stop with a usage error, exit 2, before any other work:
- `--format`, `-o`, `--stdout`, `--compare`, `--accepted`, or `--fail-on` with `--print-sudoers` or `--install-sudoers`. The installer runs as root and must not read user files.
- `--bundle` with any output option: `--format`, `-o`, `--stdout`, `--compare`, `--accepted`, or `--fail-on`.
- `--bundle` with `--host`.
- `--stdout` with more than one format.
- `--compare` when `--format` names none of `md`, `html`, or `json`. Only those formats show the comparison. (Added 2026-11-26 after the pre-merge review, decision A5.)

Other combinations:
- `-o` with several formats: a trailing `.md`, `.json`, `.jsonl`, `.html`, or `.csv` is removed from the path, which is then the base path. So `-o report.md --format md,json` writes `report.md` and `report.json`.
- `--stdout` with `--host` writes the report to stdout on the local Mac. 1.4 ignores `--stdout` in remote mode.

## Side effects

No new side effect and no new network traffic. `profiles status -type enrollment` reads local state. `osascript` runs a fixed script on local files. Reading `/Library/Managed Preferences` reads files only.

## Out of scope

- An `--only` option and a partial report when a run is stopped (Later in `docs/ISSUES.md`).
- SARIF, OSCAL, and the AWS Security Finding Format, which wait for a consumer.
- Detecting Apple Business Manager assignment without enrollment.
- Reading settings that DDM applies outside `/Library/Managed Preferences`.
- New checks (version 1.6).

## How to continue if interrupted

1. Read `docs/ISSUES.md` (Version 1.5 and the open questions).
2. Read this doc and `report-1.5-tests.md`.
3. Run `git status` on `feature/report-1.5`.
