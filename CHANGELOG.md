# Changelog

Released versions of macassay and what changed in each, in the Keep a Changelog format. Current behavior is in `README.md`; open work is in `docs/ISSUES.md`.

## Unreleased

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
