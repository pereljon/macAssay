---
kind: feature
lifecycle: shipped
status: shipped in v1.5.2 (2026-11-27)
---

# Privacy permissions and iPhone apps (version 1.5.2)

This doc is the plan of record for version 1.5.2: two bug fixes found on 2026-11-27. Test cases and review findings live in `fixes-1.5.2-tests.md`. The bugs themselves live in `docs/ISSUES.md` (Bugs).

Investigated against macOS 27.2.1 on the development Mac and macOS 26.3 on a second Mac, with `macassay` 1.5.1 at commit `26d1878`.

## Goal

Report the privacy permission grants that macOS 27 still lets the audit read, with the right reason when it cannot, and stop flagging iPhone and iPad apps as programs in a temporary folder. No new finding ID, no new sudo rule, and no new side effect.

## Requirements

1. The report lists the Full Disk Access, Accessibility, Screen Recording, and Input Monitoring grants when the run has Full Disk Access. The user database grants stay listed on Macs where that database exists. Source: `docs/ISSUES.md` (Bugs); the user's question on 2026-11-27.
2. A skip names the real reason: a missing user database is not a Full Disk Access problem. Source: decision A3 in `dev/features/report-1.5.md` (unreadable evidence gets a skip record with its reason).
3. MA-APPS-001 does not fire for an App Store iPhone or iPad app, and still fires for any other program in a temporary or shared folder. Source: `docs/ISSUES.md` (Bugs), approved by the user 2026-11-27.
4. Stock tools under `/bin/bash` 3.2, no new sudo rule. Source: `AGENTS.md` (Design Principles).

## Fix 1: privacy permissions

### Cause

The check (`macassay:2192`) reads only the user database at `~/Library/Application Support/com.apple.TCC/TCC.db`. On macOS 27 that folder does not exist; Apple moved the user database into a protected container that Full Disk Access does not open (research in `docs/ISSUES.md`, Bugs). `sqlite3` then fails, and the check blames Full Disk Access. The four grants the user asked about live in the system database, which the check never reads; it always records a skip that says root is needed.

Verified 2026-11-27 over SSH to the development Mac, a session with Full Disk Access: `sqlite3 -init /dev/null -readonly` opens `/Library/Application Support/com.apple.TCC/TCC.db` as the user, without root. The `access` table still has `service`, `client`, and `auth_value`. The development Mac has 23 Accessibility, 13 Screen Recording, 12 Full Disk Access, and 3 Input Monitoring grants. The agent's tmux session, which has no Full Disk Access, gets "Operation not permitted".

### Change

Move the check into a function, `tcc_report SYSDB USERDB`, defined before the `MACASSAY_LIB` stop line, so that fixtures can pass their own database paths. The audit calls it with the two real paths.

1. Query each database once for grants (`auth_value = 2`) of the seven services the check lists today: Accessibility, Screen Recording, Full Disk Access, Input Monitoring (`ListenEvent`), `PostEvent`, Microphone, and Camera. Keep the query's output and its exit status.
2. When the query succeeds, print its output through `block`: "Privacy permissions granted (system database)" and "Privacy permissions granted (user database)". No rows print `- TITLE: none`, as `block` does today.
3. When the system query fails, say `- Privacy permissions (system database): skipped (REASON)` and record the skip `Privacy permissions (system TCC database)`. REASON is "not readable, or the database format changed; needs Full Disk Access".
4. When the user database file is absent, say `- Privacy permissions (user database): skipped (REASON)` and record the skip `Privacy permissions (user TCC database)`. REASON is "not at ~/Library/Application Support/com.apple.TCC; newer macOS keeps it in a protected location". When the file exists and the query fails, REASON is the same as in step 3.

A failed query, not a failed open, decides the skip: `select 1` succeeds on a database without the `access` table, while the real query fails (review finding F2).

The client names come from the audited Mac and reach the report only through `block`. Reading the database writes nothing: `-readonly` opens it without a write lock, and the user cannot create files in the root-owned folder (checked by the plan review on a scratch WAL database).

## Fix 2: iPhone and iPad apps

### Cause

On Apple silicon, macOS runs an iPhone or iPad app from `/private/var/folders/.../X/<UUID>/d/Wrapper/APP.app`. `temp_program` matches `/private/var/folders/*`, so MA-APPS-001 (HIGH) fires for every running iPhone app.

### Change

Add `ios_app PATH`: it succeeds when the path holds `/Wrapper/` and an `.app`, and `codesign --verify --ignore-resources` accepts the code against the requirement `anchor apple generic and certificate leaf[subject.CN] = "Apple iPhone OS Application Signing"`. MA-APPS-001 fires only when `temp_program` succeeds and `ios_app` fails.

- The path alone never decides the result. Only Apple's App Store signature for iPhone apps does, so a program that an attacker places in a `Wrapper` folder still fires.
- `--ignore-resources` is needed: a plain verification fails on the iPhone app with "resource envelope is obsolete (custom omit rules)". It still verifies the executable's signature and the requirement.
- Verified 2026-11-27 on the second Mac: the iPhone app's main executable, its bundle, and its extension pass (exit 0); `/bin/ls` and a Mac app in `/Applications` fail the requirement (exit 3).
- `--ignore-resources` leaves one gap: a tampered framework or plug-in inside a genuine App Store wrapper passes. An attacker who can write there can also run from `~/Library`, which `temp_program` never covers, so the gap adds no new exposure.
- Define `ios_app` before the `MACASSAY_LIB` stop line. `codesign` runs only for a path that holds `/Wrapper/`, so other temporary-folder programs cost nothing extra.

## Release

Version 1.5.2, a patch release. Update `CHANGELOG.md`, `docs/CHECKS.md` (the privacy permission rows and MA-APPS-001), `VERSION` in `macassay`, and `docs/ISSUES.md`.

## Decisions

- C1 (2026-11-27): only Apple's App Store signature for iPhone apps suppresses MA-APPS-001. Rejected: the path or the app's platform field alone, which a file on disk controls. TestFlight and Xcode-signed iPhone apps still fire HIGH; accepted by the user 2026-11-27 (J1, `firm`).
- C2 (2026-11-27): both databases keep the seven-service list. Rejected: narrowing the user query to Microphone and Camera, which rests on unverified training knowledge (plan review F3).
- C3 (2026-11-27): the skip reason states the missing path, not a macOS version, because the code checks no version (plan review F4).
- C4 (2026-11-27, `firm`, J2): the Full Disk Access skip reasons in `readable` and the Time Machine check name the Remote Login setting for remote users as well as the terminal app, through one string, `FDA_HINT`. Rejected: leaving the older two reasons, which are wrong for an SSH run (plan review F5).
- I1 (2026-11-27, `firm`): the user approved the revised test plan.
