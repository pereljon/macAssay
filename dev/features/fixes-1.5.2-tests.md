# Test plan: privacy permissions and iPhone apps

This file holds the test cases, review findings, and results for `fixes-1.5.2.md`. It does not repeat the design.

## dev/test.sh (fixture tests)

- W1. `ios_app` with `codesign` defined as a shell function in the test, because the script resets `PATH` when it loads. The function writes its arguments to a file and exits with a status the case sets:
  - A `/Wrapper/X.app/...` path with status 0 succeeds; with status 3 it fails.
  - A path without `/Wrapper/` fails, and the function is never called.
  - The recorded arguments hold `--verify`, `--ignore-resources`, and the exact requirement string.
- W2. `tcc_report` on fixture databases built with `sqlite3` (an `access` table with `service`, `client`, and `auth_value`):
  - A system database with one granted and one denied Full Disk Access row lists only the granted client.
  - A user database with a granted Microphone row lists it.
  - A missing user database records the skip with the "protected location" reason, and the body line says `skipped`.
  - An unreadable system database (mode 000) records the skip with the Full Disk Access reason.
  - A system database without an `access` table records the same skip, not `none`.
  - A client name with a backtick and `$(touch PWNED)` prints inside the code block, and no `PWNED` file appears.
- The existing cases still pass, and the skip labels keep their `SKIP_IDS` rows (P19).

## Manual tests

- M1. Quick run over SSH to 127.0.0.1 (Full Disk Access, macOS 27): the system database block lists grants, and Limitations does not list the system database. The user database records the "protected location" skip.
- M2. Quick run from the agent's tmux session (no Full Disk Access, macOS 27): the system database skip gives the Full Disk Access reason; the user database skip gives the protected location reason. Neither names root.
- M3. Remote run against the second Mac (macOS 26.3):
  - No MA-APPS-001 for the iPhone app, and the program table still lists each of its paths with its signer.
  - The user database block lists grants, or skips with the Full Disk Access reason; it never gives the protected location reason, because the file exists there. The system database block depends on the remote Full Disk Access setting; record what it shows.

## Review findings

Plan review, 2026-11-27, opus at high effort, independent of the author's conclusions. Triage per the development `AGENTS.md` (Review findings).

- F1. W2 could not reach top-level code past the `MACASSAY_LIB` stop line. Fixed: `tcc_report SYSDB USERDB`.
- F2. A failed query would print `none`, since only `select 1` decided the skip. Fixed: the real query's status decides; new W2 case.
- F3. Narrowing the user query had no verified source. Fixed: keep seven services (decision C2).
- F4. The skip reason claimed a macOS version that the code does not check. Fixed: the reason names the missing path (decision C3).
- F5. The Full Disk Access reason says "the terminal app", which is wrong over SSH; `readable` and the Time Machine check share the wording. Fixed after the user approved it (J2, decision C4).
- F6. Decisions were not recorded. Fixed: C1 to C3; the TestFlight question goes to the user.
- F7. The signature check was verified on the extension only. Fixed: the main executable and the bundle pass too (checked 2026-11-27 on the second Mac); M3 checks every `ps` path.
- F8. `--ignore-resources` passes tampered resources inside a genuine wrapper. Dropped: no requirement and no new exposure; the gap is stated in the design.
- F9. A `codesign` stub on `PATH` is not used, because the script resets `PATH`. Fixed: a shell function in W1.
- F10. Missing cases (failed query, macOS 26.3 privacy section, report lines). Fixed in W2, M2, M3, and the design's Change steps.

## Results

Run 2026-11-27 on the development Mac (macOS 27.2.1) and the second Mac (macOS 26.3).

- W1 and W2: pass; 635 cases pass in all. Negative check: the old pattern (`select 1`, then the query with its error dropped) prints `none` and records no skip on a database without an `access` table, so the W2 format case catches it. ShellCheck on `macassay` matches the baseline; on `dev/test.sh` the new SC2016 and SC2329 notes are suppressed inline with reasons.
- M1: pass. Quick run over SSH to 127.0.0.1: the system database block lists 52 grants (12 Full Disk Access, 23 Accessibility, 13 Screen Recording, 3 Input Monitoring, 1 PostEvent); Limitations lists only the user database, with the protected location reason.
- M2: pass. Quick run from the agent's tmux session: the system database skip gives the Full Disk Access reason, the user database skip gives the protected location reason, and neither names root.
- M3: pass. Remote quick run against the second Mac: no MA-APPS-001; the program table lists the iPhone app's running extension with its signer. The system database was read (the remote Full Disk Access setting is on), and the user database exists there and was read, with no matching grants.
