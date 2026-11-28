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
- E9. Data with none of the four characters renders the same Markdown and HTML as release 1.5.2. The fixture is synthetic, because a real report describes a real Mac; the 1.5.2 script comes from the `v1.5.2` tag. M1 covers a real report.
- E10. Each raw `say` value and `block` title is classified below: untrusted values go through `mdesc`, the others are listed with their source.
- E11. A skip label with `[`, `<`, and `\` is escaped in the Markdown Limitations list, shows the original text in HTML, and is unchanged in JSON.
- E12. `skip_reason` escapes a reason with H.

### Fix 2: report permissions

- W1. A report written to a new path has mode 0600.
- W2. A report written over an existing 0644 file has mode 0600 and the new content.
- W3. With `--format md,json`, both files have mode 0600.
- W4. `--stdout` writes to standard output and creates no file.

### Manual checks

- M1. A full local run in iTerm (`./macassay -o <temp path>`): the report reads as before, and the listener table and code spans show no stray backslashes.
- M2. Open the M1 report and an E1 fixture report in a Markdown viewer that loads remote images (Obsidian or VS Code preview): no image, link, or HTML element comes from H.

## E10 classification

Raw values written to the Markdown body before 1.5.3, found with `grep` over `say` lines and `block` titles.

Now through `mdesc` (from the audited Mac):
- Time Machine destinations (`TMDEST`, volume names), latest backup and count (`LASTBK`, `NSD`), encryption (`TMENC`), home folder exclusion (`EXC`).
- SSH offers (`AM`, parsed from the SSH client), SSH access group members, admin group members (`ADM`).
- Account name in each account heading; the home path in that heading uses `mdcode`, inside a code span.
- Guest account value (`GU`) in the unmanaged branch.
- Block title "Largest items in" (`THOME`, from `dscl`); sudoers file blocks and their skip lines (file names in `/etc/sudoers.d`).
- Every `skip_reason` output, through `md_esc`.

Left raw (set by the script):
- Counts: memory, Jetsam reports, panics, snapshots, backup age, packages, firewall entries, writable folders, root daemons, login items, crontab entries, SSH log counts, XProtect results, SSH client blocks.
- `XPI` (a date that a `sed` pattern extracts), `LANIP` (an address), `sc` (fixed text), `SW` (inside a code span), block titles and `h2`/`h3` headings with fixed text.
- `M_HOST` and `M_USER` in the header, which `valid_meta` limits to `[A-Za-z0-9_.-]`.

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

Pre-merge review of `fix/1.5.3` at `b5d8695` (R, 2026-11-27, opus, high):

- R1 Limitations and `skip_reason` escaping had no test (three mutations passed): fixed with E11 and E12; each mutation now fails a case.
- R2 E9 not built as planned, E10 and results missing: fixed. E9 compares with the `v1.5.2` script; E10 and Results below.
- R3 Raw values from the audited Mac still in Markdown (`GU`, the `THOME` block title, sudoers file names): fixed. They break the "Text from the audited Mac is data" invariant as written; only root or an admin can set them.
- R4 The docs named an `-o -` mode that does not exist: fixed; the docs name `--stdout`.
- R5 `-o /dev/null` now fails because `chmod` is refused: dropped. No requirement; `--stdout >/dev/null` works. Recorded in the design doc.
- R6 E2's regex accepts `\\[`: dropped. E1's exact match covers that case.

## Results

- Fixtures (2026-11-27, development Mac, `/bin/bash` 3.2): all cases pass, including E1 to E12 and W1 to W4. `bash -n` passes; ShellCheck shows the 3 historical findings in `macassay` and no new finding in `dev/test.sh`.
- Mutations (2026-11-27): removing the `chmod`, the `\` from either `md_esc`, `md_unesc` on bold lines, its `\\` handling, or the escaping of change lines, accepted-risk reasons, Markdown limitations, HTML limitations, or `skip_reason` each makes a 1.5.3 case fail.
- M1 (2026-11-27, agent session without Full Disk Access, `--quick --offline --skip-du --format md,html`): both files are mode 0600. The only escaped value was `tmutil`'s `[Included]`, which shows as `[Included]` in HTML. No backslash appears in a code span. A full run in iTerm is still to do.
- M2 (2026-11-27, the user, in a Markdown viewer that loads remote images): a synthetic report from 1.5.2 showed two remote images (Markdown image syntax and raw `<img>`) and a link, in the Findings table and the body. The same data from 1.5.3 showed the text literally in the body line, with no image, link, or HTML; only the bare URLs were linked by the viewer, as the design expects. The 1.5.3 Findings table was not viewed; E1 checks that its cell carries the same escapes.
- Homebrew auto-update, for the README (2026-11-27, development Mac, Homebrew 7.0.17), judged by the `FETCH_HEAD` time in the Homebrew repository:
  - A plain `brew outdated` updated less than 5 hours after the previous update. This Mac has `homebrew.devcmdrun = true`, which sets a 1-hour interval (`brew.sh:550-557`, `utils/auto-update.sh:79-82`); the default is 24 hours.
  - `HOMEBREW_NO_AUTO_UPDATE=1` with `HOMEBREW_AUTO_UPDATE_SECS=1` blocked the update, both for `brew outdated` alone and through `./macassay --quick --skip-du`; the outdated lists still printed.
  - `HOMEBREW_AUTO_UPDATE_SECS=1` alone updated Homebrew, for `brew outdated` alone and 13 seconds into a `macassay` run.
