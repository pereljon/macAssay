---
kind: feature
lifecycle: shipped
status: shipped in v1.5.3 (2026-11-27)
---

# Markdown escaping and report permissions (version 1.5.3)

This doc is the plan of record for version 1.5.3: two fixes from the outside reviews of 1.5.2 on 2026-11-27. Test cases and the triage of every review finding live in `fixes-1.5.3-tests.md`. The proxy fix from the same review is a trivial change on `master` and is not part of this doc.

Investigated against `macassay` 1.5.2 at commit `1d4da9e` on the development Mac (macOS 27.2.1).

## Goal

Text read from the audited Mac stays inert text in every Markdown viewer, and a report file is readable only by its owner, also when it replaces an older file. No new finding ID, no new sudo rule, and no new side effect.

## Requirements

1. Untrusted text in the Markdown report never renders as a link, an image, or HTML. Source: `dev/SKELETON.md` (Text from the audited Mac is data); review finding C2; approved by the user 2026-11-27 (A2).
2. The HTML, JSON, CSV, and OCSF reports show the same text as before, with no added backslashes. Source: the same invariant, which gives one escaping function to each format.
3. Every report file the run writes has mode 0600. Source: approved by the user 2026-11-27 (A3), extending the intent of `umask 077` (`macassay:64`).
4. Stock tools under `/bin/bash` 3.2. Source: `AGENTS.md` (Design Principles).

## Fix 1: Markdown escaping

### Cause

`clean_field` (`macassay:88`) removes tabs, newlines, pipes, backticks, and control characters. It keeps `[`, `]`, `!`, `(`, and `<`. A finding's text goes into the Markdown findings table outside a code span, so `![x](http://host/a.png)` renders as a remote image, and `<img src=...>` renders as HTML in viewers that allow it. MA-PERSISTENCE-001 copies a program path under `/tmp` into its text, and anyone who can create that file chooses the path. The same holds for every `mdesc` value outside a code span in the report body. Some `say` lines and `block` titles also write a value from the audited Mac without `mdesc`; `fixes-1.5.3-tests.md` (E10) lists them.

The HTML report escapes with `html_esc` and never makes a link, so it is not affected. `clean_field` also feeds the JSON, CSV, and OCSF formats, so the fix cannot go there.

### Change

1. Add `md_esc`, which puts a backslash before each `\`, `[`, `]`, and `<`. Backslash escapes of these characters are standard Markdown (CommonMark 6.1). Escaping `[` breaks links, images, and reference links; escaping `<` breaks raw HTML and `<URL>` autolinks; escaping `\` stops input from cancelling an escape.
2. `mdesc` becomes `clean_field` followed by `md_esc`. Add `mdcode`, which is `clean_field` alone, for the call sites inside a code span (seven calls on six lines). Markdown does not process escapes in a code span, and a code span renders nothing active.
3. In the Markdown path only, escape with the same rule: the finding text (field 4) and the accepted-risk reason (field 8) in `render_md` (awk `md_esc` in `MD_LIB`); the old host, date, options, and change lines in `md_changes`; the Limitations list; and `skip_reason`, whose output goes only into `say` lines.
4. Classify each `say` line and `block` title that writes a raw value. Route each value that comes from the audited Mac through `mdesc`. Leave counts and values the script sets itself.
5. In `md_html`, `md_unesc` removes the backslash from `\\`, `\[`, `\]`, and `\<` outside code spans and on bold lines, so the HTML report shows the original text. It runs after `html_esc`, so it matches `\&lt;` for `\<`. The HTML Limitations list escapes with `md_esc` before `md_inline`, so that a backslash in a skip reason survives.

Bare URLs stay as text. Some viewers (GitHub Flavored Markdown) show them as links, but a viewer never fetches a link without a click, and macAssay already prints URLs that a person may want to open.

Remote mode needs no change: the remote side writes `body.md` with the same script, and the local side renders it.

## Fix 2: report permissions

### Cause

`render_all` writes each report with `cp` (`macassay:615`). When the target file exists, BSD `cp` keeps its mode, so a report that replaces a 0644 file stays 0644. Verified 2026-11-27 on the development Mac. `umask 077` protects new files only.

### Change

After each `cp`, run `chmod 600` on the report. A failed `chmod` reports `Could not write PATH.` and returns 1, as a failed `cp` does. `--stdout` writes no file and is unchanged.

A target the user cannot `chmod`, such as `-o /dev/null`, now fails with `Could not write /dev/null.` (review finding R5, dropped). `--stdout >/dev/null` gives the same result as before.

A symbolic link at the target path keeps working as today: the run writes as the user, to a path the user chose, so no other account can plant the link (review finding C3, symlink half, dropped).

## Decisions

- 2026-11-27: Escape in the Markdown output, not in `clean_field`. Rejected: escaping in `clean_field`, which would add backslashes to the JSON, CSV, OCSF, and HTML reports. `firm` (the user approved A2).
- 2026-11-27: Escape four characters (`\`, `[`, `]`, `<`). Rejected: escaping every Markdown punctuation character, which makes the report harder to read for people and LLMs and blocks nothing active. Emphasis characters such as `*` and `_` change only how text looks.
- 2026-11-27: Set the mode with `chmod 600` after `cp`. Rejected: deleting the old file before the copy, which breaks a target that is a link the user set up.
