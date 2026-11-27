# Test plan: fixes from the post-release decision review

This file holds the test cases, review findings, and results for `fixes-1.5.1.md`. It does not repeat the design.

Two kinds of test cover version 1.5.1:
- `dev/test.sh` runs the changed functions on fixtures, without root and without the network. The new cases are V1 to V4.
- A quick run on the development Mac, and one full run in the user's terminal, check the changed report sections.

## Before code

- B1. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay` on `master`, and record the counts.

## dev/test.sh (fixture tests)

- V1. `app_login_items` on a test folder:
  - Listed: a login item of an app directly under the root; a login item of an app in a vendor folder; a login item of an app in a hidden folder, which `unusual_path` then matches.
  - Listed: a launchd plist in `Contents/Library/LaunchAgents` and in `Contents/Library/LaunchDaemons` of an app in a vendor folder.
  - Not listed: `Info.plist` inside a bundle inside `Contents/Library/LaunchAgents`, and a plist in a subfolder of `Contents/Library/LaunchAgents` at depth 6.
  - An app folder whose name holds a space, a leading `-`, and `$(touch PWNED)` is listed unchanged, and no `PWNED` file appears.
- V2. `btm_items` on a fixture dump with two accounts:
  - An item listed in both accounts with dispositions `enabled` and `disabled` prints once, with `enabled/disabled`.
  - An item listed twice with the same disposition prints once, with `enabled`.
  - An item with Identifier `16.com.apple.tftpd` is left out.
  - A `developer` row is left out (per question B2).
  - An item with an executable path shows that path; an item with only a URL shows the URL.
  - Output is one line per item in the order `TYPE | NAME | PATH | DISPOSITIONS`.
- V3. The outbound check on fixture `netstat` text:
  - `tcp_listed` fails on text with no `tcp` line, and succeeds on text with a listener.
  - The label `Outbound connections` has a row in `SKIP_IDS`.
  - The skip record and the body line are checked live in M1. The `none` line when no connection is outbound comes from `block` on empty input, which fixture P7 covers; no run on this Mac can show it, because its `netstat` lists no sockets.
- V4. For each format that `check_formats` accepts, `git check-ignore -q` ignores `macassay-host-20261127-1200` plus `fmt_ext FORMAT`. The case is skipped with a note outside a git repo.
- The existing F, G, P, and R cases still pass.

## Development tool

- T1. `time dev/test.sh | tail -1` returns within a few seconds of the last case.
- T2. With a temporary `sleep 120` added as the first case, the suite still fails with "suite timed out after 60 seconds". Remove the line afterwards.

## Manual tests

- M1. Quick run from the agent's shell: `./macassay --quick --offline --skip-du -o <session temp folder>/m1.md`. Pass:
  - The outbound section says `skipped` with the reason, and Limitations lists `Outbound connections`.
  - The login items section lists the login item of the app in a vendor folder that depth 5 missed.
- M2. Full run in the user's terminal with the sudo rules installed. Pass: the background items block holds one line per item, no `com.apple.` identifier, no truncation note, and no `developer` row.

## Review findings

Pre-merge review, 2026-11-27, opus at high effort, against `ebf7475`. Triage per the development `AGENTS.md` (Review findings).

- R1. The V1 nested-bundle case sat at depth 7, beyond `-maxdepth 6`, so it passed without the exclusion. Fixed: a depth-6 plist in a subfolder of `LaunchAgents`, which fails without the exclusion.
- R2. The plan and results claimed V3 cases that the fixtures do not hold (the skip record, the `none` line). Fixed: V3 is narrowed to what it tests, and the rest points to M1 and fixture P7 (root `AGENTS.md`, do not report work as passing without having checked it).
- R3. An item whose Identifier claims `com.apple.` is hidden from the background items block; the plist Label or bundle ID sets it. Dropped: not Critical, and no requirement; the approved design sets this filter. Legacy plists still show in the startup items table. Candidate for the B2 review in `docs/ISSUES.md`.
- R4. Under a UTF-8 locale, an invalid byte in the dump makes `/usr/bin/awk` abort, and the block then reads `none`. Dropped: not Critical, and no trigger shown (`sfltool` prints plist strings and file names, normally valid UTF-8). The open item to run the suite under a UTF-8 locale in `docs/ISSUES.md` covers the class.
- R5. DISPOSITIONS keeps only the first word, so `disallowed` (from training knowledge, set when the user turns an item off) is not shown. Dropped: no requirement; the approved design says first word, and no item on this Mac shows `disallowed`. Candidate for the B2 review.

## Results

Run 2026-11-27 on the development Mac (macOS 27.2.1).

- B1: on `master` (`797a541`), 600 fixture cases pass, `bash -n` passes, and ShellCheck shows the three historical findings (2 SC2010, 3 SC2012 lines).
- V1 to V4: pass; 616 cases pass in all. The V1 subfolder case fails when the `! -path` exclusion is removed (checked 2026-11-27). The old P4 case tested `btm_unique`, which V2 replaces. ShellCheck on `macassay` matches the baseline; on `dev/test.sh` the one new SC2016, the intended literal `$(touch PWNED)` in V1, is suppressed inline.
- T1: pass; `dev/test.sh | tail -1` took 7.1 s in all.
- T2: pass; the watchdog printed "suite timed out after 60 seconds" at 60 s. The piped run still ended at 120 s, because the injected `sleep 120` is the suite's own hung command and holds the pipe. A real hang behaves the same, and so did the old watchdog.
- M1: pass. The outbound section reads `skipped (netstat lists no TCP sockets for this account)`, and Limitations lists it. The login items section now lists the app in a vendor folder, 17 items against 16 before.
- M2: pass. Full run by the user in iTerm, 2026-11-27, from `b34c84f`: 68 findings, 2 checks skipped, 5 min 28 s. The background items block holds 109 lines, each with four fields, no `com.apple.` identifier, no developer row, and no truncation note. Login items inside apps: 17. The outbound list holds connections: `netstat` lists sockets in iTerm but not in the agent's tmux session on the same Mac. The user TCC database check recorded a skip with the reason "needs Full Disk Access", although the Time Machine settings, which need the same access, were read.
