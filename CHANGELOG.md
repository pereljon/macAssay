# Changelog

Released versions of macassay and what changed in each, in the Keep a Changelog format. Current behavior is in `README.md`; open work is in `docs/ISSUES.md`.

## Unreleased

## [1.3.0] - 2026-11-25

### Added

- Each finding has a stable ID, `MA-<LABEL>-NNN`, where LABEL names the report section.
- New checks: boot arguments and code-signing settings; update safety settings and XProtect age; recent non-Apple installs; user-domain certificate trust; authorization plugins, PAM modules, StartupItems, ScriptingAdditions, directory service and audio plug-ins; login items inside app bundles; extra UID 0 and hidden accounts; home folders writable by others; stronger sudoers checks (`NOPASSWD: ALL`, NOPASSWD for programs that can load code or that a non-root account can write, weak `Defaults`, sudoers file owner and mode); browser policies that force-install extensions; native-messaging hosts; programs with a debug port; quarantine turned off; credential files and SSH private keys (mode and passphrase state, never contents); SSH client options; more sharing services (Remote Apple Events, printer sharing, Internet Sharing, AirDrop); Time Machine policy; battery health on laptops; remote-support tools; the global git `hooksPath`.

### Changed

- The report has 14 themed sections: System health; Backups; Updates and installs; Platform security; Device management and security software; Sharing and remote access; Network exposure; Startup and persistence; Apps and browsers; Accounts and privileges; Credentials and keys; Shell, developer and AI tools; Trust and privacy; Security events from the logs. Privileged checks show in their topic sections, not in a separate section.
- Severities follow the decision record in `dev/features/checks-1.3.md`, which changes several 1.2 findings.

### Fixed

- Long hex identifiers in certificate and drive labels are masked.
