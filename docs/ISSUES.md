# Issues

Project state: bugs, planned work, next steps, open questions, and decisions. Design detail lives in `dev/HANDOFF.md` and feature docs.

## Bugs

- [ ] The usage line in the header says `scripts/mac-audit.sh`; the script now lives at the repo root.
- [ ] Root mode shows root's crontab as the user's when the user has none: `crontab -u USER -l || crontab -l` falls through (`mac-audit.sh:273`, ShellCheck SC2015).
- [ ] The home-folder `du` glob passes file names that start with `-` to `du` as options (`mac-audit.sh:327`, ShellCheck SC2035). File names on the audited Mac are untrusted input.
- [ ] More 1.1 bugs from the architecture review, all fixed by the 1.2 design (`dev/features/sudo-rules.md`, 1.1 fixes): shell startup line text copied into the report; `kmutil` UUIDs in the report; `awk \s` in `authorized_keys`; untrusted text can add report rows; the SSH flag misses keyboard-interactive; a missing option value loops forever; truncation has no marker; remote `sudo bash` uses the remote `PATH`; a root audit reads the user's `PATH`, `HOME` rc files, and writes the report through a symlink.

## Planned

- [/] Version 1.2: per-command sudo rules and installer, no root audits, mode dispatch, skipped-check record, `dev/test.sh`, the handoff's new checks, root-run programs that a user can write, and the 1.1 fixes. Design: `dev/features/sudo-rules.md`.

Version 1.3, checks proposed by the architecture review (2026-11-24), ranked by value:

- [ ] Boot and code-signing settings: `nvram boot-args` (never `nvram -p`), `csrutil authenticated-root status`, library validation.
- [ ] Update safety settings (`CriticalUpdateInstall`, `ConfigDataInstall`) and XProtect age (`xprotect version`).
- [ ] User-domain certificate trust (`security dump-trust-settings` without `-d`).
- [ ] Authorization plugins, PAM modules, StartupItems, ScriptingAdditions, directory service and audio plug-ins.
- [ ] Login items registered inside app bundles (`launchctl print gui/UID`).
- [ ] Accounts: extra UID 0, hidden accounts, home folders readable or writable by others.
- [ ] Browser policies that force-install extensions.
- [ ] Quarantine turned off (`LSQuarantine`).
- [ ] SSH private keys: loose permissions, no passphrase.
- [ ] More sharing services: Remote Apple Events (TCP 3031), printer sharing, Internet Sharing, AirDrop discoverable by everyone.
- [ ] Time Machine policy: `AutoBackup` off, home folder excluded.
- [ ] Battery health on laptops.
- [ ] Recent non-Apple installs (`pkgutil`, install history).
- [ ] Stronger sudoers checks: `NOPASSWD: ALL` as HIGH, NOPASSWD for programs that can load code, weak Defaults, no `secure_path`.

## Next steps

- [x] Ask the user to choose sudo approach A or B, then write the design doc and test plan. (resolved 2026-11-24): B chosen; design doc and test plan drafted.
- [x] Run an architecture review and decide its findings. (resolved 2026-11-24): the user approved A1 to A3, B1, and B2; the design doc and test plan are revised.
- [ ] The user reviews the revised `dev/features/sudo-rules.md` and `dev/features/sudo-rules-tests.md`; code starts after approval.

## Open questions

- [x] Sudo approach: A (script in sudoers, pinned by SHA-256) or B (per-command rules)? (resolved 2026-11-24): B. The decision is recorded in `dev/features/sudo-rules.md` (Decisions).
- [ ] Should network-manager delete its uncommitted copy at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` now that this project owns the script?
- [ ] Does `/etc/sudoers` contain an `includedir` line for `sudoers.d`? Reading it needs root.

## Decisions

- 2026-11-24: Project created from the network-manager handoff. `mac-audit.sh` version 1.1 copied unchanged (sha256 `1810ee55…a187a`). The handoff copy replaces two local account names with role names.
- 2026-11-24: Keep Homebrew's auto-update before `brew outdated`, and list it as a side effect. Rejected: `HOMEBREW_NO_AUTO_UPDATE=1`, which makes the outdated count compare against stale package lists. Conviction: `firm` ("Updating brew is safe enough").
