# Report formats

This file is the reference for what macAssay writes and reads: the five report formats, the accepted-risk file, `--compare`, and the exit statuses. It does not give the reasons for these choices (see `dev/features/report-1.5.md`) or list the checks (see `docs/CHECKS.md`).

## Choosing formats

`--format LIST` takes a comma-separated list of `md` (the default), `json`, `ocsf`, `html`, and `csv`. Every format is built at the end of the run from the same data files, so the formats always agree.

| Format | File extension | For |
|---|---|---|
| `md` | `.md` | A person or an LLM (large language model). It holds the findings and all the evidence. |
| `json` | `.json` | Scripts and `--compare`. It holds the findings, counts, skips, and limitations, but no evidence. |
| `ocsf` | `.ocsf.jsonl` | Security tools that read OCSF (Open Cybersecurity Schema Framework) events. |
| `html` | `.html` | A person with a browser. It holds the same content as `md`. |
| `csv` | `.csv` | A spreadsheet. It holds the findings table only. |

Output paths follow these rules:
- With one format and `-o PATH`, the report goes to PATH exactly as given.
- With several formats, `-o PATH` is a base path. A trailing `.md`, `.json`, `.jsonl`, `.html`, `.csv`, or `.ocsf.jsonl` is removed, and each format adds its own extension. So `-o report.md --format md,json` writes `report.md` and `report.json`.
- Without `-o`, the base path is `./macassay-<host>-<date>`. In remote mode `<host>` is the `--host` value.
- `--stdout` works with one format only. With several formats it is a usage error (exit 2).
- The run builds every format before it writes any. A builder that returns a failure status stops the run with exit 1, and no report is written. The HTML builder returns the status of its last write, so an earlier failure in the page goes unnoticed.
- A failed copy of one format stops the run with exit 1. Formats copied before it stay written.

Every format starts from text that is valid UTF-8 with dashed UUIDs replaced by `<UUID>`. Text read from the audited Mac never reaches a format without passing the format's own escaping function.

## JSON

The JSON report is one object with the schema name `macassay-report/1`. Write the file with `--format json`; `--compare` reads it.

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | Always `macassay-report/1`. |
| `tool.name` | string | `macassay`. |
| `tool.version` | string | The script's `VERSION`, such as `1.5.0 (2026-12-01)` or `1.4.0+dev`. |
| `host` | string | The audited Mac's LocalHostName. |
| `user` | string | The account that ran the audit. |
| `date` | string | Local date and time of the run, such as `2026-12-01 10:00 PST`. |
| `epoch` | number | Unix time of the run's start, in seconds. |
| `options.quick`, `options.offline`, `options.skip_du` | boolean | The collection options of the run. |
| `management.dep` | string | `Yes`, `No`, or `unknown`: enrolled via Apple Business Manager (Device Enrollment Program). |
| `management.mdm` | string | `Yes`, `No`, or `unknown`: enrolled in an MDM (mobile device management) service. |
| `privileged.ran`, `privileged.skipped` | number | Privileged checks that ran, and that were skipped. |
| `counts.HIGH`, `counts.MEDIUM`, `counts.LOW`, `counts.INFO` | number | Open findings at each severity. Accepted findings are not counted here. |
| `counts.accepted` | number | Findings that the accepted-risk file moved out of the open list. |
| `findings` | array | Every finding, open and accepted, in severity order. Each element is described below. |
| `accepted` | array | One `{id, reason}` object per accepted finding. |
| `skipped` | array | One `{kind, label, reason}` object per skipped check. `kind` is `priv` or `other`. |
| `limitations` | array of strings | The report's Limitations lines. |
| `changes` | object | Present only with `--compare`. See the Comparison section. |

Each element of `findings` has these fields:

| Field | Type | Meaning |
|---|---|---|
| `id` | string | The finding ID, `MA-<LABEL>-NNN`. |
| `severity` | string | `HIGH`, `MEDIUM`, `LOW`, or `INFO`. |
| `section` | string | The section label, such as `Sharing`. |
| `section_number` | number | The report section, 1 to 14. |
| `text` | string | The finding text. It contains no tab, newline, pipe, backtick, or control character. |
| `source` | string | `managed` when the finding judges a value that a configuration profile set, otherwise `local`. |
| `accepted` | boolean | `true` when the accepted-risk file covers the finding. |
| `guidance` | string | One sentence on what to check next. The audit never runs it. |

The evidence sections are not part of the JSON. They are free text, and `md` and `html` hold them.

`JSON.stringify` writes the file, so quotes, backslashes, and non-ASCII text are escaped by construction. The file is indented with two spaces.

## OCSF

The `ocsf` format writes one Compliance Finding event (OCSF class 2003, schema version 1.10.0) per finding, then one per skipped check. It is newline-delimited JSON: one event per line, no enclosing array. A run with no findings and no skips writes one blank line.

| OCSF attribute | Finding | Skipped check |
|---|---|---|
| `activity_id`, `type_uid` | 1, 200301 | same |
| `category_uid`, `class_uid` | 2, 2003 | same |
| `severity_id` | HIGH 4, MEDIUM 3, LOW 2, INFO 1 | 1 |
| `time` | `epoch` times 1000 (milliseconds) | same |
| `metadata.version` | `1.10.0` | same |
| `metadata.product` | `name` `macAssay`, `version` the script's `VERSION` | same |
| `finding_info.uid` | `HOST:ID:N`, where N counts this run's findings with that ID from 1 | `HOST:MA-SKIP:N`, where N is the skip's position from 1 |
| `finding_info.title` | the finding text | the skipped check's label |
| `compliance.status_id` | 3 (Fail) | 2 (Warning: no result for lack of information) |
| `compliance.control` | the bare finding ID | absent |
| `compliance.status_details` | absent | an array that holds the skip reason |
| `remediation.desc` | the guidance text | absent |
| `device.hostname` | the host name | same |
| `device.type_id` | 3 (laptop) or 2 (desktop) | same |
| `status_id` | 1 (New), or 3 (Suppressed) for an accepted finding | absent |
| `unmapped` | `section`, `section_number`, `source` | `kind` |

An INFO finding is still a Fail in `compliance.status_id`: it is a judged result, and its severity says how much it matters. The evidence sections and the accepted-risk reason are not in the OCSF output.

## CSV

The `csv` format holds the findings table, open and accepted, in severity order. It follows RFC 4180: lines end in CRLF, every field is in double quotes, and a quote inside a field is doubled. A field that starts with `=`, `+`, `-`, `@`, or a tab gets a leading `'`, so a spreadsheet does not run it as a formula.

The columns, in order:

| Column | Meaning |
|---|---|
| `severity` | `HIGH`, `MEDIUM`, `LOW`, or `INFO`. |
| `id` | The finding ID. |
| `section` | The section label. |
| `finding` | The finding text. |
| `source` | `local` or `managed`. |
| `accepted` | `yes` or `no`. |
| `guidance` | The guidance sentence. |

The first line is the header row. The CSV has no Changes section: with `--compare`, only `md`, `html`, and `json` show the comparison.

## HTML

The `html` format is one self-contained page. It loads nothing and runs nothing.

- No JavaScript. A `Content-Security-Policy` meta tag is the first element in `<head>`: `default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'`. It blocks every script, image, frame, font, and form, and every request to another host. Only the page's own inline style is allowed.
- `html_esc` escapes `&`, `<`, `>`, `"`, and `'` in every value from the audited Mac: finding text, header values, guidance, reasons, limitations, and the page title.
- `md_html` converts the evidence. It escapes each line first, then converts only the Markdown that macAssay writes: `##` and `###` headings, a bold line, fenced blocks, list items, pipe tables, inline code, and plain lines. It never makes a link, an image, or an attribute from text.
- The only links are from each finding's section label to `#section-N`. N comes from the validated section number (1 to 14), never from free text.
- A severity filter of four radio buttons hides rows with the CSS `:has()` selector. A browser without `:has()` shows every finding.
- Evidence sections are `<details open>` blocks, so they print open. The print style hides the filter.
- Colors come from CSS variables, with a dark scheme for `prefers-color-scheme: dark`.

## The accepted-risk file

`--accepted FILE` names a text file that moves known, accepted findings out of the findings table. The file is read as text and never run. It stays on the local Mac in remote mode. There is no default file, so a scheduled run must name it.

Each line has this form:

```text
MA-SHARING-026 TeamViewer   # IT support tool, approved 2026-11
MA-UPDATES-009              # tap kept for testing
```

1. The ID is the first word. It ends at the first space, tab, or `#`.
2. The match text is what follows the ID, up to the first `#`, without leading spaces. It is optional.
3. The reason is what follows the first `#`, without leading spaces. It is optional.

Rules:
- A line with no match text accepts every finding with that ID, including new ones in later runs.
- With a match text, a finding is accepted only when its whole text equals the match text, compared as a fixed string. A partial match is not used, because finding text holds names on disk that an attacker can choose. A match text with regex characters matches literally.
- The first `#` on a line starts the reason. A match text therefore cannot contain `#`. A finding whose text holds a `#` can be accepted only by ID alone, which accepts every finding with that ID.
- The match text and the reason pass through the same cleaning as finding text (pipes become `/`, backticks and control characters are removed), so write the match text as the report shows it.
- When one finding fits both a match line and an ID-only line, the match line's reason is used. When two lines repeat the same ID and match text, the later one wins.
- Blank lines and lines whose first character after leading spaces is `#` are comments.
- A first word that is not a finding ID that macAssay gives stops the run before the audit starts, with exit 2 and `Line N of FILE: ID is not an ID that macassay gives to a finding.` A file that cannot be read stops the run the same way.

Accepted findings leave the header counts, the findings table, and the `--fail-on` test. They appear in an Accepted risks section (`md`, `html`), in `findings` with `accepted: true` and in `accepted` (`json`), with `status_id` 3 (`ocsf`), and with `accepted` set to `yes` (`csv`).

## Comparison

`--compare OLD.json` compares this run with an earlier macAssay JSON report. The old file must carry `"schema": "macassay-report/1"`; any other file stops the run before the audit starts, with exit 2 and a message that names the file.

The comparison uses finding IDs only, never finding text, because text often holds counts, sizes, or ages that change on every run. It sorts IDs into three groups:

| Group | The ID is |
|---|---|
| New | in this run, and absent from the old report |
| Resolved | in the old report, and absent from this run, and no skipped check of this run lists it |
| Not checked | in the old report, and absent from this run, and listed by a skipped check of this run |

Not checked covers a `--quick` run after a full run, and a run without the sudo rules. These checks did not run, so their findings are not resolved.

Details:
- Accepted findings take part like open ones.
- An entry in the old file whose ID does not have the form `MA-<LABEL>-NNN` is ignored. An unknown severity reads as INFO.
- The old file passes through UTF-8 normalization and UUID redaction, and each value from it is stripped of control characters, tabs, and newlines. It is untrusted text, and each format escapes it like this run's values.
- The section heading names the old run's host and date. It adds a line when the collection options of the two runs differ. A different host is allowed.
- `md` and `html` hold a `Changes since the previous run` section after Findings, with each group's count and one line per ID (severity, ID, text). `json` holds a `changes` object: `compared_with` (`host`, `date`), and the arrays `new`, `resolved`, and `not_checked`, each element `{id, severity, section, text}`. `ocsf` and `csv` show no changes.

## Exit statuses

| Exit | Meaning |
|---|---|
| 0 | The run finished and wrote every report. No open finding reaches `--fail-on`, or `--fail-on` is not set. `-h` and `--version` also exit 0. |
| 1 | An error: a failed SSH connection or remote audit, a malformed remote result, a data file that could not be normalized, a format that could not be built, a comparison that failed, or a report file that could not be written. |
| 2 | A usage error, before any audit work: an unknown option or format, a missing value, a bad `--fail-on` level, an option combination that is not allowed, an unreadable or invalid `--accepted` or `--compare` file, or a run as root. |
| 3 | The run finished and wrote every report, and an open finding is at or above the `--fail-on` level. |

`--fail-on LEVEL` takes `high`, `medium`, `low`, or `info`, in lowercase. An empty or other value is a usage error, so an unset variable in a scheduled job cannot turn the gate off. Accepted findings never count. In remote mode `--fail-on` works the same, because the local Mac renders the report.

These option combinations are usage errors:
- `--format`, `-o`, `--stdout`, `--compare`, `--accepted`, or `--fail-on` with `--print-sudoers` or `--install-sudoers`.
- `--bundle` with any of those output options, or with `--host`.
- `--stdout` with more than one format.

If one format's file cannot be copied to its path after others were written, the earlier files stay on disk and the run exits 1.
