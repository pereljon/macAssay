---
kind: feature
lifecycle: designing
status: 2026-11-24 scope, outline, secret handling, and severities approved by the user; design doc drafted; architecture review next
---

# Report by theme and new checks (version 1.3)

This doc is the plan of record for version 1.3: the report reorganized into 14 themed sections, about 20 groups of new checks, and the certificate-label masking fix. Test cases and review findings live in `checks-1.3-tests.md`.

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64) and `macassay` 1.2 at commit `aa397f3`.

## Goal

Make the report cover the security exposure that the architecture review and the prior-art register found missing, and make it easy to read. Each section covers one theme, and each flag's category names its section.

## Requirements

Each requirement traces to a user decision on 2026-11-24 (recorded in `docs/ISSUES.md` and below) or to `AGENTS.md`.

1. The report has the 14 sections in "Report outline", in that order, followed by the Summary and Limitations as now. Source: user decision.
2. Each flag's category is the short label of its section. Source: user decision.
3. The "Privileged checks" section is removed; each privileged check moves to its topic section. Source: user decision.
4. Every check group in "New checks" is built. Source: user decision (scope).
5. Long hex strings in certificate labels are masked. Source: `docs/ISSUES.md` bug, user decision (scope).
6. No new sudo rules and no new side effects. Source: `AGENTS.md` (Least privilege, Read-only), user approval of design part 1.
7. No secret value reaches the report, the temporary folder, or the terminal. Source: `AGENTS.md` (No secrets), user approval of design part 2.
8. Severities follow "Severities". Source: user approval of design part 3.
9. Stock tools under `/bin/bash` 3.2 only. Source: `AGENTS.md` (Stock macOS only).

## Decisions

- 2026-11-24: 1.3 takes every proposed check group plus the certificate-label bug in one release. Rejected: inventory checks in a 1.4, which repeats the design and review cycle for the lowest-risk checks. Recorded in `docs/ISSUES.md`.
- 2026-11-24: Section selection (`--only`) waits for a later release. Rejected for 1.3: it needs dependency handling between sections and a Limitations record of what was skipped.
- 2026-11-24: The report is reorganized by theme. Rejected: adding checks into the 1.2 sections, which crowds the security baseline section; appending new sections, which splits related checks. The reorder is mechanical because all privileged data is collected before section 1.
- 2026-11-24: Two themes beyond the first draft, "Device management and security software" and "Shell, developer and AI tools". Both hold existing or planned checks from `dev/prior-art-ideas.md` that fit no other theme.
- 2026-11-24: Inventory checks print a count and the unusual items only. A missing setting gets an explicit "macOS default" line. Repeated findings collapse into one flag.
- 2026-11-24: Secret presence is decided from key names and file headers only (design part 2).
- 2026-11-24: Severities as in "Severities", with three raised to HIGH after comparison with the 1.2 scale: quarantine off, locally set forced browser extensions, and a user-writable authorization plugin or PAM module.
- 2026-11-24: The architecture review of this design must review every severity, existing and new, for consistency and correctness. Source: the user.

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
- `/Users/<user>` is `drwxr-xr-x` by default, so readable home folders are not flagged.
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

Each section has a short label, used as the flag category. Content moved from 1.2 is listed with its old section number.

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

1.2 categories map to labels: Memory, Stability, and Storage (disk use) go to Health; Backup to Backups; Security and Firewall go to Platform, except failed SSH sign-ins, which go to Events; Malware (XProtect detections) goes to Events; Processes and Apps go to Apps; the rest keep their meaning under the new label. Flag texts that cite a section number are updated.

## Build order

1. Commit 1 moves blocks into the outline, renames categories, and folds the privileged checks into topic sections. It adds no check and changes no check logic. Verification: run 1.2 and the reordered script with `--quick --offline --skip-du`, normalize headings and category names, sort both reports, and compare. The line sets must match, apart from values that change between runs (load, memory, connection counts).
2. Commit 2 adds hex masking.
3. Later commits add the new checks, one section per commit, with fixture tests for each parser.

## Shared helpers

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
- Screen lock: the delay from `sysadminctl -screenLock status 2>&1`; also `immediate` and `off`.
- World-writable apps: `find /Applications -maxdepth 2 -name '*.app' -type d -perm -2`. World-writable folders: `find /Library -xdev -type d -perm -002 ! -perm -1000`, count plus the first 10.

### 6. Sharing and remote access

- More sharing services, each from one key or listener: Remote Apple Events (`launchctl print system/com.apple.AEServer` succeeds), Internet Sharing (`com.apple.nat` `NAT` `Enabled`), SMB guest access (`AllowGuestAccess`), Apache (`org.apache.httpd` loaded), NFS (`/etc/exports` with entries), printer sharing (`cupsctl` `_share_printers=1`), AirDrop (`DiscoverableMode`), AirPlay receiver (ControlCenter listening on TCP 5000 or 7000), media sharing (`home-sharing-enabled`), content caching (`AssetCache` `Activated`).
- Remote-support tools: process names from `ps -axo comm=` matched against TeamViewer, AnyDesk, RustDesk, ScreenConnect, Splashtop, BeyondTrust, LogMeIn, RealVNC, TigerVNC, and JumpCloud Assist.
- More sshd settings, only when SSH listens, from the existing `sshd -G` output: `permituserenvironment`, `gatewayports`, `hostbasedauthentication`, `x11forwarding`, `maxauthtries`.

### 8. Startup and persistence

- Authorization plugins: each bundle in `/Library/Security/SecurityAgentPlugins`, with its signer from `codesign -dv` (team ID only) and its owner. HIGH when the user can write it or its folder chain (the 1.2 `chain_writable` helper).
- PAM: modules in `/etc/pam.d` given as an absolute path outside `/usr/lib/pam`, with owner and `chain_writable`.
- StartupItems, ScriptingAdditions (`/Library` and `~/Library`), directory service plug-ins: any entry.
- Audio plug-ins: count, and names of entries in `/Library/Audio/Plug-Ins/HAL`.
- Login items in apps: the `find` above, as app name and item name; count, then items whose app is not signed or sits in an unusual path.

### 9. Apps and browsers

- Forced extensions: `ExtensionInstallForcelist` (Chrome, Edge, Brave) and Firefox `ExtensionSettings` with `force_installed`, from `/Library/Managed Preferences` (INFO) and `/Library/Preferences` or `~/Library/Preferences` (HIGH). Extension IDs only.
- Native-messaging hosts: count per folder; for each host manifest, the `path` key read with `plutil -extract path raw` (JSON); MEDIUM when the path is unusual or missing.
- Debug ports: `ps -axwwo comm=,command=` for `--remote-debugging-port`, `--remote-debugging-pipe`, or `--inspect`, excluding the check's own process; program name only. Launch items whose `ProgramArguments` contain these flags: MEDIUM.

### 10. Accounts and privileges

- UID 0: accounts other than `root` with UID 0.
- Hidden accounts: `IsHidden` set on an account with UID 500 or above; MEDIUM when the account is in the `admin` group.
- Home folders writable by group or others: `stat` on each `/Users/*` home except `Shared`.
- Sudoers ownership: `stat` on `/etc/sudoers`, `/etc/sudoers.d`, its files, and `/usr/bin/sudo`; expect `root:wheel`, no write for group or others, and setuid on `sudo`.
- Sudoers content, through the existing rule that reads `/etc/sudoers` and `sudoers.d` files: `NOPASSWD: ALL` (HIGH), `!authenticate` (HIGH), NOPASSWD for a program on the code-loading list (MEDIUM), weak `Defaults` (MEDIUM), no `secure_path` (LOW). The code-loading list: shells, `env`, `python*`, `perl`, `ruby`, `node`, `osascript`, `vi`, `vim`, `less`, `more`, `find`, `awk`, `sed`, `tar`, `zip`, `git`, `ssh`, `scp`, `rsync`, `tee`, `cp`, `mv`, `dd`, `chmod`, `chown`, `curl`, `wget`, and `ALL`. Only names are printed, never full rule lines, so rules that name hosts or files stay out.

### 11. Credentials and keys

- Credential files in the home folder: `.netrc`, `.aws/credentials`, `.git-credentials`, `.npmrc`, `.pypirc`, `.docker/config.json`, `.kube/config`, `.config/gh/hosts.yml`. For each: presence, owner, mode, and whether `has_key` finds an inline secret (`password`, `aws_secret_access_key`, any line in `.git-credentials`, `_authToken` or `_auth`, `password` in `.pypirc`, `"auth":`, `token:` or `client-key-data:`, `oauth_token:`). The report never names profiles or sections.
- SSH private keys: files in `~/.ssh` whose line 1 is a private-key header. Report file name, mode, and passphrase state from the header only. Never run `ssh-keygen` on a private key.
- SSH public keys: `ssh-keygen -l -f` on each `~/.ssh/*.pub`; weak types.
- SSH client options: parse `~/.ssh/config` (and its `Include` files under `~/.ssh`) for `ForwardAgent yes` and `StrictHostKeyChecking no`; report whether each applies under `Host *` and a count of other `Host` blocks. Host names are not reported.

### 12. Shell, developer and AI tools

- Git settings: read `~/.gitconfig` and `~/.config/git/config` for `hooksPath` (the path is printed) and `helper = store`. Never run `git`.

### 13. Trust and privacy

- User-domain trust: `security dump-trust-settings`, certificate names only through `mask_hex`; policy strings are dropped.

## Severities

New flags, by section. Repeated findings give one flag with a count.

| Section | HIGH | MEDIUM | LOW | INFO |
|---|---|---|---|---|
| Health | | | Battery health below 80% or a service condition | |
| Backups | | AutoBackup off with a destination; home folder excluded | | |
| Updates | | Checks off or last full check over 30 days; critical responses or data updates off; XProtect over 60 days old | Automatic download, macOS auto-install, or App Store auto-update off | Recent non-Apple installs |
| Platform | Signed system volume off; boot arguments with `amfi_` or `cs_enforcement_disable`; quarantine off | Other boot arguments; library validation off; world-writable app; screen lock over 1 hour or off | Screen lock over 5 minutes; world-writable `/Library` folder without the sticky bit | |
| Sharing | | Remote Apple Events, Internet Sharing, SMB guest, Apache, NFS; remote-support tool running; `PermitUserEnvironment`, `GatewayPorts`, or `HostbasedAuthentication` on | Printer sharing, AirDrop to everyone, AirPlay receiver, media sharing, content caching; `X11Forwarding` on; `MaxAuthTries` over 6 | |
| Persistence | Authorization plugin or PAM module the user can write | Non-Apple authorization plugin; PAM module outside `/usr/lib/pam`; any StartupItem, ScriptingAddition, or directory service plug-in | | Audio plug-ins; login items in apps |
| Apps | Program running with a debug port; forced extensions set locally | Debug port in a launch item; native-messaging host in an unusual path | | Forced extensions set by MDM; native-messaging host count |
| Accounts | Extra UID 0; home folder writable by others; sudoers file or `sudo` with wrong owner or writable by others; `NOPASSWD: ALL`; `!authenticate` | Hidden admin account; NOPASSWD for a code-loading program; weak `Defaults` | Hidden non-admin account; no `secure_path` | |
| Credentials | Credential file with an inline secret, or a private key, readable by group or others | Weak SSH key; `ForwardAgent yes` or `StrictHostKeyChecking no` under `Host *` | Private keys without a passphrase; owner-only credential files with inline secrets; the same SSH options for specific hosts | |
| Developer | | | Global `hooksPath`; `credential.helper store` | |
| Trust | | User-domain trusted certificates | | |

`NOPASSWD: ALL` changes from MEDIUM in 1.2 to HIGH.

## Side effects

None new. `tmutil isexcluded`, `system_profiler SPPowerDataType`, `codesign -dv`, and `sysadminctl -screenLock status` only read. No check runs `git`, `ssh -G`, `ssh-keygen` on a private key, or a helper inside an app.

## Out of scope

- Section selection (`--only`): a later release.
- The other register ideas (I014, I017 to I072): later releases.
- Report-format ideas (I076 to I086).

## How to continue if interrupted

1. Read `docs/ISSUES.md`, this doc, and `checks-1.3-tests.md`.
2. Check `git log master..feature/checks-1.3` for the commits in "Build order" that are done.
3. Continue with the next commit in "Build order". Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay` before each commit.
