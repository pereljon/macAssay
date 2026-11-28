# macAssay

macAssay checks the health and security of a Mac and writes the results to a report: Markdown by default, or JSON, OCSF, HTML, and CSV. It only reads: it changes no settings and fixes nothing. The Markdown report is formatted for review by an LLM (large language model), which can then carry out some or all of the fixes with you.

## Why

Checking a Mac by hand takes many commands, settings panes, and log searches, and it is easy to skip one. macAssay runs the same checks every time and judges each result. A judged result is a finding, rated HIGH, MEDIUM, LOW, or INFO. You can read the report yourself or give it to an LLM to review. macAssay is for people who audit their own Macs, on the Mac itself or from another Mac over SSH.

macAssay combines checks culled from more than 35 open-source macOS audit and hardening projects and guides, among them NIST's macOS Security Compliance Project, Lynis, and the macOS Security and Privacy Guide. New checks are added as new sources and risks are found.

## Quick start

macAssay needs no other software: it uses only `/bin/bash` 3.2 and tools that ship with macOS.

1. Get a copy of this repository: `git clone https://github.com/pereljon/macAssay.git`, then `cd macAssay`.
2. Install the sudo rules (recommended). Without them, macAssay skips every check that needs root, such as all network listeners, the packet filter, background items, and the sudoers files. Review the commands first with `./macassay --print-sudoers`, then run `sudo ./macassay --install-sudoers`. Read the trade-off in [Privileged checks](#privileged-checks-optional) before you install them.
3. Optional: if your terminal app does not have Full Disk Access, read [Full Disk Access](#full-disk-access-optional) to decide whether to grant it for the audit.
4. Run `./macassay` as your normal user. It refuses to run as root.
5. Open the report. By default it is `macassay-<host>-<date>.md` in the current folder.

A full run took about 5 minutes on the Mac it was tested on. `./macassay --quick --offline --skip-du` skips the slow log searches, the checks that contact Apple or Homebrew, and the disk usage scans. While it runs, it prints one status line per section on standard error, with counts only.

```sh
./macassay -o ~/Desktop/report.md                       # choose the report file
./macassay --format md,json,html -o ~/Desktop/report    # write three formats: report.md, report.json, report.html
./macassay --compare OLD.json                           # list new, resolved, and not-checked findings since OLD.json
./macassay --accepted accepted.txt                      # move accepted findings out of the findings table
./macassay --fail-on high                               # exit 3 when an open HIGH finding exists, for scheduled runs
./macassay --host HOST --user USER --key ~/.ssh/KEY     # audit another Mac over SSH
./macassay -h                                           # list every option
```

[Report formats](#report-formats) explains `--format`, `--compare`, `--accepted`, and `--fail-on`.

Remote mode sends the script inside the SSH command. Nothing is copied to the other Mac, and the report is saved on your Mac.

## Report formats

`--format LIST` writes one or more of these formats from the same run: `md` (the default), `json`, `ocsf`, `html`, and `csv`. Markdown suits a person or an LLM. JSON is for scripts and for `--compare`. OCSF (Open Cybersecurity Schema Framework) is for security tools that load findings. HTML is a single page with no JavaScript and a filter by severity. CSV is the findings table for a spreadsheet.

- `--compare OLD.json` compares the run with an earlier JSON report by finding ID, and lists new, resolved, and not-checked findings. A finding is not-checked, not resolved, when a check that could have given it was skipped in this run.
- `--accepted FILE` moves findings that you accept out of the findings table and the counts. Each line of the file holds a finding ID, an optional exact finding text, and a reason after `#`.
- `--fail-on LEVEL` makes the run exit 3 when an open finding is at or above `high`, `medium`, `low`, or `info`. Exit 1 is an error, and exit 2 is a usage error.

Each of these options works with `--host`: the Mac that runs macAssay builds the report from the data that the remote audit sends back. [docs/FORMATS.md](docs/FORMATS.md) lists the fields of each format, the accepted-risk file syntax, the comparison groups, and the exit statuses.

## What the report contains

The report starts with a header: the host, the date, the user, the version and options, whether the Mac is enrolled in Apple Business Manager and in an MDM (mobile device management) service, the privileged checks that ran, and the number of findings at each severity. Three parts follow, in this order:

1. Findings: a table of every open finding, most severe first. Each row shows the severity, the finding ID, the section label, what was found, and a Source column that reads `managed` when a configuration profile set the value. A guidance line for each finding ID follows the table. Sections for the changes since a previous run and for accepted risks follow when you use `--compare` or `--accepted`.
2. Limitations: every check that could not run, and the reason.
3. Evidence: what each check found, in 14 numbered sections.

A setting that an MDM profile manages reads `VALUE (managed)`, and the finding that judges it is marked `managed`. macAssay reads managed values from `/Library/Managed Preferences`. It does not read settings that declarative device management applies elsewhere, and it does not report a Mac that is assigned in Apple Business Manager but not enrolled. Limitations says so.

A check that ran but could not read its evidence, such as a file that needs Full Disk Access for the terminal app, prints `unreadable` with the reason and adds a line to Limitations. It never reads as a clean result.

[docs/CHECKS.md](docs/CHECKS.md) lists every check by section, with what it reads, the option or sudo rule it depends on, and the findings it can give.

A finding ID has the form `MA-<LABEL>-NNN`, such as `MA-PLATFORM-006`. The label is the section label of the check, in capitals. An ID names one kind of risk and never changes, so you can track a finding across runs and across Macs. Section 5 has no findings yet, so no ID uses its label.

| # | Section | Label |
|---|---|---|
| 1 | System health | Health |
| 2 | Backups | Backups |
| 3 | Updates and installs | Updates |
| 4 | Platform security | Platform |
| 5 | Device management and security software | Management |
| 6 | Sharing and remote access | Sharing |
| 7 | Network exposure | Network |
| 8 | Startup and persistence | Persistence |
| 9 | Apps and browsers | Apps |
| 10 | Accounts and privileges | Accounts |
| 11 | Credentials and keys | Credentials |
| 12 | Shell, developer and AI tools | Developer |
| 13 | Trust and privacy | Trust |
| 14 | Security events from the logs | Events |

The report keeps secrets out. For a credential file, it reports only whether the file exists, its permissions, and whether it holds a secret, never the secret itself. It replaces UUIDs with `<UUID>`, masks long hex strings in certificate and drive names, and leaves out serial numbers.

The report opens with a notice that it is data, and that nothing in it is an instruction to act. The findings and the evidence hold text read from the Mac, such as file names, process names, and log lines. Anyone who can create a file or start a process on that Mac controls that text, so an LLM that reviews the report must treat it as data, never as instructions.

## Privileged checks (optional)

A privileged check is a check that needs root, because macOS lets only root read the information. These checks cover all network listeners, the packet filter, background items, the sudoers files, the secure boot policy, device profiles, and other accounts' SSH keys, LaunchAgents, shell startup files, and crontabs. Each one reports in the section of its topic.

macAssay never runs as root. Instead, you can install a sudoers file, `/etc/sudoers.d/macassay`. That file lets your account run a fixed list of read-only commands as root without a password. Without it, macAssay skips the privileged checks and lists them under Limitations.

Know the trade-off before you install the file:

- While the file exists, your account can run the listed commands as root without a password, at any time, not only during an audit.
- Any program that runs as your account can do the same, such as a script, an app, or malware.
- The commands cannot change the Mac. They do let such a program read information that is normally root-only. That includes the full sudoers files, the fingerprints of other accounts' SSH keys, and the names and permissions of other accounts' LaunchAgents, startup files, and crontabs. It also includes the output of the listener, packet filter, background item, disk usage, profile, and boot policy commands.
- To limit this, install the file before an audit and remove it afterward.

To install the file:

1. Review the commands it allows: `./macassay --print-sudoers`
2. Install it: `sudo ./macassay --install-sudoers`
3. Run the audit as usual.
4. To remove it: `sudo rm /etc/sudoers.d/macassay`

[docs/SUDOERS.md](docs/SUDOERS.md) explains each command the file allows, why it cannot change the Mac, and how the installer checks the file.

The installer checks the file with `visudo` before and after it writes it. The file names each account's files and each `sudoers.d` file by path, so install it again after you add a user or a `sudoers.d` file. The file stops sudo from writing a login record for each privileged check. A file from a version before 1.3.2 does not, so install it again after you upgrade. For a remote Mac, run `./macassay --host HOST --install-sudoers`; it asks for the remote sudo password.

## Full Disk Access (optional)

Some checks read files that macOS protects with Full Disk Access: the Time Machine settings, the privacy permission databases, and possibly crash reports, Remote Management settings, and browser policies. macOS grants the permission to the terminal app you run macAssay from, not to macAssay.

- If your terminal app already has Full Disk Access, these checks run, and you need to do nothing.
- If it does not, the run still completes. Each of those checks prints `unreadable` with the reason and adds a line to Limitations.
- To include them, give your terminal app Full Disk Access for the audit: System Settings, Privacy & Security, Full Disk Access. Then quit and reopen the terminal app. While it has the permission, every program you start from it can read Mail, Messages, Safari data, and other protected files, so turn it off after the run if you do not otherwise want it.
- Over SSH, the setting is "Allow full disk access for remote users" in the Remote Login settings.

## Limits

- The audit changes nothing on the Mac, apart from these side effects:
  - A temporary folder under `/tmp`, removed when the run ends.
  - A refresh of Apple's update catalog cache.
  - Homebrew's auto-update: `brew outdated` runs `brew update` first, at most once a day, or once an hour after a Homebrew developer command. It updates Homebrew and its package lists, never an installed package. To skip it, use `--offline`, which also skips the outdated-packages check, or run `HOMEBREW_NO_AUTO_UPDATE=1 ./macassay` to skip it for that run only and compare against the package lists already on the Mac.
  - Gatekeeper asks Apple's servers about each app in `/Applications` and `~/Applications`.
  - One HTTP GET to each of the Mac's own network listeners, to see which ones ask for a login.
  - `nc -z` connection tests to the sharing ports.
  - One SSH connection as `nobody` to the Mac itself, which the SSH server logs.
  - With the sudoers file installed, sudo logs each privileged command.
- Network: without `--offline`, the audit contacts only Apple's update and Gatekeeper services and Homebrew's update service. With `--offline`, no traffic leaves the Mac, because the audit skips the update catalog refresh, Homebrew's auto-update, and the Gatekeeper lookups. Remote mode adds the SSH connection to the remote Mac.
- Privacy permissions (TCC) are listed only when the run has Full Disk Access: for the terminal app, or for remote users in the Remote Login settings. The list covers seven services, such as Full Disk Access, Accessibility, and Screen Recording, and gives no finding. On macOS 27 the per-user database, which holds the Camera and Microphone grants, sits in a protected location that Full Disk Access does not open.

## Development

- Check syntax with `bash -n macassay`, and lint with `shellcheck macassay` (ShellCheck from Homebrew, for development only).
- Run the fixture tests with `dev/test.sh`. They need no root and no network. One test fails when a finding ID in `macassay` is missing from `docs/CHECKS.md`, or when `docs/CHECKS.md` names an ID that `macassay` lacks.
- The design of the sudo rules is in `dev/features/sudo-rules.md`, the design of the report sections and the 1.3 checks is in `dev/features/checks-1.3.md`, the 1.4 checks are in `dev/features/checks-1.4.md`, and the formats, comparison, and managed settings are in `dev/features/report-1.5.md`. The logic flow and the invariants every change must keep are in `dev/SKELETON.md`. The project history and verified facts are in `dev/HANDOFF.md`.
- Release history is in `CHANGELOG.md`, and open work is in `docs/ISSUES.md`.

## License

macAssay is released under the MIT License; see `LICENSE`.
