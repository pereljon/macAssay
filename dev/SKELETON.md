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
   - For an audit, it runs the remote copy with `--bundle` and the same `--quick`, `--offline`, and `--skip-du` flags. The remote run prints its data files as a bundle (`write_bundle`) and renders nothing.
   - `read_bundle` decodes the bundle into the temporary folder, and `render_all` renders it on this Mac. The output options, `--compare`, `--accepted`, and `--fail-on` therefore act on this Mac.
4. `--print-sudoers` prints the sudo rules from `gen_rules` and exits. `--install-sudoers` runs `install_mode` and exits.
5. Otherwise the audit runs as the user:
   1. Setup creates a temporary folder under `/tmp`, removed on exit by a `trap`. It holds the four data files: `meta.tsv` (run facts), `findings.tsv`, `skipped.tsv`, and `body.md` (the evidence). Before the audit starts, `load_accepted` and `compare_load` read the user's `--accepted` and `--compare` files, and a bad file exits 2 before any audit work.
   2. The privileged data that several sections share is collected first, through `priv`.
   3. Sections 1 to 14 run in report order. Each starts with `h2`, writes evidence with `say`, `run`, `block`, and `default_line`, records findings with `finding`, and records skipped checks with `skip`, `priv`, or `readable`.
   4. After each section, `sect_end` prints a status line on stderr. `total_status` prints the total line at the end.
   5. `write_meta` writes `meta.tsv`. With `--bundle`, `write_bundle` prints the four files and the run ends here.
   6. `render_all` renders every requested format from the data files, in this order:
      1. `norm_all` makes each file valid UTF-8 (`strict_utf8`) and replaces dashed UUIDs (`redact_ids`). A failed step writes no report and exits 1.
      2. `validate_all` drops each line that fails its shape check, and records the counts for Limitations.
      3. `load_meta` and `accept_rows` read the validated data and split open from accepted findings.
      4. With `--compare`, the JXA script `REPORT_JS` writes `changes.tsv`.
      5. `render_one` builds each format into the temporary folder: `render_md`, `render_html`, `render_csv`, or `REPORT_JS` for JSON and OCSF.
      6. Only when every format built, the files are copied to their paths (`out_paths`) or to stdout.
      7. The exit status is 3 when `--fail-on` matches an open finding (`fail_hit`), otherwise 0.

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

Enforced by: review, and two measured checks before each release. Run both in the user's terminal, because the agent's shell has no terminal and no Full Disk Access, and sudo writes no login record without a terminal.
1. Login records: with the sudo rules installed, note `last | wc -l`, run `script -q /dev/null ./macassay --quick --offline --skip-du -o <temp path>`, and count again. Pass: no new row.
2. Network: log `nettop -P -x -L 240 -s 1` to a file during a `./macassay --offline` run. Pass: the only processes the audit starts that show traffic are the `nc` and `curl` probes of the Mac's own listeners.

`README.md` (Limits) and the help text at the top of `macassay` list the same side effects.

### Network promise

Rule: without `--offline`, the audit contacts only Apple's update and Gatekeeper services and Homebrew's update service. With `--offline`, no traffic leaves the Mac. Remote mode adds the SSH connection to the remote Mac.

Reason: the user decided this on 2026-11-26 (decisions A7 and A9 in `dev/features/checks-1.4.md`). A check that breaks the promise needs the user's approval.

Enforced by: the `OFFLINE` tests around `softwareupdate -l`, `brew outdated`, and the Gatekeeper loop. Checks that need Homebrew data read local files (`brew_receipts`, `brew_taps`), because `brew info` can download API data. Manual test M2 in `dev/features/checks-1.4-tests.md`.

### Text from the audited Mac is data

Rule: never execute text read from the audited Mac, or use it unquoted in a command. This covers file names, process names, plist and JSON values, listener answers, and log lines. Such text reaches the report only through `block` and `clean`, or `finding`, `mdesc`, and `clean_field`, which keep it inside one code block or one table cell. A name on disk never decides a severity.

Reason: an attacker who can create a file or start a process on the audited Mac controls that text. The report is also read by LLMs, which must treat it as data. Every report opens with a notice that says so (`REPORT_NOTICE`), and states it nowhere else.

Enforced by: `clean_field`, `block`, `mdesc`; one escaping function for each output format (`html_esc`, `md_html`, `csv_field`, and `JSON.stringify` in `REPORT_JS`; fixtures P3, P5, P6, P7); `REPORT_NOTICE` (fixture N1); the JXA script `BREW_RECEIPTS_JS`, which parses with `JSON.parse` and strips tabs and newlines; `remote_installed_findings`, which takes severity from place labels only. Fixtures F10, R1, R3, R6, R8, and the hostile-name cases in F3 and Q2.

### No secrets in the report

Rule: the report never holds a secret or a hardware identifier.
- Serial numbers and UUIDs are left out or replaced (`drop_ids`; `redact_ids`, which runs under `LC_ALL=C` after `iconv -c` through `strict_utf8`, because BSD `sed` stops at an invalid byte under a UTF-8 locale and the report must not be written then); values read from the `--compare` file are redacted again after `JSON.parse` (`c()` in `REPORT_JS`), because a `\u` escape decodes to a UUID only then; long hex strings in certificate and drive names are masked (`mask_hex`).
- `authorized_keys` shows key bits, fingerprint, type, and comment only.
- Shell startup files are searched for patterns; their lines are never copied (`rc_hits`).
- Credential files show presence, mode, owner, and whether a secret is inline, never the value (`cred_scan`).
- `brew.env` files and the environment are read for three setting names only, never a value or a line (`brew_settings`).
- Crontab lines show the schedule and command name, never arguments (`crontab_summary`).
- The NVRAM variable that holds the Find My token is never read.

Reason: reports are shared with people and LLMs. `AGENTS.md` (No secrets in the report).

Enforced by: `normalize_file`, `norm_all`, and `c()` in `REPORT_JS`; fixtures F7, F8, F11, F12, G1, G3, G4, G6, and R7 (Homebrew settings); P1 (normalization under a UTF-8 locale); "1.5 PM N3" (an escaped UUID in the `--compare` file).

### Least privilege

Rule: the audit never runs as root. Privileged checks run only through `priv`, which calls `sudo -n -k` with a command that must match a rule from `gen_rules` exactly: read-only commands with exact arguments, no wildcards, no shells or interpreters. Without the rules, `priv` records a skip and makes no sudo call.

Reason: a rule that grants more than a read-only command gives root to anyone who can run as the user. `AGENTS.md` (Least privilege, Security Context).

Enforced by: `gen_rules`, `priv`, `classify_refusal`; `install_mode`, which checks the rules with `visudo -c -f`, refuses when the user can write a folder on a rule path, and rolls back when `visudo -c` fails after the install. Fixtures F1 to F5, F14, and Q1.

### Data files are untrusted until validated

Rule: `render_all` trusts no data file. In remote mode all four come from the audited Mac. A value from `meta.tsv`, `findings.tsv`, or `skipped.tsv` reaches no shell arithmetic, `[[ ]]`, or path until `validate_all` has checked its shape. The output path never uses a value from the data files. The bundle is five fixed lines, and no file name or path comes from it.

Reason: bash 3.2 runs a command substitution inside an array subscript in `$(( ))`, so a meta count such as `a[$(cmd)]` would run `cmd`. A remote shell startup file can control the whole remote stdout.

Enforced by: `valid_meta`, `valid_findings`, `valid_skipped`, `validate_all`; `read_bundle`, which checks the first line, the line count, the base64 alphabet, and a NUL byte before decoding; fixtures P12 (bundle) and P12a (validation).

### Stock macOS only

Rule: the script runs under `/bin/bash` 3.2 and calls only tools that ship with macOS. Homebrew checks run only when Homebrew is installed. LAN access uses `/usr/bin/curl`, `/usr/bin/nc`, and `/usr/bin/ssh`, because macOS Local Network privacy blocks tools that an agent starts from Homebrew, Python, or Node.

Reason: the audit must run on any Mac without an install. `AGENTS.md` (Stock macOS only).

Enforced by: review, and test runs under `/bin/bash`.

### Stable finding IDs

Rule: each finding ID (`MA-<LABEL>-NNN`) names one risk, never changes, and is never reused. `docs/CHECKS.md` lists every ID.

Reason: users track findings across runs and Macs, and `--compare` matches runs by ID.

Enforced by: fixtures F15 and F16 (every `finding` call names a valid literal ID), and D1 (`docs/CHECKS.md` and the script list the same IDs).

### The status line holds counts only

Rule: the stderr status line and total line print section titles, counts, and times, never finding text.

Reason: finding text can hold text from the audited Mac, and stderr often goes to a terminal or a log.

Enforced by: `count_sev`, `sect_end`, `total_status`; fixture R9.
