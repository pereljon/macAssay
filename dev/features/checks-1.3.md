---
kind: feature
lifecycle: ready
status: 2026-11-24 approved by the user after the architecture review and the delta review; implementation plan next
---

# Report by theme and new checks (version 1.3)

This doc is the plan of record for version 1.3: the report reorganized into 14 themed sections, about 20 groups of new checks, and the certificate-label masking fix. Test cases and review findings live in `checks-1.3-tests.md`.

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64) and `macassay` 1.2 at commit `aa397f3`.

## Goal

Make the report cover the security exposure that the architecture review and the prior-art register found missing, and make it easy to read. Each section covers one theme, and each finding's category names its section.

## Requirements

Each requirement traces to a user decision on 2026-11-24 (recorded in `docs/ISSUES.md` and below) or to `AGENTS.md`.

1. The report has the 14 sections in "Report outline", in that order, followed by the Findings and Limitations sections, which keep their place before the evidence. Source: user decision.
2. Each finding's category is the short label of its section. Source: user decision.
3. The "Privileged checks" section is removed; each privileged check moves to its topic section. Source: user decision.
4. Every check group in "New checks" is built. Source: user decision (scope).
5. Long hex strings in certificate labels are masked. Source: `docs/ISSUES.md` bug, user decision (scope).
6. No new sudo rules and no new side effects. Source: `AGENTS.md` (Least privilege, Read-only), user approval of design part 1.
7. No secret value reaches the report, the temporary folder, or the terminal. Source: `AGENTS.md` (No secrets), user approval of design part 2.
8. Severities follow "Severities". Source: user approval of design part 3.
9. Stock tools under `/bin/bash` 3.2 only. Source: `AGENTS.md` (Stock macOS only).
10. Each check that can give a finding has a stable ID, shown with the finding. Source: user decision (E1, E2).

## Decisions

- 2026-11-24: 1.3 takes every proposed check group plus the certificate-label bug in one release. Rejected: inventory checks in a 1.4, which repeats the design and review cycle for the lowest-risk checks. Recorded in `docs/ISSUES.md`.
- 2026-11-24: Section selection (`--only`) waits for a later release. Rejected for 1.3: it needs dependency handling between sections and a Limitations record of what was skipped.
- 2026-11-24: The report is reorganized by theme. Rejected: adding checks into the 1.2 sections, which crowds the security baseline section; appending new sections, which splits related checks. The reorder is mechanical because all privileged data is collected before section 1.
- 2026-11-24: Two themes beyond the first draft, "Device management and security software" and "Shell, developer and AI tools". Both hold existing or planned checks from `dev/prior-art-ideas.md` that fit no other theme.
- 2026-11-24: Inventory checks print a count and the unusual items only. A missing setting gets an explicit "macOS default" line. Repeated findings collapse into one finding.
- 2026-11-24: Secret presence is decided from key names and file headers only (design part 2).
- 2026-11-24: Severities as in "Severities", with three raised to HIGH after comparison with the 1.2 scale: quarantine off, locally set forced browser extensions, and a user-writable authorization plugin or PAM module.
- 2026-11-24: The architecture review of this design must review every severity, existing and new, for consistency and correctness. Source: the user.
- 2026-11-24: The review's severity recommendations are adopted (architecture review A-SEV, user decisions A1 to A10, B1 to B14, C1). "Severities" and "Changes to 1.2 findings" show the result. This supersedes the earlier severity decision where they differ; for forced extensions, the user's HIGH stays for managed preferences on a Mac without MDM enrollment.
- 2026-11-24: Scale rule for passwordless root: HIGH when someone configured the grant (`NOPASSWD: ALL`, NOPASSWD for a code-loading program); MEDIUM when it comes from default macOS permissions, such as a root daemon in an admin-writable folder under `/Applications` (decision C1). Rejected: HIGH for both, which gives 9 HIGH findings on this Mac for Apple's default layout.
- 2026-11-24: Each check gets a stable ID, `MA-<LABEL>-NNN`, where LABEL is the section label in capitals (decisions E1, E2). An ID names one risk that a check reports, not one occurrence. A call site that reports several risks gives each risk its own ID; for example `classify_sudoers` has separate IDs for `NOPASSWD: ALL`, code-loading programs, `!authenticate`, weak `Defaults`, and other NOPASSWD rules. An ID never changes and is never reused, and it keeps its label if its check later moves to another section. A check can give several findings with one ID in a run (root daemons, firewall rules); an export builds a per-occurrence ID from the check ID, the host, the date, and a hash of the finding text. A standard export can build a per-run ID from the check ID, the host, and the date. Rejected: standard catalogs as IDs; CCE changes with each macOS version, NIST 800-53 controls are too coarse, and CIS numbers change between benchmark versions. References to mSCP rules, NIST 800-53 controls, and ATT&CK techniques come later (register I076, decision E3).
- 2026-11-24: The script's `flag` function is renamed `finding`, per the project terminology in `AGENTS.md`.

## Decision record, 2026-11-24

The user decided each item below after the architecture review. In each, the rejected option is keeping the earlier severity (the 1.2 one, or the one approved in design part 3), unless the item names another.

- A1 swap over 75% LOW. A2 application firewall off MEDIUM. A3 Time Machine not encrypted MEDIUM. A4 auto-login MEDIUM. A5 another account's shell startup file HIGH. A6 shell startup patterns split, HIGH and MEDIUM. A7 firewall rule for a missing program LOW. A8 Permissive secure boot HIGH. A9 tunnels (cloudflared, ngrok, frpc) LOW. A10 App Translocation paths left out of the temporary-folder finding.
- B1 other boot arguments LOW. B2 debug port by bind address; no finding for `--remote-debugging-pipe`. B3 forced extensions by source and MDM enrollment; rejected: the review's MEDIUM for managed preferences without enrollment. B4 authorization plugin LOW when signed with a team ID, MEDIUM when unsigned. B5 writable plugin or PAM module by `chain_writable` (amended by G3). B6 StartupItems LOW. B7 missing native-messaging host program LOW. B8 NOPASSWD for a code-loading program HIGH. B9 no `secure_path` check dropped. B10 `credential.helper store` check dropped. B11 Remote Apple Events and Apache LOW. B12 macOS auto-install off INFO. B13 home folder writable by its group added (raised to HIGH by G1). B14 login items in apps added, MEDIUM when unsigned, HIGH in an unusual path.
- C1 passwordless root: HIGH when configured, MEDIUM from default macOS permissions; rejected: HIGH for both.
- G1 group-writable home folders and other accounts' shell startup files HIGH when the group has other members; supersedes B13 and the group part of A5. G2 NOPASSWD for a program a non-root account can write HIGH. G3 admin-group write MEDIUM only under `/Applications`, HIGH elsewhere; supersedes the MEDIUM part of B5. These follow the delta review.
- R1 (after the plan): another account's root-owned shell startup file gives no owner finding, but a write bit for everyone, or for a group with other members, still gives HIGH; rejected: no finding at all for root-owned files.
- E1 stable check IDs in 1.3. E2 format `MA-<LABEL>-NNN`. E3 standard references later; rejected: in 1.3.

## Verified facts

Checked on this Mac, 2026-11-24, as the user without sudo:

- `nvram boot-args` exits non-zero with "data was not found" when no boot arguments are set.
- `csrutil authenticated-root status` prints `Authenticated Root status: enabled`.
- `com.apple.security.libraryvalidation` does not exist when library validation is at its default (on).
- `xprotect version` prints `Version: N Installed: YYYY-MM-DD HH:MM:SS +0000`.
- `/Library/Preferences/com.apple.SoftwareUpdate` is readable and holds `LastFullSuccessfulDate`, `AutomaticDownload`, `AutomaticallyInstallMacOSUpdates`, `ConfigDataInstall`, `CriticalUpdateInstall`. `AutomaticCheckEnabled` is absent at its default (on). It also holds `AutoInstallProductKeys`, which the report must not copy.
- `/Library/Preferences/com.apple.commerce AutoUpdate` reads `1`.
- `security dump-trust-settings` (user domain) lists certificate names, and policy strings that can hold IP addresses.
- `/Library/Security/SecurityAgentPlugins` lists bundles; this Mac has a non-Apple one. `/Library/StartupItems` and `/Library/ScriptingAdditions` are empty; `/Library/DirectoryServices/PlugIns` does not exist.
- `/etc/pam.d` modules are bare names, which load from `/usr/lib/pam`, plus the include `sudo_local`.
- `/Library/Audio/Plug-Ins/HAL` lists third-party drivers.
- `com.apple.LaunchServices LSQuarantine` is absent at its default (on).
- `sysadminctl -screenLock status` prints the delay on standard error, with a timestamp prefix: `screenLock delay is 900 seconds`.
- `tmutil destinationinfo` prints the destination `ID` as a UUID; the existing UUID masking must cover it.
- `defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup` reads `1`.
- `system_profiler SPPowerDataType` takes 0.2 s; on this desktop it prints no battery fields. `pmset -g batt` names no internal battery.
- `pkgutil --pkgs` lists 45 non-Apple packages. `/Library/Receipts/InstallHistory.plist` is readable with `plutil -p` and has `date`, `displayName`, `displayVersion`, `processName` per install.
- `com.apple.sharingd DiscoverableMode` is absent at its default. The domain also holds AirDrop UUIDs, which the report must not copy.
- `launchctl print-disabled system` lists service overrides. `com.apple.AEServer` is not loaded when Remote Apple Events is off.
- `com.apple.smb.server AllowGuestAccess` and `com.apple.nat` are absent at their defaults; `cupsctl` prints `_share_printers=0`; `com.apple.AssetCache Activated` and `com.apple.amp.mediasharingd home-sharing-enabled` read `0`; `/etc/exports` does not exist.
- `lsof` as the user shows the user's own listeners, which include ControlCenter (AirPlay receiver) when it listens.
- `find /Applications ~/Applications -maxdepth 5` for `Contents/Library/LoginItems/*.app` and `Contents/Library/Launch{Agents,Daemons}/*.plist` takes 0.9 s and finds 16 items.
- Native-messaging host folders exist under `~/Library/Application Support/<browser>/NativeMessagingHosts`, `/Library/Google/Chrome/NativeMessagingHosts`, and `/Library/Application Support/Mozilla/NativeMessagingHosts`.
- `dscl . -list /Users UniqueID` and `dscl . -list /Users IsHidden` work without root. `IsHidden` is `1` or `YES`.
- `/Users/<user>` is `drwxr-xr-x` by default, so readable home folders give no finding.
- `find /Applications -maxdepth 2 -name '*.app' -perm -2` finds one world-writable app here.
- `stat -f '%Su:%Sg %Sp'` reads `/etc/sudoers`, `/etc/sudoers.d`, its files, and `/usr/bin/sudo` without root.
- For an OpenSSH private key, base64-decoding line 2 shows the cipher name (`none` when there is no passphrase). The result matched `ssh-keygen -y -P ''` on every key here. PEM keys mark encryption with an `ENCRYPTED` header line.
- `ps -axwwo command=` piped to `grep` matches the `grep` itself; the debug-port check must exclude its own process.

## Assumptions to verify during the build

- Battery fields on a laptop: `system_profiler SPPowerDataType` prints `Condition:` and `Maximum Capacity: N%` (training knowledge; no laptop here).
- `DiscoverableMode` values are `Everyone`, `Contacts Only`, and `Off` (training knowledge).
- Chromium browsers read `ExtensionInstallForcelist` from `/Library/Managed Preferences/<domain>.plist` (MDM) and `/Library/Preferences/<domain>.plist` (local) (training knowledge).
- `nvram boot-args` reads without root on Intel Macs as on Apple silicon (not tested on Intel).

## Report outline

Each section has a short label, used as the finding category. Content moved from 1.2 is listed with its old section number.

| # | Section | Label | Moved from 1.2 | New in 1.3 |
|---|---|---|---|---|
| 1 | System health | Health | 1 (all), 2 (all), 3 volumes and drives, 12 crash and panic counts, 13 (all), 14 power and sleep | Battery |
| 2 | Backups | Backups | 3 Time Machine and local snapshots | Time Machine policy |
| 3 | Updates and installs | Updates | 4 (all) | Update settings, XProtect age, recent installs |
| 4 | Platform security | Platform | 5 baseline, system extensions, kexts; 6 (all); 15 secure boot policy and packet filter | Boot arguments, signed system volume, library validation, quarantine, screen lock, world-writable apps and folders |
| 5 | Device management and security software | Management | 5 MDM and profiles; 15 device profiles | None |
| 6 | Sharing and remote access | Sharing | 7 (all); 9 authorized_keys | More sharing services, remote-support tools, more sshd settings |
| 7 | Network exposure | Network | 8 (all); 14 DNS, proxy, hosts, outbound connections; 15 all TCP listeners | None |
| 8 | Startup and persistence | Persistence | 9 except sudoers.d and authorized_keys; 15 other accounts' shell startup files, crontabs | Authorization plugins, PAM, StartupItems, ScriptingAdditions, directory service and audio plug-ins, login items in apps |
| 9 | Apps and browsers | Apps | 11 (all); 14 Chrome and Safari extensions | Forced extensions, native-messaging hosts, debug ports |
| 10 | Accounts and privileges | Accounts | 10 (all); 9 sudoers.d; 15 sudo configuration | UID 0 and hidden accounts, home folders writable by others, sudoers checks |
| 11 | Credentials and keys | Credentials | None | Credential files, SSH private and public keys, SSH client options |
| 12 | Shell, developer and AI tools | Developer | None | Git settings |
| 13 | Trust and privacy | Trust | 14 certificates, admin trust, privacy permissions | User-domain trust |
| 14 | Security events from the logs | Events | 12 XProtect messages, failed SSH sign-ins | None |

Each 1.2 finding gets its new label from the section that holds its check, not from its old category. For example, the 1.2 "Security" findings for sudoers go to Accounts and the admin trust finding goes to Trust, while SIP and Gatekeeper go to Platform. R5 lists every finding call with its old category, new label, and ID. Finding texts that cite a section number are updated.

Five 1.2 items from section 14 move as follows, and the per-account loop for other accounts (authorized_keys, LaunchAgents, shell startup files) moves whole to Persistence, so commit 1 does not split it: the guest account to Accounts; `DYLD_INSERT_LIBRARIES` to Persistence; Gatekeeper-rejected apps to Apps; the 1.2 screen lock line to Platform, where the new screen lock check replaces it; the "rules not installed" notice to Limitations.

## Build order

1. Commit 1 moves blocks into the outline and folds the privileged checks into topic sections. It renames nothing and changes no logic, category, or severity. Verification:
   - Script check (R0): sort the non-heading lines of the 1.2 script and the commit 1 script and diff. Only headings and section-number references may differ.
   - Report check (R1): run 1.2 twice to measure run-to-run noise, then compare 1.2 and commit 1, sorted and with headings stripped. Run it twice: `--quick --offline --skip-du` without the sudo rules, and a full run with the rules installed, so the privileged blocks are covered. Differences beyond the noise fail.
   - Order check: `bash -n`, and in the full run no "unbound" or empty-variable output in a moved block. A sorted comparison cannot see a variable used before it is set.
   - Placement check (R2): a table of every `h3`, `block`, and `run` label with its expected section.
2. Commit 2 renames `flag` to `finding`, sets each finding's label, and assigns IDs. It also renames the report strings "Automatic flags", "No automatic flags", and "(N flags)" to use "findings". Verification: a mechanical diff, in which every changed line is a finding call, a report string, or the findings table; plus R3, R5, and R6.
3. Commit 3 adds hex masking.
4. Commit 4 applies "Changes to 1.2 findings", except the screen lock removal, which moves to the Platform commit with its replacement.
5. Later commits add the new checks, one section per commit, with fixture tests for each parser.

## Shared helpers

- `finding ID SEVERITY LABEL TEXT` replaces `flag SEVERITY CATEGORY TEXT`. The findings file gains an ID column, and the report's Findings table shows it. Every ID is a literal string in the source, including in functions that compute a severity, such as `classify_sudoers`, which prints the ID with each result.
- One item gives one finding, at its highest severity. For example, an unsigned authorization plugin that the user can write gives one HIGH finding; a debug port that is running and set in a launch item gives one finding. Commit 2 assigns IDs to the 1.2 checks; each new check gets its ID when it is built.

- `mask_hex`: replaces runs of 32 or more hex characters with `<ID>`. Applied to certificate labels in section 13 (both trust checks and the System keychain list).
- `default_line LABEL VALUE DEFAULT`: prints `- LABEL: VALUE`, or `- LABEL: not set (macOS default: DEFAULT)` when VALUE is empty.
- `unusual_path PATH`: true for paths under `/tmp`, `/private/tmp`, `/private/var/folders`, `/Users/Shared`, or a hidden folder. It reuses the pattern of the 1.2 startup item check.
- `has_key FILE PATTERN`: `grep -qsE` on FILE; prints nothing. It is the only way the credential checks read a credential file.

## New checks

Each check runs as the user. Severity labels follow "Severities".

### 1. System health

- Battery: when `pmset -g batt` names an internal battery, read `Condition` and `Maximum Capacity` from `system_profiler SPPowerDataType`. Otherwise print `- Battery: none`.

### 2. Backups

- Time Machine policy: when a destination exists, read `AutoBackup` from `/Library/Preferences/com.apple.TimeMachine`, and check `tmutil isexcluded "$HOME"`.

### 3. Updates and installs

- Update settings from `/Library/Preferences/com.apple.SoftwareUpdate`: `AutomaticCheckEnabled`, `LastFullSuccessfulDate`, `AutomaticDownload`, `AutomaticallyInstallMacOSUpdates`, `CriticalUpdateInstall`, `ConfigDataInstall`, each with `default_line`. App Store `AutoUpdate` from `com.apple.commerce`. Read single keys; never print the whole domain.
- XProtect age: the `Installed:` date from `xprotect version`.
- Recent installs: from `InstallHistory.plist`, the non-Apple installs in the last 30 days (`processName` not `softwareupdated`), as date, name, and version. `pkgutil --pkgs` gives the count of non-Apple packages.

### 4. Platform security

- Boot arguments: `nvram boot-args`; HIGH when the value contains `amfi_` or `cs_enforcement_disable`.
- Signed system volume: `csrutil authenticated-root status`.
- Library validation: `DisableLibraryValidation` from `/Library/Preferences/com.apple.security.libraryvalidation`.
- Quarantine: `LSQuarantine` from `com.apple.LaunchServices`.
- Screen lock: the delay from `sysadminctl -screenLock status 2>&1`; also `immediate` and `off`. It replaces the 1.2 screen lock line and its LOW finding.
- World-writable apps: `find /Applications -maxdepth 2 -name '*.app' -type d -perm -2`. World-writable folders: `find /Library -xdev -type d -perm -002 ! -perm -1000`, count plus the first 10.

### 6. Sharing and remote access

- More sharing services, each from one key or listener: Remote Apple Events (`launchctl print system/com.apple.AEServer` succeeds), Internet Sharing (`com.apple.nat` `NAT` `Enabled`), SMB guest access (`AllowGuestAccess`), Apache (`org.apache.httpd` loaded), NFS (`/etc/exports` with entries), printer sharing (read the world-readable `/etc/cups/cupsd.conf`: on when it has a `Port` line or a `Listen` line that is not localhost or a socket; this Mac shows `Listen localhost:631`. No `cupsctl`, which can start cupsd), AirDrop (`DiscoverableMode`), AirPlay receiver (ControlCenter listening on TCP 5000 or 7000), media sharing (`home-sharing-enabled`), content caching (`AssetCache` `Activated`).
- Remote-support tools: process names from `ps -axo comm=` matched against TeamViewer, AnyDesk, RustDesk, ScreenConnect, Splashtop, BeyondTrust, LogMeIn, RealVNC, TigerVNC, and JumpCloud Assist.
- More sshd settings, only when SSH listens, from the existing `sshd -G` output: `permituserenvironment`, `gatewayports`, `hostbasedauthentication`, `x11forwarding`, `maxauthtries`.

### 8. Startup and persistence

- Authorization plugins: each bundle in `/Library/Security/SecurityAgentPlugins`, with its signer from `codesign -dv` (team ID only) and its owner. Severity also uses the 1.2 `chain_writable` helper on the bundle and its folder chain.
- PAM: modules in `/etc/pam.d` given as an absolute path outside `/usr/lib/pam`, with owner and `chain_writable`. The parser reads the module as the first field after the control field, where a bracketed control such as `[success=ok default=die]` counts as one field, and follows `include` and `substack` targets inside `/etc/pam.d`.
- StartupItems, ScriptingAdditions (`/Library` and `~/Library`), directory service plug-ins: any entry.
- Audio plug-ins: count, and names of entries in `/Library/Audio/Plug-Ins/HAL`.
- Login items in apps: the `find` above, as app name and item name; count, then items whose app is not signed or sits in an unusual path.

### 9. Apps and browsers

- Forced extensions: `ExtensionInstallForcelist` (Chrome, Edge, Brave) and Firefox `ExtensionSettings` with `force_installed`, from `/Library/Managed Preferences`, `/Library/Managed Preferences/<user>`, `/Library/Preferences`, and `~/Library/Preferences`, plus Firefox `distribution/policies.json` inside the app bundle. The source and the MDM enrollment state (from the existing `profiles status -type enrollment`) set the severity. Extension IDs only.
- Native-messaging hosts: count per folder; for each host manifest, the `path` key read with `plutil -extract path raw` (JSON). Findings: a path under `/tmp`, `/private/tmp`, `/private/var/folders`, or `/Users/Shared`; a missing path. Hidden folders give no finding here, because Claude Code and Codex install hosts under `~/.claude` and `~/.codex`.
- Debug ports: match `ps -axwwo pid=,command=` in a pipe for `--remote-debugging-port` or a word-bounded `--inspect` (`--inspect`, `--inspect=`, `--inspect-brk`), excluding the check's own process. `--remote-debugging-pipe` opens no socket and is ignored. For each match, the name comes from `ps -o comm= -p PID` and the bind address from `lsof -nP -a -p PID -iTCP -sTCP:LISTEN`. `ps` output is never written to the temporary folder. Launch items whose `ProgramArguments` contain the flags are also listed, by label and program path only, never other arguments; `--remote-debugging-address` with a non-loopback value counts as non-loopback. Without the sudo rules, `lsof` sees only the user's own processes, so another account's process gets the bind address from the privileged listener list, or "unknown" when that is skipped.

### 10. Accounts and privileges

- UID 0: accounts other than `root` with UID 0.
- Hidden accounts: `IsHidden` set on an account with UID 500 or above; MEDIUM when the account is in the `admin` group.
- Home folders writable by group or others: `stat` on each `/Users/*` home except `Shared`.
- Sudoers ownership: `stat` on `/etc/sudoers`, `/etc/sudoers.d`, its files, and `/usr/bin/sudo`; expect `root:wheel`, no write for group or others, and setuid on `sudo`.
- Sudoers content: the 1.2 `classify_sudoers` function is extended, so one rule gives one finding at its highest severity. It reads the files through the existing rule. It expands `Cmnd_Alias` names before matching, matches program basenames exactly (`ssh` does not match `ssh-keygen`), and reads `Defaults` lines for `!authenticate` and weak settings. The code-loading list: shells, `env`, `python*`, `perl`, `ruby`, `node`, `osascript`, `vi`, `vim`, `less`, `more`, `find`, `awk`, `sed`, `tar`, `zip`, `git`, `ssh`, `scp`, `rsync`, `tee`, `cp`, `mv`, `dd`, `chmod`, `chown`, `curl`, `wget`. The 1.2 block that lists non-comment lines, and the rule text in the finding, are unchanged; they come from root-owned configuration the user controls. No check for a missing `secure_path`: stock macOS sudoers has none (verified), so it would fire on every Mac.

### 11. Credentials and keys

- Credential files in the home folder: `.netrc`, `.aws/credentials`, `.git-credentials`, `.npmrc`, `.pypirc`, `.docker/config.json`, `.kube/config`, `.config/gh/hosts.yml`. For each: presence, owner, mode (`stat -L`, so a symlink reports its target), and whether `has_key` finds an inline secret: `password` in `.netrc`; `aws_secret_access_key` or `aws_session_token`; any line in `.git-credentials`; `_authToken`, `_auth`, or `_password` in `.npmrc`; `password` in `.pypirc`; `"auth":` or `"identitytoken":`; `token:`, `password:`, or `client-key-data:` in `.kube/config`; `oauth_token:`. A value that starts with `${` names an environment variable and does not count. The report never names profiles or sections.
- SSH private keys: files in `~/.ssh` whose line 1 is a private-key header. Report file name, mode (`stat -L`), and passphrase state from the header only. For OpenSSH keys, take only the first 31 characters of line 2 (`cut -c1-31`) and compare them with the fixed base64 prefix `b3BlbnNzaC1rZXktdjEAAAAABG5vbmU` (cipher `none`) without decoding, because a key written as one line holds the private material on line 2. A PKCS#8 `BEGIN ENCRYPTED PRIVATE KEY` line 1 counts as encrypted; for other PEM keys, `ENCRYPTED` is searched in the first 3 lines only. Never run `ssh-keygen` on a private key. File names are printed, because the user needs them to fix a finding; key file names are not secrets under `AGENTS.md`.
- SSH public keys: `ssh-keygen -l -f` on each `~/.ssh/*.pub`; print bits and type only, never the comment, which `AGENTS.md` allows only from `authorized_keys`.
- SSH client options: parse `~/.ssh/config`, `/etc/ssh/ssh_config`, `/etc/ssh/ssh_config.d/*`, and every `Include` target they name, for `ForwardAgent yes` and `StrictHostKeyChecking no` or `off`. Accept `Key value` and `Key=value`, any case. Options before the first `Host` or `Match` apply to every host, like `Host *`. Report whether each applies to every host, and a count of other `Host` blocks. Host names are not reported. `Include` handling: expand a leading `~/` by hand, expand globs with `compgen -G "$pattern"` (quoted, so the text is never split or run), skip patterns that contain `%` or `$` tokens, keep a list of files already read, and stop at a depth of 16, as ssh does. PAM `include` and `substack` use the same list of files read.

### 12. Shell, developer and AI tools

- Git settings: read `~/.gitconfig` and `~/.config/git/config` for `hooksPath` (the path is printed). Never run `git`.

### 13. Trust and privacy

- User-domain trust: `security dump-trust-settings`, certificate names only through `mask_hex`; policy strings are dropped. A certificate counts as trusted when it has a `TrustRoot` or `TrustAsRoot` result, has a trust setting with no result type (the default is TrustRoot), or has zero trust settings ("always trust"), per `SecTrustSettings.h`. `Deny` and `Unspecified` results do not count. The 1.2 admin-domain trust finding uses the same rule (see "Changes to 1.2 findings").

## Changes to 1.2 findings

Decided by the user on 2026-11-24 (A1 to A10). Commit 1 keeps 1.2 severities so that its comparison stays exact; these changes come in their own commit after it.

- Swap over 75%: MEDIUM to LOW.
- Application firewall off: HIGH to MEDIUM.
- Time Machine backup not encrypted: LOW to MEDIUM.
- Auto-login: LOW to MEDIUM.
- Another account's shell startup file owned by an account other than its user or root, or writable by others: MEDIUM to HIGH. Root-owned files give no finding. Writable by its group: HIGH when the group has members other than the file's user, such as `staff` (decision G1).
- Shell startup patterns: download-and-run, `/dev/tcp`, and `nc -e` stay HIGH; `base64` decoding and `osascript -e` become MEDIUM.
- Firewall allow rule for a program that no longer exists: MEDIUM to LOW; unsigned and ad hoc programs stay MEDIUM.
- Secure boot policy: Permissive is HIGH; Reduced stays MEDIUM.
- Tunnels: cloudflared INFO to LOW; ngrok and frpc processes give the same LOW finding.
- Programs running from `/private/var/folders`: paths containing `/AppTranslocation/` are left out of the HIGH finding.
- `NOPASSWD: ALL`: MEDIUM to HIGH.
- The 1.2 screen lock finding is removed in the Platform commit, which adds its replacement.
- Admin-domain trusted certificates count by the same rule as the user domain: Deny and Unspecified results no longer count.
- `chain_writable`, per decisions C1 and G3: admin-group write is MEDIUM only under `/Applications`, where macOS gives the admin group write by default. Elsewhere it is HIGH.
- `classify_sudoers`: a NOPASSWD rule for a program that a non-root account can write (by `chain_writable`) is HIGH (decision G2). Other NOPASSWD rules for programs off the code-loading list stay LOW.
- Shell startup patterns: the MEDIUM part gets its own ID; the HIGH part keeps the 1.2 check's ID.

## Severities

New findings, by section. Repeated findings give one finding with a count, and one risk gives one finding.

The security scale is: HIGH for direct exposure or tampering now, MEDIUM for a real weakening, LOW for hygiene, INFO for inventory. For passwordless root, see the C1 rule in Decisions. Health findings (disk space, SMART status, kernel panics, memory) use a separate scale: HIGH means data loss or failure is likely soon.

| Section | HIGH | MEDIUM | LOW | INFO |
|---|---|---|---|---|
| Health | | | Battery health below 80% or a service condition | |
| Backups | | AutoBackup off with a destination; home folder excluded | | |
| Updates | | Checks off or last full check over 30 days; critical responses or data updates off; XProtect over 60 days old | Automatic download or App Store auto-update off | macOS auto-install off; recent non-Apple installs |
| Platform | Signed system volume off; boot arguments with `amfi_` or `cs_enforcement_disable`; quarantine off | Library validation off; world-writable app; screen lock over 1 hour or off | Other boot arguments; screen lock over 5 minutes; world-writable `/Library` folder without the sticky bit | |
| Sharing | | Internet Sharing, SMB guest, NFS; remote-support tool running; `PermitUserEnvironment`, `GatewayPorts`, or `HostbasedAuthentication` on | Remote Apple Events, Apache, printer sharing, AirDrop to everyone, AirPlay receiver, media sharing, content caching; `X11Forwarding` on; `MaxAuthTries` over 6 | |
| Persistence | Authorization plugin or PAM module that a non-root account can write, including through the admin group (`chain_writable` HIGH, decision G3); login item in an app in an unusual path | Unsigned or ad hoc authorization plugin; PAM module outside `/usr/lib/pam`; any ScriptingAddition or directory service plug-in; unsigned login item in an app | Authorization plugin signed with a team ID; any StartupItem | Audio plug-ins; login items in apps |
| Apps | Debug port listening on a non-loopback address, running or set in a launch item; forced extensions in managed preferences or Firefox `policies.json` on a Mac without MDM enrollment | Debug port on loopback only, or with an unknown bind address; forced extensions in local preferences only; native-messaging host under a temporary or shared folder | Native-messaging host whose program is missing | Forced extensions (any source) on an MDM-enrolled Mac; native-messaging host count |
| Accounts | Extra UID 0; home folder writable by others; sudoers file or `sudo` with wrong owner or writable by others; `NOPASSWD: ALL`; `!authenticate`; NOPASSWD for a code-loading program or for a program a non-root account can write; home folder writable by a group with other members | Hidden admin account; weak `Defaults` | Hidden non-admin account | |
| Credentials | Credential file with an inline secret, or a private key, readable by group or others | Weak SSH key; `ForwardAgent yes` or `StrictHostKeyChecking no` for every host | Private keys without a passphrase; owner-only credential files with inline secrets; the same SSH options for specific hosts | |
| Developer | | | Global `hooksPath` | |
| Trust | | User-domain trusted certificates | | |

`--remote-debugging-pipe` gives no finding. Dropped after the review: the missing `secure_path` check (stock macOS has none) and `credential.helper store` (the `.git-credentials` check covers it).

## Side effects

None new. `cupsctl` can start cupsd on demand, so the printer sharing check runs it only when cupsd is already running. `tmutil isexcluded`, `system_profiler SPPowerDataType`, `codesign -dv`, and `sysadminctl -screenLock status` only read. No check runs `git`, `ssh -G`, `ssh-keygen` on a private key, or a helper inside an app.

## Out of scope

- Section selection (`--only`): a later release.
- The other register ideas (I014, I017 to I072): later releases.
- Report-format ideas (I076, I078 to I086), including standard-format export. Stable IDs (I077) are in scope.

## How to continue if interrupted

1. Read `docs/ISSUES.md`, this doc, and `checks-1.3-tests.md`.
2. Check `git log master..feature/checks-1.3` for the commits in "Build order" that are done.
3. Continue with the next commit in "Build order". Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay` before each commit.
