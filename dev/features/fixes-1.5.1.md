---
kind: feature
lifecycle: building
status: approved by the user 2026-11-27
---

# Fixes from the post-release decision review (version 1.5.1)

This doc is the plan of record for version 1.5.1: five fixes from the follow-ups of the post-release decision review (`dev/features/decision-review-1.5.md`, decision A15). Test cases and review findings live in `fixes-1.5.1-tests.md`. The items themselves live in `docs/ISSUES.md` (Next steps).

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64) and `macassay` 1.5.0 at commit `797a541`, on the development Mac.

## Goal

Make the one unreachable check reachable, shorten the background items block so that it fits, note an outbound list that macOS hides, and fix two development-tool gaps. No new finding ID, no new sudo rule, and no new side effect.

## Requirements

1. MA-PERSISTENCE-023 can fire for an app in a hidden folder under `/Applications` or `~/Applications`. Source: `docs/ISSUES.md` (Next steps, I24 of the decision review).
2. The background items block lists every non-Apple item without truncation on the development Mac. Source: `docs/ISSUES.md` (Next steps, I12).
3. When `netstat` lists no TCP sockets, the report says the outbound list is unavailable. Source: `docs/ISSUES.md` (Next steps); the 1.5 rule that unreadable evidence gets a skip record (decision A3 in `dev/features/report-1.5.md`).
4. A fixture test fails when a `--format` extension is not covered by `.gitignore`. Source: `docs/ISSUES.md` (Next steps); `AGENTS.md` (Do not commit generated reports).
5. Piping `dev/test.sh` returns when the last case ends. Source: `docs/ISSUES.md` (Next steps).
6. Stock tools under `/bin/bash` 3.2 only. Source: `AGENTS.md` (Design Principles).

## Fix 1: login items in hidden folders

### Cause

The search for login items inside apps (`macassay:1922`) runs `find /Applications "$THOME/Applications" -maxdepth 5`. A login item at `/Applications/X.app/Contents/Library/LoginItems/Y.app` is at depth 5. An app in any subfolder puts its login item at depth 6, so the search never sees it. `unusual_path` matches a temporary folder, `/Users/Shared`, or a hidden folder. Under the two search roots, only a hidden folder can match, and a hidden folder always adds a level. MA-PERSISTENCE-023 therefore cannot fire.

The same limit hides login items of apps in vendor folders. On the development Mac, depth 6 adds one: the login item of an app in a vendor folder (`/Applications/VENDOR/APP.app/Contents/Library/LoginItems/HELPER.app`). MA-PERSISTENCE-021 and MA-PERSISTENCE-022 miss such apps today.

### Change

1. Move the search into a function, `app_login_items ROOT...`, so that a fixture can call it on a test folder.
2. Raise the depth to 6. This covers one folder between a root and the app: a vendor folder or a hidden folder.
3. Exclude matches below a launchd folder (`! -path '*/LaunchAgents/*/*'` and the same for `LaunchDaemons`). At depth 7, the current patterns match an `Info.plist` inside a bundle inside an app's `Contents/Library/LaunchAgents`, which is not a launchd plist (seen on the development Mac). Depth 6 avoids this case today, but the exclusion keeps a nested bundle from matching.

A hidden folder two levels down still escapes the search. Question B1 asks whether to accept that limit.

Measured once each on the development Mac: depth 5 took 1.95 s, depth 7 took 1.71 s, and depth 8 took 2.76 s. Depth 6 was not timed; it lies between two runs that differ by less than the run-to-run noise.

## Fix 2: background items, one line per item

### Cause

The block (`macassay:1884`) keeps six fields per item from `sfltool dumpbtm`, one per line. `sfltool` lists the items once for each account (four accounts on the development Mac). `btm_unique` drops exact repeats, but an item's Disposition differs between accounts, so most repeats survive. On the development Mac the dump has 2,490 lines and the block has 792 lines against a cap of 200.

The `grep -v com.apple` filter drops single lines, not items. An Apple item keeps its Name, Type, and Disposition lines whenever its path does not contain `com.apple`, so the block is not "non-Apple" as titled.

### Change

Replace `btm_unique` with `btm_items`, an `awk` function that reads the whole dump and prints one line per item:

```
TYPE | NAME | PATH | DISPOSITIONS
```

- PATH is the `Executable Path`, or the `URL` when there is no executable path.
- An item is the same item in every account when its type, name, and path match. DISPOSITIONS joins the first word of each distinct Disposition, such as `enabled/disabled`.
- An item whose `Identifier` starts with a number and `.com.apple.` is left out.
- A `developer` row is left out: it names a developer group and has no path. Question B2 asks whether to keep these rows.

On the development Mac a prototype of this format gives 133 lines before the Apple and developer rows are removed. The 200-line cap stays as a guard.

The text still reaches the report only through `block`, so the Text from the audited Mac is data invariant holds.

## Fix 3: a hidden outbound list

### Cause

The outbound list (`macassay:1834`) prints nothing when `netstat -anv -p tcp` finds no established connection. On the development Mac, unprivileged `netstat` lists no TCP sockets at all (`docs/ISSUES.md`, Bugs), so the list is missing with no note. A Mac with network access always has some TCP socket, at least `mDNSResponder` or a listener, so an empty `netstat` means that macOS hid the sockets.

### Change

1. Read `netstat -anv -p tcp` once.
2. When it holds no line that starts with `tcp`, record a skip with the label `Outbound connections` and say `- Outbound connections: skipped (REASON)`. The reason is "netstat lists no TCP sockets for this account". The label gets a row in `SKIP_IDS` with no finding IDs.
3. Otherwise print the block, which prints `- TITLE: none` when no connection is outbound.

The listener table already falls back to `lsof` and stays unchanged. The root cause of the hidden sockets stays an open bug.

## Fix 4: a fixture test for report patterns in `.gitignore`

Add fixture V4: for each format that `check_formats` accepts, build the name `macassay-host-20261127-1200` plus `fmt_ext FORMAT`, and pass when `git check-ignore -q` ignores it. The test is skipped with a note when `git` or the repo is missing, so the suite still runs from an exported copy.

## Fix 5: the test watchdog holds the pipe open

### Cause

The watchdog (`dev/test.sh:10`) runs `sleep 60` in a background subshell. The EXIT trap kills the subshell but not its `sleep` child. The `sleep` inherited the suite's stdout and stderr, so a pipe reader such as `tail` waits for up to 60 seconds.

### Change

Redirect the `sleep` to `/dev/null`: `( sleep 60 >/dev/null 2>&1; echo ... >&2; kill -TERM $$ ) &`. The orphaned `sleep` then holds no pipe, and the timeout still fires.

## Release

Version 1.5.1, a patch release. Update `CHANGELOG.md`, `docs/CHECKS.md` (the login items row and the background items text), `VERSION` in `macassay`, and `docs/ISSUES.md`.

## Decisions

- B1 (2026-11-27, `firm`): search one folder level between a root and the app (depth 6), and accept that a hidden folder two levels down escapes the search. Rejected: a deeper search, which adds nested-bundle matches and is still evaded by a deeper path. The user asked to review this again later; `docs/ISSUES.md` (Next steps) holds the item.
- B2 (2026-11-27, `firm`): leave `developer` rows out of the background items block. Rejected: keeping them, since they name a group and carry no path. The user asked to review this again later; `docs/ISSUES.md` (Next steps) holds the item.
- B3 (2026-11-27, `firm`): the user approved the test plan.
