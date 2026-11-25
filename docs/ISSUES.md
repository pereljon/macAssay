# Issues

Project state: bugs, planned work, next steps, open questions, and decisions. Design detail lives in `dev/HANDOFF.md` and feature docs.

## Bugs

- [x] The usage line in the header says `scripts/mac-audit.sh`; the script now lives at the repo root. (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] Root mode shows root's crontab as the user's when the user has none: `crontab -u USER -l || crontab -l` falls through (`mac-audit.sh:273`, ShellCheck SC2015). (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] The home-folder `du` glob passes file names that start with `-` to `du` as options (`mac-audit.sh:327`, ShellCheck SC2035). File names on the audited Mac are untrusted input. (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] More 1.1 bugs from the architecture review, all fixed by the 1.2 design (`dev/features/sudo-rules.md`, 1.1 fixes): shell startup line text copied into the report; `kmutil` UUIDs in the report; `awk \s` in `authorized_keys`; untrusted text can add report rows; the SSH finding misses keyboard-interactive; a missing option value loops forever; truncation has no marker; remote `sudo bash` uses the remote `PATH`; a root audit reads the user's `PATH`, `HOME` rc files, and writes the report through a symlink. (resolved 2026-11-24): fixed on `feature/sudo-rules` (`dev/features/sudo-rules.md`, 1.1 fixes; root mode was removed).
- [x] Certificate labels in section 14 can carry a 32-character hex identifier, such as a Cloudflare account ID in a gateway CA name (found in the 1.2 pre-merge review; present in 1.1). Consider masking long hex strings in certificate labels in 1.3. (resolved 2026-11-25): `mask_hex` masks them on `feature/checks-1.3`; the M3 check on a full run found no 32-character hex string, and a gateway CA label with a long hex ID shows `<ID>`.
- [ ] Without the sudo rules, the listener table misses root-owned listeners (sshd, smbd, screen sharing, kdc): unprivileged `netstat -anv` stopped listing them on this Mac on 2026-11-24, though `nc` still connects (seen in the 1.3 Task 1 runs; cause not verified). 1.2 behaves the same.

## Planned

- [x] Version 1.2: per-command sudo rules and installer, no root audits, mode dispatch, skipped-check record, `dev/test.sh`, the handoff's new checks, root-run programs that a user can write, and the 1.1 fixes. Design: `dev/features/sudo-rules.md`. (resolved 2026-11-24): merged into `master`; tests pass there. Open checks: `profiles list` output with a device profile installed, and T19 on a second Mac.

Version 1.3 (released 2026-11-25 as v1.3.0; design `dev/features/checks-1.3.md`; plan `docs/superpowers/plans/2026-11-24-checks-1.3.md`; verification results and review record in `dev/features/checks-1.3-tests.md`): every check below, the priority-A ideas I001 to I012, and I013, I015, I016 in `dev/prior-art-ideas.md`, and the certificate-label bug. Checks proposed by the architecture review (2026-11-24), ranked by value:

- [x] Boot and code-signing settings: `nvram boot-args` (never `nvram -p`), `csrutil authenticated-root status`, library validation. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Update safety settings (`CriticalUpdateInstall`, `ConfigDataInstall`) and XProtect age (`xprotect version`). (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] User-domain certificate trust (`security dump-trust-settings` without `-d`). (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Authorization plugins, PAM modules, StartupItems, ScriptingAdditions, directory service and audio plug-ins. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Login items registered inside app bundles (a `find` under /Applications and ~/Applications). (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Accounts: extra UID 0, hidden accounts, home folders writable by others. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Browser policies that force-install extensions. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Quarantine turned off (`LSQuarantine`). (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] SSH private keys: loose permissions, no passphrase. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] More sharing services: Remote Apple Events (TCP 3031), printer sharing, Internet Sharing, AirDrop discoverable by everyone. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Time Machine policy: `AutoBackup` off, home folder excluded. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Battery health on laptops. (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Recent non-Apple installs (`pkgutil`, install history). (resolved 2026-11-25): built on `feature/checks-1.3`.
- [x] Stronger sudoers checks: `NOPASSWD: ALL` as HIGH, NOPASSWD for programs that can load code, weak Defaults. The `secure_path` check was dropped (decision B9). (resolved 2026-11-25): built on `feature/checks-1.3`.

Version 1.4 (needs a design doc and test plan):

- [ ] Homebrew packages and casks: count outdated formulae and casks separately and list their names; add an optional `--greedy` count for casks that update themselves or track `latest`; report third-party taps and the tap of each installed package, and Homebrew settings such as `HOMEBREW_CASK_OPTS` (`--no-quarantine`) and `HOMEBREW_VERIFY_ATTESTATIONS` (register I018); check cask apps for removed quarantine and missing notarization. 1.3 reports only one `brew outdated --quiet` count (MA-UPDATES-002). The design must weigh the run time and network use of `brew info --json=v2 --installed` and `--greedy`.

Later:

- [ ] Run selected report sections only (an `--only` option), with the skipped sections listed under Limitations.
- [ ] Export findings in a standard security format beside the Markdown report (candidates: NIST OSCAL assessment results, the AWS Security Finding Format, SARIF; register I084, I086). The Markdown report stays the default, for LLMs and people.

## Publish checklist

Do these in the change that gives the repo a public remote.

- [x] Write `SECURITY.md`: report privately through a GitHub security advisory only (no email address); supported versions are the latest release; in scope are sudoers rules and the installer, the audit changing the Mac, secrets reaching the report, and command injection from data read off the audited Mac; findings in an audit's results are not security issues. (resolved 2026-11-24): written.
- [ ] Turn on private vulnerability reporting in the GitHub repo settings. GitHub offers it only for public repos; the API returned 404 on the private repo on 2026-11-24, so do it right after the repo goes public.
- [ ] Add a license line (MIT, see `LICENSE`) to `README.md`.
- [ ] Make `pereljon/macassay` public.

## Next steps

- [ ] L1: read the battery condition and maximum capacity on a laptop; the `system_profiler SPPowerDataType` field names are from training knowledge (`dev/features/checks-1.3-tests.md`).
- [ ] T19 and X1: run remote mode against a second Mac. X1 was skipped on 2026-11-25 because `ssh localhost` failed host key verification.
- [ ] Verify the open 1.3 assumptions in `dev/features/checks-1.3.md` (battery fields, `DiscoverableMode` values, Chromium forced-extension key paths, `nvram boot-args` on Intel). The Firefox key path is resolved (2026-11-25): it matches Mozilla's policy-templates documentation.
- [x] Ask the user to choose sudo approach A or B, then write the design doc and test plan. (resolved 2026-11-24): B chosen; design doc and test plan drafted.
- [x] Run an architecture review and decide its findings. (resolved 2026-11-24): the user approved A1 to A3, B1, and B2; the design doc and test plan are revised.
- [x] The user reviews the revised `dev/features/sudo-rules.md` and `dev/features/sudo-rules-tests.md`; code starts after approval. (resolved 2026-11-24): approved and built.
- [x] Answer the code review questions CR-4, CR-5, and CR-11 (`dev/features/sudo-rules-tests.md`), and whether to read SSH settings with `sshd -G` instead of the `sshd -T` rule. (resolved 2026-11-24): all four approved and built; see `dev/features/sudo-rules.md` (Decisions).
- [x] The user runs T5 and installs the rules for T7 to T11; then merge `feature/sudo-rules` into `master`. (resolved 2026-11-24): T5 and T7 to T11 pass; merged after the pre-merge review.
- [h] After the 1.2 merge, rename the project folder and claude-mux session to `macassay` with `claude-mux --rename`.
- [ ] Work through the 115-repo "Review queue" in `dev/prior-art.md` with the `prior-art-scout` agent, and move adopted checks into the 1.3 plan.

## Open questions

- [x] Sudo approach: A (script in sudoers, pinned by SHA-256) or B (per-command rules)? (resolved 2026-11-24): B. The decision is recorded in `dev/features/sudo-rules.md` (Decisions).
- [x] Should network-manager delete its uncommitted copy at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` now that this project owns the script? (resolved 2026-11-24): yes; network-manager had already moved it to the Trash, and its one reference now names `macassay`.
- [x] Does `/etc/sudoers` contain an `includedir` line for `sudoers.d`? Reading it needs root. (resolved 2026-11-24): yes, `#includedir /private/etc/sudoers.d`.
- [x] Continue macassay rather than adopt, fork, or contribute to another project? Recommended: continue. Deep reviews of mac-posture-audit and macharden found no remote mode and no sudo-rule model in either, and both cover about half of macassay's host checks; evidence is in `dev/prior-art.md`. (resolved 2026-11-24): continue, per the user.
- [x] Project name: pick one that does not overlap with the projects in `dev/prior-art.md` (several use `macaudit` or `mac-security-audit`). (resolved 2026-11-24): `macassay`. See Decisions.
- [x] Send the drafted security report on macharden's `eval` injection through its private advisory form? The draft is not in the repo; the user decides the channel. (resolved 2026-11-24): the user sent it through macharden's private advisory form.
- [x] Another account's shell startup file that root owns: the 1.3 design says root-owned files give no finding. Should a root-owned file that everyone, or a group with other members, can write still give a HIGH finding? Recommended: yes; the plan (Task 4, `rc_file_risks`) is written that way. (resolved 2026-11-24): yes, per the user; recorded as decision R1 in `dev/features/checks-1.3.md`.

## Decisions

- 2026-11-24: Project created from the network-manager handoff. `mac-audit.sh` version 1.1 copied unchanged (sha256 `1810ee55…a187a`). The handoff copy replaces two local account names with role names.
- 2026-11-24: Keep Homebrew's auto-update before `brew outdated`, and list it as a side effect. Rejected: `HOMEBREW_NO_AUTO_UPDATE=1`, which makes the outdated count compare against stale package lists. Conviction: `firm` ("Updating brew is safe enough").
- 2026-11-24: The project is renamed `macassay`. Checked on 2026-11-24: no Homebrew formula or cask, no GitHub user, org, or repo, `macassay.com` unregistered (whois), and no `.dev`, `.io`, or `.app` DNS records. Web search found no product with the name; no formal USPTO search was done. Rejected: macwitness (a 2011 Mac security app named Witness), macdossier, macreceipt, macledger, maccensus, macreckon, macnotary, macfathom, macplumb, macaffirm. Conviction: `firm`.
- 2026-11-24: The command is `macassay` with no `.sh` extension. The rename happens on `feature/sudo-rules`, so 1.2 ships as macassay 1.2. `dev/HANDOFF.md` keeps its history and updates its paths. Conviction: `ok`.
- 2026-11-24: The code is on GitHub at `pereljon/macassay`, private until the project is ready, then public. The license is MIT, with the user's full name as the copyright holder in `LICENSE` only. Rejected: the GitHub username or "the macassay contributors" as the holder.
- 2026-11-24: Version 1.3 takes every proposed check group (the 1.3 list here and the priority-A register ideas) plus the certificate-label bug, in one release. Rejected: splitting the inventory checks into 1.4, which repeats the design and review cycle for the lowest-risk checks. Section selection waits for a later release.
