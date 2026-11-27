# Checks

This file lists the checks that macAssay runs, grouped by report section, with the options and privileges that affect each one and the finding IDs each can give. It does not explain how to fix a finding or describe report formatting.

A check is a test that the script runs. A finding is a judged result of a check, with a severity (HIGH, MEDIUM, LOW, INFO) and a stable ID such as `MA-SHARING-026`. The report lists findings in its Findings section. A check marked "none" under Findings gives evidence only. The code in `macassay` is the source of truth.

## Options and privileges

| Option or privilege | Checks it skips or enables |
|---|---|
| `--quick` | Skips the 7-day unified-log searches in section 14: XProtect messages (`MA-EVENTS-001`) and SSH failures (`MA-EVENTS-002`). |
| `--offline` | Skips three checks that contact Apple or Homebrew: `softwareupdate -l` (`MA-UPDATES-001`), Homebrew outdated packages (`MA-UPDATES-002`), and the Gatekeeper assessment of apps (`MA-APPS-002`). |
| `--skip-du` | Skips the disk usage scans in section 1: the home folder scan and the top-level usage scan. |
| `--format LIST` | Changes the report's formats (`md`, `json`, `ocsf`, `html`, `csv`), not which checks run. See [FORMATS.md](FORMATS.md). |
| `--compare OLD.json` | Adds a comparison with an earlier JSON report, by finding ID. It runs no check. |
| `--accepted FILE` | Moves findings that the file accepts out of the findings table and the counts. It runs no check. |
| `--fail-on LEVEL` | Sets exit status 3 when an open finding reaches LEVEL. It runs no check. |
| sudo rules (privileged checks) | Enable the checks marked "sudo rules". Without `/etc/sudoers.d/macassay`, each of them records a skip. [SUDOERS.md](SUDOERS.md) lists each command the rules allow and the check that uses it. |

Each skipped check is listed under Limitations in the report, with the reason. A sudo rule that sudo refuses counts as a skip too.

Other gates and notes:

- Full Disk Access (a macOS privacy permission that the terminal app holds) gates the Time Machine settings file and the user TCC (Transparency, Consent, and Control, the macOS privacy permission) database. Each records a skip when unreadable. The sudo rules do not cover either one.
- A setting that a configuration profile manages reads `VALUE (managed)` in the evidence, and a finding that judges it has the source `managed`. macAssay reads `/Library/Managed Preferences` for the settings in sections 2, 3, 4, 6, 8, 9, and 10. Effective-state commands such as `fdesetup`, `csrutil`, and `socketfilterfw` already show the real state, so they do not change.
- A check that ran but could not read its evidence prints `unreadable (REASON)` and records a skip, never a clean value. These skips are: Time Machine settings (file unreadable or missing while a destination exists), the Jetsam and kernel panic folders, the 7-day log searches, Homebrew outdated packages, the XProtect version, the enrollment state, browser policy files, Remote Management settings, Find My, firewall stealth mode, and screen lock. Each skip lists the finding IDs that the check could have given, so `--compare` reports them as not checked.
- `-o`, `--stdout`, and remote mode (`--host`, `--user`, `--key`, `--port`, `--known-hosts`) change where the report goes or which Mac is audited. They do not change which checks run. Remote mode passes `--quick`, `--offline`, and `--skip-du` to the remote run.
- `--print-sudoers` and `--install-sudoers` do not run the audit.
- While it runs, the script prints one status line per section on standard error: finding counts, skipped checks, and time.

## 1. System health (Health)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| macOS | `sw_vers` | none | none |
| Kernel | `uname -a` | none | none |
| Hardware | `system_profiler SPHardwareDataType`, with serial and UUID lines removed | none | none |
| Uptime and load | `uptime` | none | none |
| Installed memory and swap | `sysctl hw.memsize`, `sysctl vm.swapusage` | none | `MA-HEALTH-001` LOW: swap is 75% used or more |
| Memory pressure | `memory_pressure`, `vm_stat` | none | none |
| Top 15 processes by memory, top 10 by CPU | `ps -axo` | none | none |
| Out-of-memory (Jetsam) reports | `JetsamEvent-*` files in the system and user DiagnosticReports folders, last 7 days | none | `MA-HEALTH-002` MEDIUM: 3 or more reports |
| Volumes | `df -h`, `df -k /System/Volumes/Data` | none | `MA-HEALTH-003` MEDIUM at 85% used; HIGH at 95% |
| Drives and SMART (disk self-monitoring) status | `system_profiler SPStorageDataType` | none | `MA-HEALTH-004` HIGH: a drive reports a status other than Verified |
| Crash and diagnostic reports | DiagnosticReports folders, last 14 days, counted by program | none | none |
| Kernel panics | `*.panic` files in `/Library/Logs/DiagnosticReports`, last 30 days | none | `MA-HEALTH-005` HIGH: at least one panic |
| Largest items in the home folder | `du -sh -x` on the home folder | `--skip-du` skips | none |
| Top-level usage | `du` on `/Users` and on `/Library`, `/Applications`, `/opt`, `/private/var` | sudo rules; `--skip-du` skips | none |
| Power and sleep | `pmset -g` | none | none |
| Battery | `pmset -g batt`, `system_profiler SPPowerDataType`; laptops only | none | `MA-HEALTH-006` LOW: condition is not Normal or maximum capacity is under 80% |

## 2. Backups (Backups)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Local snapshots | `tmutil listlocalsnapshots /` | none | none |
| Time Machine destinations | `tmutil destinationinfo` | none | `MA-BACKUPS-001` MEDIUM: no destination |
| Latest backup and backup age | `Destinations.0.SnapshotDates` in `/Library/Preferences/com.apple.TimeMachine.plist` | Full Disk Access; records a skip when the file is unreadable | `MA-BACKUPS-003` MEDIUM: latest backup is 48 hours old or more |
| First destination encryption | `LastKnownEncryptionState` in the same file | Full Disk Access, as above | `MA-BACKUPS-002` MEDIUM: not encrypted |
| Automatic backups | `AutoBackup` in `com.apple.TimeMachine`; runs only when a destination exists | none | `MA-BACKUPS-004` MEDIUM: automatic backups are off |
| Home folder in Time Machine | `tmutil isexcluded` on the home folder; runs only when a destination exists | none | `MA-BACKUPS-005` MEDIUM: the home folder is excluded |

## 3. Updates and installs (Updates)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Software Update settings | `AutomaticCheckEnabled`, `LastFullSuccessfulDate`, `AutomaticDownload`, `AutomaticallyInstallMacOSUpdates`, `CriticalUpdateInstall`, `ConfigDataInstall` in `/Library/Preferences/com.apple.SoftwareUpdate`; `AutoUpdate` in `com.apple.commerce` | none | `MA-UPDATES-003` MEDIUM: checks are off, or the last full check is over 30 days old; `MA-UPDATES-004` MEDIUM: security responses or XProtect data updates are off; `MA-UPDATES-006` LOW: automatic download or App Store auto-update is off; `MA-UPDATES-007` INFO: macOS updates are not installed automatically |
| `softwareupdate -l` | `softwareupdate -l` (contacts Apple) | `--offline` skips | `MA-UPDATES-001` MEDIUM: macOS updates are available |
| Outdated Homebrew formulae and casks | `brew outdated`, plain and `--greedy` (contacts Homebrew); runs only when Homebrew is installed | `--offline` skips | `MA-UPDATES-002` LOW: 20 or more outdated packages |
| Homebrew security settings | names only of `HOMEBREW_VERIFY_ATTESTATIONS`, `HOMEBREW_NO_VERIFY_ATTESTATIONS`, `HOMEBREW_NO_INSECURE_REDIRECT` in the environment and `brew.env` files; runs only when Homebrew is installed | none | none |
| Third-party Homebrew taps | tap folders under Homebrew's `Library/Taps` and the install receipts in `Cellar` and `Caskroom` (no `brew` command); runs only when Homebrew is installed | none | `MA-UPDATES-009` LOW: a third-party tap has no installed package; `MA-UPDATES-010` INFO: installed packages come from third-party taps |
| Homebrew cask apps with no quarantine attribute | `xattr -p com.apple.quarantine` on cask apps in `/Applications` and the user's `Applications`; runs only when Homebrew is installed | none | `MA-UPDATES-011` LOW: at least one cask app has no attribute |
| XProtect versions | `system_profiler SPInstallHistoryDataType` | none | none |
| XProtect age | `xprotect version` | none | `MA-UPDATES-005` MEDIUM: last updated over 60 days ago |
| Non-Apple installs, last 30 days | `/Library/Receipts/InstallHistory.plist`, `pkgutil --pkgs` | none | `MA-UPDATES-008` INFO: at least one non-Apple install |

## 4. Platform security (Platform)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Baseline: System Integrity Protection (SIP) | `csrutil status` | none | `MA-PLATFORM-001` HIGH: SIP is not enabled |
| Baseline: Gatekeeper | `spctl --status` | none | `MA-PLATFORM-002` HIGH: Gatekeeper is disabled |
| Baseline: application firewall | `socketfilterfw --getglobalstate`, `--getstealthmode`, `--getallowsigned` | none | `MA-PLATFORM-003` MEDIUM: firewall is off; `MA-PLATFORM-004` LOW: stealth mode is off |
| Baseline: FileVault | `fdesetup status` | none | `MA-PLATFORM-005` MEDIUM: FileVault is off |
| Baseline: automatic login | `autoLoginUser` in `/Library/Preferences/com.apple.loginwindow` | none | `MA-PLATFORM-006` MEDIUM: automatic login is on |
| Screen lock | `sysadminctl -screenLock status` | none | `MA-PLATFORM-010` MEDIUM: off or over 3600 seconds; LOW: over 300 seconds |
| Boot arguments | `nvram boot-args` | none | `MA-PLATFORM-013` HIGH: arguments turn off code-signing enforcement; `MA-PLATFORM-014` LOW: other arguments are set |
| Authenticated root | `csrutil authenticated-root status` | none | `MA-PLATFORM-012` HIGH: the signed system volume is off |
| Library validation disabled | `DisableLibraryValidation` in `/Library/Preferences/com.apple.security.libraryvalidation` | none | `MA-PLATFORM-016` MEDIUM: library validation is off |
| Quarantine for downloads | `LSQuarantine` in `com.apple.LaunchServices` | none | `MA-PLATFORM-015` HIGH: quarantine is off |
| Find My Mac and Activation Lock | `FMMEnabled` in `/Library/Preferences/com.apple.FindMyMac`; `Activation Lock Status` from the hardware profile | none | `MA-PLATFORM-019` LOW on a laptop, INFO otherwise: `FMMEnabled` is 0 |
| Apps writable by everyone | `find /Applications -maxdepth 2 -name '*.app' -perm -2` | none | `MA-PLATFORM-017` MEDIUM: at least one app |
| Folders in `/Library` writable by everyone | `find /Library -xdev -type d -perm -002` without the sticky bit | none | `MA-PLATFORM-018` LOW: at least one folder |
| System extensions | `systemextensionsctl list` | none | `MA-PLATFORM-007` INFO: an extension waits for user approval |
| Third-party kernel extensions | `kmutil showloaded --list-only` | none | none |
| Application firewall rules | `socketfilterfw --listapps`, signer from `codesign -dv` | none | `MA-PLATFORM-008` MEDIUM: an Allow rule for an unsigned or ad hoc program; `MA-PLATFORM-011` LOW: an Allow rule for a program that no longer exists |
| Secure boot policy | `bputil -d`, filtered to security settings; Apple silicon only, reports "not applicable" on Intel | sudo rules | `MA-PLATFORM-009` HIGH: Permissive Security; MEDIUM: another mode that is not Full |
| Packet filter (pf) | `pfctl -s info`, `pfctl -s rules` | sudo rules | none |

## 5. Device management and security software (Management)

This section gives evidence only; no finding uses its label yet.

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| MDM (mobile device management) and profiles | `profiles status -type enrollment`, `profiles list` | none | none |
| Device configuration profiles | `profiles list -type configuration`, names and identifiers only | sudo rules | none |

## 6. Sharing and remote access (Sharing)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| launchd services | `launchctl print-disabled system` for sshd, screensharing, smbd, tftpd, ftp, AppleFileServer, RemoteDesktop, ARDAgent | none | none |
| Listening test of common ports | `nc -z` to 127.0.0.1 and the LAN address: ports 22 (SSH, secure shell), 445 (SMB, file sharing), 548 (AFP, Apple file sharing), 5900 (VNC, Screen Sharing), 3283 (ARD, Apple Remote Desktop), 88 (Kerberos) | none | none |
| TFTP (trivial file transfer) | `netstat -anv -p udp` for UDP 69; `launchctl print-disabled system` and the `tftp.plist` file | none | `MA-SHARING-001` MEDIUM: listening on UDP 69; `MA-SHARING-002` LOW: enabled in launchd |
| SMB file sharing | `nc -z` on port 445; `sharing -l` | none | `MA-SHARING-003` LOW: SMB is on |
| Remote Management settings | `/Library/Preferences/com.apple.RemoteManagement.plist`; runs only when port 3283 listens or `ARDAgent` runs | none | `MA-SHARING-004` MEDIUM: on for all local users; `MA-SHARING-005` MEDIUM: legacy VNC passwords; `MA-SHARING-006` MEDIUM: insecure Diffie-Hellman |
| SSH offers | one `ssh` connection as `nobody` to 127.0.0.1; runs only when port 22 listens | none | `MA-SHARING-007` MEDIUM: SSH accepts passwords (from `sshd -G`, else from the offered methods) |
| SSH access group | `dscl . -read /Groups/com.apple.access_ssh`; runs only when port 22 listens | none | `MA-SHARING-008` LOW: group absent, so SSH is not limited to specific users |
| `sshd_config.d` | `/etc/ssh/sshd_config.d/*`, non-comment lines; runs only when port 22 listens | none | none |
| Effective sshd settings | `sshd -G`; runs only when port 22 listens; records a skip when `sshd -G` fails | none | `MA-SHARING-009` HIGH: root login is permitted; `MA-SHARING-014` MEDIUM: `PermitUserEnvironment`; `MA-SHARING-015` MEDIUM: `GatewayPorts`; `MA-SHARING-016` MEDIUM: host-based authentication; `MA-SHARING-017` LOW: X11 forwarding; `MA-SHARING-018` LOW: `MaxAuthTries` over 6 |
| Screen Sharing access group | `dscl . -read /Groups/com.apple.access_screensharing` | none | none |
| File shares | `sharing -l` | none | none |
| Remote Apple Events | `launchctl print system/com.apple.AEServer` | none | `MA-SHARING-019` LOW: on |
| Internet Sharing | `NAT.Enabled` in `com.apple.nat.plist` | none | `MA-SHARING-010` MEDIUM: on |
| SMB guest access | `AllowGuestAccess` in `com.apple.smb.server.plist` | none | `MA-SHARING-011` MEDIUM: guests allowed |
| Apache web server | `launchctl print system/org.apache.httpd` | none | `MA-SHARING-020` LOW: loaded |
| NFS (network file system) exports | `/etc/exports` | none | `MA-SHARING-012` MEDIUM: exports are configured |
| Printer sharing | `/etc/cups/cupsd.conf` | none | `MA-SHARING-021` LOW: cupsd listens beyond localhost |
| AirDrop discoverability | `DiscoverableMode` in `com.apple.sharingd` | none | `MA-SHARING-022` LOW: discoverable by everyone |
| AirPlay receiver | `lsof` on ControlCenter listeners (TCP 5000 or 7000) | none | `MA-SHARING-023` LOW: listening |
| Media sharing | `home-sharing-enabled` in `com.apple.amp.mediasharingd` | none | `MA-SHARING-024` LOW: on |
| Content caching | `Activated` in `/Library/Preferences/com.apple.AssetCache` | none | `MA-SHARING-025` LOW: on |
| Remote-access tools running | `ps -axo comm=` matched against a fixed list of tools | none | `MA-SHARING-013` MEDIUM: a remote-support tool is running |
| Remote-access tools installed | file names in application, support, launch, helper, and `/opt` folders matched against the same list; each match is named in the report | none | `MA-SHARING-026` MEDIUM for a launch daemon, launch agent, or helper; LOW otherwise: a tool is installed but not running |
| SSH `authorized_keys` | `ssh-keygen -l -f` on the user's `authorized_keys` | none | none |

## 7. Network exposure (Network)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Listeners reachable from other devices | `netstat -anv -p tcp` (else `lsof`); one HTTP GET with `curl` to each listener; signer from `codesign` | sudo rules (without them, root-owned ports may show without a process name); the program path lookup uses `lsof -d txt` | `MA-NETWORK-001` MEDIUM: a non-Apple listener answers HTTP 200 without a login; `MA-NETWORK-002` INFO: a non-Apple listener on all interfaces |
| Tunnel programs | `ps` for `cloudflared`, `ngrok`, `frpc` | none | `MA-NETWORK-003` LOW: one is running |
| VPN and tunnel processes | `ps` filtered for tunnel and VPN names | none | none |
| All TCP listeners | `lsof -nP -iTCP -sTCP:LISTEN` | sudo rules | none |
| DNS servers in use | `scutil --dns` | none | none |
| Proxy settings | `scutil --proxy` | none | `MA-NETWORK-004` MEDIUM: a system proxy or auto-config is on |
| Non-default `/etc/hosts` entries | `/etc/hosts` | none | `MA-NETWORK-005` LOW: at least one non-default entry |
| Established outbound TCP connections | `netstat -anv -p tcp`, `ps` | none | none |

## 8. Startup and persistence (Persistence)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Launch items table | `*.plist` in `/Library/LaunchDaemons`, `/Library/LaunchAgents`, and the user's `LaunchAgents`; signer from `codesign` | none | `MA-PERSISTENCE-001` HIGH: runs from an unusual path; `MA-PERSISTENCE-002` LOW: program is missing; `MA-PERSISTENCE-003` MEDIUM (LOW under `/opt/homebrew` or `/usr/local`): changed in 14 days and unsigned or ad hoc |
| Root daemons a non-root account can change | `/Library/LaunchDaemons/*.plist`, the program, its link target, a script argument, and the folders above them | none | `MA-PERSISTENCE-004` HIGH, or MEDIUM when only the admin group can write under `/Applications` |
| Privileged helper tools | `ls -l /Library/PrivilegedHelperTools`, signer | none | none |
| Login hook | `LoginHook` in `com.apple.loginwindow` | none | `MA-PERSISTENCE-005` HIGH: set |
| User crontab | `crontab -l`; arguments and values hidden | none | none |
| Non-standard periodic scripts | `/etc/periodic/daily`, `weekly`, `monthly` | none | none |
| Shell startup files | the user's `.zshrc`, `.zprofile`, `.zshenv`, `.zlogin`, `.bashrc`, `.bash_profile`, `.profile`, and the system files in `/etc`; pattern matches only, no line text | none | `MA-PERSISTENCE-006` HIGH: download-and-run, `/dev/tcp`, or `nc -e` patterns; `MA-PERSISTENCE-011` MEDIUM: base64 decode or `osascript -e` |
| Executables in shared or temporary folders | `find` in `/Users/Shared`, `/private/tmp`, `/private/var/tmp` | none | `MA-PERSISTENCE-007` MEDIUM: at least one executable |
| Background items | `sfltool dumpbtm`, non-Apple items | sudo rules | none |
| launchd `DYLD_INSERT_LIBRARIES` | `launchctl getenv DYLD_INSERT_LIBRARIES` | none | `MA-PERSISTENCE-008` HIGH: set |
| Authorization plugins | `/Library/Security/SecurityAgentPlugins/*.bundle`, signer, owner | none | `MA-PERSISTENCE-012` HIGH, or MEDIUM under the admin-group rule: a non-root account can change it; `MA-PERSISTENCE-013` MEDIUM: unsigned or ad hoc; `MA-PERSISTENCE-014` LOW: installed and signed by a third party |
| PAM (pluggable authentication modules) | modules in `/etc/pam.d` given as absolute paths outside `/usr/lib/pam` | none | `MA-PERSISTENCE-015` HIGH, or MEDIUM under the admin-group rule: a non-root account can change it; `MA-PERSISTENCE-016` MEDIUM: module outside `/usr/lib/pam` |
| StartupItems | `/Library/StartupItems` | none | `MA-PERSISTENCE-017` LOW: present |
| Scripting additions | `/Library/ScriptingAdditions` and the user's folder | none | `MA-PERSISTENCE-018` MEDIUM: present |
| Directory service plug-ins | `/Library/DirectoryServices/PlugIns` | none | `MA-PERSISTENCE-019` MEDIUM: present |
| Audio plug-ins (HAL) | `/Library/Audio/Plug-Ins/HAL/*`, signer | none | `MA-PERSISTENCE-020` INFO: at least one not signed by Apple |
| Login items inside apps | `LoginItems`, `LaunchAgents`, `LaunchDaemons` inside `.app` bundles in `/Applications` and the user's `Applications` | none | `MA-PERSISTENCE-021` INFO: at least one registered; `MA-PERSISTENCE-022` MEDIUM: unsigned or ad hoc app; `MA-PERSISTENCE-023` HIGH: app in an unusual path |
| Other accounts: `authorized_keys` fingerprints, LaunchAgents, shell startup files | `ssh-keygen -l -f`, `ls -ln`, `ls -lnd` for each other account | sudo rules | `MA-PERSISTENCE-009` HIGH: another account can change a shell startup file |
| Crontabs | `ls -ln /var/at/tabs` | sudo rules | `MA-PERSISTENCE-010` INFO: an account other than the user has a crontab |

## 9. Apps and browsers (Apps)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Running programs outside standard locations | `ps -axo comm=`, signer from `codesign` | none | `MA-APPS-001` HIGH: a program runs from a temporary or shared folder |
| Applications that Gatekeeper rejects | `spctl -a -t exec` on each app in `/Applications` and the user's `Applications` (contacts Apple) | `--offline` skips | `MA-APPS-002` LOW: Gatekeeper rejects an app |
| Chrome extensions | `manifest.json` files under the Chrome profile folders | none | none |
| Safari web extensions | `pluginkit -mAvvv -p com.apple.Safari.web-extension` | none | none |
| Forced browser extensions | managed and local preferences for Chrome, Edge, Brave, and Firefox; Firefox `policies.json`; MDM enrollment from `profiles status -type enrollment` | none | `MA-APPS-005` HIGH: forced by managed preferences or `policies.json` on a Mac not enrolled in MDM; `MA-APPS-006` MEDIUM: forced by local preferences; `MA-APPS-007` INFO: forced by policy on an MDM-enrolled Mac |
| Native-messaging hosts | `NativeMessagingHosts` folders under the user's and system `Application Support` and Chrome folders | none | `MA-APPS-010` INFO: at least one host; `MA-APPS-008` MEDIUM: a host runs a program from a temporary or shared folder; `MA-APPS-009` LOW: a host points to a missing program |
| Programs with a debug port | `ps -axwwo pid=,command=` for `--remote-debugging-port` and `--inspect` flags; `lsof` for the bind address; launch item `ProgramArguments` | none (reuses the sudo-rule `lsof` listeners when installed) | `MA-APPS-003` HIGH: debug port on a non-loopback address; `MA-APPS-004` MEDIUM: on loopback or an unknown address |

## 10. Accounts and privileges (Accounts)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Local users | `dscl . -list /Users UniqueID`, UID (user ID) 500 and above | none | none |
| Admin group | `dscl . -read /Groups/admin GroupMembership` | none | `MA-ACCOUNTS-002` LOW: lists a user that does not exist |
| root account | `AuthenticationAuthority` and `Password` of `/Users/root` | none | `MA-ACCOUNTS-003` MEDIUM: appears enabled |
| Accounts with UID 0 | `dscl . -list /Users UniqueID` | none | `MA-ACCOUNTS-012` HIGH: an account other than root has UID 0 |
| Hidden accounts | `dscl . -list /Users IsHidden`, `dsmemberutil checkmembership` | none | `MA-ACCOUNTS-013` MEDIUM: hidden administrator, UID 500 or above; `MA-ACCOUNTS-014` LOW: other hidden account, UID 500 or above |
| Home folders | `stat` on each folder in `/Users` | none | `MA-ACCOUNTS-015` HIGH: writable by everyone, or by a group with other members |
| Recent logins | `last -25` | none | none |
| Guest account | `GuestEnabled` in `com.apple.loginwindow` | none | `MA-ACCOUNTS-004` LOW: enabled |
| `/etc/sudoers.d` | `ls -l /etc/sudoers.d` | none | `MA-ACCOUNTS-001` INFO: a file other than `macassay` is present |
| Sudo files (owner, mode) | `stat` on `/etc/sudoers`, `/etc/sudoers.d`, its files, and `/usr/bin/sudo` | none | `MA-ACCOUNTS-016` HIGH: wrong owner or mode |
| `/etc/sudoers` | `cat /etc/sudoers`, parsed for NOPASSWD rules and weak `Defaults` lines | sudo rules | `MA-ACCOUNTS-005` HIGH: a NOPASSWD rule covers ALL; `MA-ACCOUNTS-006` LOW: other NOPASSWD rule; `MA-ACCOUNTS-008` HIGH: a rule runs a program that a non-root account can change; `MA-ACCOUNTS-009` HIGH: a rule allows a program that can run other code; `MA-ACCOUNTS-010` HIGH: `Defaults !authenticate`; `MA-ACCOUNTS-011` MEDIUM: weak `Defaults` such as `!env_reset` |
| Files in `/etc/sudoers.d` | `cat` of each file whose name has no dot and does not end in `~`, parsed as above | sudo rules | the same IDs as `/etc/sudoers`; `MA-ACCOUNTS-007` INFO: a file is not covered by the installed rules |

## 11. Credentials and keys (Credentials)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Credential files in the home folder | mode and owner of `.netrc`, `.aws/credentials`, `.git-credentials`, `.npmrc`, `.pypirc`, `.docker/config.json`, `.kube/config`, `.config/gh/hosts.yml`; a pattern test for an inline secret, never the value | none | `MA-CREDENTIALS-001` HIGH: a file with an inline secret is readable by other accounts; `MA-CREDENTIALS-003` LOW: inline secrets, owner-readable only |
| SSH private keys | header of each private key file in `~/.ssh`; passphrase state only | none | `MA-CREDENTIALS-002` HIGH: readable by other accounts; `MA-CREDENTIALS-004` LOW: no passphrase |
| SSH public keys | `ssh-keygen -l -f` on `~/.ssh/*.pub`, bits and type only | none | `MA-CREDENTIALS-005` MEDIUM: DSA, or RSA under 2048 bits |
| SSH client `ForwardAgent` | `~/.ssh/config`, `/etc/ssh/ssh_config`, `ssh_config.d`, `Include` targets | none | `MA-CREDENTIALS-006` MEDIUM: yes for every host; `MA-CREDENTIALS-008` LOW: yes for some hosts |
| SSH client `StrictHostKeyChecking` | the same files | none | `MA-CREDENTIALS-007` MEDIUM: no for every host; `MA-CREDENTIALS-009` LOW: no for some hosts |
| SSH client Host and Match blocks | the same files | none | none |

## 12. Shell, developer and AI tools (Developer)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Git global `hooksPath` | `core.hooksPath` in `~/.gitconfig` and `~/.config/git/config`; `git` is never run | none | `MA-DEVELOPER-001` LOW: set |

## 13. Trust and privacy (Trust)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| Certificates in the System keychain | `security find-certificate -a /Library/Keychains/System.keychain` | none | none |
| Admin trust settings | `security dump-trust-settings -d` | none | `MA-TRUST-001` MEDIUM: an administrator trusts a certificate |
| User trust settings | `security dump-trust-settings` | none | `MA-TRUST-002` MEDIUM: the user trusts a certificate |
| Privacy permissions, user database | `sqlite3` on the user `TCC.db`, read-only: accessibility, screen capture, full disk access, input monitoring, microphone, camera | Full Disk Access; records a skip when unreadable | none |
| Privacy permissions, system database | not read | always skipped; needs root and Full Disk Access, and the sudo rules do not cover it | none |

## 14. Security events from the logs (Events)

| Check | What it reads | Needs or skipped by | Findings |
|---|---|---|---|
| XProtect detections | `log show --last 7d` for `com.apple.XProtect` messages with "detected" or "remediat"; counts `NoThreatDetected` results | `--quick` skips | `MA-EVENTS-001` HIGH: detection or remediation messages found |
| SSH log lines | `log show --last 7d` for `sshd` accepted, failed, and invalid-user lines | `--quick` skips | `MA-EVENTS-002` MEDIUM: 20 or more failed attempts |
