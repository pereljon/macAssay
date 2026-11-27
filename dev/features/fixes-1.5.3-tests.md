# Markdown escaping and report permissions: tests (version 1.5.3)

This file holds the test plan for `fixes-1.5.3.md` and the triage of the two outside reviews of 1.5.2. Results go under `## Results` after the build.

## Test plan

Fixture cases run in `dev/test.sh`, with no root and no network. The hostile string H is:

```
![x](http://host.invalid/a.png) <img src=http://host.invalid/b> [l](http://host.invalid/c) \[ end
```

### Fix 1: Markdown escaping

- E1. A finding with text H, rendered with `render_md`: in the findings table, every `[`, `]`, `<`, and `\` from H has a backslash before it.
- E2. The same finding through a CommonMark check: the Markdown line holds no `](` and no `<img` without a backslash before the bracket or angle. (Stock macOS has no Markdown renderer, so the check is textual.)
- E3. `mdesc H` in a list item: the same escapes as E1.
- E4. `mdcode H` keeps H unchanged except for the `clean_field` rules (no added backslashes).
- E5. An accepted-risk reason with H (field 8) is escaped in the Accepted risks table.
- E6. A `--compare` change line whose finding text is H is escaped.
- E7. The HTML report from the same data shows H's text exactly once per place, html-escaped, with no backslash added by `md_esc`, and still no `<a` or `<img` element from H.
- E8. The JSON, CSV, and OCSF reports carry H's finding text with no backslash added.
- E9. Plain text with none of the four characters renders the same as in 1.5.2 (a real 1.5.2 report body as the fixture, compared line by line).
- E10. Each of the twelve raw `say` lines is classified in this file: untrusted values go through `mdesc`, the others are listed with their source.

### Fix 2: report permissions

- W1. A report written to a new path has mode 0600.
- W2. A report written over an existing 0644 file has mode 0600 and the new content.
- W3. With `--format md,json`, both files have mode 0600.
- W4. `-o -` writes to standard output and creates no file.

### Manual checks

- M1. A full local run in iTerm (`./macassay -o <temp path>`): the report reads as before, and the listener table and code spans show no stray backslashes.
- M2. Open the M1 report and an E1 fixture report in a Markdown viewer that loads remote images (Obsidian or VS Code preview): no image, link, or HTML element comes from H.

## Review findings

Triage per `../AGENTS.md` (Review findings). C is the first review (Codex, 2026-11-27); G is the second review (2026-11-27).

- C1 Listener probe follows `http_proxy` and `ALL_PROXY`: fixed on `master` (trivial). It broke the Network promise in `dev/SKELETON.md`; a set proxy variable triggers it. Verified with a fake proxy: the probe reached it without `--noproxy '*'` and not with it.
- C2 Markdown links, images, and HTML survive `clean_field`: fix (Fix 1). It breaks the intent of the "Text from the audited Mac is data" invariant; a planted program path triggers it. Raw HTML was found in addition to the reported images.
- C3 An overwritten report keeps mode 0644: fix (Fix 2), approved by the user (A3). The symlink half is dropped: no trigger, because the user runs the audit and chooses the path.
- C4a `priv` counts a failed command as ran: dropped. Its error output shows in the evidence block, and failures that read as clean are the open Diagnostic log item in `docs/ISSUES.md`.
- C4b The `TMRC` constant makes a failed `tmutil` query read as no destination: dropped. It is decision variant B (`report-1.5.md:50`), upheld by the 1.5 decision review pending I43; the review brought no new evidence.
- C5 Standing sudo access, sensitive reports, documented side effects: dropped. Already documented in `README.md` (Privileged checks, Limits); no requirement broken.
- G1 Sudo rules expose other accounts' crontabs and startup files: dropped, claim wrong. The rules list names and modes only (`docs/SUDOERS.md:28-34`).
- G2 Rules reduce audit visibility: dropped, claim wrong. Only the login record is off; sudo still logs each command.
- G3 HTTP GET to local debug servers: dropped, claim wrong. Loopback listeners are skipped (`macassay:1850`).
- G4 Path staleness, Gatekeeper and Homebrew traffic, `nobody` SSH probe, remote rule install: dropped. Documented in `README.md`.
- G5 Prompt injection through the report: covered by C2 and the report notice (`REPORT_NOTICE`).
- G6 No DDM coverage: dropped. Documented in `README.md:54` and in each report's Limitations.
- G7 EDR alerts, enterprise data handling, maintainer maturity: dropped. Outside the Security Context (one user, own Macs).
- G8 No advice to turn off Full Disk Access after an audit: dropped; no requirement. Offered to the user as an optional README line.
