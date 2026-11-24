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

- [ ] Work through the 115-repo "Review queue" in `dev/prior-art.md` with the `prior-art-scout` agent, and move adopted checks into the 1.3 plan.

- [ ] Ask the user to choose sudo approach A or B, then write the design doc and test plan.

## Open questions

- [ ] Sudo approach: A (script in sudoers, pinned by SHA-256) or B (per-command rules)? network-manager recommended A. Trade-offs are in `dev/HANDOFF.md`.
- [ ] Should network-manager delete its uncommitted copy at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` now that this project owns the script?
- [ ] Does `/etc/sudoers` contain an `includedir` line for `sudoers.d`? Reading it needs root.
- [ ] Continue mac-audit rather than adopt, fork, or contribute to another project? Recommended: continue. Deep reviews of mac-posture-audit and macharden found no remote mode and no sudo-rule model in either, and both cover about half of mac-audit's host checks; evidence is in `dev/prior-art.md`.
- [x] Project name: pick one that does not overlap with the projects in `dev/prior-art.md` (several use `macaudit` or `mac-security-audit`). (resolved 2026-11-24): `macassay`. See Decisions.
- [ ] Send the drafted security report on macharden's `eval` injection through its private advisory form? The draft is not in the repo; the user decides the channel.

## Decisions

- 2026-11-24: Project created from the network-manager handoff. `mac-audit.sh` version 1.1 copied unchanged (sha256 `1810ee55…a187a`). The handoff copy replaces two local account names with role names.
- 2026-11-24: The project is renamed `macassay`. Checked on 2026-11-24: no Homebrew formula or cask, no GitHub user, org, or repo, `macassay.com` unregistered (whois), and no `.dev`, `.io`, or `.app` DNS records. Web search found no product with the name; no formal USPTO search was done. Rejected: macwitness (a 2011 Mac security app named Witness), macdossier, macreceipt, macledger, maccensus, macreckon, macnotary, macfathom, macplumb, macaffirm. Conviction: `firm`.
