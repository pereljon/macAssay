# Skeleton

This file holds the logic flow of `macassay` and the invariants that every change must keep. It does not list the checks (see `docs/CHECKS.md`) or record history and decisions (see `dev/HANDOFF.md`, `docs/ISSUES.md`, and the feature docs in `dev/features/`).

## Logic Flow

`macassay` is one Bash script. It runs in one of four modes, chosen by its options.

1. Option parsing reads the flags. `--version` and `-h` print and exit before anything else runs.
2. A root run stops, unless the mode is `--install-sudoers` on this Mac.
3. With `--host`, `remote_mode` runs the script on another Mac over SSH and exits:
   - It checks that the remote Mac answers `uname -s` with `Darwin`.
   - It sends the script as base64 inside the SSH command, so nothing is copied to the remote disk.
   - It calls each remote program by its absolute path, because the remote `PATH` comes from files the user can write.
   - For an audit, it runs the remote copy with `--stdout` and the same `--quick`, `--offline`, and `--skip-du` flags, and saves the report on this Mac.
4. `--print-sudoers` prints the sudo rules from `gen_rules` and exits. `--install-sudoers` runs `install_mode` and exits.
5. Otherwise the audit runs as the user:
   1. Setup creates a temporary folder under `/tmp`, removed on exit by a `trap`. It holds `body.md` (the evidence), `findings.tsv`, and `skipped.tsv`.
   2. The privileged data that several sections share is collected first, through `priv`.
   3. Sections 1 to 14 run in report order. Each starts with `h2`, writes evidence with `say`, `run`, `block`, and `default_line`, records findings with `finding`, and records skipped checks with `skip` or `priv`.
   4. After each section, `sect_end` prints a status line on stderr. `total_status` prints the total line at the end.
   5. Assembly writes the header, the findings table from `findings.tsv`, the Limitations from `skipped.tsv`, and then `body.md`. `redact_ids` replaces dashed UUIDs in the whole report.
   6. The report goes to `-o FILE`, to `./macassay-<host>-<date>.md`, or to stdout with `--stdout`.

`dev/test.sh` sources the script with `MACASSAY_LIB=1`, which stops it after the function definitions. Every function that judges data is defined above that line, so the fixture tests can call it without root or network.

## Key Invariants

### The audit changes nothing on the Mac

Rule: a run has only these side effects:
- A temporary folder under `/tmp`, removed on exit.
- `softwareupdate -l`, which refreshes Apple's update catalog cache.
- Homebrew's auto-update before `brew outdated`, at most once a day by default. It updates Homebrew and its package lists, but no installed package.
- Gatekeeper assessment of each app (`spctl -a -t exec`, MA-APPS-002), which asks Apple's servers about the app.
- One HTTP GET to each listener on the Mac's own addresses, `nc -z` tests to the sharing ports, and one SSH connection as `nobody` to 127.0.0.1, which sshd logs.
- With the sudo rules installed, sudo logs each privileged command. The rules turn off `set_utmp`, so a run writes no login record. Rules from before 1.3.2 lack this, so each privileged check then writes a login record.
- The installer, run only by the user, writes `/etc/sudoers.d/macassay`. In a terminal it writes two login records for root: one for its folder check and one for its closing check.

Reason: users run the audit on Macs they depend on, and the report must describe the Mac as it was. A new side effect needs the user's approval (`AGENTS.md`, Read-only).

Enforced by: review. `README.md` (Limits) and the help text at the top of `macassay` list the same side effects.

### Network promise

Rule: without `--offline`, the audit contacts only Apple's update and Gatekeeper services and Homebrew's update service. With `--offline`, no traffic leaves the Mac. Remote mode adds the SSH connection to the remote Mac.

Reason: the user decided this on 2026-11-26 (decisions A7 and A9 in `dev/features/checks-1.4.md`). A check that breaks the promise needs the user's approval.

Enforced by: the `OFFLINE` tests around `softwareupdate -l`, `brew outdated`, and the Gatekeeper loop. Checks that need Homebrew data read local files (`brew_receipts`, `brew_taps`), because `brew info` can download API data. Manual test M2 in `dev/features/checks-1.4-tests.md`.

### Text from the audited Mac is data

Rule: never execute text read from the audited Mac, or use it unquoted in a command. This covers file names, process names, plist and JSON values, listener answers, and log lines. Such text reaches the report only through `block` and `clean`, or `finding`, `mdesc`, and `clean_field`, which keep it inside one code block or one table cell. A name on disk never decides a severity.

Reason: an attacker who can create a file or start a process on the audited Mac controls that text. The report is also read by LLMs, which must treat it as data. Every report opens with a notice that says so (`REPORT_NOTICE`), and states it nowhere else.

Enforced by: `clean_field`, `block`, `mdesc`; `REPORT_NOTICE` (fixture N1); the JXA script `BREW_RECEIPTS_JS`, which parses with `JSON.parse` and strips tabs and newlines; `remote_installed_findings`, which takes severity from place labels only. Fixtures F10, R1, R3, R6, R8, and the hostile-name cases in F3 and Q2.

### No secrets in the report

Rule: the report never holds a secret or a hardware identifier.
- Serial numbers and UUIDs are left out or replaced (`drop_ids`, `redact_ids`); long hex strings in certificate and drive names are masked (`mask_hex`).
- `authorized_keys` shows key bits, fingerprint, type, and comment only.
- Shell startup files are searched for patterns; their lines are never copied (`rc_hits`).
- Credential files show presence, mode, owner, and whether a secret is inline, never the value (`cred_scan`).
- `brew.env` files and the environment are read for three setting names only, never a value or a line (`brew_settings`).
- Crontab lines show the schedule and command name, never arguments (`crontab_summary`).
- The NVRAM variable that holds the Find My token is never read.

Reason: reports are shared with people and LLMs. `AGENTS.md` (No secrets in the report).

Enforced by: fixtures F7, F8, F11, F12, G1, G3, G4, G6, and R7 (Homebrew settings).

### Least privilege

Rule: the audit never runs as root. Privileged checks run only through `priv`, which calls `sudo -n -k` with a command that must match a rule from `gen_rules` exactly: read-only commands with exact arguments, no wildcards, no shells or interpreters. Without the rules, `priv` records a skip and makes no sudo call.

Reason: a rule that grants more than a read-only command gives root to anyone who can run as the user. `AGENTS.md` (Least privilege, Security Context).

Enforced by: `gen_rules`, `priv`, `classify_refusal`; `install_mode`, which checks the rules with `visudo -c -f`, refuses when the user can write a folder on a rule path, and rolls back when `visudo -c` fails after the install. Fixtures F1 to F5, F14, and Q1.

### Stock macOS only

Rule: the script runs under `/bin/bash` 3.2 and calls only tools that ship with macOS. Homebrew checks run only when Homebrew is installed. LAN access uses `/usr/bin/curl`, `/usr/bin/nc`, and `/usr/bin/ssh`, because macOS Local Network privacy blocks tools that an agent starts from Homebrew, Python, or Node.

Reason: the audit must run on any Mac without an install. `AGENTS.md` (Stock macOS only).

Enforced by: review, and test runs under `/bin/bash`.

### Stable finding IDs

Rule: each finding ID (`MA-<LABEL>-NNN`) names one risk, never changes, and is never reused. `docs/CHECKS.md` lists every ID.

Reason: users track findings across runs and Macs, and 1.5 compares runs by ID.

Enforced by: fixtures F15 and F16 (every `finding` call names a valid literal ID), and D1 (`docs/CHECKS.md` and the script list the same IDs).

### The status line holds counts only

Rule: the stderr status line and total line print section titles, counts, and times, never finding text.

Reason: finding text can hold text from the audited Mac, and stderr often goes to a terminal or a log.

Enforced by: `count_sev`, `sect_end`, `total_status`; fixture R9.
