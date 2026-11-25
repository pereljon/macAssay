# Prior art: ideas register

This file lists each check or idea from the reviewed projects that macassay could adopt, with its sources, the date it was added, and its status. It does not describe the projects themselves; `dev/prior-art.md` holds the repo log and the per-repo reviews. It is not the plan of record either: a planned idea also appears in `docs/ISSUES.md` or a feature design doc. The `prior-art-scout` agent (`.claude/agents/prior-art-scout.md`) maintains both files.

## How to read the register

- **ID:** a stable number for citing an idea. New rows take the next free number, and numbers are never reused.
- **Kind:** `check` (a new audit check), `report` (report format or content), `design` (interface or privilege model), or `tooling` (development and tests).
- **Priority:** `A` for the highest-value gaps, `B` for useful checks, `C` for low-value extras, `unset` when not yet ranked.
- **Sources:** reviewed repos, by the short name used in `dev/prior-art.md` (Tracked repos). Rule IDs such as CIS or Lynis test numbers follow the repo name.
- **Added:** the date the idea entered the register. Adding a source to an existing row does not change it.
- **Status:**
  - `proposed`: found in a review, with no decision yet.
  - `planned X.Y`: the user approved it for that version, or it is in the version list in `docs/ISSUES.md`.
  - `adopted X.Y`: shipped in that version.
  - `rejected`: will not be adopted; the reason is in Notes.
- **Notes:** for a check, the stock command, whether it needs root, and the severity to flag. Every command needs a check on a live Mac before it ships.

All checks fit macassay's rules: stock tools, read-only, and no secrets in the report. Rows are grouped by kind and priority.

## Register

| ID | Idea | Kind | Priority | Sources | Added | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| I001 | Remote-support tools running | check | A | macaudit | 2026-11-24 | planned 1.3 | `ps -axo comm=` for TeamViewer, AnyDesk, RustDesk, ScreenConnect, Splashtop, BeyondTrust, LogMeIn, RealVNC, TigerVNC, JumpCloud Assist. Root: no. Flag: MEDIUM. |
| I002 | Plaintext credential files | check | A | mac-posture-audit, Pareto | 2026-11-24 | planned 1.3 | Presence, key names, and `stat` mode of `~/.netrc`, `~/.aws/credentials`, `~/.git-credentials`, `~/.npmrc`, `~/.pypirc`, `~/.docker/config.json`, `~/.kube/config`, `~/.config/gh/hosts.yml`; never values. Root: no. Flag: MEDIUM; HIGH if group or others can read. |
| I003 | Browser or Electron app with a debug port | check | A | mac-posture-audit | 2026-11-24 | planned 1.3 | `ps -axwwo command=` for `--remote-debugging-port`, `--remote-debugging-pipe`, `--inspect`; report the app name only. Root: no. Flag: HIGH if running; MEDIUM if set in a LaunchAgent. |
| I004 | Dangerous global git settings | check | A | mac-posture-audit | 2026-11-24 | planned 1.3 | Read `~/.gitconfig` for `core.hooksPath` and `credential.helper store`. Do not run `/usr/bin/git`, which can prompt to install developer tools. Root: no. Flag: MEDIUM. |
| I005 | Sudoers file ownership and permissions | check | A | Lynis AUTH-9252, sudo-check | 2026-11-24 | planned 1.3 | `stat -f '%Su:%Sg %Sp'` on `/etc/sudoers`, `/etc/sudoers.d`, its files, and `/usr/bin/sudo` (expect root-owned and setuid). Root: no. Flag: HIGH if not root-owned or writable by others. |
| I006 | SSH client options | check | A | mac-posture-audit, Pareto | 2026-11-24 | planned 1.3 | Parse `~/.ssh/config` for `ForwardAgent yes` and `StrictHostKeyChecking no`. Do not run `ssh -G`, which can run `Match exec`. Root: no. Flag: MEDIUM under `Host *`; else LOW. |
| I007 | Weak SSH keys | check | A | Pareto | 2026-11-24 | planned 1.3 | `ssh-keygen -l -f` on `~/.ssh/*.pub`. Root: no. Flag: MEDIUM for DSA, or RSA under 2048 bits. |
| I008 | More sshd settings | check | A | Lynis SSH-7408 | 2026-11-24 | planned 1.3 | `sshd -G` keys `permituserenvironment`, `hostbasedauthentication`, `gatewayports`, `permittunnel`, `allowtcpforwarding`, `x11forwarding`, `maxauthtries`. Root: no. Flag: MEDIUM or LOW by key. |
| I009 | Screen-lock delay | check | A | mSCP CIS 2.11.2 | 2026-11-24 | planned 1.3 | `sysadminctl -screenLock status`. Root: no. Flag: LOW above 5 s; MEDIUM above 15 min. |
| I010 | Update checks stale or off | check | A | mSCP CIS 1.1, Pareto, check-mac, agentic toolkit | 2026-11-24 | planned 1.3 | `/Library/Preferences/com.apple.SoftwareUpdate` keys `LastFullSuccessfulDate`, `AutomaticCheckEnabled`, `AutomaticDownload`, `AutomaticallyInstallMacOSUpdates`, `ConfigDataInstall`, `CriticalUpdateInstall`; App Store `AutoUpdate`. Root: no. Flag: MEDIUM if not checked in 30 days or checks off; LOW for the rest. `CriticalUpdateInstall` and `ConfigDataInstall` are already in the 1.3 list in `docs/ISSUES.md`. |
| I011 | Browser native-messaging hosts | check | A | fuzzlove | 2026-11-24 | planned 1.3 | List `NativeMessagingHosts` folders for Chrome, Edge, Brave, and Firefox, system-wide and per user. Root: no. Flag: INFO; MEDIUM if the host program is in an unusual path. |
| I012 | World-writable apps and folders | check | A | mSCP CIS 5.1.5, 5.1.7 | 2026-11-24 | planned 1.3 | `find /Applications -name '*.app' -type d -perm -2`; `find /Library -type d -perm -002 ! -perm -1000`. Root: no. Flag: MEDIUM for apps; LOW for folders. |
| I013 | More sharing services | check | B | mergen, Pareto, mSCP, macabre, check-mac | 2026-11-24 | planned 1.3 | AirPlay Receiver (ControlCenter on TCP 5000 or 7000), Media Sharing (TCP 3689), Content Caching (`AssetCache` `Activated`), Bluetooth Sharing, SMB guest access, Apache and NFS enabled; printer sharing (`cupsctl`, `_share_printers`); Internet Sharing; Remote Apple Events (`launchctl list`, `com.apple.AEServer`). Root: no. Flag: MEDIUM for Apache, NFS, SMB guest; LOW for the rest. Remote Apple Events, printer sharing, and Internet Sharing are already in the 1.3 list in `docs/ISSUES.md`. |
| I014 | Launch item anomaly flags | check | B | drduh guide, macos-persist-scan, mcp-macos-security, mac-security-audit-skill, macharden, fullstacksushil | 2026-11-24 | proposed | `plutil -extract` on each launchd plist; `xattr -p com.apple.quarantine` on the target; `stat -f %m` on the plist. Flags: target under `~/Downloads` or `/var/folders`; quarantined target; `AbandonProcessGroup`; `StartInterval` under 60 s; shell with `-c`; program named like a system binary outside system folders; plist younger than 7 days; inline commands (`curl`, `wget`, `base64`, `eval`, `python -c`, `osascript -e`, `/dev/tcp`); `KeepAlive` with a user-writable program. Root: no. Flag: MEDIUM for a Downloads, temp, or quarantined target; LOW for the rest. |
| I015 | Sudoers Defaults that weaken sudo | check | B | sudo-check, macharden | 2026-11-24 | planned 1.3 | Read through the existing sudoers rule: `env_keep` with `DYLD_*` or `LD_*`, `!env_reset`, `setenv`, `!authenticate`, `visiblepw`, `timestamp_timeout` of -1. Root: yes (existing rule). Flag: MEDIUM; HIGH for `!authenticate`. Part of "Stronger sudoers checks" in `docs/ISSUES.md`; this row adds the key list. |
| I016 | NOPASSWD for programs that can load code | check | unset | sudo-check | 2026-11-24 | planned 1.3 | Compare NOPASSWD commands against a GTFOBins-style list. Part of "Stronger sudoers checks" in `docs/ISSUES.md`. |
| I017 | SSH authorized_keys options | check | B | mcp-macos-security | 2026-11-24 | proposed | Read option names (`command=`, `from=`, `no-pty`, `permitopen`) from `authorized_keys`; never option values. Root: no. Flag: INFO; MEDIUM for `command=`. |
| I018 | Third-party Homebrew taps and settings | check | B | agentic toolkit | 2026-11-24 | proposed | `brew tap` names; the tap of each installed package (`brew info --json=v2 --installed`); names in `HOMEBREW_NO_INSECURE_REDIRECT`, `HOMEBREW_CASK_OPTS`, `HOMEBREW_VERIFY_ATTESTATIONS`. Run after the existing Homebrew update. The `brew.env` path is unverified. Root: no. Flag: INFO; LOW for a tap with no installed package. |
| I019 | XProtect scans off | check | B | mSCP CIS 5.10 | 2026-11-24 | proposed | `xprotect status`, launch and background scans. Root: unverified. Flag: MEDIUM. |
| I020 | AI-agent hooks and MCP servers | check | B | loongsuite-pilot, mac-posture-audit, agentic toolkit | 2026-11-24 | proposed | `plutil -convert json -o -` on `~/.claude/settings.json`, Cursor, and Codex config; names and program paths only. Also flag launcher packages with no pinned version (`npx -y name`). Root: no. Flag: INFO; HIGH if a program is in `/tmp`, `/Users/Shared`, or a hidden folder; LOW for an unpinned launcher. |
| I021 | Editor workspace trust off | check | B | mac-posture-audit | 2026-11-24 | proposed | Grep VS Code and Cursor `settings.json` for `security.workspace.trust.enabled: false` and `task.allowAutomaticTasks: on`. Root: no. Flag: LOW. |
| I022 | Mounted network shares | check | B | fuzzlove | 2026-11-24 | proposed | `/sbin/mount` for `smbfs`, `nfs`, `afpfs`. Root: no. Flag: INFO. |
| I023 | Password hints and login window | check | B | mSCP CIS 2.12.1, mergen | 2026-11-24 | proposed | `dscl . -list /Users hint` (account names only); `SHOWFULLNAME`, `RetriesUntilHint`. Root: no. Flag: LOW. |
| I024 | Password and lockout policy | check | B | fuzzlove | 2026-11-24 | proposed | `pwpolicy getaccountpolicies`, key fields only. Root: unverified. Flag: LOW. |
| I025 | Privileged helpers in app bundles | check | B | MacOS-Maid | 2026-11-24 | proposed | `Contents/Library/LaunchServices` and `SMPrivilegedExecutables` in `Info.plist`, with signer. Root: no. Flag: MEDIUM if unsigned or ad hoc. |
| I026 | Unencrypted external volumes | check | B | mSCP CIS 5.3.2 | 2026-11-24 | proposed | `diskutil list external`, then `diskutil info`. Root: no. Flag: INFO. |
| I027 | Umask too open or unset | check | B | Lynis SHLL-6230, drduh guide | 2026-11-24 | proposed | `umask` lines in `/etc/zshrc`, `/etc/profile`, and the user's startup files, value and file only; the user umask from `launchctl config user umask` (drduh README, "Custom umask"). Root: no. Flag: LOW for 000 or 002. |
| I028 | Shell history not a regular file | check | B | Lynis HOME-9310 | 2026-11-24 | proposed | `find ~ -maxdepth 1 -name '.*history' ! -type f`. Root: no. Flag: LOW. |
| I029 | Long uptime | check | B | Pareto | 2026-11-24 | proposed | `sysctl -n kern.boottime`. Root: no. Flag: LOW above 14 days. |
| I030 | Tailscale Funnel or Serve | check | B | fullstacksushil, ivanpsn | 2026-11-24 | proposed | `tailscale funnel status` and `tailscale serve status`, with the app's CLI when installed. Root: no. Flag: HIGH for Funnel; INFO for Serve. |
| I031 | Local AI servers and containers on all interfaces | check | B | fullstacksushil, ivanpsn | 2026-11-24 | proposed | A listener on `*:11434` (Ollama) rated as such; `docker ps` ports on `0.0.0.0` when the Docker CLI exists and the daemon answers. Root: no. Flag: MEDIUM. |
| I032 | Installers without quarantine | check | B | macwatchdog-cli, mac-security-audit-skill | 2026-11-24 | proposed | `xattr -p com.apple.quarantine` on `.app`, `.pkg`, `.dmg`, `.command` items in `~/Downloads` from the last 90 days. Root: no. Flag: MEDIUM. |
| I033 | Profile payload types | check | B | macwatchdog-cli | 2026-11-24 | proposed | Flag root CA, VPN, and SCEP payloads in the profiles inventory. Root: no for user profiles. Flag: MEDIUM for a root CA; else INFO. |
| I034 | CA private-key permissions | check | B | fexxdev | 2026-11-24 | proposed | `stat -f %Lp` on `~/Library/Application Support/mkcert/rootCA-key.pem` and similar CA roots. Root: no. Flag: HIGH if group or others can read; else INFO. |
| I035 | IP forwarding | check | B | macharden | 2026-11-24 | proposed | `sysctl -n net.inet.ip.forwarding net.inet6.ip6.forwarding`. Root: no. Flag: MEDIUM if on while Internet Sharing is off. |
| I036 | BPF device access | check | B | macharden | 2026-11-24 | proposed | `ls -l /dev/bpf*`; `dscl . -read /Groups/access_bpf GroupMembership`. Root: no. Flag: MEDIUM if world-readable; INFO for the group. |
| I037 | PATH hygiene | check | B | macharden | 2026-11-24 | proposed | The user's login `PATH`, captured before macassay resets it: `.`, or world-writable folders. Root: no. Flag: HIGH for `.`; MEDIUM for a world-writable folder. |
| I038 | Secrets in shell history | check | B | macharden | 2026-11-24 | proposed | `grep -c` for token patterns in `~/.zsh_history` and `~/.bash_history`; counts only. Root: no. Flag: MEDIUM. |
| I039 | macOS release without security updates | check | B | fort | 2026-11-24 | proposed | `sw_vers -productVersion` against a maintained list of supported majors. Root: no. Flag: MEDIUM. |
| I040 | Login keychain lock policy | check | B | macharden | 2026-11-24 | proposed | `security show-keychain-info ~/Library/Keychains/login.keychain-db`. Root: no. Flag: LOW without auto-lock or lock on sleep. |
| I041 | Network time off | check | C | fuzzlove | 2026-11-24 | proposed | Root: no. Flag: INFO or LOW. |
| I042 | Unified-log private data on | check | C | fuzzlove | 2026-11-24 | proposed | Root: no. Flag: INFO or LOW. |
| I043 | Third-party QuickLook generators | check | C | fuzzlove | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I044 | Wake-on-LAN and Power Nap | check | C | check-mac, macabre | 2026-11-24 | proposed | `pmset -g`. Root: no. Flag: INFO. |
| I045 | Terminal Secure Keyboard Entry | check | C | Pareto, check-mac | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I046 | Outbound firewall and antivirus inventory | check | C | Lynis | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I047 | `.rhosts` and `hosts.equiv` present | check | C | Lynis | 2026-11-24 | proposed | The source is inferred from the old "Low-value extras" row; no review names it. Root: no. Flag: LOW. |
| I048 | Hibernate mode | check | C | check-mac | 2026-11-24 | proposed | `pmset -g`. In mode 0 the FileVault key stays in memory during sleep. Root: no. Flag: LOW. |
| I049 | Firewall block-all | check | C | macabre, MacScope | 2026-11-24 | proposed | `socketfilterfw --getblockall`. Root: no. Flag: INFO. |
| I050 | Bluetooth power | check | C | Di-kairos, check-mac | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I051 | Saved Wi-Fi network count | check | C | Di-kairos | 2026-11-24 | proposed | Count only, never network names. Root: no. Flag: INFO. |
| I052 | iCloud Desktop and Documents sync | check | C | hackerman-jpeg | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I053 | Find My Mac | check | C | Di-kairos, fexxdev | 2026-11-24 | proposed | `nvram fmm-mobileme-token-FMM`, one variable, never `nvram -p`; unverified. Root: no. Flag: INFO. |
| I054 | Entitlements of third-party apps | check | C | macos-trust | 2026-11-24 | proposed | `codesign -d --entitlements :-`: `get-task-allow`, `disable-library-validation`, `allow-dyld-environment-variables`, `allow-unsigned-executable-memory`, `no-sandbox` (`entitlements.py:28-45`). Expect noise from Electron apps. Root: no. Flag: INFO or LOW. |
| I055 | Random-looking launchd labels | check | C | macos-persist-scan | 2026-11-24 | proposed | Name entropy. The review found a high false-positive risk. Root: no. Flag: LOW. |
| I056 | sudo version against known CVEs | check | C | sudo-check | 2026-11-24 | proposed | `sudo -V`. Whether Apple backports fixes is unverified. Root: no. Flag: INFO. |
| I057 | Secret-bearing file names in project folders | check | C | SwordCheck | 2026-11-24 | proposed | Names only: `.env`, `*.tfstate`, `*.tfvars`, `*.pem`, `credentials.json`. Root: no. Flag: LOW. |
| I058 | Developer mode | check | C | 6kdave | 2026-11-24 | proposed | `DevToolsSecurity -status`. Root: no. Flag: INFO. |
| I059 | Core dumps on | check | C | macharden | 2026-11-24 | proposed | `sysctl -n kern.coredump`. Root: no. Flag: LOW. |
| I060 | USB restricted mode | check | C | fexxdev | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I061 | Promiscuous interfaces | check | C | macharden | 2026-11-24 | proposed | Root: no. Flag: LOW. |
| I062 | Configured VPN services | check | C | idlework | 2026-11-24 | proposed | `scutil --nc list`. Root: no. Flag: INFO. |
| I063 | Per-service DNS servers | check | C | idlework, check-mac | 2026-11-24 | proposed | `networksetup -getdnsservers`. Root: no. Flag: INFO. |
| I064 | Telemetry sharing | check | C | check-mac, fexxdev | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I065 | Touch ID for sudo | check | C | fort, fexxdev | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I066 | Daily-use account is an admin | check | C | Pareto | 2026-11-24 | proposed | Root: no. Flag: LOW. |
| I067 | USB device inventory | check | C | macwatchdog-cli | 2026-11-24 | proposed | Root: no. Flag: INFO. |
| I068 | Code signing of running programs and launch targets | check | unset | mac-compass, mac-security-audit-skill | 2026-11-24 | proposed | Signing and notarization state of each running program and launchd target; flag unsigned code running from temp folders. |
| I069 | Open Wi-Fi auto-join | check | unset | macharden, fexxdev | 2026-11-24 | proposed | |
| I070 | Screen-saver idle time and hot corners | check | unset | mergen | 2026-11-24 | proposed | Use mergen's CIS key names. |
| I071 | Authorization rights for screensaver unlock and System Settings | check | unset | mOSL, icdcdev | 2026-11-24 | proposed | Whether System Settings requires an admin password. |
| I072 | Risky command counts in AI-agent transcripts | check | unset | clawkeeper | 2026-11-24 | proposed | Counts only, never transcript text. |
| I073 | Read SSH settings with `sshd -G` | design | unset | mSCP | 2026-11-24 | planned 1.2 | Drops the `sshd -T` sudo rule. Verified on macOS 27.2.1: it runs without root and prints the same keys. Built on `feature/sudo-rules`. |
| I074 | Inventory device profiles with `profiles list -type configuration` | design | unset | 1.2 code review (CR-4) | 2026-11-24 | planned 1.2 | Replaces `profiles show`, whose expanded output might carry payload secrets. Built on `feature/sudo-rules`. |
| I075 | Read-only tripwire test | tooling | unset | mac-posture-audit | 2026-11-24 | proposed | A test that fails when `macassay` gains a command that changes the system. Target 1.3. |
| I076 | Control citations on findings | report | unset | mSCP, mac-compass, macharden | 2026-11-24 | proposed | Each matching finding names its CIS section, mSCP rule ID, NIST control, and MITRE ATT&CK technique where one applies. Cite rule IDs with attribution; mSCP text is CC BY 4.0 except Apple-contributed text. Target 1.3. |
| I077 | Stable finding IDs and a uniform check shape | report | unset | Lynis, macabre, macharden | 2026-11-24 | proposed | Each flag gets an ID such as `MA-SSH-001`, so findings can be cited, suppressed, and compared. Target 1.3. |
| I078 | Accepted-risk list | report | unset | Lynis | 2026-11-24 | proposed | A user file of finding IDs to hide or mark as accepted. Needs I077. Target 1.3. |
| I079 | Missing evidence is INFO, never a pass | report | unset | macharden | 2026-11-24 | proposed | macassay 1.2 lists skipped checks in Limitations. This extends the rule to checks that ran but could not read their evidence. |
| I080 | Guidance text for each finding | report | unset | macharden | 2026-11-24 | proposed | A short "what to check next" line per finding, as text only; macassay never runs a fix. |
| I081 | "Managed" result for settings an MDM or DDM sets | report | unset | check-mac | 2026-11-24 | proposed | |
| I082 | Combined findings | report | unset | fexxdev, mac-posture-audit | 2026-11-24 | proposed | Report attack chains such as FileVault off with auto-login on, or SSH on with the firewall off. Target 1.3. |
| I083 | Severity exit codes | design | unset | fort | 2026-11-24 | proposed | Exit status reflects the worst finding, for scripted use. Target 1.3. |
| I084 | Machine-readable sidecar | report | unset | Lynis, macabre, mac-compass | 2026-11-24 | proposed | ID, severity, and text per finding, for run-to-run comparison. Target later. |
| I085 | Run-to-run comparison | report | unset | macaudit, macabre, mac-compass | 2026-11-24 | proposed | `--compare PREVIOUS` shows what changed; startup items keyed on program, arguments, and run conditions. macabre exits non-zero on a regression; mac-compass compares normalized baselines. Target later. |
| I086 | SARIF output | report | unset | macharden | 2026-11-24 | proposed | A SARIF file beside the Markdown report, for code-scanning tools. Target later. |
| I087 | Running any reviewed tool on the audited Macs | design | unset | all | 2026-11-24 | rejected | Root daemons, settings changes, network calls, or a whole-script root run. |
| I088 | mSCP pass and fail rules | check | unset | mSCP | 2026-11-24 | rejected | About 57% of checks pass only under an MDM profile. |
| I089 | Remediation and fix commands | design | unset | mergen, mOSL, mSCP, stronghold, armazi | 2026-11-24 | rejected | macassay never changes the Mac. mergen's fixes also have bugs. |
| I090 | Hardening index and other scores | report | unset | Lynis, macabre, SwordCheck, Di-kairos | 2026-11-24 | rejected | One score hides a HIGH finding among passes. |
| I091 | Continuous monitoring, file-activity logs, notifications | design | unset | macaudit, NuwaStone | 2026-11-24 | rejected | Not a one-shot audit; logs file names; needs permanent root services. |
| I092 | Per-app version checks | check | unset | Pareto | 2026-11-24 | rejected | Needs vendor update feeds over the network. |
| I093 | Threat feeds and known-bad extension catalogs | check | unset | fuzzlove, mac-posture-audit | 2026-11-24 | rejected | Needs external feeds. |
| I094 | Vulnerability and release feeds (SOFA, OSV, NVD, CISA KEV, EPSS) | check | unset | MacScope, SwordCheck | 2026-11-24 | rejected | Network calls to third parties. |
| I095 | Check definitions or tool updates fetched from GitHub and run by `sh -c` | design | unset | armazi | 2026-11-24 | rejected | Remote text decides what runs. |
| I096 | Whole-tool root runs and `sudo -v` keep-alive loops | design | unset | mac-compass, Di-kairos, hackerman-jpeg | 2026-11-24 | rejected | Breaks least privilege; macassay uses per-command sudo rules. |
| I097 | `nvram -p` for AMFI boot arguments | check | unset | mSCP, mergen | 2026-11-24 | rejected | Dumps every NVRAM variable; read `nvram boot-args` only. |
| I098 | Privacy toggles (Siri, analytics, Apple Intelligence, Safari) | check | unset | mergen | 2026-11-24 | rejected | Preferences, not security findings. |
| I099 | IPv6 off, firmware password, kext consent, eficheck | check | unset | mOSL | 2026-11-24 | rejected | Preferences, or obsolete on Apple silicon. |
| I100 | Remediation strings run through `eval` with values read from the Mac | design | unset | macharden | 2026-11-24 | rejected | Command injection. A private report to the maintainer is drafted. |
| I101 | `curl \| bash` and `curl \| sudo bash` installs | tooling | unset | fullstacksushil, icdcdev, clawkeeper | 2026-11-24 | rejected | Runs unreviewed remote code, as root in some cases. |
| I102 | README download links to binary archives | tooling | unset | ivanpsn | 2026-11-24 | rejected | Looks like a malware lure; nothing was downloaded. |
