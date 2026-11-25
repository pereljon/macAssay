# Prior art: macOS audit and security projects

This file is the repo log: the GitHub projects that audit or harden macOS, what each one checks, and the search state for finding more. It does not hold the ideas to adopt; `dev/prior-art-ideas.md` lists each idea with its sources, date added, and status. Neither file is macassay's plan of record; planned checks move to `docs/ISSUES.md` and a feature design doc. The `prior-art-scout` agent (`.claude/agents/prior-art-scout.md`) maintains both files.

Last full review: 2026-11-24.

## Summary

None of the reviewed tools should run on the audited Macs as they stand, and none replaces macassay. Deep reviews of the two closest peers, mac-posture-audit and macharden, found that neither has a remote mode or a sudo-rule model, both cover about half of macassay's host checks, and mac-posture-audit's written rules forbid both features. mac-posture-audit, macharden, Pareto, and NIST mSCP are the best sources of checks to borrow. Most of the others install root daemons, change settings, or reach the network, which conflicts with macassay's read-only, stock-tools, least-privilege design.

The 2026-11-24 discovery run added 15 reviews. Most of the 115 relevant repos the macOS audit searches found are small, recent, and often written with AI assistance; few add checks. The best new sources are drduh's launchd script (launch item flags), sudo-check (sudoers rules), mac-compass (signing and baseline design), and the agentic toolkit (Homebrew and MCP settings).

The recommendations from these reviews are in `dev/prior-art-ideas.md`: priority A checks for 1.3, and the `sshd -G` and `profiles list` changes for 1.2.

## Tracked repos

Rows are sorted by value as a source for macassay. "Last commit" is the newest commit at the last review; the scout compares it with the current one to find repos worth a second look.

| Repo | Type | Language | Runs as | Changes the Mac | Network | Last commit | Reviewed | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [demirelo/mac-posture-audit](https://github.com/demirelo/mac-posture-audit) | One-shot audit | Bash 3.2 | User; `sudo -n` when cached | No (CI tripwire) | Only with `--network` | `a0dbf6e` 2026-10-15 (v1.7.0) | 2026-11-24 | Borrow checks and the tripwire |
| [ParetoSecurity/pareto-mac](https://github.com/ParetoSecurity/pareto-mac) | Scheduled checker, menu-bar app | Swift | User; root XPC helper | No (auto-updates itself) | Vendor cloud, version feeds | `2851e86` 2026-11-24 | 2026-11-24 | Borrow checks |
| [usnistgov/macos_security](https://github.com/usnistgov/macos_security) (mSCP) | Compliance rule catalog | YAML, zsh, Python | Root, for managed fleets | Fixes separate from checks | No | `fd08e55` 2026-11-23 (macOS 27) | 2026-11-24 | Borrow commands; cite rule IDs |
| [CISOfy/lynis](https://github.com/CISOfy/lynis) | One-shot Unix audit | Shell | User or root | No (own logs) | DNS version check by default | `a9527dc` 2026-11-20 (3.1.8) | 2026-11-24 | Borrow 2 to 4 checks and report ideas |
| [drduh/macOS-Security-and-Privacy-Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide) | Guide with three read-only scripts | Markdown, Bash | User, no sudo | No | None in the scripts | `caa3ca4` 2026-11-19 | 2026-11-24 | Borrow launch item flags and umask |
| [jimididit/mac-compass](https://github.com/jimididit/mac-compass) | One-shot triage, baseline, monitor | Go | User; whole run under `sudo` for 14 checks | No | `softwareupdate -l` only | `b0eba7a` 2026-10-16 | 2026-11-24 | Borrow signing checks, ATT&CK tags, baseline design |
| [Harvester57/sudo-check](https://github.com/Harvester57/sudo-check) | Sudoers policy auditor | Go | User | No (patch mode writes a diff) | Optional database download (uncertain) | `deee229` 2026-11-23 | 2026-11-24 | Borrow sudoers rules |
| [ilyamk/agentic-macos-security-toolkit](https://github.com/ilyamk/agentic-macos-security-toolkit) | Read-only assessment, workstation audit, playbooks | POSIX sh, jq | User; `--deep` through sudo | No | Optional, behind flags | `bf405eb` 2026-11-22 | 2026-11-24 | Borrow Homebrew and MCP checks |
| [sametsazak/mergen](https://github.com/sametsazak/mergen) | CIS checker with fixes | Swift, Go | User; fixes as admin | Yes (Fix All) | No | `7684791` 2026-04-22 (v2.3) | 2026-11-24 | Borrow CIS keys; never run fixes |
| [navjotk8690/macaudit](https://github.com/navjotk8690/macaudit) | Continuous monitor | Bash, Python | Root daemons every 60 s | Installs daemons; logs file activity | No | `1056bc4` 2026-08-18 (v3.5.3) | 2026-11-24 | Borrow the remote-support tool list |
| [fuzzlove/macOS-Security-Audit-Agent](https://github.com/fuzzlove/macOS-Security-Audit-Agent) | Commercial GUI platform | Python | User; optional root daemon | Installs daemons and packages | Feeds, licensing | `b812b4d` 2026-08-28 | 2026-11-24 | Borrow 4 checks from its registry |
| [Sn0wAlice/macabre](https://github.com/Sn0wAlice/macabre) | One-shot audit with report diff | Rust | User; some checks need root | No | None found | `90b88d3` 2026-06-17 | 2026-11-24 | Borrow firewall and sharing keys; diff design |
| [N4M3Z/check-mac](https://github.com/N4M3Z/check-mac) | One-shot smoke test | Shell | User | No | None found | `e5bdf83` 2026-05-21 | 2026-11-24 | Borrow hibernate mode and DNS checks |
| [haasonsaas/macos-persist-scan](https://github.com/haasonsaas/macos-persist-scan) | Persistence scanner | Go | User | No | None found | `96d6223` 2025-06-03 | 2026-11-24 | Borrow launch item heuristics |
| [zavora-ai/mcp-macos-security](https://github.com/zavora-ai/mcp-macos-security) | Read-only MCP server | Rust | User | No | None found | `28c28d6` 2026-08-22 | 2026-11-24 | Borrow quarantine and key option checks |
| [texasbe2trill/macos-trust](https://github.com/texasbe2trill/macos-trust) | App and persistence scanner | Python | User | No | None found | `fdb4e7c` 2026-02-08 | 2026-11-24 | Borrow the entitlement list |
| [hideouts-io/MacScope](https://github.com/hideouts-io/MacScope) | Posture and vulnerability scanner | Go, Swift app | User; `--privileged` runs fixed probes through sudo | No | SOFA feed; downloads pinned tools | `5ae6205` 2026-10-09 | 2026-11-24 | Skip; borrow little |
| [SwordSec/SwordCheck](https://github.com/SwordSec/SwordCheck) | One-shot audit and dependency scanner | Rust | User | No | Only with `--online` | `bb808b1` 2026-11-22 | 2026-11-24 | Skip; borrow little |
| [Di-kairos/macos-security-audit](https://github.com/Di-kairos/macos-security-audit) | One-shot audit with HTML report | Bash | User; `sudo -v` keep-alive | No (prints fix commands) | README download link names another account | `d5bc527` 2026-03-17 | 2026-11-24 | Skip; one idea |
| [canerfilibeli/armazi](https://github.com/canerfilibeli/armazi) | CIS checker, app and CLI | Swift | User | Self-updates; fixes by command | GitHub API for checks and updates | `2e620c0` 2026-04-16 | 2026-11-24 | Skip |
| [hackerman-jpeg/macOS-13-Automated-CIS-Benchmark](https://github.com/hackerman-jpeg/macOS-13-Automated-CIS-Benchmark) | CIS check script, macOS 13 | Bash | Root | No | None found | `5cdf6be` 2025-06-03 | 2026-11-24 | Skip; one idea |
| [alichtman/stronghold](https://github.com/alichtman/stronghold) | Settings wizard | Python | User; `sudo` | Yes (applies settings) | None found | `62f12a0` 2026-11-10 | 2026-11-24 | Skip; changes settings |
| [jgamblin/MacOS-Maid](https://github.com/jgamblin/MacOS-Maid) | Cleanup tool | Python | User; `sudo` for cleanup | Yes (`maid clean` deletes) | No | `ab0bb78` 2026-11-02 (v1.0.0) | 2026-11-24 | Skip |
| [0xmachos/mOSL](https://github.com/0xmachos/mOSL) | Audit and lockdown | Bash | User; `sudo` | Yes (fix mode) | No | `e45649e` 2020-06-19 | 2026-11-24 | Skip; unmaintained |
| [ConradSun/NuwaStone](https://github.com/ConradSun/NuwaStone) | Event monitor (Endpoint Security) | Swift | Root daemon, system extension | Yes (can block apps) | Update check | `81f9587` 2026-09-15 (v2.5) | 2026-11-24 | Skip; not an audit tool |
| [alibaba/loongsuite-pilot](https://github.com/alibaba/loongsuite-pilot) | Telemetry for AI coding agents | TypeScript | User launch agent | Yes (edits agents' settings) | Sends serial and MAC to Alibaba Cloud | `eb622a2` 2026-11-24 (v1.9.0) | 2026-11-24 | Skip; not an audit tool |

| [jankesec/macharden](https://github.com/jankesec/macharden) | Hardening audit with fixes and scoring | zsh | User; `sudo -n sshd -T` when cached; root not refused | Yes (`--fix` through `eval`; daemon mode) | No | `9958b4e` 2026-11-11 (v1.5.0) | 2026-11-24 (deep) | Borrow checks and CIS, NIST, MITRE mappings |
| [fexxdev/macos_security_audit](https://github.com/fexxdev/macos_security_audit) | One-shot audit with grade | Bash | User | No (fix text only) | Only with `--online` | `eb30866` 2026-07-26 | 2026-11-24 | Borrow ideas only; no license |
| [ianheil/macwatchdog-cli](https://github.com/ianheil/macwatchdog-cli) | Auditor with management commands | Python | User; `sudo -n` | Yes (kills ports, edits login items, quarantines kexts, removes profiles) | No | `0478461` 2026-06-06 (v2.2.0) | 2026-11-24 | Borrow ideas |
| [djadmin/fort](https://github.com/djadmin/fort) | Audit and fix CLI | Go | User; fixes through `sudo` | Yes (`--fix`) | Daily GitHub release check | `a2b103f` 2026-07-09 (v0.3.2) | 2026-11-24 | Borrow 2 ideas; its report includes the serial number |
| [idlework/security-check](https://github.com/idlework/security-check) | Scored audit CLI | Rust | User | No | No | `b0882b4` 2026-04-11 | 2026-11-24 | Borrow 2 small checks |
| [yanis7774/mac-security-audit-skill](https://github.com/yanis7774/mac-security-audit-skill) | Claude skill wrapping an audit script | Bash | User; `sudo -n` | No (report to Desktop; a separate redaction tool edits files with `--apply`) | No | `a04cc67` 2026-07-01 (v1.5.0) | 2026-11-24 | Borrow 3 ideas |
| [fullstacksushil/mac-security-audit](https://github.com/fullstacksushil/mac-security-audit) | Audit and fix for AI-agent hosts | Bash | `curl \| sudo bash` install | Yes (`--fix`) | No | `f415000` 2026-03-04 | 2026-11-24 | Borrow AI-host ideas |
| [rad-security/clawkeeper](https://github.com/rad-security/clawkeeper) | Scanner for AI-agent hosts | Bash, TypeScript | User; `sudo` for fixes | Yes (fixes, launch agent) | API when a key is set; CVE feed | `64259af` 2026-10-06 (archived) | 2026-11-24 | Skip; archived |
| [6kdave/mac-security](https://github.com/6kdave/mac-security) | Deployment toolkit with an audit script | Bash | User | Other scripts do | No | `ecabc0e` 2026-03-26 (v0.10.0) | 2026-11-24 | Skip; one new check |
| [icdcdev/icdc-macos-audit](https://github.com/icdcdev/icdc-macos-audit) | CIS Level 1 and 2 audit and apply | Bash | Root for apply | Yes (apply) | Installs Homebrew with `curl \| bash` | `1af41fe` 2022-08-22 | 2026-11-24 | Skip; stale, no license |
| [ivanpsn/mac-security-audit](https://github.com/ivanpsn/mac-security-audit) | Audit and fix for AI-agent hosts | Bash | `sudo` | Yes (`--fix`) | `softwareupdate -l` | `be4ff6d` 2026-10-14 | 2026-11-24 | Unsafe: README links to a zip of Windows executables |
## Per-repo reviews

Each review lists what the tool does, how it works, the tests it runs, its safety on a personal Mac, and what to adopt. Each item in an **Adopt:** bullet has a row in `dev/prior-art-ideas.md`. Reviews read shallow clones; nothing was run.

### demirelo/mac-posture-audit

- **What it is:** a read-only posture audit for developer Macs, aimed at crypto and web3 work. MIT.
- **How it works:** one Bash 3.2 script (`#!/bin/bash -p`, 7,473 lines, 30 sections) that prints a colored report or JSON, with an optional HTML renderer. It has bats tests, fuzzing, signed releases, and an OpenSSF Scorecard.
- **Tests:** about 587 results across the system baseline, sharing, persistence, browsers and extensions, wallets, MCP servers, AI-agent instruction files, git and SSH configuration, credential files, and developer tools.
- **Safety:** a CI tripwire (`scripts/check-read-only.sh`) fails the build on any command that changes the system. Network calls run only with `--network`. Privileged checks use `sudo -n` and are skipped when sudo needs a password; there are no fixed sudo rules.
- **Adopt:** credential-file presence and permissions, dangerous global git settings, risky `~/.ssh/config` options, browsers or Electron apps with a debug port, VS Code and Cursor workspace trust, and the read-only tripwire as a test.
- **Deep review (2026-11-24):** no remote mode, although it is one file with no `source` and could support one. No sudo-rule model: it refuses root and uses `sudo -n` per probe, so privileged checks run only while sudo credentials are cached. Its Markdown report has no Limitations section and, by design, no command-output evidence. CONTRIBUTING.md forbids writes other than `--snapshot`, remediation, and network calls outside `--network`, so a sudoers installer or SSH remote mode would not fit upstream. About half its 7,473 lines are wallet, AI-agent, or developer-tool specific, and it lacks most of macassay's host checks. One maintainer; no outside pull requests or issues.

### ParetoSecurity/pareto-mac

- **What it is:** a menu-bar app that runs security checks on a schedule and nudges the user, with an optional team dashboard. GPL-3.0.
- **How it works:** a Swift app plus a root XPC helper installed as an `SMAppService` daemon. The helper runs only `socketfilterfw --getglobalstate`, `--getstealthmode`, and `sudo -n -l -U <caller>`.
- **Tests:** about 50 checks in five groups: access (auto-login, password after sleep, screensaver timeout, admin account, unused accounts, SSH key strength, SSH client config, plaintext credentials, password manager), system integrity (FileVault, Gatekeeper, boot arguments, Time Machine, uptime, open Wi-Fi, compromised CAs, Secure Keyboard Entry), firewall and sharing (firewall, stealth, app exceptions, all sharing services, AirPlay, AirDrop), macOS updates, and about 30 per-app version checks.
- **Safety:** not sandboxed. It contacts `cloud.paretosecurity.com` (after enrollment; default unverified), its own API, a Cloudflare Worker proxy for version lookups, Apple's update and App Store endpoints, and per-app update feeds. It auto-updates its own bundle. The sampled checks change no settings.
- **Adopt:** plaintext credential files, SSH client settings, weak SSH key types and sizes, the macOS and App Store auto-update switches, AirPlay and media-sharing listeners, and uptime over 14 days.

### usnistgov/macos_security (mSCP)

- **What it is:** NIST's macOS Security Compliance Project, the implementation behind NIST SP 800-219. CC BY 4.0, with Apple-contributed description text excluded.
- **How it works:** 471 YAML rules, each with a read-only `check` command, an expected `result`, a `fix` command, references (CIS, 800-53, DISA STIG, CCE), and per-OS overrides. Generators build compliance scripts, configuration profiles, and guidance from baselines (CIS Level 1 and 2, 800-53, 800-171, CMMC, STIG).
- **Tests:** 271 rules have checks. About 155 of them (57%) pass only when an MDM profile sets a key, so they fail on an unmanaged Mac even when the setting is correct. About 72 read real state outside the audit and password-policy families.
- **Safety:** checks are read-only and call stock tools by absolute path; fixes are separate. The scan expects root.
- **Adopt:** individual real-state check commands, and CIS section numbers and rule IDs for citations. Not its pass and fail rules, which assume MDM enforcement.

### CISOfy/lynis

- **What it is:** a mature general Unix auditing tool. GPLv3, with a commercial Enterprise edition.
- **How it works:** shell, run as `lynis audit system`, about 480 registered tests. It writes `lynis.log` and `lynis-report.dat` (key=value with suggestions, warnings, and a hardening index).
- **Tests:** only about 10 target macOS (SIP, FileVault, application firewall, outbound firewall apps, antivirus processes, packages, boot files). Several generic tests read Linux files such as `/etc/passwd` and find nothing on a Mac.
- **Safety:** low risk as a normal user. It makes a DNS TXT version check to `cisofy.com` by default. Full results need a whole-script root run, and its report records MAC addresses and the installed app list.
- **Adopt:** more `sshd` keys, sudoers file ownership and permissions, umask in shell files, and shell history files that are not regular files. Report ideas: stable finding IDs, an accepted-risk list, and a machine-readable sidecar. Not the hardening index, which hides a HIGH finding among passes.

### sametsazak/mergen

- **What it is:** a CIS macOS 26 benchmark checker with one-click fixes. MIT. The README says the 2026 rewrite was "vibe coded" and "may have bugs".
- **How it works:** a SwiftUI app and a Go command-line tool, each with hand-written checks that run `defaults`, `launchctl`, `pmset`, or `csrutil` and grep the output.
- **Tests:** about 85 CIS items: sharing services, screen saver, login window, power settings, password policy, root account, firewall, Gatekeeper, SIP, and privacy toggles.
- **Safety:** the scan runs as the user with no network calls. Fixes run as admin and have bugs: sudoers files written with `echo >` and no `visudo -c`, failures reported as success, a Media Sharing fix that writes root's preferences, and a "disable root" fix that only changes the shell.
- **Adopt:** CIS key names for Content Caching, Media Sharing, AirPlay Receiver, login-window settings, screen-saver idle time, and hot corners.

### navjotk8690/macaudit

- **What it is:** a continuous root monitor with a local web dashboard. MIT.
- **How it works:** three root LaunchDaemons: a collector every 60 seconds, an `fs_usage` file-activity watcher, and a Python dashboard on `127.0.0.1:8765`. It baselines state and records changes as events.
- **Tests:** remote access (SSH sessions, Screen Sharing, ARD, about 12 remote-support tools), TCC permissions, persistence (startup items fingerprinted by behaviour, not file hash), users and admins, security settings, installed software, and file movement.
- **Safety:** config parsing, notification text, and the dashboard's host check and token are done carefully. But root runs with `/opt/homebrew/bin` in `PATH`, the dashboard token goes in a URL, and it logs moved and deleted file names for 90 days. No tests; docs and code disagree.
- **Adopt:** the remote-support tool list, and later an optional run-to-run comparison.

### fuzzlove/macOS-Security-Audit-Agent

- **What it is:** a commercial Python GUI platform for audit, monitoring, and investigation, with a paid license.
- **How it works:** about 1,180 Python files; `pip install`, an optional root LaunchDaemon and user LaunchAgent, and a command registry of about 80 fixed-argument read-only commands.
- **Tests:** audit commands, process and ransomware monitoring, a vulnerability scanner, packet capture, a decoy listener, and compliance mappings.
- **Safety:** its root launcher runs a user-chosen Python with `/opt/homebrew/bin` in `PATH`. It writes to `/Library`, `/var/root`, and LaunchDaemons; contacts GitHub, threat feeds, RDAP, news, and licensing servers; and can run `brew install` at runtime.
- **Adopt:** mounted network shares, browser native-messaging hosts, password and lockout policy, network time, unified-log private data, and QuickLook generators.

### jgamblin/MacOS-Maid

- **What it is:** a cleanup tool with a thin audit layer. MIT.
- **How it works:** Python, `maid audit` and `maid clean [--dry-run]`.
- **Tests:** mostly empty audits; the real one parses `lsof` and `scutil --nc list`.
- **Safety:** `maid clean` deletes caches, empties the Trash, removes saved Wi-Fi networks, and deletes merged git branches.
- **Adopt:** privileged helpers declared inside app bundles, flagged when unsigned.

### 0xmachos/mOSL

- **What it is:** a lockdown script for macOS Catalina. MIT, unmaintained.
- **How it works:** one Bash script, `Lockdown audit` and `Lockdown fix`, running each check through `bash -c` with hard-coded strings.
- **Tests:** about 20 Catalina-era settings, several now obsolete (eficheck, firmware password, kext consent).
- **Safety:** fix mode runs `csrutil clear`, turns IPv6 off, and writes the FileVault recovery key into the home folder.
- **Adopt:** at most whether System Settings requires an admin password.

### ConradSun/NuwaStone

- **What it is:** a real-time file, process, and network event monitor, not an audit tool. GPL-3.0.
- **How it works:** an Endpoint Security and Network Extension system extension (a kernel extension on macOS 10.x), a root daemon, and a UI.
- **Safety:** it can block unsigned apps from running, and its README asks to disable SIP on macOS 10.x.
- **Adopt:** nothing.

### alibaba/loongsuite-pilot

- **What it is:** a telemetry collector for AI coding agents, not an audit tool. Apache-2.0.
- **How it works:** a Node user launch agent that installs hooks into about 20 agents' settings files and exports their activity.
- **Safety:** every 12 hours it posts status to Alibaba Cloud, including IP, MAC, serial number, and hostname. It auto-updates from Alibaba storage and installs with `curl | bash`.
- **Adopt:** the idea of inventorying AI-agent hooks and MCP servers as a persistence surface.

### drduh/macOS-Security-and-Privacy-Guide

- **What it is:** a long community guide to securing macOS (22.6k stars), with three small scripts and a pf rule file. MIT.
- **How it works:** the guide is `README.md` (1,761 lines). `scripts/printPersistent.sh` prints launchd jobs as JSON with signing and anomaly flags; `printSystemInfo.sh` prints system facts; `printKeychainCerts.sh` prints certificates by expiry.
- **Tests:** the persistence script flags a wrapper script, an unsigned target, a target in a temp folder or `~/Downloads`, a timed job without `RunAtLoad`, `AbandonProcessGroup`, and a quarantined target.
- **Safety:** the scripts are read-only. `printSystemInfo.sh:3` says no sudo is needed. The guide itself tells readers to run many changing commands; none run from the scripts.
- **Adopt:** the launch item flags (the existing `/tmp` executable check covers only part), and a check that a user umask is set (`launchctl config user umask`, README section "Custom umask").

### jimididit/mac-compass

- **What it is:** a triage, baseline, and monitor tool with 51 read-only checks. MIT, v-tagged releases, tests with per-macOS fixtures (15 and 26).
- **How it works:** Go. A YAML catalog (`internal/catalog/checks.yaml`) lists each check with its command and an optional ATT&CK technique. Output goes to a terminal, JSON, HTML, SARIF, or a hashed evidence bundle. `snapshot` and `compare` diff two baselines.
- **Tests:** SIP, sealed system volume, Gatekeeper, non-Apple kexts, system extensions, boot arguments, launchd items with signing and notarization state of each target, login items, background items, cron, shell startup file hashes, login hooks, `/etc/hosts`, sudoers.d, listeners, firewall, DNS and proxies, XProtect version, profiles, MDM, TCC grants, accounts, admins, and authorized key fingerprints.
- **Safety:** the README runs the full check as `sudo ./mac-compass run-all -y` (whole tool as root; `--no-sudo` skips 14 checks). Commands use absolute paths and a scrubbed environment (README). Only `harden.softwareupdate-list` contacts Apple. Reports are mode 0600 and can be redacted.
- **Adopt:** code-signing state of each running program and launchd target, ATT&CK tags on findings, and the baseline and compare design. Not the whole-tool root run.

### Harvester57/sudo-check

- **What it is:** a sudoers policy auditor for Linux and macOS, with a large rule catalog. MIT (GitHub shows no license name; `LICENSE` is the MIT text).
- **How it works:** Go. It parses `/etc/sudoers` and drop-ins itself, compares against `cvtsudoers` JSON, and prints text, JSON, SARIF, HTML, or PDF. It simulates one user's effective rights and diffs two runs by finding fingerprint.
- **Tests:** rule IDs `SUDO-DEF-001` to `018` (Defaults), `SUDO-CMD-001` to `016` (commands), `SUDO-GTFO` (programs that give a shell), `SUDO-SYS-PERM` (ownership and modes of sudoers files and `/usr/bin/sudo`), and sudo CVE matching by `sudo --version`. The Defaults checks cover `secure_path`, `env_reset`, `env_keep` with `DYLD_*`, `use_pty`, `visiblepw`, `!authenticate`, `setenv`, `timestamp_timeout`.
- **Safety:** reads files and runs `sudo --version` (`cmd/system.go:206`). `update-db` uses an HTTP client (`cmd/update_db.go:33`); the endpoint was not read. `--fix-patch` writes a diff only (README).
- **Adopt:** the Defaults keys, `/usr/bin/sudo` owner and setuid bit, and `env_keep` with `DYLD_*`. The GTFOBins list overlaps with planned work in `docs/ISSUES.md` (NOPASSWD for programs that can load code).

### ilyamk/agentic-macos-security-toolkit

- **What it is:** a read-only assessment and workstation audit with playbooks, aimed at developers and AI agents. MIT, OpenSSF Scorecard, unit tests and fixtures.
- **How it works:** POSIX sh plus `jq`. Collectors write schema-validated, hashed JSON. `workstation-audit` runs 30 checks in nine areas: Homebrew, npm, pnpm, Node, uv, shell startup, Objective-See tools, TCC, AI agents.
- **Tests:** Homebrew settings (`HOMEBREW_VERIFY_ATTESTATIONS`, `HOMEBREW_CASK_OPTS` with `--require-sha`, `HOMEBREW_NO_INSECURE_REDIRECT`, `brew.env`, `trust.json`, third-party taps and packages from them), unpinned MCP launcher packages in `~/.claude.json` and `~/.cursor/mcp.json`, shell startup patterns, browser native-messaging hosts, credential file metadata, Software Update keys.
- **Safety:** the README says assessment and workstation audit never change settings or print secret values. `--deep` runs through sudo. Network and installs sit behind separate flags (README); not read in full.
- **Adopt:** third-party Homebrew taps and Homebrew hardening settings, unpinned MCP launcher packages, and `ConfigDataInstall` and `CriticalUpdateInstall` (already in `docs/ISSUES.md`).

### Sn0wAlice/macabre

- **What it is:** a read-only hardening audit with a score and a report diff. MIT.
- **How it works:** Rust. Checks are grouped in 10 modules and run through `src/sys.rs`. Output goes to a terminal, JSON, Markdown, HTML, or a live dashboard. `macabre diff old.json new.json` reports regressions by stable check ID and exits non-zero.
- **Tests:** SIP, system extensions, FileVault, firewall (block-all, auto-allow signed, third-party firewalls), Gatekeeper, XProtect, accounts, root account, SSH and `sshd_config`, Screen Sharing, ARD, SMB, printer sharing, Internet Sharing, Remote Apple Events, Content Caching, Wake-on-LAN, listeners, launchd jobs, profiles, update settings, and privacy toggles.
- **Safety:** it reads state (`src/sys.rs:14`). Some checks skip without root (README roadmap). Failing checks print the fix command; nothing runs it. No network calls found.
- **Adopt:** the sharing and firewall keys, and the stable-ID diff that exits on regression. Not the hardening index.

### N4M3Z/check-mac

- **What it is:** a smoke test against drduh's guide, written with Claude Code. EUPL-1.2. It says it is not a compliance gate.
- **How it works:** `check.sh` runs about 27 scripts under `checks/`, each runnable alone. Results are pass, fail, warn, info, unknown, or MDM-managed.
- **Tests:** FileVault, SIP, Gatekeeper, XProtect, software update keys, screen lock, firewall and stealth, remote login, remote management, DNS, Bluetooth, sharing, auto-login, guest, hibernate mode, Wake-on-LAN, Terminal secure keyboard, Siri, analytics, Homebrew, and tool versions.
- **Safety:** reads with `defaults`, `pmset`, `launchctl list`, `networksetup`, `profiles status`. No network calls found. It treats MDM-managed settings as a separate result, which the mSCP review flagged as a gap.
- **Adopt:** `pmset -g` hibernate mode (FileVault key stays in RAM in sleep mode 0), `networksetup -getdnsservers`, and the "managed" result for DDM settings.

### haasonsaas/macos-persist-scan

- **What it is:** a persistence scanner with risk scores. MIT. Last commit 2025-06-03.
- **How it works:** Go. Collectors read launchd, login items, profiles, cron, periodic scripts, and login hooks. Heuristics score each item; output is a table, JSON, or SARIF.
- **Tests:** signature state, path (temp, `/Users/Shared`, hidden folders, a system binary name outside system folders), behavior (`base64`, `curl`, `eval`, a shell with `-c`, `StartInterval` under 60 s, an item younger than 7 days), and name entropy.
- **Safety:** read-only collectors (README). No network calls found.
- **Adopt:** the item age, `StartInterval` and system-name checks. Name entropy has a high false-positive risk.

### zavora-ai/mcp-macos-security

- **What it is:** a read-only MCP server with seven tools for macOS security facts. Apache-2.0, small (one source file).
- **How it works:** Rust. Each tool resolves its path input as data, runs a stock tool through `Command::new` (`src/main.rs:82`), and bounds the output.
- **Tests:** XProtect and Remediator versions, TCC grants, code-signature verification, Gatekeeper and notarization assessment, quarantine attribute decoding, launchd plist and target ownership and modes, and authorized key fingerprints with option names only.
- **Safety:** all tools are declared read-only in `mcp-server.toml`. No network calls found.
- **Adopt:** authorized key option names (`command=`, `from=`) and the quarantine attribute on launchd targets.

### texasbe2trill/macos-trust

- **What it is:** an app and persistence scanner with vendor-aware risk. MIT, 59 tests.
- **How it works:** Python. Collectors run `codesign`, `spctl`, and `xattr` (`macos_trust/collectors/*.py`); a rules file scores each result; baseline mode shows only changes.
- **Tests:** signatures, Gatekeeper assessment, quarantine, launch items, kexts, browser extension permissions, and 24 entitlements.
- **Safety:** read-only, no network calls (README; `grep` found no network code in the collectors).
- **Adopt:** the entitlement list (`entitlements.py:28-45`): `get-task-allow`, `disable-library-validation`, `allow-dyld-environment-variables`, `allow-unsigned-executable-memory`, `no-sandbox`. Expect noise from Electron apps.

### hideouts-io/MacScope

- **What it is:** a posture and vulnerability scanner for Apple silicon that combines native checks, the SOFA feed, osquery, mSCP, Syft, and Grype. Apache-2.0, version 0.1.0-dev.
- **How it works:** Go with a Swift app. It stores raw command output with SHA-256 hashes and writes a JSON scan document and an HTML report.
- **Tests:** about 14 native probes (SIP, FileVault, Gatekeeper, firewall states and block-all, `softwareupdate --schedule`, XProtect against SOFA, PF, Remote Login), plus a subset of mSCP rules and package vulnerabilities.
- **Safety:** it refuses to run as root; `--privileged` runs the same binary through sudo for two fixed probes. It fetches the SOFA feed and expects pinned downloads of Go, osquery, Syft, and Grype (README). I did not download them.
- **Adopt:** nothing new. Its native probes are in macassay already.

### SwordSec/SwordCheck

- **What it is:** a Mac check-up with a score, a dependency vulnerability scan, and a secret scan. AGPL-3.0.
- **How it works:** Rust. Seventeen checks have weights and CIS section links. `--online` adds OSV, NVD, CISA KEV, and EPSS lookups through `curl` (`src/net.rs:50`).
- **Tests:** FileVault, SIP, Gatekeeper, updates, XProtect, firewall, stealth, SSH, sharing, AirDrop, auto-login, guest, screen lock, passwordless sudo (`sudo -n -l`), launch items, and malicious npm packages.
- **Safety:** read-only; offline without `--online` (README). It reads `.env` files for the secret scan and masks values.
- **Adopt:** nothing new. Its secret-file name list (`*.tfstate`, `*.tfvars`, `*.pem`, `credentials.json`) is a low-priority extra.

### Di-kairos/macos-security-audit

- **What it is:** one Bash script with about 55 checks and an HTML report. MIT.
- **How it works:** `macos_security_audit.sh` (855 lines) scores each check and collects fix commands in the report.
- **Tests:** system integrity, firewall, VPN presence, sharing, Bluetooth, saved Wi-Fi networks, privacy toggles, screen lock, password hints, SSH, Find My Mac, launch items, TCC, and battery.
- **Safety:** it starts `sudo -v` and a keep-alive loop (`macos_security_audit.sh:152-154`). It prints fix commands, which the user runs. The README quick start downloads the script from a different GitHub account than this repo's owner; I did not fetch it. The "Sudo Timeout" check always warns (`:572`).
- **Adopt:** only the Find My Mac idea. The script reads it with `nvram -x -p` (`:574`), which dumps all of NVRAM; a single-variable read is the only form macassay could use.

### canerfilibeli/armazi

- **What it is:** a CIS checker as a SwiftUI app and a CLI, with 27 checks in one YAML file. MIT.
- **How it works:** Swift. Each check's audit command runs through `/bin/sh -c` (`ShellExecutor.swift:18-19`).
- **Tests:** about 27 CIS-style items such as automatic login, firewall, and updates.
- **Safety:** the benchmark updater fetches check files from a GitHub repo (`BenchmarkUpdater.swift:22`, `BenchmarkRegistry.swift:142`), so remote text decides which commands run. A self-updater replaces the binary (`SelfUpdater.swift:79-85`).
- **Adopt:** nothing.

### hackerman-jpeg/macOS-13-Automated-CIS-Benchmark

- **What it is:** a 1,771-line script of CIS checks for macOS 13. GPL-3.0. Last commit 2025-06-03.
- **How it works:** one Bash file, `Archive/checks_macOS_13_CIS.sh`, run as root, with a helper folder.
- **Tests:** CIS macOS 13 items, including iCloud Keychain and iCloud Drive settings read with `defaults read MobileMeAccounts` (`:194`, `:215`).
- **Safety:** root is a prerequisite (README). It calls `sudo softwareupdate -l` and `sudo -u USER defaults read` (`:97`, `:194`). It removes only its own temp files.
- **Adopt:** iCloud sync status as an INFO line. The benchmark is for macOS 13.

### alichtman/stronghold

- **What it is:** a wizard that applies security settings. MIT. The README says it targets Sierra and High Sierra.
- **How it works:** Python, installed with pip. It asks about each setting and applies it.
- **Tests:** firewall, logging, stealth, and a few system settings.
- **Safety:** it changes settings and asks for a sudo password (`stronghold.py:108`). The repo holds built archives under `dist/`; I did not open them.
- **Adopt:** nothing.

### jankesec/macharden (deep review)

- **What it is:** a dependency-free macOS hardening audit with 54 weighted checks mapped to CIS, NIST 800-53, and MITRE ATT&CK, a score, and a `--fix` mode. MIT, one maintainer, created 2026-09-12.
- **How it works:** zsh only; `bin/macharden` sources 14 library files and reads JSON data files (`data/compliance_mappings.json`, locales) from disk, and refuses to run from standard input. Markdown, HTML, SARIF, and JSON reports; HTML, SARIF, and `--diff` need python3. Mocked zsh tests with a fake root run in CI.
- **Tests:** hardening 21, network 12, secrets 11, persistence 10. It lacks listener probes, signers, root-daemon writability, accounts, logs, disk, backups, DNS, proxy, certificates, TCC, and `pf`.
- **Safety:** the audit path makes no network calls and writes only its report. It does not refuse root, and its one privileged command (`sudo -n sshd -T`) can resolve `sshd` through `PATH`. As a normal user it cannot read `/etc/sudoers.d`, so it reports no NOPASSWD rules (false negative). `--fix` runs remediation strings with `eval` (`lib/remediate.sh:562`), and some embed file names read from the Mac in double quotes (`lib/audit_persistence.sh:94`), so a crafted LaunchAgent file name runs code when the user applies fixes; a report to the maintainer is drafted. Its NOPASSWD check would fail on every Mac with macassay's rules.
- **Adopt:** BPF device access, IP forwarding, promiscuous interfaces, open Wi-Fi auto-join, core dumps, login keychain lock policy, secrets in shell history, `PATH` hygiene, sudo `timestamp_timeout`, the CIS, NIST, and MITRE IDs, and the rule that missing evidence is INFO, never PASS. Never its `eval` remediation.

### fexxdev/macos_security_audit

- **What it is:** a single Bash CLI (about 3,500 lines, 48 checks) with a letter grade, `--show-fix` text, a baseline diff, and attack-chain correlation. No license file, so no code may be reused.
- **How it works:** Markdown or JSON report; Homebrew formula; CI with a test script. Bash 3.2 compatibility is not claimed.
- **Tests:** system baseline, sharing, Wi-Fi, USB restricted mode, Find My, analytics, mkcert CA, Lockdown Mode, Location Services, Docker, Touch ID, Safari.
- **Safety:** its `CLAUDE.md` bans sudo, `defaults write`, `kill`, and network calls, and every `sudo` match is fix text. `softwareupdate -l` runs only with `--online`. `--redact` masks the serial number.
- **Adopt:** mkcert CA private-key permissions, open Wi-Fi auto-join, USB restricted mode, and the attack-chain correlation idea.

### ianheil/macwatchdog-cli

- **What it is:** a Python auditor with 28 checks, a 0 to 100 score, snapshots with diff, and JSON export. MIT.
- **How it works:** pipx install, a menu, and a test suite. Snapshots go to `~/Library/Application Support/macwatchdog/`.
- **Tests:** persistence, privilege paths, MDM, remote access, profiles, ports, kexts, quarantine.
- **Safety:** management commands change the Mac: they kill processes on ports, edit login items through osascript, quarantine kexts with `rmtree`, and remove profiles with `sudo -n`. No network calls. Commands use argument lists.
- **Adopt:** installers in Downloads without the quarantine attribute, profile payload types (root CA, VPN, SCEP), and a USB device inventory.

### djadmin/fort

- **What it is:** a Go binary with about 15 checks for SOC 2 and ISO 27001 evidence, an HTML report, and a Claude Code plugin. MIT, 82 stars.
- **How it works:** audit, `--fix` with confirmation, `--dry-run`, and `--json`; installed with Homebrew.
- **Tests:** firewall, Gatekeeper, FileVault, auto-login, guest, Remote Login, updates, Touch ID for sudo, password manager, EDR.
- **Safety:** the audit is unprivileged with fixed arguments. `--fix` runs `sudo` and writes `/etc/pam.d/sudo_local`; `--fix --yes` skips the prompt. A daily GET to the GitHub releases API (opt out with `FORT_NO_UPDATE_CHECK`). The report includes the hardware serial number.
- **Adopt:** a check for macOS versions without security updates, and exit codes that reflect the worst severity.

### idlework/security-check

- **What it is:** a small Rust audit CLI with an A+ to F grade and JSON output. MIT.
- **How it works:** fixed-argument commands with a 10-second timeout; optional `sudo` run unlocks more checks.
- **Tests:** SIP, Gatekeeper, FileVault, firewall, XProtect, updates, guest, MDM, screen lock, VPN, DNS.
- **Safety:** read-only; no network beyond `softwareupdate`.
- **Adopt:** configured VPN services (`scutil --nc list`) and per-service DNS servers (`networksetup -getdnsservers`).

### yanis7774/mac-security-audit-skill

- **What it is:** a Claude, Codex, and OpenCode skill that runs a 650-line Bash audit script, written in Russian. MIT, a new hobby repo.
- **How it works:** the skill tells the agent to run the script, read the report, and suggest sudo or Full Disk Access steps; it says not to publish the report.
- **Tests:** persistence, processes, temp folders, quarantine, kexts, `/etc/hosts`, proxies, and tokens in AI-agent session logs.
- **Safety:** the script uses `sudo -n` only when cached and writes its report to `~/Desktop`. A separate tool, `redact-agent-secrets.sh`, rewrites files with `--apply`.
- **Adopt:** inline commands in launch plists, processes running from temp folders with unsigned code, and quarantine data on recent apps.

### fullstacksushil/mac-security-audit

- **What it is:** a Bash audit and hardening script for always-on Mac minis that run AI agents. MIT.
- **How it works:** the README installs it with `curl | sudo bash`; `--fix` changes settings.
- **Tests:** firewall, FileVault, SIP, Ollama, Docker, Tailscale, listeners, LaunchAgents, cron, SSH, updates, `pmset`.
- **Safety:** `--fix` disables Screen Sharing, deletes Docker LaunchDaemons, edits shell startup files with `sed -i`, and sets `pmset autorestart`.
- **Adopt:** Tailscale Funnel and Serve, Docker ports on all interfaces, local AI servers bound to all interfaces, and KeepAlive jobs with user-writable programs.

### rad-security/clawkeeper

- **What it is:** a scanner for hosts that run AI agents (OpenClaw), now archived in favour of AgentKeeper. Apache-2.0.
- **How it works:** Bash checks plus TypeScript, Helm, and Docker parts; installed with `curl | bash`; downloads a `gum` binary.
- **Tests:** 42 checks, about half OpenClaw, Docker, or Linux specific.
- **Safety:** interactive fixes with `sudo`; posts to `clawkeeper.dev` when an API key is set; can install a launch agent.
- **Adopt:** risky command counts in AI-agent transcripts (counts only).

### 6kdave/mac-security

- **What it is:** a workstation deployment toolkit with one audit script. MIT.
- **How it works:** Homebrew capture and restore, dotfiles, deploy scripts, and `security-audit.sh` with Markdown output.
- **Safety:** the audit is read-only; other scripts change the Mac and install Homebrew with `curl | bash`.
- **Adopt:** developer mode (`DevToolsSecurity -status`).

### icdcdev/icdc-macos-audit

- **What it is:** a 2022 port of CIS Level 1 and 2 for macOS 12, with audit and apply scripts. No license.
- **How it works:** needs Homebrew, `blueutil`, and `jq`; installs Homebrew with `curl | bash` when missing.
- **Safety:** apply mode runs many root `defaults write`, `systemsetup`, and `launchctl` commands.
- **Adopt:** at most the authorization database rights for the screensaver unlock and System Settings.

### ivanpsn/mac-security-audit

- **What it is:** a Bash audit and fix script for AI workstations. Treat the repo as unsafe.
- **How it works:** the README's download buttons point to `docs/security-audit-mac-3.9.zip`, which holds Windows files (`unit.exe`, `Application.cmd`). The topics are keyword stuffing.
- **Safety:** do not download the zip. The script claims to change nothing, but `--fix` disables services, edits shell files, deletes Docker LaunchDaemons, and changes permissions.
- **Adopt:** nothing beyond ideas already taken from fullstacksushil.

## Search terms

The scout runs each term with `gh search repos` and records what it found. Add a term when a reviewed repo's topics or README suggest one; drop a term after two runs that find nothing new.

Run on 2026-11-24 with `--updated ">=2025-05-24"` and `--limit 1000`, terms unquoted (the caller found that a quoted phrase returned 0 results from the CLI; I did not retest it). "New repos found" counts the distinct non-fork results of that term that are not tracked or on the caller's skip list, so the counts overlap. Topic runs were `--topic T`; the `security-audit` run also used `--language Shell` and the keyword `macos`, and `cis-benchmark` also used the keyword `macos`. Topic pages on GitHub show repos by topic only, so `macos-security` found many non-audit projects.

| Term | Kind | Source | Last run | New repos found |
| --- | --- | --- | --- | --- |
| `macos security audit` | Query | Seed | 2026-11-24 | 276 |
| `macos hardening` | Query | Seed | 2026-11-24 | 299 |
| `macos security checklist` | Query | Seed | 2026-11-24 | 12 |
| `mac security posture` | Query | Seed | 2026-11-24 | 19 |
| `cis macos benchmark` | Query | Seed | 2026-11-24 | 17 |
| `macos compliance script` | Query | Seed | 2026-11-24 | 12 |
| `macos-security` | Topic | Seed | 2026-11-24 | 55 |
| `macos-hardening` | Topic | Seed | 2026-11-24 | 4 |
| `cis-benchmark` | Topic | Seed | 2026-11-24 | 13 |
| `security-audit` with `language:Shell` | Topic | Seed | 2026-11-24 | 12 |
| `macos auditing security` | Query | User's GitHub web search | 2026-11-24 | 246 |
| `macos audit security` | Query | Caller's variants | 2026-11-24 | 276 |
| `mac security audit` | Query | Caller's variants | 2026-11-24 | 140 |
| `macos-security-audit` | Topic | Caller's variants | 2026-11-24 | 0 |

## Review queue

Candidates that passed the discovery filter but are not reviewed yet, most promising first. Read-only audit tools come first, then tools that also apply settings, then guides. Almost all are young repos with 0 to 2 stars; the "Why" column quotes the repo description, not a review.

| Repo | Last push | Stars | Why it may help | Found by |
| --- | --- | --- | --- | --- |
| [hemp-dev/quietscope](https://github.com/hemp-dev/quietscope) | 2026-05-25 | 4 | Defensive local security audit tool for macOS, Linux, and Windows. Zero telemetry, zero ne | `macos auditing security`, `macos audit security` |
| [namtao/macguard](https://github.com/namtao/macguard) | 2026-11-18 | 1 | Audit and harden macOS from the command line, following drduh's macOS Security and Privacy | `macos auditing security`, `macos audit security` |
| [Dominic-Ferri/mactriage](https://github.com/Dominic-Ferri/mactriage) | 2026-11-24 | 0 | Read-only Mac triage and security audit with an HTML report and a double-click MacSecurity | `macos auditing security`, `macos audit security` |
| [afterdarksys/stigit](https://github.com/afterdarksys/stigit) | 2026-09-02 | 0 | macOS compliance scanner and remediation tool: audits an endpoint against STIG and other s | `macos auditing security`, `macos audit security` |
| [anand1996aditya/MacSec](https://github.com/anand1996aditya/MacSec) | 2026-11-20 | 0 | Deterministic, read-only macOS security and health posture audit | `macos auditing security`, `macos audit security` |
| [bhavyavashisth/macaudit](https://github.com/bhavyavashisth/macaudit) | 2026-05-20 | 2 | A powerful, local-first macOS security audit CLI with an interactive Terminal UI. | `macos auditing security`, `macos audit security` |
| [Nebyular/macos-baseline-auditor](https://github.com/Nebyular/macos-baseline-auditor) | 2026-07-04 | 0 | SwiftUI macOS hardening posture auditor mapped to Five Eyes guidance. | `macos hardening` |
| [star7js/macos-fingerprint](https://github.com/star7js/macos-fingerprint) | 2026-07-24 | 2 | macOS config drift & tamper detection with CIS benchmark auditing | `macos auditing security`, `macos audit security` |
| [boberito/mscp_scripts](https://github.com/boberito/mscp_scripts) | 2026-11-21 | 22 | Scripts to use with the macOS Security Compliance Project | `macos compliance script` |
| [TPOALOS/hostguard](https://github.com/TPOALOS/hostguard) | 2026-11-14 | 0 | Read-only hardening auditor for Linux and macOS: 76 checks, score, HTML report, drift dete | `macos hardening`, `cis-benchmark (topic)` |
| [IAmLegionVaal/macOS-Gatekeeper-SIP-and-XProtect-Auditor](https://github.com/IAmLegionVaal/macOS-Gatekeeper-SIP-and-XProtect-Auditor) | 2026-06-21 | 0 | Read-only macOS security toolkit for auditing Gatekeeper, SIP, XProtect, MRT, notarisation | `macos auditing security`, `macos audit security` |
| [thatswhatworks/hardenmac-scan](https://github.com/thatswhatworks/hardenmac-scan) | 2026-07-24 | 1 | Read-only scanner that checks a Mac for AMOS / Atomic / SHAMOS infostealer indicators, la | `macos-security (topic)` |
| [Dominic-Ferri/JamfSecurityAudit](https://github.com/Dominic-Ferri/JamfSecurityAudit) | 2026-11-09 | 0 | Read-only security audit of a Jamf-managed Mac: double-click app, 30 checks, private HTML  | `macos auditing security`, `macos audit security` |
| [Kristofers/little-brother](https://github.com/Kristofers/little-brother) | 2026-06-28 | 0 | Read-only security-and-privacy audit of an Intune/MDM-managed macOS machine: what's protec | `macos auditing security`, `macos audit security` |
| [vipulgupta2048/mac-security-audit](https://github.com/vipulgupta2048/mac-security-audit) | 2026-10-22 | 1 | Read-only macOS security audit skill for Claude Code: posture, persistence, credentials, e | `macos auditing security`, `macos audit security` |
| [flombois/mac-security-audit](https://github.com/flombois/mac-security-audit) | 2026-10-14 | 0 | Read-only security audit for a macOS development workstation | `macos auditing security`, `macos audit security` |
| [marlyngiselle/macos-security-audit](https://github.com/marlyngiselle/macos-security-audit) | 2026-11-23 | 0 | Read-only macOS security audit: 35 checks, privacy-safe reports and SARIF output for GitHu | `macos auditing security`, `macos audit security` |
| [Worldtraveler247/macos-hardening-audit](https://github.com/Worldtraveler247/macos-hardening-audit) | 2026-11-05 | 0 | Read-only macOS security audit script, checks firewall, FileVault, SIP, Gatekeeper, and m | `macos auditing security`, `macos audit security` |
| [ponzofonzo/macos-security-audit](https://github.com/ponzofonzo/macos-security-audit) | 2026-11-05 | 0 | Read-only macOS security audit (FileVault, SIP, Gatekeeper, firewall, access control) with | `macos auditing security`, `macos audit security` |
| [titomazzetta/neptune-mac](https://github.com/titomazzetta/neptune-mac) | 2026-11-11 | 0 | Read-only macOS security audit and cleanup toolkit: posture, persistence, network, bloat,  | `macos auditing security`, `macos audit security` |
| [dilrajsooch/securemac](https://github.com/dilrajsooch/securemac) | 2026-08-14 | 0 | A read-only macOS security posture checker. Audits 15 endpoint controls and explains every | `macos auditing security`, `macos audit security` |
| [umbraaeternaa/macbastion](https://github.com/umbraaeternaa/macbastion) | 2026-10-06 | 1 | Defensive security audit tool for macOS | `macos auditing security`, `macos audit security` |
| [camilocbarrera/skill-molt](https://github.com/camilocbarrera/skill-molt) | 2026-08-30 | 0 | Audit a Mac for compromise and unwanted monitoring, then shed the dead software it accumul | `macos auditing security`, `macos audit security` |
| [ejkaz/claude-mac-security](https://github.com/ejkaz/claude-mac-security) | 2026-11-24 | 0 | Open-source, read-only macOS security harness as a Claude Code plugin, scan, egress firew | `macos auditing security`, `macos audit security` |
| [brianharms/skill-security-audit](https://github.com/brianharms/skill-security-audit) | 2026-11-13 | 0 | Claude Code skill that scans a macOS development system for security issues and diffs agai | `macos audit security`, `macos security audit` |
| [shorconsulting/security-audit](https://github.com/shorconsulting/security-audit) | 2026-11-14 | 0 | Claude Code plugin: weekly security audit of the Mac, SSH keys, repos, GitHub orgs, server | `mac security audit` |
| [b0dea/fortkeep](https://github.com/b0dea/fortkeep) | 2026-11-21 | 1 | A security checkup for developer Macs, run through your coding agent | `macos hardening` |
| [ShanedixonGit/macverify](https://github.com/ShanedixonGit/macverify) | 2026-09-26 | 1 | For the Devs. Point-in-time, read-only audit of your Mac and its AI assistant config. Offl | `macos auditing security`, `macos audit security` |
| [bartek-filipiuk/ai-agent-audit](https://github.com/bartek-filipiuk/ai-agent-audit) | 2026-10-12 | 4 | Read-only audit of a developer machine for what AI coding agents and malicious packages ca | `macos auditing security`, `macos audit security` |
| [HarmonicSecurity/claudit-sec](https://github.com/HarmonicSecurity/claudit-sec) | 2026-05-12 | 305 | Security audit tool for Claude Desktop and Claude Code on macOS, single-command visibilit | `macos auditing security`, `macos audit security` |
| [saumyatech01-spec/MacSentry](https://github.com/saumyatech01-spec/MacSentry) | 2026-03-28 | 0 | Production-grade macOS Security Scanner, 10-step read-only security audit for Apple Silic | `macos auditing security`, `macos audit security` |
| [samsadrashid/sentinel-audit](https://github.com/samsadrashid/sentinel-audit) | 2026-11-15 | 0 | Local, sandboxed security audit engine for macOS. Not release-ready: no signed release yet | `macos auditing security`, `macos audit security` |
| [stunwill/mac-security-audit](https://github.com/stunwill/mac-security-audit) | 2026-08-13 | 0 | A comprehensive macOS security auditing and privacy monitoring tool that detects permissio | `macos auditing security`, `macos audit security` |
| [Mihai-Go/Security-Audit-tool](https://github.com/Mihai-Go/Security-Audit-tool) | 2026-02-17 | 0 | macOS security audit tool - automated security compliance checking | `macos auditing security`, `macos audit security` |
| [VioletSoul/macos_security_audit](https://github.com/VioletSoul/macos_security_audit) | 2026-07-23 | 0 | macOS Security Audit Toolkit, a lightweight Bash utility for checking system integrity, F | `macos auditing security`, `macos audit security` |
| [joedular/mac_security_audit](https://github.com/joedular/mac_security_audit) | 2026-08-12 | 0 | Un script de bash ligero e integral diseñado para auditar la seguridad, detectar elementos | `macos audit security`, `macos security audit` |
| [pTechPL/macOS_security_audit](https://github.com/pTechPL/macOS_security_audit) | 2026-06-18 | 6 | macOS script for auditing | `macos auditing security`, `macos audit security` |
| [namuan/security-check](https://github.com/namuan/security-check) | 2026-04-19 | 0 | A macOS security audit CLI tool that checks your system configuration for common security  | `macos auditing security`, `macos audit security` |
| [pipedalvia21-boop/macos-security-auditor](https://github.com/pipedalvia21-boop/macos-security-auditor) | 2026-04-21 | 0 | Python tool that audits macOS security configuration | `macos auditing security`, `macos audit security` |
| [aharon-sudo/macos-security-scanner](https://github.com/aharon-sudo/macos-security-scanner) | 2026-10-14 | 0 | A CIS Apple macOS Benchmark-inspired security compliance scanner. Checks SIP, Gatekeeper,  | `cis macos benchmark`, `cis-benchmark (topic)` |
| [Itstwisha/complianceguard](https://github.com/Itstwisha/complianceguard) | 2026-01-12 | 0 | Automated Security Compliance Scanner for macOS - CIS Benchmarks & Security Best Practices | `cis macos benchmark` |
| [TerranceDessaure/macaudit](https://github.com/TerranceDessaure/macaudit) | 2026-10-18 | 0 | Zsh tool that audits 14 macOS security settings (FileVault, firewall, Gatekeeper, SIP, upd | `macos auditing security`, `macos audit security` |
| [ulasb/macaudit](https://github.com/ulasb/macaudit) | 2026-07-21 | 0 | Read-only Mac audit: reclaimable disk space, security posture, and improvement suggestions | `mac security audit`, `mac security posture` |
| [HerrStolzier/local-security-twin](https://github.com/HerrStolzier/local-security-twin) | 2026-08-17 | 0 | Local-first macOS security companion for normal users, combining privacy, hardening, and c | `macos hardening` |
| [XexusCode/hardenme](https://github.com/XexusCode/hardenme) | 2026-11-14 | 0 | Check your Mac's security in plain language: a score weighted by how you use it, step-by-s | `macos hardening` |
| [lu-zhengda/macdog](https://github.com/lu-zhengda/macdog) | 2026-02-21 | 0 | macOS security & privacy suite, audit your security posture, manage firewall rules, and h | `macos auditing security`, `macos audit security` |
| [dyntr/Sentinel](https://github.com/dyntr/Sentinel) | 2026-07-13 | 0 | Native macOS security auditor, hardening checks, malware scan & real-time guard. | `macos hardening` |
| [Sergeyshall/MacScan](https://github.com/Sergeyshall/MacScan) | 2026-10-25 | 0 | A native macOS app that audits your Mac's security, performance, storage and apps, and fix | `macos auditing security`, `macos audit security` |
| [ajinkyalahade/Vigil](https://github.com/ajinkyalahade/Vigil) | 2026-03-09 | 0 | ⏺ Vigil, Local-first macOS security dashboard. Scans system hardening, SSH hygiene, open  | `macos hardening` |
| [bacescuandrei/macos-inspector](https://github.com/bacescuandrei/macos-inspector) | 2026-10-25 | 1 | Local-first macOS security and DFIR inspection with guided audits, application trust, guar | `macos auditing security`, `macos audit security` |
| [Sets/macos-startup-security-scanner](https://github.com/Sets/macos-startup-security-scanner) | 2025-06-19 | 1 | This script performs a security audit of your macOS system by analyzing applications, agen | `macos auditing security`, `macos audit security` |
| [Trench-Sec/MacOSHardening](https://github.com/Trench-Sec/MacOSHardening) | 2026-03-25 | 1 | A collection of shell scripts for detecting existing security configurations and for harde | `macos hardening` |
| [krishnasureshcpa/BooBoo](https://github.com/krishnasureshcpa/BooBoo) | 2026-07-02 | 1 | BooBoo, macOS security auditing and remediation. CIS Level 1 compliance scanner with a ch | `macos auditing security`, `macos audit security` |
| [akshaymahaldar/macos-cis-benchmark-hardening](https://github.com/akshaymahaldar/macos-cis-benchmark-hardening) | 2026-05-02 | 2 | macOS CIS Benchmark security audit script, checks 12 Level 1 controls including FileVault | `macos auditing security`, `macos audit security` |
| [ocapraro/cis-benchmark-macos-audit](https://github.com/ocapraro/cis-benchmark-macos-audit) | 2025-12-03 | 0 | macOS Security Auditing Software | `macos auditing security`, `macos audit security` |
| [o0MattE0o/MacOS15CISL1](https://github.com/o0MattE0o/MacOS15CISL1) | 2025-05-29 | 0 | CIS Apple macOS 15.0 Sequoia Benchmark v1.0.0 | `cis macos benchmark` |
| [piekstra/mac-secure](https://github.com/piekstra/mac-secure) | 2026-11-24 | 0 | Keep a Mac updated without waiting for a click, and audit its security settings. CLI plus  | `macos auditing security`, `macos audit security` |
| [MuniraCyber/security-audit-tool](https://github.com/MuniraCyber/security-audit-tool) | 2026-06-28 | 1 | Python security audit tool for macOS - system info & port scanner | `macos auditing security`, `macos audit security` |
| [BlockSiFr/verified-trust-local.0.0.0.1](https://github.com/BlockSiFr/verified-trust-local.0.0.0.1) | 2026-05-11 | 2 | A modular, security-hardened macOS scanner that audits local and daemon accounts across ef | `macos auditing security`, `macos audit security` |
| [CAUCOLabs/aisosec-audit](https://github.com/CAUCOLabs/aisosec-audit) | 2026-07-10 | 1 | AisoSec Audit is a macOS-friendly security assessment and reporting tool focused on author | `macos auditing security`, `macos audit security` |
| [Runpoint-Partners/personal-security-audit](https://github.com/Runpoint-Partners/personal-security-audit) | 2026-07-17 | 0 | Private automated personal security audit for macOS | `macos auditing security`, `macos audit security` |
| [krewdev/privacy-kit](https://github.com/krewdev/privacy-kit) | 2026-07-09 | 0 | Local macOS privacy audits, permissions, trackers, tunnels, listeners, MDM | `macos auditing security`, `macos audit security` |
| [LunaParker/macos-permission-report](https://github.com/LunaParker/macos-permission-report) | 2026-11-21 | 0 | Python tool that audits macOS TCC privacy permissions, flags ghost entries from uninstalle | `macos auditing security`, `macos audit security` |
| [diskyer2025-rgb/macos-security-audit](https://github.com/diskyer2025-rgb/macos-security-audit) | 2026-08-09 | 0 | 对 macOS 本机做只读安全审计与卸载残留核验（进程、端口、启动项、代理、证书、Keychain、包残留、skills 接管路径），并对 skill 包做安装前/安装后静态安全扫 | `macos auditing security`, `macos audit security` |
| [carringtonabarnes-lab/security-compliance-checker](https://github.com/carringtonabarnes-lab/security-compliance-checker) | 2026-07-28 | 0 | Python application that audits macOS security settings by checking FileVault, Firewall, an | `macos auditing security`, `macos audit security` |
| [cancelself/local-security-agent](https://github.com/cancelself/local-security-agent) | 2026-07-15 | 0 | Claude Code agent that audits a macOS machine phase-by-phase; phase 1: startup agents/serv | `macos auditing security`, `macos audit security` |
| [HarisK-0111/macos-hardening-audit](https://github.com/HarisK-0111/macos-hardening-audit) | 2026-10-25 | 1 | Local-first macOS authentication audit prototype in C#/.NET 10 with Unified Logging parsin | `macos hardening` |
| [ayinedjimi/MacSecCheck](https://github.com/ayinedjimi/MacSecCheck) | 2026-07-25 | 1 | 🍎 Auditeur de posture de sécurité macOS (Sonoma/Tahoe) piloté par les baselines NIST mSCP  | `macos audit security`, `macos security audit` |
| [brandonstevens-sec-dev/MacOS-Security-Audit](https://github.com/brandonstevens-sec-dev/MacOS-Security-Audit) | 2026-02-11 | 1 | No description | `macos audit security`, `macos security audit` |
| [jenna-mccarthy/mac-security-audit](https://github.com/jenna-mccarthy/mac-security-audit) | 2026-04-24 | 1 | No description | `mac security audit` |
| [shamith-shankar/mac-security-audit](https://github.com/shamith-shankar/mac-security-audit) | 2026-05-06 | 0 | No description | `mac security audit` |
| [BurroClurse/mac-security-audit](https://github.com/BurroClurse/mac-security-audit) | 2026-04-21 | 1 | Mac mini M4 security audit tools, run on demand via Claude plus a manual checks script | `mac security audit` |
| [gfreedman/mac_audit](https://github.com/gfreedman/mac_audit) | 2026-09-26 | 0 | Mac System Health Inspector & Auditor, narrated, educational, beautiful. 69 checks across | `macos audit security`, `macos security audit` |
| [sebastianspicker/rootstock-macos](https://github.com/sebastianspicker/rootstock-macos) | 2026-11-21 | 4 | macOS security analysis: local collection, modeled attack paths, scoped CVE scans, and off | `macos-security (topic)` |
| [Yukino-Akane/BMA](https://github.com/Yukino-Akane/BMA) | 2026-09-27 | 0 | Behavior Monitoring and Audit - macOS security auditing for AI agent file and network acti | `macos auditing security`, `macos audit security` |
| [davidtkeane/macos-security-audit](https://github.com/davidtkeane/macos-security-audit) | 2026-02-19 | 0 | Security audit toolkit for macOS apps, source code, binary, and network testing using bui | `macos auditing security`, `macos audit security` |
| [evanderweb3-a11y/homeguard](https://github.com/evanderweb3-a11y/homeguard) | 2026-11-16 | 0 | Defensive personal/home security self-audit: macOS baseline, LAN weak-service checks, depe | `macos auditing security`, `macos audit security` |
| [3n1gm496/security-baseline-auditor](https://github.com/3n1gm496/security-baseline-auditor) | 2026-03-10 | 0 | Defensive, read-only local security audit tool for Linux, macOS and Windows | `macos auditing security`, `macos audit security` |
| [rtulke/checkmate](https://github.com/rtulke/checkmate) | 2026-11-22 | 1 | Compliance checks as commands: YAML-defined, command-based checks for Linux, macOS, Window | `macos audit security`, `macos security audit` |
| [Klau5t4ler0x90/MacOS_Audit](https://github.com/Klau5t4ler0x90/MacOS_Audit) | 2025-07-02 | 0 | A security audit tool for macOS/Linux to check for vulnerabilities, misconfigurations, and | `macos auditing security`, `macos audit security` |
| [macokay/Mac_Security_Audit](https://github.com/macokay/Mac_Security_Audit) | 2026-08-10 | 1 | macOS endpoint security audit tool generating HTML compliance reports with risk ratings. | `macos auditing security`, `macos audit security` |
| [lkolo-prez/secure-scan](https://github.com/lkolo-prez/secure-scan) | 2026-11-23 | 0 | Lekki audyt bezpieczeństwa macOS, Security Score 0-100 + dashboard HTML. 20 kontroli, rea | `macos hardening`, `security-audit (topic)` |
| [GunnarMUC/security-vulnerability-auto-check](https://github.com/GunnarMUC/security-vulnerability-auto-check) | 2026-08-04 | 0 | macOS system-wide security audit tool. Scans Homebrew, pip, npm, Ruby gems for outdated pa | `macos auditing security`, `macos audit security` |
| [TokyoDuck/trojanshield-macos](https://github.com/TokyoDuck/trojanshield-macos) | 2026-11-22 | 0 | TrojanShield 2.0: experimental macOS Terminal security toolkit with optional ClamAV scanni | `macos auditing security`, `macos audit security` |
| [abhaymettu/ssh-posture](https://github.com/abhaymettu/ssh-posture) | 2026-11-24 | 0 | Check and tighten SSH on a Mac or Linux box you host yourself, including the ones your cod | `mac security posture` |
| [dallison001/claude-security-audit](https://github.com/dallison001/claude-security-audit) | 2026-02-08 | 0 | Claude skill: 16-point macOS security audit for MCP/skills supply chain threats | `macos auditing security`, `macos audit security` |
| [focuslight-nr/claude-audit](https://github.com/focuslight-nr/claude-audit) | 2026-08-21 | 0 | Unofficial read-only local security audit tool for claude on macOS | `macos auditing security`, `macos audit security` |
| [Valicen/cenlogic-mac_privacy_reset](https://github.com/Valicen/cenlogic-mac_privacy_reset) | 2026-08-10 | 0 | Audit and clear stale macOS Privacy & Security (TCC) grants left behind by uninstalled app | `macos auditing security`, `macos audit security` |
| [cch1rag/Clearance](https://github.com/cch1rag/Clearance) | 2026-07-01 | 2 | Local-first macOS TCC.db editor for auditing and editing app privacy permissions. | `macos auditing security`, `macos audit security` |
| [cryptosecco/vulnwatch](https://github.com/cryptosecco/vulnwatch) | 2026-11-05 | 4 | Daily vulnerability check for macOS that never tells anyone what you run: public feeds mat | `macos hardening` |
| [kdaillo/SystemWatch](https://github.com/kdaillo/SystemWatch) | 2026-03-30 | 0 | Real-time macOS security scanner, audits login sessions, network connections, processes,  | `macos auditing security`, `macos audit security` |
| [JagsZ/portcullis](https://github.com/JagsZ/portcullis) | 2026-07-04 | 0 | One-command security self-audit for Linux & macOS: find open ports, firewall gaps & unencr | `macos auditing security`, `macos audit security` |
| [cluster2600/ALBATOR](https://github.com/cluster2600/ALBATOR) | 2026-10-19 | 25 | A series of scripts to harden macOS 26.x (Tahoe) | `macos hardening` |
| [guillermolam/macos-harden](https://github.com/guillermolam/macos-harden) | 2026-05-31 | 0 | Declarative, idempotent macOS 26 Tahoe (arm64) hardening tool, 75 controls across 12 secu | `macos hardening` |
| [amudijog-eng/macos-hardening-framework](https://github.com/amudijog-eng/macos-hardening-framework) | 2026-09-04 | 0 | 🍏 Automated CIS Benchmark & NIST SP 800-219 Security Hardening Suite for macOS (Ventura/So | `macos hardening`, `cis macos benchmark` |
| [juju4/ansible-harden-darwin](https://github.com/juju4/ansible-harden-darwin) | 2026-10-24 | 9 | Ansible role to harden darwin/macos system | `macos hardening` |
| [StrangeRanger/macos-security-scripts](https://github.com/StrangeRanger/macos-security-scripts) | 2026-09-22 | 7 | A collection of scripts designed to secure/harden macOS | `macos hardening` |
| [katvio/macos-hardening](https://github.com/katvio/macos-hardening) | 2026-04-14 | 1 | security hardening toolkit for macOS built for developers with long-lived daily-driver Mac | `macos hardening` |
| [cjb00/macos-lockdown](https://github.com/cjb00/macos-lockdown) | 2026-03-16 | 1 | A shell script that applies security hardening settings to macOS. No dependencies - just b | `macos hardening` |
| [Epsilon0xCell/MacOS-Hardening](https://github.com/Epsilon0xCell/MacOS-Hardening) | 2026-11-07 | 1 | This is a macOS hardening to read or set security configuration. | `macos hardening` |
| [Epsilon0xCell/MacOS-Hardening-Toolkit](https://github.com/Epsilon0xCell/MacOS-Hardening-Toolkit) | 2026-11-07 | 1 | Harden MacOS Security/Privacy without security tradeoff | `macos hardening` |
| [Epsilon0xCell/MacOS-Security](https://github.com/Epsilon0xCell/MacOS-Security) | 2026-11-07 | 1 | Shell scripts and settings that harden macOS security and privacy. | `macos hardening` |
| [neolaf2/mac_harden](https://github.com/neolaf2/mac_harden) | 2026-01-30 | 1 | macOS security hardening scripts | `macos hardening` |
| [mcps976/macos-security-hardening](https://github.com/mcps976/macos-security-hardening) | 2026-11-22 | 0 | No description | `macos hardening` |
| [Zombiebbb8/macos-security-hardening](https://github.com/Zombiebbb8/macos-security-hardening) | 2026-03-26 | 0 | Full macOS security audit using Lynis & rkhunter. 15 remediation actions, SSH hardening, a | `macos auditing security`, `macos audit security` |
| [sakisan6/NukeOSX](https://github.com/sakisan6/NukeOSX) | 2025-12-23 | 0 | A low-noise macOS hardening script that reduces background activity, telemetry, and unboun | `macos hardening` |
| [abdulhamza510/mac-security-automation](https://github.com/abdulhamza510/mac-security-automation) | 2025-12-10 | 0 | A macOS security hardening and automation toolkit that performs encryption checks, firewal | `macos auditing security`, `macos audit security` |
| [chrisvrakas/sovereign-mac](https://github.com/chrisvrakas/sovereign-mac) | 2026-09-04 | 8 | macOS privacy & security toolkit, Don't trust Apple. Verify. YOUR machine, YOUR rules. | `macos hardening`, `macos-security (topic)` |
| [thomasryan0317-cell/macos-hardening-baseline](https://github.com/thomasryan0317-cell/macos-hardening-baseline) | 2026-08-14 | 1 | Baseline → remediate → verify hardening of my macOS daily driver, Lynis audit, CIS guidan | `macos hardening`, `cis-benchmark (topic)` |
| [TrifoldPathSec/deliverance-macos-cis](https://github.com/TrifoldPathSec/deliverance-macos-cis) | 2026-10-14 | 0 | Hardening macOS 26 Tahoe from 62% to 100% on the CIS Benchmark, measured and verified with | `macos hardening`, `cis macos benchmark` |
| [cwasdf/macscripts](https://github.com/cwasdf/macscripts) | 2026-05-16 | 0 | MacOS hardening scripts | `macos hardening` |
| [VladimirKozin/macos-security-hardening](https://github.com/VladimirKozin/macos-security-hardening) | 2026-02-05 | 0 | No description | `macos hardening` |
| [rgregory/claus](https://github.com/rgregory/claus) | 2026-11-12 | 0 | Santa front-end for hardening MacOS. | `macos hardening` |
| [beerisgood/macOS_Hardening](https://github.com/beerisgood/macOS_Hardening) | 2026-11-09 | 198 | a collection about macOS | `macos hardening` |
| [woodbloom/Mac-hardening-guide](https://github.com/woodbloom/Mac-hardening-guide) | 2026-06-17 | 1 | macOS hardening - FileVault, SIP, Little Snitch, iCloud audit, privacy settings | `macos hardening` |

## Rejected without review

Repos the scout found and skipped, so later runs do not reconsider them. Reasons come from each repo's name and description, not from reading it, so a few may be misjudged.

| Repo | Reason | Date |
| --- | --- | --- |
| [jtesta/ssh-audit](https://github.com/jtesta/ssh-audit) | Audits remote SSH servers over the network; not a macOS host audit | 2026-11-24 |
| [cirosantilli/china-dictatorship](https://github.com/cirosantilli/china-dictatorship) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [gege-circle/.github](https://github.com/gege-circle/.github) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [janreges/siteone-crawler](https://github.com/janreges/siteone-crawler) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ChaoticSi1ence/SlimBrave-Neo](https://github.com/ChaoticSi1ence/SlimBrave-Neo) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [dweep-desai/FaceGate-Mac](https://github.com/dweep-desai/FaceGate-Mac) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sdrapkin/SecurityDriven.Inferno](https://github.com/sdrapkin/SecurityDriven.Inferno) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [thakur2309/PEGASUS-PRO](https://github.com/thakur2309/PEGASUS-PRO) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [cirosantilli/china-dictatroship-7](https://github.com/cirosantilli/china-dictatroship-7) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [cordwainersmith/Claudoscope](https://github.com/cordwainersmith/Claudoscope) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [crasowas/app_privacy_manifest_fixer](https://github.com/crasowas/app_privacy_manifest_fixer) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [makalin/CornerFix](https://github.com/makalin/CornerFix) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [mRFWq7LwNPZjaVv5v6eo/cihna-dictattorshrip-8](https://github.com/mRFWq7LwNPZjaVv5v6eo/cihna-dictattorshrip-8) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [dutkiewiczmaciej/MakLock](https://github.com/dutkiewiczmaciej/MakLock) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [thousandflowers/Raccoon](https://github.com/thousandflowers/Raccoon) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [clearframes/mcp-observatory](https://github.com/clearframes/mcp-observatory) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Adversis/mcp-snitch](https://github.com/Adversis/mcp-snitch) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [amanaiproduct/openclaw-setup](https://github.com/amanaiproduct/openclaw-setup) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [backslash-security/Claw-Hunter](https://github.com/backslash-security/Claw-Hunter) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [aashish254/agentvault](https://github.com/aashish254/agentvault) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [juliensimon/cache-commander](https://github.com/juliensimon/cache-commander) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [cn0xroot/CC-Monitor](https://github.com/cn0xroot/CC-Monitor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Turtlecute33/Debloat.net](https://github.com/Turtlecute33/Debloat.net) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [7wdn/7shell](https://github.com/7wdn/7shell) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Opsek/OSs-security](https://github.com/Opsek/OSs-security) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [zheltukheen/lanfi](https://github.com/zheltukheen/lanfi) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [EhsanAzish80/Nick](https://github.com/EhsanAzish80/Nick) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [sebastienrousseau/dotfiles.github.io](https://github.com/sebastienrousseau/dotfiles.github.io) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [RockxyApp/Shieldxy](https://github.com/RockxyApp/Shieldxy) | Network tool, not a host audit | 2026-11-24 |
| [huntsman11177/secure_dokploy_local](https://github.com/huntsman11177/secure_dokploy_local) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [lyq1996/X-Monitor](https://github.com/lyq1996/X-Monitor) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [SingLinkLabs/SingLinkVPN](https://github.com/SingLinkLabs/SingLinkVPN) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [vincentkoc/autosecure](https://github.com/vincentkoc/autosecure) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [JulyIghor/AppTrustPreview](https://github.com/JulyIghor/AppTrustPreview) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Wonderfall/torrent7](https://github.com/Wonderfall/torrent7) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [anthonyonazure/privacy-sweep](https://github.com/anthonyonazure/privacy-sweep) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [darmado/attack-macOS](https://github.com/darmado/attack-macOS) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [getintogit1/ScanMyNet](https://github.com/getintogit1/ScanMyNet) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [vietanhdev/bulwark](https://github.com/vietanhdev/bulwark) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Dexel-Software-Solutions/CyberForge](https://github.com/Dexel-Software-Solutions/CyberForge) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [nexlabz/snare](https://github.com/nexlabz/snare) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [redinpulse/CVE-2026-84568](https://github.com/redinpulse/CVE-2026-84568) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Roadmvn/C-Full-Offensive-Course](https://github.com/Roadmvn/C-Full-Offensive-Course) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [evilboyajay/proxyaudit](https://github.com/evilboyajay/proxyaudit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [kotique123/FnKeyboard](https://github.com/kotique123/FnKeyboard) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [eriknewton/sanctuary-framework](https://github.com/eriknewton/sanctuary-framework) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [sebastienrousseau/maccfg](https://github.com/sebastienrousseau/maccfg) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Accademia/Anti-FBI-Win11-Security-Hardening](https://github.com/Accademia/Anti-FBI-Win11-Security-Hardening) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ProjectZeroDays/Pegasus_Phantom-Menace](https://github.com/ProjectZeroDays/Pegasus_Phantom-Menace) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [0xsyr0/Audit-Checklists](https://github.com/0xsyr0/Audit-Checklists) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [AndyShaman/vps-setup-skill](https://github.com/AndyShaman/vps-setup-skill) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Azure/ConfigForge](https://github.com/Azure/ConfigForge) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sethwebster/dotfiles](https://github.com/sethwebster/dotfiles) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [DesusLove/Keylogger-Keystroke-Surveillance-Technology](https://github.com/DesusLove/Keylogger-Keystroke-Surveillance-Technology) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [I4cTime/q-ring](https://github.com/I4cTime/q-ring) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ippitenin/EDEX-macOS](https://github.com/ippitenin/EDEX-macOS) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [jozeta/EndpointPostureCheck](https://github.com/jozeta/EndpointPostureCheck) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [paulo-amaral/dockup](https://github.com/paulo-amaral/dockup) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [rick-rami94/spinarr](https://github.com/rick-rami94/spinarr) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [thekondor/mycryptfs](https://github.com/thekondor/mycryptfs) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Hamza01541/PolinRider-Shield](https://github.com/Hamza01541/PolinRider-Shield) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [SalvatoreNoschese/wp-check.sh](https://github.com/SalvatoreNoschese/wp-check.sh) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Sanjay-Program/ZENTRION-TERMINAL](https://github.com/Sanjay-Program/ZENTRION-TERMINAL) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [balyakin/codex-docker-sandbox](https://github.com/balyakin/codex-docker-sandbox) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [doug445/AsahiLocker](https://github.com/doug445/AsahiLocker) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [edojapatricia/SecureBuildGen](https://github.com/edojapatricia/SecureBuildGen) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [elonmasai7/macOS_Keylogger_Suite](https://github.com/elonmasai7/macOS_Keylogger_Suite) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [kaosagnt/useful-utilities](https://github.com/kaosagnt/useful-utilities) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [DzA-sec/macos-pf-wireguard-hardened](https://github.com/DzA-sec/macos-pf-wireguard-hardened) | Network tool, not a host audit | 2026-11-24 |
| [andrd3v/tfp_and_pft_detect](https://github.com/andrd3v/tfp_and_pft_detect) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [deepakvamsi/kosh](https://github.com/deepakvamsi/kosh) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [drbarq/macrelay](https://github.com/drbarq/macrelay) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [gorkemguler/tinfoil](https://github.com/gorkemguler/tinfoil) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [hackingpal/hackingpal](https://github.com/hackingpal/hackingpal) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [neohiro/Cripple-NetStrip](https://github.com/neohiro/Cripple-NetStrip) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sfs016/rimote-mac](https://github.com/sfs016/rimote-mac) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [traylorre/openclaw-mac](https://github.com/traylorre/openclaw-mac) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [5byuri/sudoers-hosts-guard](https://github.com/5byuri/sudoers-hosts-guard) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [BaumerCrypto/digidollar-oracle-tools](https://github.com/BaumerCrypto/digidollar-oracle-tools) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [BeeEvolved/Bitcoin-UI](https://github.com/BeeEvolved/Bitcoin-UI) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [OpenMacaw/OpenMacaw](https://github.com/OpenMacaw/OpenMacaw) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Raunaksplanet/Thick-Client-Pentesting-On-MacOS](https://github.com/Raunaksplanet/Thick-Client-Pentesting-On-MacOS) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Secure-Pride/secure-pride](https://github.com/Secure-Pride/secure-pride) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [SecureBitChat/securebit-desktop](https://github.com/SecureBitChat/securebit-desktop) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [SirsiMaster/sirsi-pantheon](https://github.com/SirsiMaster/sirsi-pantheon) | Network tool, not a host audit | 2026-11-24 |
| [at0m-b0mb/MacRecon](https://github.com/at0m-b0mb/MacRecon) | Network tool, not a host audit | 2026-11-24 |
| [chrisstampar/venice-ai-tui](https://github.com/chrisstampar/venice-ai-tui) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [cypr0/mac-bootstrap](https://github.com/cypr0/mac-bootstrap) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [errantpacket/RhubarbTart](https://github.com/errantpacket/RhubarbTart) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [everythings-gonna-be-alright/Hostwatch](https://github.com/everythings-gonna-be-alright/Hostwatch) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [felipeolifre/dotfiles](https://github.com/felipeolifre/dotfiles) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [logiqum/luna](https://github.com/logiqum/luna) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [lokan/YouTube-Auto-Upload-for-Mac](https://github.com/lokan/YouTube-Auto-Upload-for-Mac) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ranjithrajv/MachO-explorer](https://github.com/ranjithrajv/MachO-explorer) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [redeyessssss/timetrap](https://github.com/redeyessssss/timetrap) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [rynl3571/Vault-Session](https://github.com/rynl3571/Vault-Session) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [smartwatermelon/mac-server-setup](https://github.com/smartwatermelon/mac-server-setup) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [vkend/briefcred](https://github.com/vkend/briefcred) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [wandersick/tcrypt2go](https://github.com/wandersick/tcrypt2go) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Bergetarbitral1818/macchk](https://github.com/Bergetarbitral1818/macchk) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [HumairAli26/SecureAudit](https://github.com/HumairAli26/SecureAudit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Jeremy-Burgos/macos-privacy-hardening](https://github.com/Jeremy-Burgos/macos-privacy-hardening) | Network tool, not a host audit | 2026-11-24 |
| [RXVEN-1907/compid](https://github.com/RXVEN-1907/compid) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Vassbrekke/PrivGuide](https://github.com/Vassbrekke/PrivGuide) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [VioletScar-Hui/cc-tackle](https://github.com/VioletScar-Hui/cc-tackle) | Network tool, not a host audit | 2026-11-24 |
| [Ziad-cp/Dlr](https://github.com/Ziad-cp/Dlr) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [aleksibovellan/hideBrowser](https://github.com/aleksibovellan/hideBrowser) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [alexpitcher/LanAudit](https://github.com/alexpitcher/LanAudit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [alidagdelen/NetRecon-scan](https://github.com/alidagdelen/NetRecon-scan) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [amirali313/setup-mac](https://github.com/amirali313/setup-mac) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [andreas-glaser/FoxPrivacy](https://github.com/andreas-glaser/FoxPrivacy) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [armelingu/mac-manager](https://github.com/armelingu/mac-manager) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [atak946/MacAppUpdater](https://github.com/atak946/MacAppUpdater) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [atakzlrmk/hardenfox](https://github.com/atakzlrmk/hardenfox) | Browser profile or browser app | 2026-11-24 |
| [aws-solutions-library-samples/guidance-for-sensitive-information-scanning-with-amazon-macie-on-aws](https://github.com/aws-solutions-library-samples/guidance-for-sensitive-information-scanning-with-amazon-macie-on-aws) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [bpmorris22/gmail-mcp-hardened-cross-platform](https://github.com/bpmorris22/gmail-mcp-hardened-cross-platform) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [cavi-ai/secure-agent](https://github.com/cavi-ai/secure-agent) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [civillizard/MacOS-Full-Disk-Access-Tunnel](https://github.com/civillizard/MacOS-Full-Disk-Access-Tunnel) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [corleylun/flowbrowse](https://github.com/corleylun/flowbrowse) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [diShine-digital-agency/prismo](https://github.com/diShine-digital-agency/prismo) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [edjchapman/dotfiles](https://github.com/edjchapman/dotfiles) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [enabled404/openclawsecurity](https://github.com/enabled404/openclawsecurity) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ilyasaalmadani/shipsafe-macos](https://github.com/ilyasaalmadani/shipsafe-macos) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [lennystepn-hue/clawshield](https://github.com/lennystepn-hue/clawshield) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [manuelpenazuniga/ClawCrate](https://github.com/manuelpenazuniga/ClawCrate) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [marcelcotta/Basalt](https://github.com/marcelcotta/Basalt) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [mobinert/machunt](https://github.com/mobinert/machunt) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [p10ns11y/arch-machine](https://github.com/p10ns11y/arch-machine) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [pierredelaguiche/Mac_Scripts](https://github.com/pierredelaguiche/Mac_Scripts) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [rbfp/agentic-ai-assistant-security-guide](https://github.com/rbfp/agentic-ai-assistant-security-guide) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [sentinelden/machoscope](https://github.com/sentinelden/machoscope) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [tuanductran/macos-system-prose](https://github.com/tuanductran/macos-system-prose) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [uakbr/bypass-mdm](https://github.com/uakbr/bypass-mdm) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [yxdwind/agent-skill-manager](https://github.com/yxdwind/agent-skill-manager) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [yyasar21/Mooring](https://github.com/yyasar21/Mooring) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [0xSynapse/ironmac](https://github.com/0xSynapse/ironmac) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [0xjitsu/jitsu-skills](https://github.com/0xjitsu/jitsu-skills) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Aaryan-Rajora14/Universal_Billing_System-V4.0](https://github.com/Aaryan-Rajora14/Universal_Billing_System-V4.0) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Akshat200008/macOS-ClickFix-Malware-Analysis](https://github.com/Akshat200008/macOS-ClickFix-Malware-Analysis) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ArihantDeva/Aegis](https://github.com/ArihantDeva/Aegis) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [BAWES-Universe/orbit-browser](https://github.com/BAWES-Universe/orbit-browser) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [CheginiSoroush/obsidian-sync-scripts](https://github.com/CheginiSoroush/obsidian-sync-scripts) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [CyborgMage99/safari-update-check](https://github.com/CyborgMage99/safari-update-check) | Browser profile or browser app | 2026-11-24 |
| [D-celld/imagegen-mac](https://github.com/D-celld/imagegen-mac) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [DareDev256/clickfix-protection-macos](https://github.com/DareDev256/clickfix-protection-macos) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Frun1753/claude-codecraft-toolkit](https://github.com/Frun1753/claude-codecraft-toolkit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [GmMars1/grokipedia-security-auditor](https://github.com/GmMars1/grokipedia-security-auditor) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Gr3y-foX/foxhole-macos](https://github.com/Gr3y-foX/foxhole-macos) | Network tool, not a host audit | 2026-11-24 |
| [H4shir007/OmniBench](https://github.com/H4shir007/OmniBench) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Hamad-Alrashede/security-audit](https://github.com/Hamad-Alrashede/security-audit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [JaidenTGreen/Home-Security-Lab](https://github.com/JaidenTGreen/Home-Security-Lab) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [JinHanAI/ClawGears](https://github.com/JinHanAI/ClawGears) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [Karmaz95/macOS_HR_bypass_net_maui](https://github.com/Karmaz95/macOS_HR_bypass_net_maui) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [KeyValet/KeyValet](https://github.com/KeyValet/KeyValet) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [MaliParag/trust-chain](https://github.com/MaliParag/trust-chain) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [MrCee/oclp-lid-sleep-hardening](https://github.com/MrCee/oclp-lid-sleep-hardening) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [Mrwoady-hub/Phantom](https://github.com/Mrwoady-hub/Phantom) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Omarnano11498/Universal-IT-Health-Security-Platform](https://github.com/Omarnano11498/Universal-IT-Health-Security-Platform) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [RyZenoKelb/Sogar](https://github.com/RyZenoKelb/Sogar) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [SaiDinesh200214/network-audit-tool](https://github.com/SaiDinesh200214/network-audit-tool) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [SankethSubhas/cis-benchmark-compliance-checker](https://github.com/SankethSubhas/cis-benchmark-compliance-checker) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [SecurityRonin/pipeguard](https://github.com/SecurityRonin/pipeguard) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Sung-tsan/line-desktop-mcp](https://github.com/Sung-tsan/line-desktop-mcp) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Toddoward/chromium-audit](https://github.com/Toddoward/chromium-audit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Vantasin/restic-rest-client](https://github.com/Vantasin/restic-rest-client) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [Vlad-1618M/web_audit](https://github.com/Vlad-1618M/web_audit) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [a95674127-beep/mack-zerotrust-rust-starter](https://github.com/a95674127-beep/mack-zerotrust-rust-starter) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [adamtty/pkgdash](https://github.com/adamtty/pkgdash) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [ajith254t/VULFI--Vulnerability-Finding-Platform](https://github.com/ajith254t/VULFI--Vulnerability-Finding-Platform) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [andreapianidev/paranoid-macOS-security-helper](https://github.com/andreapianidev/paranoid-macOS-security-helper) | Network tool, not a host audit | 2026-11-24 |
| [azoz70/mijhar](https://github.com/azoz70/mijhar) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [bad-antics/nullsec-guardian](https://github.com/bad-antics/nullsec-guardian) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [bad-antics/nullsec-mac](https://github.com/bad-antics/nullsec-mac) | Network tool, not a host audit | 2026-11-24 |
| [bad-antics/nullsec-macos](https://github.com/bad-antics/nullsec-macos) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [blaineam/Tessera](https://github.com/blaineam/Tessera) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [br4vesirrobin/openclaw-sysadmin-agent](https://github.com/br4vesirrobin/openclaw-sysadmin-agent) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [bunta-expert/git-path-audit](https://github.com/bunta-expert/git-path-audit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [bx2-labs/hourous-MAC](https://github.com/bx2-labs/hourous-MAC) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [chaoyupeng/wechat_docker](https://github.com/chaoyupeng/wechat_docker) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [costibotez/system-audit-scripts](https://github.com/costibotez/system-audit-scripts) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [creativeprofit22/intruder-hunter](https://github.com/creativeprofit22/intruder-hunter) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [dasgeekchannel/orionsguard](https://github.com/dasgeekchannel/orionsguard) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [domidetres/m365-admin-scripts](https://github.com/domidetres/m365-admin-scripts) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [duhd/local-workstation-security-audit](https://github.com/duhd/local-workstation-security-audit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [durhamaustin9/DisplayLink-Drivers-Reconstruct](https://github.com/durhamaustin9/DisplayLink-Drivers-Reconstruct) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [esskslifetech/php-secure-patch](https://github.com/esskslifetech/php-secure-patch) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [hideouts-io/Interface-Sentinel](https://github.com/hideouts-io/Interface-Sentinel) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [hideouts-io/Sandbox-Lens](https://github.com/hideouts-io/Sandbox-Lens) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [ifinkelstein/firefox-profile](https://github.com/ifinkelstein/firefox-profile) | Browser profile or browser app | 2026-11-24 |
| [ionalpha/universal-app](https://github.com/ionalpha/universal-app) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [jacob-adm/glassbox](https://github.com/jacob-adm/glassbox) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [jdgiles26/macsec-agents](https://github.com/jdgiles26/macsec-agents) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [karam2022/safer-devices](https://github.com/karam2022/safer-devices) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [kdnsna/WeChatPilot](https://github.com/kdnsna/WeChatPilot) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [kochj23/HomekitControl](https://github.com/kochj23/HomekitControl) | Network tool, not a host audit | 2026-11-24 |
| [krishnasureshcpa/ghosty](https://github.com/krishnasureshcpa/ghosty) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [larsboes/mach-mono](https://github.com/larsboes/mach-mono) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [leighsrodney-prog/trust-store-audit](https://github.com/leighsrodney-prog/trust-store-audit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [luke0485/mcp-safetripwire](https://github.com/luke0485/mcp-safetripwire) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [messyvirgo-coin/messyvirgo-openclaw-client](https://github.com/messyvirgo-coin/messyvirgo-openclaw-client) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [mglaeser/imessage-proxy](https://github.com/mglaeser/imessage-proxy) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [mmabd/macos-hardening](https://github.com/mmabd/macos-hardening) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [mosabbir-maruf/Unarc](https://github.com/mosabbir-maruf/Unarc) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [nariatrip191/my-claude-skills](https://github.com/nariatrip191/my-claude-skills) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [nickciolpan/permcheck](https://github.com/nickciolpan/permcheck) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [nigeltho12/endpoint-hardening-baseline](https://github.com/nigeltho12/endpoint-hardening-baseline) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [officialbrandonsandoval-source/luminet](https://github.com/officialbrandonsandoval-source/luminet) | Network tool, not a host audit | 2026-11-24 |
| [omarss/os-doctor](https://github.com/omarss/os-doctor) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [onofreliscano/osint-stealth-script](https://github.com/onofreliscano/osint-stealth-script) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [pdubbbbbs/bluetooth-hardening-toolkit](https://github.com/pdubbbbbs/bluetooth-hardening-toolkit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [pleniv01/ai-agent-security-hardening](https://github.com/pleniv01/ai-agent-security-hardening) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [prince1604/SEC-AUDIT.1604](https://github.com/prince1604/SEC-AUDIT.1604) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [pt-act/node2shell-cve-2026-111497](https://github.com/pt-act/node2shell-cve-2026-111497) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [qtorb/rosmarops](https://github.com/qtorb/rosmarops) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ratazzi/floria](https://github.com/ratazzi/floria) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [rayitalks/ray-i-security-hardening-agent](https://github.com/rayitalks/ray-i-security-hardening-agent) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ricco020/os-hardening-checklist](https://github.com/ricco020/os-hardening-checklist) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [rishikasinha29/Compliance-Assesment](https://github.com/rishikasinha29/Compliance-Assesment) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [rtwsvj/skill-switch](https://github.com/rtwsvj/skill-switch) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [rwensel/markseal](https://github.com/rwensel/markseal) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sebastienrousseau/raidhos](https://github.com/sebastienrousseau/raidhos) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [selrahcDC/cjsoftware-license-checker](https://github.com/selrahcDC/cjsoftware-license-checker) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [semihbugrasezer/sigsieve](https://github.com/semihbugrasezer/sigsieve) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sinuoslabs/dotfiles](https://github.com/sinuoslabs/dotfiles) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [snoe-findley/mcp-velociraptor](https://github.com/snoe-findley/mcp-velociraptor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sreegokul2006-creator/mac-changer](https://github.com/sreegokul2006-creator/mac-changer) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [superdedooperboy/Scouter-Agent](https://github.com/superdedooperboy/Scouter-Agent) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [supervking/MakLock-Secure](https://github.com/supervking/MakLock-Secure) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [terrypsv/Argus](https://github.com/terrypsv/Argus) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [thekondor/homebrew-mycryptfs](https://github.com/thekondor/homebrew-mycryptfs) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [thelaggingway/repo-security-audit](https://github.com/thelaggingway/repo-security-audit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [thiagocaian/os-hardening-scripts](https://github.com/thiagocaian/os-hardening-scripts) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [thijsvos/icecube](https://github.com/thijsvos/icecube) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [tilas01/deny_all_wifi](https://github.com/tilas01/deny_all_wifi) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [tldr-it-stepankutaj/ansible_role](https://github.com/tldr-it-stepankutaj/ansible_role) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [tnalbant/trailwarden](https://github.com/tnalbant/trailwarden) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [tombrewsviews/remember-everything-locally-super-duper-securly](https://github.com/tombrewsviews/remember-everything-locally-super-duper-securly) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [vigyanbytes/niyantrak-keys](https://github.com/vigyanbytes/niyantrak-keys) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [vinitop/hardening-audit-toolkit](https://github.com/vinitop/hardening-audit-toolkit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [vuminhhoa/macsentry](https://github.com/vuminhhoa/macsentry) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [xdrew87/wifi-auditor](https://github.com/xdrew87/wifi-auditor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [yigitkonur/droid-daemon-hardening](https://github.com/yigitkonur/droid-daemon-hardening) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [zxu756/rea-build-guard](https://github.com/zxu756/rea-build-guard) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [09josuec-cloud/mac-network-security-audit](https://github.com/09josuec-cloud/mac-network-security-audit) | Network tool, not a host audit | 2026-11-24 |
| [1970sRedux/MacOS-Services-Controller-Script](https://github.com/1970sRedux/MacOS-Services-Controller-Script) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [5RIndustries/darkhan](https://github.com/5RIndustries/darkhan) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [5tier/osxrdp](https://github.com/5tier/osxrdp) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [6a6f6a6f/cx-sideload](https://github.com/6a6f6a6f/cx-sideload) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [6kdave/homebrew-mac-security](https://github.com/6kdave/homebrew-mac-security) | Homebrew tap that packages a tool under review in another task | 2026-11-24 |
| [AES256Afro/Porchlight](https://github.com/AES256Afro/Porchlight) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [AK-92/safesync](https://github.com/AK-92/safesync) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [ANierbeck/apple-mcp-secure](https://github.com/ANierbeck/apple-mcp-secure) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [AT25893/VaultGuard](https://github.com/AT25893/VaultGuard) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [AldeabAhmed/xnu-hardened-exception-flavor-confusion](https://github.com/AldeabAhmed/xnu-hardened-exception-flavor-confusion) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [Antonmentor77/CyberShield-Analyzer](https://github.com/Antonmentor77/CyberShield-Analyzer) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [AralimNGA/siegel](https://github.com/AralimNGA/siegel) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ArcScreenHike/bitwarden-pcwinmac-nf99](https://github.com/ArcScreenHike/bitwarden-pcwinmac-nf99) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Arkadiusz-Czubik/macbook-seed](https://github.com/Arkadiusz-Czubik/macbook-seed) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [BIGMOSSX/local-audit-agent](https://github.com/BIGMOSSX/local-audit-agent) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [BalaShankar9/toolforge](https://github.com/BalaShankar9/toolforge) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [CesarJ262/aws-macie-s3-data-security](https://github.com/CesarJ262/aws-macie-s3-data-security) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [ChandranilDas/NEELx](https://github.com/ChandranilDas/NEELx) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [Cyberbob8305/Tiffany-AI-Assistant-Startup-Kit](https://github.com/Cyberbob8305/Tiffany-AI-Assistant-Startup-Kit) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [Cyberfilo/iphone-audit](https://github.com/Cyberfilo/iphone-audit) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [DD-HAHA/proxy-sentry](https://github.com/DD-HAHA/proxy-sentry) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [DJCastle/goPrivateQuickly-Chromium](https://github.com/DJCastle/goPrivateQuickly-Chromium) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [DJCastle/goPrivateQuickly-Firefox](https://github.com/DJCastle/goPrivateQuickly-Firefox) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [DMLayMan/warpgate-tailscale-mac](https://github.com/DMLayMan/warpgate-tailscale-mac) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [DaddyMadu/ssh-operations-skill](https://github.com/DaddyMadu/ssh-operations-skill) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [DeltaEcho3/agent-hardening-tools](https://github.com/DeltaEcho3/agent-hardening-tools) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [DrakkarWolf/Hackintosh-of-the-Iron-Wolf-P50-Hackintosh](https://github.com/DrakkarWolf/Hackintosh-of-the-Iron-Wolf-P50-Hackintosh) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [ErfanZmp/rayo](https://github.com/ErfanZmp/rayo) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Fallen-leaves089/project-health-macos](https://github.com/Fallen-leaves089/project-health-macos) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [FaresMohamed6/NetPen](https://github.com/FaresMohamed6/NetPen) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Fatemerjn/Security-and-privacy-in-machine-learning](https://github.com/Fatemerjn/Security-and-privacy-in-machine-learning) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [Fing-Network-Inspector/.github](https://github.com/Fing-Network-Inspector/.github) | Network tool, not a host audit | 2026-11-24 |
| [FlorianKreativLab/secure-vault-template](https://github.com/FlorianKreativLab/secure-vault-template) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [FrankG23/Mac-Address-Changer-Script](https://github.com/FrankG23/Mac-Address-Changer-Script) | Network tool, not a host audit | 2026-11-24 |
| [Gentlebatjoist/advanced-syre-pcwinmac-nb30](https://github.com/Gentlebatjoist/advanced-syre-pcwinmac-nb30) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [GrillCodE-web/mac-autosetup](https://github.com/GrillCodE-web/mac-autosetup) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [HARSHA2396/Compliance-Assessment-Security-Hardening](https://github.com/HARSHA2396/Compliance-Assessment-Security-Hardening) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [HarryLDev/Cross-Platform-Security-Hardening-Toolkit](https://github.com/HarryLDev/Cross-Platform-Security-Hardening-Toolkit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Husein-Edris/MacPulse](https://github.com/Husein-Edris/MacPulse) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [Intelliship/enterprise-infra-hybrid-hardening](https://github.com/Intelliship/enterprise-infra-hybrid-hardening) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Intelliship/mdm-device-trust-automation](https://github.com/Intelliship/mdm-device-trust-automation) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [J-R77-stack/macos-network-security-assessment](https://github.com/J-R77-stack/macos-network-security-assessment) | Network tool, not a host audit | 2026-11-24 |
| [JacinthSolomon-JS/Project-Revina](https://github.com/JacinthSolomon-JS/Project-Revina) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Jackb-cs/Brave-Macos-Hardening](https://github.com/Jackb-cs/Brave-Macos-Hardening) | Browser profile or browser app | 2026-11-24 |
| [Jamesmorales76/intune-endpoint-management](https://github.com/Jamesmorales76/intune-endpoint-management) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Jeremy-Burgos/wazuh-detection-engineering](https://github.com/Jeremy-Burgos/wazuh-detection-engineering) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [JiriHybl/macos-mde-custom-compliance](https://github.com/JiriHybl/macos-mde-custom-compliance) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [JonesB101/CTI_Investigation_Applev1](https://github.com/JonesB101/CTI_Investigation_Applev1) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [KK42205288/macis](https://github.com/KK42205288/macis) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [Karthiyayini-02/Machine-Learning-based-Threat-Detection-with-Blockchain-Audit-Trails](https://github.com/Karthiyayini-02/Machine-Learning-based-Threat-Detection-with-Blockchain-Audit-Trails) | Network tool, not a host audit | 2026-11-24 |
| [KumnegerB/Computer-System-Security-Project](https://github.com/KumnegerB/Computer-System-Security-Project) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Lapus0108/macOS-evasion-research](https://github.com/Lapus0108/macOS-evasion-research) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Linopixel/mac-logseq-sync-hardening](https://github.com/Linopixel/mac-logseq-sync-hardening) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [Lottersss/airguard](https://github.com/Lottersss/airguard) | Network tool, not a host audit | 2026-11-24 |
| [LucaLivigni/openclaw-shield](https://github.com/LucaLivigni/openclaw-shield) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [MRJANAB/iAudit](https://github.com/MRJANAB/iAudit) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [MTMartin-com/Secure-LemonSqueezy-macOS](https://github.com/MTMartin-com/Secure-LemonSqueezy-macOS) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [MainasuK/MusicCLI](https://github.com/MainasuK/MusicCLI) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [MariusVasileMaftei/NetworkGuard](https://github.com/MariusVasileMaftei/NetworkGuard) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Mon-ius/airgorah-mlx](https://github.com/Mon-ius/airgorah-mlx) | Network tool, not a host audit | 2026-11-24 |
| [MutheAkankshaSuresh/GuardOS](https://github.com/MutheAkankshaSuresh/GuardOS) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [Nagavenkatasai7/secure-setup](https://github.com/Nagavenkatasai7/secure-setup) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Nerflix/Lucasa_POS](https://github.com/Nerflix/Lucasa_POS) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [NicoX13/claude-token-monitor](https://github.com/NicoX13/claude-token-monitor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [NipunChamodya/SpiderDeck](https://github.com/NipunChamodya/SpiderDeck) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [OctopusGarage/envsentinel](https://github.com/OctopusGarage/envsentinel) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Pandora401/MAC-N-CHEESE](https://github.com/Pandora401/MAC-N-CHEESE) | Network tool, not a host audit | 2026-11-24 |
| [Pareto-Security-Checker/.github](https://github.com/Pareto-Security-Checker/.github) | Profile repo of the tracked Pareto project; not a separate tool | 2026-11-24 |
| [Pareto-Security-Checker/Pareto-Security-Download](https://github.com/Pareto-Security-Checker/Pareto-Security-Download) | Download page for the tracked Pareto app; unsafe to fetch, never downloaded | 2026-11-24 |
| [Peter-Dev08/macos-15.6.1-mit-chatGPT](https://github.com/Peter-Dev08/macos-15.6.1-mit-chatGPT) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [Pharma-Py/Sentinella_mail-IT-](https://github.com/Pharma-Py/Sentinella_mail-IT-) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [Pitchfork-and-Torch/netforge](https://github.com/Pitchfork-and-Torch/netforge) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Pitchfork-and-Torch/netforge-macos](https://github.com/Pitchfork-and-Torch/netforge-macos) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Prasanth595/lynis](https://github.com/Prasanth595/lynis) | Mirror of the tracked CISOfy/lynis | 2026-11-24 |
| [Proff506/shadow-ai-audit-kit](https://github.com/Proff506/shadow-ai-audit-kit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [RAJ015HACKING/Blue_jammer](https://github.com/RAJ015HACKING/Blue_jammer) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Radiancenopray/mev-arbitraot-pcwinmac-bx98](https://github.com/Radiancenopray/mev-arbitraot-pcwinmac-bx98) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Ramk4222/Classifing-Cyber-Security-using-Machine-Learning](https://github.com/Ramk4222/Classifing-Cyber-Security-using-Machine-Learning) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [Rani367/Armadillo](https://github.com/Rani367/Armadillo) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [RickGua90/kandji-custom-scripts](https://github.com/RickGua90/kandji-custom-scripts) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [Rphants/claude-multi](https://github.com/Rphants/claude-multi) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [SHOLA-GABRIEL/devsecops-machine](https://github.com/SHOLA-GABRIEL/devsecops-machine) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [SafraNako/usb-security-scanner](https://github.com/SafraNako/usb-security-scanner) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ShashankD210/IT-Audit-Toolkit-Linux-Windows-macOS](https://github.com/ShashankD210/IT-Audit-Toolkit-Linux-Windows-macOS) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [ShashankD210/SystemHardeningToolkit](https://github.com/ShashankD210/SystemHardeningToolkit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Shashau/mac-network-security-audit](https://github.com/Shashau/mac-network-security-audit) | Network tool, not a host audit | 2026-11-24 |
| [ShivamPatel8800/endpoint-hardening-framework](https://github.com/ShivamPatel8800/endpoint-hardening-framework) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Simple-With-Us/Autorotate](https://github.com/Simple-With-Us/Autorotate) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [SkyfallCreations/BYOD-Compliance-Monitoring-Tool---Unified-Entry-Point](https://github.com/SkyfallCreations/BYOD-Compliance-Monitoring-Tool---Unified-Entry-Point) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [SuhasH752/Microsoft-Classifying-Cybersecurity-Incidents-with-Machine-Learning](https://github.com/SuhasH752/Microsoft-Classifying-Cybersecurity-Incidents-with-Machine-Learning) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [SuryaKiran434/mac-upkeep](https://github.com/SuryaKiran434/mac-upkeep) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [Toshi-hub834/security-hardening](https://github.com/Toshi-hub834/security-hardening) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [VernestBrown/security-automation](https://github.com/VernestBrown/security-automation) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [Virginie-9/Linux-Network-Security-Auditor](https://github.com/Virginie-9/Linux-Network-Security-Auditor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [Xyness/SysAudit](https://github.com/Xyness/SysAudit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [YokiiDesu/vending-machine-mcp](https://github.com/YokiiDesu/vending-machine-mcp) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [a-magdy/revelio](https://github.com/a-magdy/revelio) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [abdihakim-said/mac-optimised](https://github.com/abdihakim-said/mac-optimised) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [abhishekyadav7012/Machine-Learning-and-Blockchain-A-Bibliometric-Study-and-Automated-Security-Audit-Engine](https://github.com/abhishekyadav7012/Machine-Learning-and-Blockchain-A-Bibliometric-Study-and-Automated-Security-Audit-Engine) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [abouchard11/graphiti-neo4j-ops](https://github.com/abouchard11/graphiti-neo4j-ops) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [aigovops-foundation/openclaw-installer](https://github.com/aigovops-foundation/openclaw-installer) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [ajslater/firefox-privacy](https://github.com/ajslater/firefox-privacy) | Browser profile or browser app | 2026-11-24 |
| [alan-sun-dev/ollama-nginx-gateway](https://github.com/alan-sun-dev/ollama-nginx-gateway) | Network tool, not a host audit | 2026-11-24 |
| [alejandrosml/security-advisories](https://github.com/alejandrosml/security-advisories) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [alvarobmp/macos-bulk-shutdown-ssh](https://github.com/alvarobmp/macos-bulk-shutdown-ssh) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [andersyin/md-reader](https://github.com/andersyin/md-reader) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [andre28abr/Uptend](https://github.com/andre28abr/Uptend) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [andrewloable/app-hardening](https://github.com/andrewloable/app-hardening) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [angelpixel-core/dotfiles](https://github.com/angelpixel-core/dotfiles) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [anuragpareek016/Mac-SOC](https://github.com/anuragpareek016/Mac-SOC) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [apwdoan/super-lighthouse-analytics-program](https://github.com/apwdoan/super-lighthouse-analytics-program) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [arighmt67-bit/zero-trust-endpoint-hardening](https://github.com/arighmt67-bit/zero-trust-endpoint-hardening) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [arkaigrowth/voice-memo-pipeline](https://github.com/arkaigrowth/voice-memo-pipeline) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [artysficial/hsm-api-security-lab](https://github.com/artysficial/hsm-api-security-lab) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [asingh713/cis-benchmark-auditor](https://github.com/asingh713/cis-benchmark-auditor) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [asoshnin/openclaw-hardened-macos](https://github.com/asoshnin/openclaw-hardened-macos) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [austinfalk/macos-llm-server](https://github.com/austinfalk/macos-llm-server) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [avespoli-sonarmd/s-devplane](https://github.com/avespoli-sonarmd/s-devplane) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [axelquack/dotfiles-macos](https://github.com/axelquack/dotfiles-macos) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [berinabraham-sec/endpoint-security-auditor](https://github.com/berinabraham-sec/endpoint-security-auditor) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [bharathvbcr/blitztree](https://github.com/bharathvbcr/blitztree) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [blackoutsecure/endpoint-toolkit](https://github.com/blackoutsecure/endpoint-toolkit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [bruja-lab/macos-system-hardening-](https://github.com/bruja-lab/macos-system-hardening-) | Network tool, not a host audit | 2026-11-24 |
| [by-sonic/claude-code-vds-proxy](https://github.com/by-sonic/claude-code-vds-proxy) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [caramel-lia/WazuHive](https://github.com/caramel-lia/WazuHive) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [carvalhonishant/lab-02-macos-hardening-logging](https://github.com/carvalhonishant/lab-02-macos-hardening-logging) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [cehlert9999/wm-audit](https://github.com/cehlert9999/wm-audit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [chakrabartyendpointautomation/macos-security-hardening-vulnerability-management](https://github.com/chakrabartyendpointautomation/macos-security-hardening-vulnerability-management) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [chemix444/xcloudwrapper](https://github.com/chemix444/xcloudwrapper) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [chidwipak/LynisShield-CrossPlatform-VulnerabilityScanner](https://github.com/chidwipak/LynisShield-CrossPlatform-VulnerabilityScanner) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [chillee151/equirectangular-photo-album](https://github.com/chillee151/equirectangular-photo-album) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [chyin1006/SDMon](https://github.com/chyin1006/SDMon) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [clearcloud-fr/checkops-cli](https://github.com/clearcloud-fr/checkops-cli) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [crimsonpython24/macsetup](https://github.com/crimsonpython24/macsetup) | Network tool, not a host audit | 2026-11-24 |
| [curtismercier/mac-lifeline](https://github.com/curtismercier/mac-lifeline) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [d-date/swift-safe-unzip](https://github.com/d-date/swift-safe-unzip) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [derryckf/macos-privacy-hardening](https://github.com/derryckf/macos-privacy-hardening) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [derryraja/TapGuard](https://github.com/derryraja/TapGuard) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [deva0x/since](https://github.com/deva0x/since) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [dm807cam/amber](https://github.com/dm807cam/amber) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [doug445/Panoptes-macOS](https://github.com/doug445/Panoptes-macOS) | Network tool, not a host audit | 2026-11-24 |
| [drdee/parental_controls](https://github.com/drdee/parental_controls) | Network tool, not a host audit | 2026-11-24 |
| [dskil/netpeek](https://github.com/dskil/netpeek) | Network tool, not a host audit | 2026-11-24 |
| [eamadit/pf.conf](https://github.com/eamadit/pf.conf) | Network tool, not a host audit | 2026-11-24 |
| [edersm-byte/365-security-baseline-audit](https://github.com/edersm-byte/365-security-baseline-audit) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [efekanbahceci/clous](https://github.com/efekanbahceci/clous) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [elias-leslie/sha](https://github.com/elias-leslie/sha) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [eltociear/homebrew-audit](https://github.com/eltociear/homebrew-audit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [emaba/opnsense-sanitize](https://github.com/emaba/opnsense-sanitize) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ericfurspan/wazuh-siem-homelab](https://github.com/ericfurspan/wazuh-siem-homelab) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [evanchoudhury/aether-os](https://github.com/evanchoudhury/aether-os) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [eztakesin/user.js](https://github.com/eztakesin/user.js) | Network tool, not a host audit | 2026-11-24 |
| [fablab503-collab/UTM](https://github.com/fablab503-collab/UTM) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [farcloser/homebrew-brews](https://github.com/farcloser/homebrew-brews) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [felipe-seabra/fs-security](https://github.com/felipe-seabra/fs-security) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [fjgbue/repo-publication-auditor](https://github.com/fjgbue/repo-publication-auditor) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [focuslight-nr/codex-audit](https://github.com/focuslight-nr/codex-audit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [fuzzlove/MSAA](https://github.com/fuzzlove/MSAA) | Homepage for the tracked fuzzlove repo | 2026-11-24 |
| [g4hio/mac-ai-tool-access-audit](https://github.com/g4hio/mac-ai-tool-access-audit) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [georgecurta/gtools-releases](https://github.com/georgecurta/gtools-releases) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [gilmanpro/portrelay](https://github.com/gilmanpro/portrelay) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [guiboorges/auditoria-seguranca-local](https://github.com/guiboorges/auditoria-seguranca-local) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [hacrex/How-To-Secure-A-Linux-And-Windows-Desktop-Server](https://github.com/hacrex/How-To-Secure-A-Linux-And-Windows-Desktop-Server) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [haqaliz/assay](https://github.com/haqaliz/assay) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [harshgaikwad22/wifi-audit-tool](https://github.com/harshgaikwad22/wifi-audit-tool) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [haycarlitos/safe-install](https://github.com/haycarlitos/safe-install) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [haydarkadioglu/ipbak](https://github.com/haydarkadioglu/ipbak) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [henderlabs/secreds](https://github.com/henderlabs/secreds) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [heyethan/macattacc](https://github.com/heyethan/macattacc) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [hiroki-io/auto-reboot](https://github.com/hiroki-io/auto-reboot) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [horsedriver/CyberCore-Sentinel](https://github.com/horsedriver/CyberCore-Sentinel) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [ibaurr/kist](https://github.com/ibaurr/kist) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ibrahim-gulzar-11/System-Vulnerability-Check](https://github.com/ibrahim-gulzar-11/System-Vulnerability-Check) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [inquinity/belvedere](https://github.com/inquinity/belvedere) | Network tool, not a host audit | 2026-11-24 |
| [ipunithgowda/claude-logger](https://github.com/ipunithgowda/claude-logger) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [its-javadizavieh/CYS-Security-Measures](https://github.com/its-javadizavieh/CYS-Security-Measures) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [jakezegil/spot-fast](https://github.com/jakezegil/spot-fast) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [jakobjhartmann/apple-calendar-jxa-mcp](https://github.com/jakobjhartmann/apple-calendar-jxa-mcp) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [jamflux/GOFlux-Builder](https://github.com/jamflux/GOFlux-Builder) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [janoulle/remove-orphan-macos-services](https://github.com/janoulle/remove-orphan-macos-services) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [jenishs524/NetEye-Professional-Network-CCTV-Security-Auditor](https://github.com/jenishs524/NetEye-Professional-Network-CCTV-Security-Auditor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [jerrytubson/pentesting-portfolio](https://github.com/jerrytubson/pentesting-portfolio) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [jetnoir/security-research](https://github.com/jetnoir/security-research) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [joelb564/Security-Log-Auditor](https://github.com/joelb564/Security-Log-Auditor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [jordanilchev/hermes-in-a-box-on-macos](https://github.com/jordanilchev/hermes-in-a-box-on-macos) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [jorgejsanchezp/security-first-lifecycle](https://github.com/jorgejsanchezp/security-first-lifecycle) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [jtwiborg/router-audit](https://github.com/jtwiborg/router-audit) | Network tool, not a host audit | 2026-11-24 |
| [jyotirmoy-dutta/Endpoint-Hardening-Script](https://github.com/jyotirmoy-dutta/Endpoint-Hardening-Script) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [kamalkarki111/maxcos](https://github.com/kamalkarki111/maxcos) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [kashisdeveloping/kash-ghost](https://github.com/kashisdeveloping/kash-ghost) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [kid0114/vps-config-skill](https://github.com/kid0114/vps-config-skill) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [km4391/agent-mcp](https://github.com/km4391/agent-mcp) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [kriuchkov/pinentry-biometric](https://github.com/kriuchkov/pinentry-biometric) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [lazymac2x/api-security-audit-worker](https://github.com/lazymac2x/api-security-audit-worker) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [ldddddddl/mac-campus-vpn](https://github.com/ldddddddl/mac-campus-vpn) | Network tool, not a host audit | 2026-11-24 |
| [leafall903/parallels-touchid-compat-patch](https://github.com/leafall903/parallels-touchid-compat-patch) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [leandro4979-hub/ollama-local-client](https://github.com/leandro4979-hub/ollama-local-client) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [leaner-app/path-policy](https://github.com/leaner-app/path-policy) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [lexoliu/fishbowl](https://github.com/lexoliu/fishbowl) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [liaw-boy/DevKeeper](https://github.com/liaw-boy/DevKeeper) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [lobsterscollide/usb-triage](https://github.com/lobsterscollide/usb-triage) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [lu-zhengda/homebrew-tap](https://github.com/lu-zhengda/homebrew-tap) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [madbitloman/bigmac](https://github.com/madbitloman/bigmac) | Network tool, not a host audit | 2026-11-24 |
| [magoo2015/wazuh-detection-engineering-lab](https://github.com/magoo2015/wazuh-detection-engineering-lab) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [magyemangprempeh/Intune-macOS-migration-compliance](https://github.com/magyemangprempeh/Intune-macOS-migration-compliance) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [mainak-roy-pentest/local_network_scanner.py](https://github.com/mainak-roy-pentest/local_network_scanner.py) | Network tool, not a host audit | 2026-11-24 |
| [mango-ux4100/SecureVault](https://github.com/mango-ux4100/SecureVault) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [maxmo74/cmdscribe](https://github.com/maxmo74/cmdscribe) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [meastblue/firefox-hardening](https://github.com/meastblue/firefox-hardening) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [mektigh/dotfile-automation](https://github.com/mektigh/dotfile-automation) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [microlaser/Mac_Session_Hardening](https://github.com/microlaser/Mac_Session_Hardening) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [microlaser/pff2](https://github.com/microlaser/pff2) | Network tool, not a host audit | 2026-11-24 |
| [microlaser/pffsensible](https://github.com/microlaser/pffsensible) | Network tool, not a host audit | 2026-11-24 |
| [mitre/sv3-runner](https://github.com/mitre/sv3-runner) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [mock1ngbb/GithubLauncher](https://github.com/mock1ngbb/GithubLauncher) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [moruku36/personal-security-auditor](https://github.com/moruku36/personal-security-auditor) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [mrheydari3/WarpGuard](https://github.com/mrheydari3/WarpGuard) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [msjurset/drifter-mac](https://github.com/msjurset/drifter-mac) | Network tool, not a host audit | 2026-11-24 |
| [nauta-ai/holster](https://github.com/nauta-ai/holster) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [neithdo269/0xShieldRed-5](https://github.com/neithdo269/0xShieldRed-5) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [nerdicbynature/ai-sandbox-macosx](https://github.com/nerdicbynature/ai-sandbox-macosx) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [neshboy/auditforge](https://github.com/neshboy/auditforge) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [ngarrison-stack/macos-security-toolkit](https://github.com/ngarrison-stack/macos-security-toolkit) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [nomouse-app/nomouse-helper](https://github.com/nomouse-app/nomouse-helper) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [omar-aldaihani/lan-auditor](https://github.com/omar-aldaihani/lan-auditor) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [pablocsl/socbox](https://github.com/pablocsl/socbox) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [pbuffolino/mac-package-updater](https://github.com/pbuffolino/mac-package-updater) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [pengpercy/KeeDesk](https://github.com/pengpercy/KeeDesk) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [plusmalias/netwatch](https://github.com/plusmalias/netwatch) | Network tool, not a host audit | 2026-11-24 |
| [prasannavarshan/update-toolchain](https://github.com/prasannavarshan/update-toolchain) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [priyanshumit/macos-terminal-mcp](https://github.com/priyanshumit/macos-terminal-mcp) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [pyankie/hybrid-access-control](https://github.com/pyankie/hybrid-access-control) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [r3d-aggro/jellyfin-homeserver](https://github.com/r3d-aggro/jellyfin-homeserver) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ramirezramiro/zephyr-secure-supervisor](https://github.com/ramirezramiro/zephyr-secure-supervisor) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [red-anaaru/sanitize-wv2-env-vars](https://github.com/red-anaaru/sanitize-wv2-env-vars) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [remaskm/VaultScan--local-security-auditing-tool-for-your-machine](https://github.com/remaskm/VaultScan--local-security-auditing-tool-for-your-machine) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [rixtrayker/startup-manager](https://github.com/rixtrayker/startup-manager) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [rkfshakti/hermes-glassbox](https://github.com/rkfshakti/hermes-glassbox) | Network tool, not a host audit | 2026-11-24 |
| [rtostudioco/division-t82](https://github.com/rtostudioco/division-t82) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [ruth-michael-it/home-network-security-scanne](https://github.com/ruth-michael-it/home-network-security-scanne) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [ryguitarguy/os-security-study-guide](https://github.com/ryguitarguy/os-security-study-guide) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [saadtahir-dev/MacOS-Binaries-Hardening-and-Signing](https://github.com/saadtahir-dev/MacOS-Binaries-Hardening-and-Signing) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [sanisapatrikar/CyberEdge-001](https://github.com/sanisapatrikar/CyberEdge-001) | Network tool, not a host audit | 2026-11-24 |
| [sarangshahane/who-signed](https://github.com/sarangshahane/who-signed) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sczdavos/messenger-browser](https://github.com/sczdavos/messenger-browser) | Browser profile or browser app | 2026-11-24 |
| [seliem-attia/proton-pass-touchid-mcp](https://github.com/seliem-attia/proton-pass-touchid-mcp) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [serg-alexv/network-hardening-blueprint](https://github.com/serg-alexv/network-hardening-blueprint) | Network tool, not a host audit | 2026-11-24 |
| [sgInnora/ghostty-macguard](https://github.com/sgInnora/ghostty-macguard) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sgreen1977/cyberforge-recon-audit-hub](https://github.com/sgreen1977/cyberforge-recon-audit-hub) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [shaileshnputhran/splunk-siem-homelab](https://github.com/shaileshnputhran/splunk-siem-homelab) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [shakelight1/claude-code-clean-env-macos](https://github.com/shakelight1/claude-code-clean-env-macos) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sinansubara/npm-security-checker](https://github.com/sinansubara/npm-security-checker) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [sisegod/machina-trinity](https://github.com/sisegod/machina-trinity) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sorasoras/udp2raw-hardened](https://github.com/sorasoras/udp2raw-hardened) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [spacela007-hue/mac-security-audits](https://github.com/spacela007-hue/mac-security-audits) | Runtime monitor or app, not a one-shot audit | 2026-11-24 |
| [spacela007-hue/macos-security-monitor-](https://github.com/spacela007-hue/macos-security-monitor-) | Network tool, not a host audit | 2026-11-24 |
| [ssevera1/Vulnerability-Scanner](https://github.com/ssevera1/Vulnerability-Scanner) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [stopete/SystemHealthReport](https://github.com/stopete/SystemHealthReport) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [subhajit0x/blackout](https://github.com/subhajit0x/blackout) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [sumit756492/Hidden-File-Detector](https://github.com/sumit756492/Hidden-File-Detector) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [sven1103-agent/pi-sandbox-hardening](https://github.com/sven1103-agent/pi-sandbox-hardening) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [svendt/Clone-NVMe-for-MacOS](https://github.com/svendt/Clone-NVMe-for-MacOS) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [talawyd/personal-nas-setup](https://github.com/talawyd/personal-nas-setup) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [tdiprima/infra-audit](https://github.com/tdiprima/infra-audit) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [techdou/poly-tts](https://github.com/techdou/poly-tts) | AI agent tooling, not a macOS audit | 2026-11-24 |
| [tejas404-code/device-management-powershell-bash-python-automation](https://github.com/tejas404-code/device-management-powershell-bash-python-automation) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [tenhkspark/agent-blast-radius](https://github.com/tenhkspark/agent-blast-radius) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [test3457890/PC-Security-Toolkit](https://github.com/test3457890/PC-Security-Toolkit) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [texasbe2trill/ScenarioKit](https://github.com/texasbe2trill/ScenarioKit) | Utility or app, not a macOS security audit tool | 2026-11-24 |
| [topsun-bot/ros2_hzj-opt](https://github.com/topsun-bot/ros2_hzj-opt) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [tori-create-7991/self-runner](https://github.com/tori-create-7991/self-runner) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [tredds/protection.check](https://github.com/tredds/protection.check) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [trmaphi/security-scan](https://github.com/trmaphi/security-scan) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [ulan-yisaev/limitping-macos-agent](https://github.com/ulan-yisaev/limitping-macos-agent) | Network tool, not a host audit | 2026-11-24 |
| [useless-husband/claudeshield](https://github.com/useless-husband/claudeshield) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [victorbonnet/enclos](https://github.com/victorbonnet/enclos) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [vitokosk8/MACabre](https://github.com/vitokosk8/MACabre) | Network tool, not a host audit | 2026-11-24 |
| [wahidhendrawan/PagerWesi](https://github.com/wahidhendrawan/PagerWesi) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [waqar-nadeem/Firewall-Configuration-And-Status-Management](https://github.com/waqar-nadeem/Firewall-Configuration-And-Status-Management) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [weijia-89/abogen-hardened](https://github.com/weijia-89/abogen-hardened) | A hardened app or wrapper, not an audit tool | 2026-11-24 |
| [wendyqiu88/AI-Security-Audits](https://github.com/wendyqiu88/AI-Security-Audits) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [wongmazi/revenue-agent-oss](https://github.com/wongmazi/revenue-agent-oss) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [wql7380/cross-platform-autostart-hardening](https://github.com/wql7380/cross-platform-autostart-hardening) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [xhaikhfahad/-aws-s3-security-macie-vs-access-analyzer](https://github.com/xhaikhfahad/-aws-s3-security-macie-vs-access-analyzer) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [xignoe/palisade](https://github.com/xignoe/palisade) | Browser profile or browser app | 2026-11-24 |
| [y-jono/XPCAppIntegrationDemo](https://github.com/y-jono/XPCAppIntegrationDemo) | Guide, lab, or write-up without a check catalog | 2026-11-24 |
| [zacker330/bla-ci](https://github.com/zacker330/bla-ci) | Generic cross-platform or Windows audit; macOS is one of several targets | 2026-11-24 |
| [zanonicode/ifolder-sync](https://github.com/zanonicode/ifolder-sync) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [zirscard/dsh-macos-signfix](https://github.com/zirscard/dsh-macos-signfix) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [zixuantemp/MacVM-MCP](https://github.com/zixuantemp/MacVM-MCP) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [PMSLLC/git-wrapper](https://github.com/PMSLLC/git-wrapper) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [max4c/keepmyvalues](https://github.com/max4c/keepmyvalues) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [nlink-jp/zip-porter](https://github.com/nlink-jp/zip-porter) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |
| [0xzcr/rawr-silicon](https://github.com/0xzcr/rawr-silicon) | Not a macOS audit tool; matched the search on a broad term only | 2026-11-24 |

## Method and caveats

- **Reading only:** no reviewed repo was run, built, or installed. Each was cloned shallow and read as data.
- **Who reviewed:** navjotk8690/macaudit was reviewed directly; the others by subagents, cross-checked against `macassay`.
- **Verified on macOS 27.2.1:** `sshd -G` without root; `sysadminctl -screenLock status` output; the macaudit `PATH` and dashboard claims, by reading its code.
- **Corrections to subagent claims:** reviewers said macassay lacks an executable-in-`/tmp` check, a stealth-mode check, an MDM check, a guest-account check, and a screen-lock check. All five exist in `macassay`; those items were removed.
- **Not verified:** network endpoints were found by reading code, not by watching traffic. Large code bases (fuzzlove, Lynis) were sampled. Shallow clones show no history, so maintenance was judged from the newest commit and releases.
- **Discovery run 2026-11-24:** the 15 reviews above read shallow clones from the GitHub web UI's `macos auditing security` family of searches; nothing was run, downloaded as an archive, or fetched from a release. Command lists came from READMEs, catalogs, and a grep of the source, not from reading every check. Ranking of the queue is by name and description only. The caller's 11 skipped repos are not in this file.
- **Licensing:** mSCP is CC BY 4.0 except Apple-contributed text; borrow commands and rule IDs with attribution, not description text. Lynis, Pareto, and NuwaStone are GPL-3.0; take ideas and stock commands, not code. The same holds for SwordCheck (AGPL-3.0), check-mac (EUPL-1.2), and the CIS script by hackerman-jpeg (GPL-3.0).
