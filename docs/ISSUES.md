# Issues

Project state: bugs, planned work, next steps, open questions, and decisions. Design detail lives in `dev/HANDOFF.md` and feature docs.

## Bugs

- [x] The usage line in the header says `scripts/mac-audit.sh`; the script now lives at the repo root. (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] Root mode shows root's crontab as the user's when the user has none: `crontab -u USER -l || crontab -l` falls through (`mac-audit.sh:273`, ShellCheck SC2015). (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] The home-folder `du` glob passes file names that start with `-` to `du` as options (`mac-audit.sh:327`, ShellCheck SC2035). File names on the audited Mac are untrusted input. (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] More 1.1 bugs from the architecture review, all fixed by the 1.2 design (`dev/features/sudo-rules.md`, 1.1 fixes): shell startup line text copied into the report; `kmutil` UUIDs in the report; `awk \s` in `authorized_keys`; untrusted text can add report rows; the SSH flag misses keyboard-interactive; a missing option value loops forever; truncation has no marker; remote `sudo bash` uses the remote `PATH`; a root audit reads the user's `PATH`, `HOME` rc files, and writes the report through a symlink. (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [ ] Certificate labels in section 14 can carry a 32-character hex identifier, such as a Cloudflare account ID in a gateway CA name (found in the 1.2 pre-merge review; present in 1.1). Consider masking long hex strings in certificate labels in 1.3.

## Planned

- [/] Version 1.2 (built, code-reviewed, and install-tested on `feature/sudo-rules`; pre-merge review done, one question open): per-command sudo rules and installer, no root audits, mode dispatch, skipped-check record, `dev/test.sh`, the handoff's new checks, root-run programs that a user can write, and the 1.1 fixes. Design: `dev/features/sudo-rules.md`.

Version 1.3, checks proposed by the architecture review (2026-11-24), ranked by value. More proposals, ranked, are in `dev/prior-art-ideas.md`:

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

## Publish checklist

Do these in the change that gives the repo a public remote.

- [ ] Write `SECURITY.md`: report privately through a GitHub security advisory only (no email address); supported versions are the latest release; in scope are sudoers rules and the installer, the audit changing the Mac, secrets reaching the report, and command injection from data read off the audited Mac; findings in an audit's results are not security issues.
- [ ] Turn on private vulnerability reporting in the GitHub repo settings.

## Next steps

- [x] Ask the user to choose sudo approach A or B, then write the design doc and test plan. (resolved 2026-11-24): B chosen; design doc and test plan drafted.
- [x] Run an architecture review and decide its findings. (resolved 2026-11-24): the user approved A1 to A3, B1, and B2; the design doc and test plan are revised.
- [x] The user reviews the revised `dev/features/sudo-rules.md` and `dev/features/sudo-rules-tests.md`; code starts after approval. (resolved 2026-11-24): approved and built.
- [x] Answer the code review questions CR-4, CR-5, and CR-11 (`dev/features/sudo-rules-tests.md`), and whether to read SSH settings with `sshd -G` instead of the `sshd -T` rule. (resolved 2026-11-24): all four approved and built; see `dev/features/sudo-rules.md` (Decisions).
- [/] The user runs T5 and installs the rules for T7 to T11; then merge `feature/sudo-rules` into `master`. T5 and T7 to T11 pass; the pre-merge review is left.
- [ ] After the 1.2 merge, rename the project folder and claude-mux session to `macassay` with `claude-mux --rename`.
- [ ] Work through the 115-repo "Review queue" in `dev/prior-art.md` with the `prior-art-scout` agent, and move adopted checks into the 1.3 plan.

## Open questions

- [x] Sudo approach: A (script in sudoers, pinned by SHA-256) or B (per-command rules)? (resolved 2026-11-24): B. The decision is recorded in `dev/features/sudo-rules.md` (Decisions).
- [ ] Should network-manager delete its uncommitted copy at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` now that this project owns the script?
- [x] Does `/etc/sudoers` contain an `includedir` line for `sudoers.d`? Reading it needs root. (resolved 2026-11-24): yes, `#includedir /private/etc/sudoers.d`.
- [ ] Continue macassay rather than adopt, fork, or contribute to another project? Recommended: continue. Deep reviews of mac-posture-audit and macharden found no remote mode and no sudo-rule model in either, and both cover about half of macassay's host checks; evidence is in `dev/prior-art.md`.
- [x] Project name: pick one that does not overlap with the projects in `dev/prior-art.md` (several use `macaudit` or `mac-security-audit`). (resolved 2026-11-24): `macassay`. See Decisions.
- [ ] Send the drafted security report on macharden's `eval` injection through its private advisory form? The draft is not in the repo; the user decides the channel.

## Decisions

- 2026-11-24: Project created from the network-manager handoff. `mac-audit.sh` version 1.1 copied unchanged (sha256 `1810ee55…a187a`). The handoff copy replaces two local account names with role names.
- 2026-11-24: Keep Homebrew's auto-update before `brew outdated`, and list it as a side effect. Rejected: `HOMEBREW_NO_AUTO_UPDATE=1`, which makes the outdated count compare against stale package lists. Conviction: `firm` ("Updating brew is safe enough").
- 2026-11-24: The project is renamed `macassay`. Checked on 2026-11-24: no Homebrew formula or cask, no GitHub user, org, or repo, `macassay.com` unregistered (whois), and no `.dev`, `.io`, or `.app` DNS records. Web search found no product with the name; no formal USPTO search was done. Rejected: macwitness (a 2011 Mac security app named Witness), macdossier, macreceipt, macledger, maccensus, macreckon, macnotary, macfathom, macplumb, macaffirm. Conviction: `firm`.
- 2026-11-24: The command is `macassay` with no `.sh` extension. The rename happens on `feature/sudo-rules`, so 1.2 ships as macassay 1.2. `dev/HANDOFF.md` keeps its history and updates its paths. Conviction: `ok`.
