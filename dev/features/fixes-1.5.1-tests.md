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
  - Not listed: `Info.plist` inside a bundle inside `Contents/Library/LaunchAgents`.
  - An app folder whose name holds a space, a leading `-`, and `$(touch PWNED)` is listed unchanged, and no `PWNED` file appears.
- V2. `btm_items` on a fixture dump with two accounts:
  - An item listed in both accounts with dispositions `enabled` and `disabled` prints once, with `enabled/disabled`.
  - An item listed twice with the same disposition prints once, with `enabled`.
  - An item with Identifier `16.com.apple.tftpd` is left out.
  - A `developer` row is left out (per question B2).
  - An item with an executable path shows that path; an item with only a URL shows the URL.
  - Output is one line per item in the order `TYPE | NAME | PATH | DISPOSITIONS`.
- V3. The outbound check on fixture `netstat` text:
  - Text with no `tcp` line records a skip with the label `Outbound connections`, and the body says `skipped`.
  - Text with TCP sockets but no outbound connection prints `- Established outbound TCP connections ...: none`.
  - The label has a row in `SKIP_IDS` (the existing skip-row fixture covers this).
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

None yet.

## Results

Run 2026-11-27 on the development Mac (macOS 27.2.1).

- B1: on `master` (`797a541`), 600 fixture cases pass, `bash -n` passes, and ShellCheck shows the three historical findings (2 SC2010, 3 SC2012 lines).
- V1 to V4: pass; 615 cases pass in all. The old P4 case tested `btm_unique`, which V2 replaces. ShellCheck on `macassay` matches the baseline; on `dev/test.sh` the one new SC2016, the intended literal `$(touch PWNED)` in V1, is suppressed inline.
- T1: pass; `dev/test.sh | tail -1` took 7.1 s in all.
- T2: pass; the watchdog printed "suite timed out after 60 seconds" at 60 s. The piped run still ended at 120 s, because the injected `sleep 120` is the suite's own hung command and holds the pipe. A real hang behaves the same, and so did the old watchdog.
- M1: pass. The outbound section reads `skipped (netstat lists no TCP sockets for this account)`, and Limitations lists it. The login items section now lists the app in a vendor folder, 17 items against 16 before.
- M2: the M1 run ran `sfltool` through the installed sudo rules, so it covers the M2 pass line: the block holds 109 lines, each with four fields, no `com.apple.` identifier, no developer row, and no truncation note. No full run in the user's terminal was made.
