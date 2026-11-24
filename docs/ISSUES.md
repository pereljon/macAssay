# Issues

Project state: bugs, planned work, next steps, open questions, and decisions. Design detail lives in `dev/HANDOFF.md` and feature docs.

## Bugs

- [ ] The usage line in the header says `scripts/mac-audit.sh`; the script now lives at the repo root.
- [ ] Root mode shows root's crontab as the user's when the user has none: `crontab -u USER -l || crontab -l` falls through (`mac-audit.sh:273`, ShellCheck SC2015).
- [ ] The home-folder `du` glob passes file names that start with `-` to `du` as options (`mac-audit.sh:327`, ShellCheck SC2035). File names on the audited Mac are untrusted input.

## Planned

Version 1.2, from `dev/HANDOFF.md` (Pending work requested by the user):

- [/] Grant privileged checks through per-command sudo rules (approach B). Design: `dev/features/sudo-rules.md`.
- [ ] Print the whole header comment block for `-h`, with examples and the install steps.
- [ ] Add optional checks: other users and root (`authorized_keys`, LaunchAgents, crontabs, shell startup patterns), sudoers contents, `bputil -d`, root `profiles show -type configuration`.
- [ ] Replace the remote `--sudo` option.
- [ ] Report which privileged checks ran and which were skipped, in the header and in Limitations.
- [ ] Build the installer with the safeguards listed in `dev/HANDOFF.md` (item 5).
- [ ] Bump `VERSION` to 1.2.

## Next steps

- [x] Ask the user to choose sudo approach A or B, then write the design doc and test plan. (resolved 2026-11-24): B chosen; design doc and test plan drafted.
- [ ] The user reviews `dev/features/sudo-rules-tests.md` and the design doc; code starts after approval.

## Open questions

- [x] Sudo approach: A (script in sudoers, pinned by SHA-256) or B (per-command rules)? (resolved 2026-11-24): B. The decision is recorded in `dev/features/sudo-rules.md` (Decisions).
- [ ] Should network-manager delete its uncommitted copy at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` now that this project owns the script?
- [ ] Does `/etc/sudoers` contain an `includedir` line for `sudoers.d`? Reading it needs root.

## Decisions

- 2026-11-24: Project created from the network-manager handoff. `mac-audit.sh` version 1.1 copied unchanged (sha256 `1810ee55…a187a`). The handoff copy replaces two local account names with role names.
- 2026-11-24: Keep Homebrew's auto-update before `brew outdated`, and list it as a side effect. Rejected: `HOMEBREW_NO_AUTO_UPDATE=1`, which makes the outdated count compare against stale package lists. Conviction: `firm` ("Updating brew is safe enough").
