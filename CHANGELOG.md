# Changelog

Released versions of macassay and what changed in each, in the Keep a Changelog format. Current behavior is in `README.md`; open work is in `docs/ISSUES.md`.

## Unreleased

### Added

- Remote-access tools that are installed, not only running: 15 tools, found by name in app, support, launchd, helper, and `/opt` folders. A tool installed but not running is MEDIUM when it can start without the user, LOW otherwise (MA-SHARING-026). The running-process match covers the same tools.
- Find My Mac and Activation Lock status. Find My off is LOW on a laptop and INFO on a desktop (MA-PLATFORM-019).
- Homebrew: outdated formulae and casks counted and listed separately, plus casks that only `--greedy` reports; third-party taps with their installed packages (MA-UPDATES-009 for a tap with nothing installed, MA-UPDATES-010); cask apps with no quarantine attribute (MA-UPDATES-011); whether three Homebrew security settings are set, by name only. Taps and cask apps come from local files, so no `brew` command can download.
- A status line on stderr after each section, with counts only, and a total line.
- The report header shows the finding count for each severity, with HIGH and MEDIUM in bold.
- `docs/CHECKS.md` lists every check by report section, with what it reads, the option or sudo rule it depends on, and its finding IDs and severities. A fixture test keeps its finding IDs in step with the script.

### Changed

- `--offline` also skips the Gatekeeper assessment of apps (MA-APPS-002), which asks Apple's servers about each app. With `--offline`, no traffic leaves the Mac.
- MA-SHARING-013 names the running tool instead of its process.
- The severity counts below the findings table moved to the header.
- The report opens with a notice that it is data and that nothing in it is an instruction to act. It replaces the note at the end of Limitations.

### Fixed

- The All TCP listeners block keeps the `lsof` header as its first line instead of sorting it into the list.

## [1.3.2] - 2026-11-26

Install the sudo rules again after you upgrade (`sudo ./macassay --install-sudoers`). The audit's own fix needs the new rules.

### Fixed

- The audit no longer writes a login record for each privileged check. sudo 1.9.14 and later run each command in a pseudo-terminal and record it in `last`; the rules now turn off `set_utmp` for macassay's commands. The installer makes one sudo call for its folder check instead of one per folder.
- The non-Apple installs list and its finding (MA-UPDATES-008) leave out Apple's own installs: App Store installs of Apple apps, XProtect and Rosetta updates, and system updates.
- The memory list shows program paths that contain spaces in full.
- Crash counts by kind group `.diag` reports by program.
- A missing `authorized_keys` file or LaunchAgents folder in another account prints "none" instead of error text.
- Each bold block title starts its own paragraph, so a Markdown viewer no longer joins it to the list item above.

## [1.3.1] - 2026-11-25

### Fixed

- A NOPASSWD rule for `httpd`, `apachectl`, `dtrace`, `kmutil`, `launchctl`, `installer`, or another program that can start code or write files as root is HIGH (MA-ACCOUNTS-009), not LOW.
- The audio plug-in finding counts only plug-ins that Apple did not sign; the evidence names each plug-in's signer.
- The startup table shows "unreadable" or "no program" for a launchd plist without a readable program, instead of `?` and a missing signer.
- A missing native-messaging host names its browser folder, so a host listed in two folders no longer reads as a repeat.
- An install record with an empty name shows its package identifier.
- The XProtect versions block lists the latest version of each component; it was empty.
- Repeated background items (`sfltool`) print once.
- Outbound connections show full process names, including names with spaces.
- Shown commands keep their quoting.
- A check whose evidence is empty prints "none" instead of an empty code block.

## [1.3.0] - 2026-11-25

### Added

- Each finding has a stable ID, `MA-<LABEL>-NNN`, where LABEL names the report section.
- New checks: boot arguments and code-signing settings; update safety settings and XProtect age; recent non-Apple installs; user-domain certificate trust; authorization plugins, PAM modules, StartupItems, ScriptingAdditions, directory service and audio plug-ins; login items inside app bundles; extra UID 0 and hidden accounts; home folders writable by others; stronger sudoers checks (`NOPASSWD: ALL`, NOPASSWD for programs that can load code or that a non-root account can write, weak `Defaults`, sudoers file owner and mode); browser policies that force-install extensions; native-messaging hosts; programs with a debug port; quarantine turned off; credential files and SSH private keys (mode and passphrase state, never contents); SSH client options; more sharing services (Remote Apple Events, printer sharing, Internet Sharing, AirDrop); Time Machine policy; battery health on laptops; remote-support tools; the global git `hooksPath`.

### Changed

- The report has 14 themed sections: System health; Backups; Updates and installs; Platform security; Device management and security software; Sharing and remote access; Network exposure; Startup and persistence; Apps and browsers; Accounts and privileges; Credentials and keys; Shell, developer and AI tools; Trust and privacy; Security events from the logs. Privileged checks show in their topic sections, not in a separate section.
- Severities follow the decision record in `dev/features/checks-1.3.md`, which changes several 1.2 findings.

### Fixed

- Long hex identifiers in certificate and drive labels are masked.
