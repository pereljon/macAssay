---
kind: feature
lifecycle: shipped
status: shipped in v1.3.2 (2026-11-26)
---

# Report fixes from the MacBook run (version 1.3.2)

This doc is the plan of record for version 1.3.2: six bug fixes found in the review of a full 1.3.1 run on the MacBook. Test cases and review findings live in `fixes-1.3.2-tests.md`. The bug list itself lives in `docs/ISSUES.md` (Version 1.3.2).

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64), sudo 1.9.17p2, and `macassay` 1.3.1 at commit `4598245`.

## Goal

Stop the audit from writing login records on the audited Mac, and fix five report errors that the MacBook run showed. No new check and no new finding.

## Requirements

1. A run with the macassay sudo rules writes no login record (utmpx or wtmp entry) on the audited Mac. Source: `AGENTS.md` (Read-only), user decision D1 on 2026-11-25.
2. The installer makes one sudo call for its folder check instead of one per folder. Its remaining login records are listed as an installer side effect in `dev/HANDOFF.md`. Source: user decision D1.
3. The non-Apple installs list and MA-UPDATES-008 leave out Apple's own installs. Source: `docs/ISSUES.md` bug.
4. Process names with spaces print in full in "Top 15 processes by memory". Source: `docs/ISSUES.md` bug.
5. Crash counts by kind group `.diag` reports by program. Source: `docs/ISSUES.md` bug.
6. A missing file in another account's folder prints "none", not error text. Source: `docs/ISSUES.md` bug; the 1.3.1 rule that empty checks print "none".
7. Each bold block title renders as its own paragraph in a Markdown viewer. Source: `docs/ISSUES.md` bug.
8. No new sudo rule, no new side effect, stock tools under `/bin/bash` 3.2 only. Source: `AGENTS.md` (Design Principles).

## Fix 1: login records from sudo

### Cause

Each privileged check runs `sudo -n -k COMMAND` through `priv` (`macassay:322`). `man sudoers` for sudo 1.9.17p2 states two defaults:
- `use_pty`: "on by default for sudo 1.9.14 and above". When sudo runs in a terminal, it runs the command in a new pseudo-terminal (pty).
- `set_utmp`: "on by default". sudo writes a utmp entry "when a pseudo-terminal is allocated".

So each privileged check adds a login record, and `last` lists it. Evidence: all 25 `last` rows in the MacBook report fall within the install and the run, and the development Mac shows the same bursts at the 2026-11-24 test runs. The cause is inferred from the man page and the timing; test M2 confirms it.

### Change

1. The rule template (`gen_rules`, `macassay:124`) writes `Defaults!MACASSAY always_set_home, !set_utmp`.
2. `use_pty` stays on. The man page says the pty stops a program run under sudo from injecting commands into the user's terminal. Several macassay commands read untrusted data, so that protection stays.
3. The installer's folder check (`macassay:401`) runs one `sudo -u USER /bin/sh -c SCRIPT sh DIR...` call. The script loops over its arguments and prints each folder that the user can write. Folder paths go in as arguments, never as script text, so no file name from the Mac is parsed as code. The script text is a fixed string in a variable, `WRITABLE_SH`, which the fixture tests also run.
4. `dev/HANDOFF.md` (Design constraints) lists the installer's login records: one for the folder check and one for the closing check that the rules work.

### Behavior on Macs with older rules

The new rules take effect only after `sudo ./macassay --install-sudoers` runs again. Until then, a 1.3.2 audit still writes login records. The installer already shows a diff when it replaces the rules file. `CHANGELOG.md` and `README.md` tell the user to reinstall.

### Assumption to verify

The man page documents command-scoped Defaults (`Defaults!cmnd`) but does not say whether `set_utmp` takes effect in one. `visudo -c` checks only the syntax. Test M2 checks the behavior on a real install.

## Fix 2: Apple installs in the non-Apple list

`recent_installs` (`macassay:454`) drops only records whose process is `softwareupdated`. This Mac's install history shows three other sources of Apple installs:
- App Store installs of Apple apps (Numbers, Pages, Keynote, Xcode) come from `appstoreagent` or `appstored`, with a first package ID of `com.apple.pkg.*`.
- XProtect data updates come from `XProtectUpdateService`, with no package ID.
- Rosetta and other system packages come from `softwareupdated`, `softwareupdate`, or `bootinstalld`, with `com.apple.pkg.*` IDs.

The new rule drops a record in either case:
- Its process is `softwareupdated`, `softwareupdate`, `XProtectUpdateService`, or `bootinstalld`.
- Its process is `appstoreagent`, `appstored`, or `CoreServicesUIAgent` (the prompt that installs Rosetta), and its first package ID starts with `com.apple.`.

A package ID alone does not prove that Apple made the package, because any package can claim a `com.apple.` ID. So a `com.apple.` package installed by `installer` or Installer.app stays in the list. Third-party App Store apps also stay.

## Fix 3: process names in the memory list

The memory list (`macassay:695`) prints awk field `$5`, which cuts `comm=` at its first space. A new function, `top_mem`, prints everything after the fourth field. User names on macOS contain no spaces, so the first four fields always split correctly.

## Fix 4: crash counts by kind

The sed pattern (`macassay:709`) strips a date that follows `-`. `.diag` names put `_` before the date, as in `WindowServer_2026-11-24-094451_host.cpu_resource.diag`. A new function, `crash_kinds`, strips a date that follows either `-` or `_`.

## Fix 5: error text in another account's blocks

`priv` copies the command's stderr into its output (`macassay:327`). For a missing `authorized_keys` file or `LaunchAgents` folder, that output is only a "No such file or directory" line. `privblk` has two callers, both in "Other accounts and root" (`macassay:1102` and `macassay:1103`). `privblk` now passes its output through `drop_enoent`. That filter prints nothing when the whole output is one `ls:` or `ssh-keygen:` missing-file error, and `block` then prints "none". ssh-keygen ends its error lines with `\r\n`, so the filter strips a final `\r` before it matches. Any other output passes unchanged. When the folder exists, `ls -ln` prints a `total` line first, so a crafted file name cannot make the output a single error line. Other error text, such as "is not a public key file", stays.

## Fix 6: bold titles inside list items

`block` and `run` write `**title**` straight after the previous report line. When that line is a list item (`- Swap: …`), Markdown joins the title to the item. Both functions now write a blank line before the title, and so does the `**Account NAME**` heading in "Other accounts and root". A doubled blank line after a heading does not change the rendered page.

## Decisions

- 2026-11-25: Turn off `set_utmp` for the MACASSAY commands and keep `use_pty`. Rejected: `!use_pty`, which removes sudo's protection against terminal injection; filtering the audit's rows out of `last`, which hides the writes but keeps them. Conviction: `firm` (D1).
- 2026-11-25: The installer merges its folder check into one sudo call and lists its remaining login records as a side effect. Rejected: leaving one call per folder (about nine records per install); `su` or other routes around sudo, which start the user's login shell and run its startup files. Conviction: `firm` (D1).
- 2026-11-25: An install record counts as Apple's only when an Apple update process wrote it, or when the App Store or the Rosetta prompt wrote it with a `com.apple.` package ID. Rejected: dropping every `com.apple.` package ID, which lets a hand-installed package hide by claiming one.

## Build order

1. Fixes 2 to 6, with their fixture tests: report-only changes.
2. Fix 1: template, installer, fixture tests, then `dev/HANDOFF.md`.
3. Manual tests M1 to M3 on this Mac, after the user confirms the install.
4. Pre-merge review, then `CHANGELOG.md`, `README.md`, `VERSION`, and `docs/ISSUES.md`.

Keep out: no change to check logic outside the six fixes, and no 1.4 work.

## How to continue if interrupted

Read `docs/ISSUES.md` (Version 1.3.2), then this doc and `fixes-1.3.2-tests.md`. Run `git log master..fix/1.3.2` to see which build steps are done. Each step is one commit.
