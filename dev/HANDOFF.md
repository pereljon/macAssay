# macassay: handoff from network-manager

Date: 2026-11-24
From: the network-manager session (`~/Claude/projects/tech/network-manager`)
Files: this document, `dev/HANDOFF.md`, and the script, now `macassay` at the repo root. The script arrived as `mac-audit.sh` version 1.1 (2026-11-24); the project was renamed `macassay` on 2026-11-24 (`docs/ISSUES.md`, Decisions). This document describes version 1.1 under its original name.

## Purpose

`mac-audit.sh` is a read-only health and security audit for macOS. It writes one Markdown report that a person or an LLM can review. The report opens with a findings table sorted by severity (HIGH, MEDIUM, LOW, INFO), then a Limitations section, then the evidence for each check section.

The script started as a scripted version of a manual review of the user's Mac mini. The user then asked for remote mode over SSH and for a sudo setup that keeps the privileged commands read-only. The user asked for the work to move into its own development project.

## Requirements set by the user

- The script must not make changes on the audited Mac.
- It writes a Markdown report that a person or an LLM can review.
- It runs locally, or on a remote Mac over SSH when a host, a user and an SSH key path are given.
- It needs a `-h` help.
- Privileged checks must run through sudo rules that allow only read-only commands with exact arguments.
- An install command, run with sudo, adds the sudoers rules if the macassay rules are not already present.

## Design constraints

- Bash 3.2 compatible, because `/bin/bash` on macOS is 3.2. No Python, Node or Homebrew tools are required.
- macOS Local Network privacy blocks agent-launched Python, Node and Homebrew tools from reaching LAN hosts. Use `/usr/bin/curl`, `/usr/bin/ssh` and `/usr/bin/nc` for any LAN access.
- Remote mode base64-encodes the script and runs it inside the SSH command: `ssh host "bash -c \"\$(printf %s 'B64' | base64 -D)\" mac-audit --stdout ..."`. Nothing is copied to the remote disk in version 1.1. The report is saved on the local Mac.
- Side effects of a run: a temporary folder `/tmp/macassay.XXXXXX` (`/tmp/mac-audit.XXXXXX` in 1.1) that is removed on exit; `softwareupdate -l` refreshes Apple's update catalog cache (skipped with `--offline`); `brew outdated` may first run Homebrew's auto-update, at most once a day by default, which updates Homebrew and its package lists but no installed package (skipped with `--offline`); one HTTP GET to each LAN listener; `nc -z` connect tests to the sharing ports; one SSH connection as `nobody` to 127.0.0.1, which sshd logs. From version 1.2: with the macassay sudo rules installed, sudo logs each privileged command; without them the script makes no sudo call. The installer, run only by the user, writes `/etc/sudoers.d/macassay`; a remote install logs the script as the sudo command line on the remote Mac.
- Keep secrets out of the report. Serial numbers and UUIDs are omitted. `authorized_keys` shows key type and comment only. Shell startup files are only searched for suspicious patterns; their contents are never copied into the report.

## Current state (version 1.1)

### Options

| Option | Effect |
|---|---|
| `-o FILE` | Report path (default `./mac-audit-<host>-<date>.md`) |
| `--quick` | Skip the 7-day unified-log searches |
| `--offline` | Skip `softwareupdate -l` and `brew outdated` |
| `--skip-du` | Skip the disk-usage scan |
| `--stdout` | Write the report to standard output |
| `--host`, `--user`, `--key`, `--port`, `--known-hosts` | Remote mode over SSH (`BatchMode=yes`, `ConnectTimeout=10`; `--key` adds `IdentitiesOnly=yes`) |
| `--sudo` | Remote only: runs the whole remote script with `sudo -n`. This needs full passwordless sudo and is to be replaced (see Pending work) |
| `-h`, `--help` | Prints header lines 2 to 26 of the script |

### Report sections

1. System and hardware
2. Memory: swap at 75% or more is MEDIUM; 3 or more Jetsam reports in 7 days is MEDIUM
3. Storage and backups: data volume, SMART, local snapshots, Time Machine destination, latest backup, encryption, backup age
4. Updates: `softwareupdate -l`, Homebrew outdated count, XProtect versions
5. Security baseline: SIP, FileVault, Gatekeeper, firewall, stealth, auto-login, profiles, system extensions, kernel extensions
6. Application firewall: Allow and Block table with signer; an Allow rule for an ad hoc, unsigned or missing program is MEDIUM
7. Sharing and remote access: launchd disabled list, `nc -z` tests on ports 22, 445, 548, 5900, 3283 and 88, TFTP on UDP 69, Remote Management settings, SSH authentication methods, `com.apple.access_ssh` group
8. Network listeners: `netstat -anv`, with an `lsof` fallback; signer; one HTTP GET each; a non-Apple listener that answers 200 is MEDIUM
9. Startup items and persistence: LaunchDaemons and LaunchAgents with signer, helper tools, login hook, crontab, periodic scripts, `sudoers.d` listing, `authorized_keys`, shell startup patterns, executables in shared or temporary folders, `sfltool dumpbtm` when root
10. Accounts: local users, admin group, root account state, recent logins
11. Running programs outside standard locations, with signer
12. Logs: crash report counts, kernel panics, XProtect detections, SSH accepted and failed counts
13. Disk usage: home folder top 25; top-level folders when root
14. Network configuration, trust and privacy: DNS, proxy, `/etc/hosts`, `DYLD_INSERT_LIBRARIES`, System keychain certificates, admin trust settings, outbound connections, guest account, screen lock, `pmset`, TCC, Gatekeeper-rejected apps, Chrome and Safari extensions
15. Root-only checks: `lsof` listeners, `sshd -T`, `pfctl`

### Test results

- Full local run on the Mac mini (macOS, Darwin 27.2.0) took about 1 minute 40 seconds. It produced 41 findings: HIGH 0, MEDIUM 14, LOW 19, INFO 8. The findings matched the earlier manual review.
- The encoded remote path was tested locally, and it produced the same report. The bad-key error was tested ("Cannot read key: /nonexistent").
- Not tested: remote mode against a real second Mac, because no other Mac accepted a key from this Mac.
- Not tested: any run as root or with sudo.
- False positives that were found and fixed: XProtect "NoThreatDetected" lines counted as detections; the root account reported as enabled (it is disabled, Password `*`); SSH, SMB and Screen Sharing reported as not listening when run without root (fixed with `nc -z`); a blank system extension name; Homebrew ad hoc programs overflagged.

## Pending work requested by the user

### Decision still open: how sudo is granted

The user has not yet chosen between two approaches. Ask the user before building either one.

**A. Script in sudoers (network-manager recommended this).**
- `sudo mac-audit.sh --install` copies the script to `/usr/local/sbin/mac-audit`, owned by root:wheel with mode 755.
- The installer writes a rule that pins the file's SHA-256 digest and allows only fixed `--stdout` argument sets, for example `USER ALL = (root) NOPASSWD: sha256:<hash> /usr/local/sbin/mac-audit --stdout`.
- A normal-user run, local or remote, calls `sudo -n /usr/local/sbin/mac-audit --stdout`, and the whole audit runs as root.
- Conditions: refuse `-o` and `--install` when started through sudo; check that the installed file and every parent folder are root-owned and not writable by the user; set `PATH` in the script; never run user-owned code as root (Homebrew already runs through `sudo -u`).
- Trade-offs: one rule and full root coverage, but the whole script runs as root, remote mode needs a one-time install on each Mac, and each script update needs a reinstall for the new digest.

**B. Per-command rules.**
- The script runs as the user and calls `sudo -n` only for exact read-only command lines.
- Before each privileged call, it probes the rule with `sudo -n -l <command> <args>`, which reports whether the command is allowed without running it.
- `--install-sudoers [USER]` writes `/etc/sudoers.d/mac-audit` when the mac-audit rules are not present. `--print-sudoers` shows the rules without installing them.
- Trade-offs: only fixed commands run as root and remote mode stays copy-free, but the rules (about 40 lines) must be regenerated when users or `sudoers.d` files change, and the system TCC check is not covered.

Draft rule list for B:

```
Cmnd_Alias MACAUDIT = \
    /usr/sbin/lsof -nP -iTCP -sTCP\:LISTEN, \
    /usr/sbin/lsof -nP -d txt -Fpn, \
    /usr/sbin/sshd -T, \
    /sbin/pfctl -s info, \
    /sbin/pfctl -s rules, \
    /usr/bin/sfltool dumpbtm, \
    /usr/bin/du -h -d 1 -x /Users, \
    /usr/bin/du -sh -x /Library /Applications /opt /private/var, \
    /usr/bin/profiles show -type configuration, \
    /usr/bin/bputil -d, \
    /bin/cat /etc/sudoers, \
    /bin/cat /etc/sudoers.d/<each file present at install time>, \
    /usr/bin/crontab -u <each other user> -l, \
    /bin/cat <home>/.ssh/authorized_keys, \
    /bin/ls -l <home>/Library/LaunchAgents, \
    /bin/cat <home>/.zshrc (and .zprofile .zshenv .bashrc .bash_profile .profile), \
    /usr/bin/crontab -u root -l, \
    /bin/ls -la /var/root, \
    /bin/cat /var/root/.ssh/authorized_keys, \
    /bin/cat /var/root/<each shell startup file>
USER ALL = (root) NOPASSWD: MACAUDIT
```

Rules for B:
- Use full paths and exact arguments.
- Never use `*` in arguments, because in sudoers argument matching it also matches spaces and slashes.
- Never allow a shell, an interpreter, an editor or `sqlite3`.
- Escape `, : = ! ( ) \` with a backslash inside arguments.
- Replace the per-PID `lsof -p` lookup (section 8) with the single `lsof -nP -d txt -Fpn` map.
- Replace the `/Users/*` glob in `du` with the fixed command lines above.

### Work needed under either approach

1. Improve `-h`: print the whole header comment block, with examples and the install steps.
2. Add the optional checks:
   - other local users and root (`/var/root`): `authorized_keys`, LaunchAgents, crontabs, shell startup patterns;
   - sudoers contents: report `NOPASSWD` rules other than mac-audit's (`NOPASSWD: ALL` is MEDIUM); report `sudoers.d` files that the rules cannot read (added after install);
   - `bputil -d` (secure boot policy);
   - `profiles show -type configuration` as root (device-level profiles).
3. Replace the remote `--sudo` option, which wraps the whole script in `sudo -n`.
4. Report which privileged checks ran and which were skipped, in the header and in Limitations.
5. Installer behavior:
   - Refuse to run without root.
   - Validate the generated file with `visudo -c -f` before installing.
   - Install with mode 0440, owned by root:wheel.
   - Run `visudo -c` after installing, and roll back if it fails.
   - Verify the rule from the granted user with `sudo -u USER /usr/bin/sudo -n -k -l /sbin/pfctl -s info`.
   - Print the undo command.
   - Warn if `/etc/sudoers` has no `includedir` line for `sudoers.d`.
6. Bump `VERSION` to 1.2.

## Facts verified on the Mac mini (2026-11-24)

- sudo version 1.9.17p2. sudoers digests (`sha256:`) and regex arguments are supported in this version (digests since 1.8.7, regex since 1.9.10; from sudo documentation, not tested here).
- `/etc/sudoers.d` exists: root:wheel, mode 755, empty. Whether `/etc/sudoers` contains an `includedir` line is unverified; reading the file needs root.
- `/usr/local` and `/usr/local/bin` are root:wheel, mode 755. `/usr/local/sbin` does not exist.
- Binary paths: `/usr/sbin/lsof`, `/usr/sbin/sshd`, `/sbin/pfctl`, `/usr/bin/sfltool`, `/usr/bin/du`, `/usr/bin/sqlite3`, `/usr/bin/crontab`, `/usr/bin/profiles`, `/usr/bin/bputil`, `/bin/cat`.
- `bputil -d` without root prints "The tool requires running as root".
- `profiles show -type configuration` without root reports user profiles only.
- Local users with UID 501 or above: an admin account (501) and the audit user (502).
- The audit user has `(ALL) ALL` with a password. When sudo credentials are cached, `sudo -n -l` succeeds for any command, so a probe can pass without a mac-audit rule. To test only the NOPASSWD rules, use `sudo -n -k -l ...`.

## Notes for the new project

- The original copy stays at `~/Claude/projects/tech/network-manager/scripts/mac-audit.sh` (uncommitted). Ask the user whether network-manager should delete its copy once the development project owns the script.
- Installing sudoers rules or a root-owned copy changes system configuration. Confirm with the user before running an install on any Mac, and state the impact and the undo.
- The scratchpad backup of version 1.1 is in the network-manager session's scratchpad and is not durable; the copy in this folder is the reference.
