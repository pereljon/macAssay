# Issues

Project state: bugs, planned work, next steps, open questions, and decisions. Design detail lives in `dev/HANDOFF.md` and feature docs.

## Bugs

- [ ] The usage line in the header says `scripts/mac-audit.sh`; the script now lives at the repo root.

## Planned

Version 1.2, from `dev/HANDOFF.md` (Pending work requested by the user):

- [ ] Grant privileged checks through sudo, by approach A or B (see Open questions).
- [ ] Print the whole header comment block for `-h`, with examples and the install steps.
- [ ] Add optional checks: other users and root (`authorized_keys`, LaunchAgents, crontabs, shell startup patterns), sudoers contents, `bputil -d`, root `profiles show -type configuration`.
- [ ] Replace the remote `--sudo` option.
- [ ] Report which privileged checks ran and which were skipped, in the header and in Limitations.
- [ ] Build the installer with the safeguards listed in `dev/HANDOFF.md` (item 5).
- [ ] Bump `VERSION` to 1.2.

## Next steps

- [ ] Ask the user to choose sudo approach A or B, then write the design doc and test plan.

## Open questions

- [ ] Sudo approach: A (script in sudoers, pinned by SHA-256) or B (per-command rules)? network-manager recommended A. Trade-offs are in `dev/HANDOFF.md`.
- [ ] Should network-manager delete its uncommitted copy at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` now that this project owns the script?
- [ ] Does `/etc/sudoers` contain an `includedir` line for `sudoers.d`? Reading it needs root.

## Decisions

- 2026-11-24: Project created from the network-manager handoff. `mac-audit.sh` version 1.1 copied unchanged (sha256 `1810ee55…a187a`). The handoff copy replaces two local account names with role names.
