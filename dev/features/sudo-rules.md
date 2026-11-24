---
kind: feature
lifecycle: designing
status: 2026-11-24 drafted; revised after the architecture review and the user's decisions
---

# Privileged checks through per-command sudo rules (version 1.2)

This doc is the plan of record for version 1.2: how privileged checks get root, the installer, the script structure, the new checks, and the 1.1 fixes. Test cases and review findings live in `sudo-rules-tests.md`.

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64), sudo 1.9.17p2, Homebrew 7.0.16, and `mac-audit.sh` 1.1 at commit `52251dc`.

## Goal

A normal-user run, local or remote, gets the privileged checks without full root. Root runs only fixed command lines that a sudoers file names exactly, and none of them prints the contents of a file that may hold secrets. The audit never runs as root. The report says which checks ran and which were skipped.

## Requirements

1. Privileged checks run only through sudo rules for read-only commands with exact arguments (`dev/HANDOFF.md`, Requirements).
2. An install command, run with sudo, adds the rules when they are not already present (`dev/HANDOFF.md`, Requirements).
3. Remote mode gets the privileged checks without copying the script to the remote disk (`dev/HANDOFF.md`, Requirements and Design constraints).
4. `-h` prints the whole header comment block, with examples and the install steps (`dev/HANDOFF.md`, Pending item 1).
5. New checks: other accounts and root, sudoers contents, `bputil -d`, root `profiles show -type configuration` (Pending item 2).
6. The remote `--sudo` option is removed (Pending item 3).
7. The report lists the checks that ran and the ones that were skipped (Pending item 4).
8. The installer has the safeguards in `dev/HANDOFF.md` (Pending item 5).
9. The audit refuses to run as root (user decision A1, 2026-11-24).
10. The script picks its mode before any audit code runs, records every skipped check, and has a development test script (user decision A3).
11. The 1.1 bugs found in review are fixed (user decision B1). They are listed under 1.1 fixes.
12. A new check flags programs that run as root but that a user can write (user decision B2).
13. `VERSION` becomes 1.2.

## Decisions

- 2026-11-24: Approach B (per-command rules) over approach A (script in sudoers, pinned by SHA-256). Conviction: `ok`. Reasons: the Least privilege principle names exact commands, B keeps root away from the code that parses untrusted input, and remote mode stays copy-free. A was rejected for running the whole audit as root and for needing a reinstall on every script update.
- 2026-11-24: Run each privileged command directly with `sudo -n -k`, and classify a refusal from sudo's exit status and error message. This replaces the `sudo -n -k -l` probe in the handoff (see Verified facts). A probe with `-ll` that looks for `!authenticate` was rejected: it parses verbose output, and it costs a second sudo call per check.
- 2026-11-24: The rules name each file explicitly. Regex arguments (`^/etc/sudoers\.d/[^/]+$`) were rejected for now: they need sudo 1.9.10 or later, and older macOS versions are unverified.
- 2026-11-24: The `--sudo` option is removed without a deprecation period, because it has no external users.
- 2026-11-24 (A1): The audit refuses to run as root; root is used only by `--install-sudoers`. Conviction: `ok`. A root audit ran the parsing code as root with the caller's `PATH` and `HOME`, and wrote the report through `cp` to a predictable name. Rejected: a hardened root mode, which needs a fixed `PATH`, `curl -q`, `sqlite3 -init /dev/null`, and an exclusive report write, and still runs the parsers as root.
- 2026-11-24 (A2): Rules for other accounts show metadata and fingerprints only: `ssh-keygen -l`, `ls -ln`, `ls -lnd`, and one `ls -ln /var/at/tabs`. Conviction: `ok`. Rejected: `cat` rules for shell startup files, `authorized_keys`, and per-user `crontab -l`. Those give standing password-free read access to files that often hold tokens, and `cat` follows symlinks. Cost: the pattern search no longer covers other accounts' startup files.
- 2026-11-24 (A3): Mode dispatch, a record of every skipped check, and a `dev/test.sh` that is not shipped. Conviction: `ok`.
- 2026-11-24 (B1, B2): Version 1.2 includes the 1.1 fixes and one new check, root-run programs that a user can write. The other proposed checks are planned for 1.3 in `docs/ISSUES.md`. Conviction: `ok`.
- 2026-11-24: The sudoers check keeps the handoff's severities in 1.2 (`NOPASSWD: ALL` MEDIUM, other NOPASSWD LOW). Stronger sudoers checks are planned for 1.3.

## Verified facts

These were checked on the Mac mini on 2026-11-24.

- `sudo -n -k -l /sbin/pfctl -s info` exits 0 for the audit user with no mac-audit rule installed. The user has `(ALL) ALL` with a password, and `-l COMMAND` reports any matching rule, not only NOPASSWD rules. The handoff's probe would pass every check.
- `sudo -n -k true` exits 1 and prints `sudo: a password is required`.
- `sudo -l` works without a password for this user because the user has NOPASSWD entries. Under the default `listpw=any`, one NOPASSWD entry is enough.
- The Defaults for this user include `env_reset` and `env_keep+="HOME MAIL"`, and do not set `secure_path`. `env_reset` keeps the caller's `PATH` (`man sudoers`). A command run through sudo therefore sees the user's `PATH` and `HOME`. The user's `PATH` puts `~/.local/bin` and `/opt/homebrew/bin` before `/usr/bin`.
- `always_set_home` takes effect exactly when `HOME` is in `env_keep` (`man sudoers`). The rules set it for the mac-audit commands.
- `log_allowed` and `log_denied` are on by default (`man sudoers`), so each `sudo -n -k` call writes a log entry, allowed or refused. The Defaults for this user show `!log_allowed`, which is a local setting.
- sudo reads every file in `sudoers.d` except names that end in `~` or contain a `.` (`man sudoers`).
- `visudo -c -f FILE` runs without root and reports `parsed OK`.
- `bputil -d` asks interactively for a volume when the Mac has more than one bootable OS (`man bputil`).
- `/usr/lib/cron` links to `/var/at`. `/var/at/tabs` is `root:wheel 700`.
- `ssh-keygen -l -f ~/.ssh/authorized_keys` prints bits, fingerprint, comment, and key type, and never prints key data.
- `/usr/bin/readlink -f` resolves a symlink chain.
- `/var/root` is `root:wheel 750`. `/Users` is `root:admin 755`. `/usr/local/bin` is `root:wheel 755`.
- The macOS `awk` (20200816) does not support `\s`.
- `./mac-audit.sh -o` with no value loops forever: `shift 2` fails with one argument left.
- `kmutil showloaded --list-only` prints a UUID column (reported by the review agent; no third-party kexts are loaded here to confirm).
- Homebrew's `brew outdated` runs `brew update --auto-update` first, at most once a day by default (`utils/auto-update.sh`).
- `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` runs `/opt/homebrew/bin/cloudflared` as root. The program and its folder are owned by and writable by the audit user. The new check must flag it.

Assumptions not yet verified:

- `/etc/sudoers` contains an `includedir` line for `sudoers.d`. The installer checks it as root and warns when it is missing.
- The output formats of `bputil -d` and root `profiles show -type configuration` are unknown, because both need root. Test T9 confirms the allow-lists.
- The root-run program check may also flag root daemons inside `/Applications` app bundles, because `/Applications` is `root:admin 775`. The first run on this Mac shows how many fire (test T8), and the severity for admin-group write is settled then.
- `du` over protected home folders may raise privacy prompts for a terminal without Full Disk Access. Test T4 checks for prompts.

## Script structure

### Mode dispatch

The script parses all options first, then runs exactly one mode. Each mode is a function that ends in `exit`.

1. Set `PATH=/usr/bin:/bin:/usr/sbin:/sbin` and `umask 077`.
2. Parse the options. An option that needs a value and has none exits 2 with a usage error.
3. Pick the mode: `help`, `print-sudoers`, `install-sudoers`, `remote`, or `audit`. Conflicting modes exit 2.
4. Run the mode's function.

The `audit` mode refuses to run as root, with exit 2 and a message that points to the sudo rules. The `install-sudoers` mode refuses to run without root.

### Library guard

The functions come first, and the dispatch comes after this line:

```sh
[ "${MAC_AUDIT_LIB:-}" = 1 ] && return 0
```

`dev/test.sh` sources the script with `MAC_AUDIT_LIB=1` to load the functions without running a mode. Functions that hold logic worth testing read standard input or arguments and write standard output, with no calls to `dscl`, `sudo`, or the file system inside them:

- `gen_rules`: the rule generator.
- `classify_refusal`: decides whether sudo refused a command.
- `classify_sudoers`: finds NOPASSWD rules in sudoers text.
- `filter_bputil` and `filter_profiles`: the allow-lists.
- `rc_hits`: the startup-file pattern search, which reports file, line number, and pattern name.
- `ssh_methods_flag`: decides the SSH authentication flag from the offered methods.
- `clean_field`: strips control characters, tabs, pipes, and backticks from report text.

### Check record

Two helpers record what ran:

- `skip LABEL REASON` writes one line to `$TMP/skipped.tsv`. Every check that cannot run calls it, privileged or not. Examples: TCC unreadable, Time Machine settings unreadable, `--quick`, `--offline`, a refused sudo rule.
- `priv LABEL COMMAND ARGS...` runs one privileged command (see below) and writes `ran` or a skip.

The report header and Limitations are built from these records.

## Privileged commands

### The priv helper

1. If `/etc/sudoers.d/mac-audit` does not exist, call `skip LABEL "mac-audit sudo rules not installed"` and stop. No sudo call is made, so nothing is logged. The user can see the file's existence, because `sudoers.d` is mode 755.
2. Run `/usr/bin/sudo -n -k COMMAND ARGS...`, with standard error sent to a temporary file.
3. If `classify_refusal` reports a refusal, call `skip LABEL "refused or unavailable"` and print nothing. A refusal is exit status 1 with a standard error line that starts with `sudo:` or contains `is not allowed to execute`.
4. Otherwise, record `LABEL` as ran, and append the command's standard error to its output.

`-k` makes sudo ignore cached credentials, so a check runs only through a NOPASSWD rule. `-n` forbids a password prompt.

### Rule list

`--print-sudoers` and `--install-sudoers` both call `collect_accounts`, which reads the local users with `dscl` and the `sudoers.d` folder with `ls`, then pass the result to `gen_rules`. Neither step needs root.

```
# mac-audit 1.2 read-only rules for USER. Generated YYYY-MM-DD.
# Undo: sudo rm /etc/sudoers.d/mac-audit
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
    /bin/cat /etc/sudoers.d/FILE, \                  (one line per file present, and mac-audit)
    /bin/ls -ln /var/at/tabs, \
    /usr/bin/ssh-keygen -l -f HOME/.ssh/authorized_keys, \       (per account)
    /bin/ls -ln HOME/Library/LaunchAgents, \                     (per account)
    /bin/ls -lnd HOME/.zshrc HOME/.zprofile HOME/.zshenv HOME/.zlogin HOME/.bashrc HOME/.bash_profile HOME/.profile   (per account)
Defaults!MACAUDIT always_set_home
USER ALL = (root) NOPASSWD: MACAUDIT
```

- The accounts are root (home `/var/root`) and each local user with UID 501 or above, except the granted user. The granted user reads their own files without sudo.
- No rule prints file contents except the sudoers files, which hold policy, not secrets.
- `ssh-keygen -l` and `ls` print fingerprints and metadata even if a path is a symlink to another file. `ls -lnd` and `ls -ln` do not follow a final symlink.
- `/bin/ls -ln /var/at/tabs` shows which accounts have a crontab and when it changed. It covers accounts added after install.
- `always_set_home` gives the commands root's `HOME`, so no command reads or writes the user's home through `HOME`.
- `bputil -d` is left out on Intel Macs.
- Validation, applied before any value goes into a rule:
  - The granted user must exist, must not be root, and must have a UID of 501 or above.
  - Each account name must match `^[A-Za-z0-9_][A-Za-z0-9_.-]*$`.
  - Each home path must be `/var/root` or `/Users/NAME`, where `NAME` passes the account name test.
  - Each `sudoers.d` file name must match `^[A-Za-z0-9_-]+$`. sudo ignores names with a `.`, so the rule set never needs them.
  - An account or file that fails is skipped with a warning.
- The rules follow the handoff's rules for B: full paths, exact arguments, no `*`, no shell, interpreter, editor, or `sqlite3`.

### Installer

`--install-sudoers[=USER]` writes `/etc/sudoers.d/mac-audit`. `USER` defaults to `SUDO_USER`. The installer refuses to run when neither is set.

1. Refuse to run without root.
2. Run `visudo -c` on the current configuration, and stop if it fails. The installer never edits a configuration that is already broken.
3. Generate the rules into `$TMP`, and validate the file with `visudo -c -f`.
4. Check that the granted user cannot write any folder on the path to a file that a rule names. The check runs `sudo -u USER /bin/test -w FOLDER` for each folder from the parent up to `/`. If any folder is writable, stop and name it.
5. If `/etc/sudoers.d/mac-audit` exists with identical content, print "already installed" and stop. If it differs, print the differences.
6. Copy the old file, if any, to `$TMP`. Write the new file to `/etc/sudoers.d/.mac-audit.new` with owner root:wheel and mode 0440, then rename it to `mac-audit`.
7. Run `visudo -c`. If it fails, restore the old file or remove the new one, and exit with an error.
8. Verify from the granted user with `sudo -u USER /usr/bin/sudo -n -k /sbin/pfctl -s info >/dev/null`. This runs one read-only rule for real; the `-l` form would pass without the rule. It also fails when a later line in `/etc/sudoers` overrides the rule, because sudo applies the last matching entry. On failure, keep the file and print a warning, since the file is valid.
9. Warn when `/etc/sudoers` has no `#includedir` or `@includedir` line for `/private/etc/sudoers.d` or `/etc/sudoers.d`.
10. Print the undo command: `sudo rm /etc/sudoers.d/mac-audit`.

`--print-sudoers[=USER]` prints the generated file and exits. It needs no root. `USER` defaults to the current user.

`--install-sudoers` and `--print-sudoers` cannot be combined with each other. Both ignore the audit options (`-o`, `--quick`, `--offline`, `--skip-du`, `--stdout`).

The rules list accounts and `sudoers.d` files as they were at install time. Rerun `--install-sudoers` after adding a user or a `sudoers.d` file. The audit flags a `sudoers.d` file that no rule covers.

### Remote mode

- Every remote command uses absolute paths: `/bin/bash -c "$(/usr/bin/printf %s 'B64' | /usr/bin/base64 -D)"`. The remote `PATH` comes from user-writable startup files, so a bare `bash` or `sudo` could run a planted program.
- A remote audit runs as the SSH user. Each privileged check runs through `priv` on the remote Mac, so the rules installed there decide what runs.
- `--host ... --print-sudoers` runs the generator on the remote Mac.
- `--host ... --install-sudoers[=USER]` runs `/usr/bin/sudo /bin/bash -c ...` with `ssh -t`, so sudo can ask for the password on the terminal. `USER` defaults to the SSH user, because sudo sets `SUDO_USER` on the remote Mac. Nothing is copied to the remote disk.
- `--sudo` is removed.

## Checks

### New checks in section 15, "Privileged checks"

Section 15 always appears. A skipped check prints one line with its reason.

- **Sudoers contents.** Show the non-comment lines of `/etc/sudoers` and each readable `sudoers.d` file. `NOPASSWD: ALL` is MEDIUM. Another NOPASSWD rule outside the mac-audit file is LOW. A `sudoers.d` file with no matching rule is INFO: "rerun --install-sudoers". The mac-audit file itself raises no flag; the existing section 9 INFO flag for `sudoers.d` files excludes it.
- **Secure boot policy.** `bputil -d </dev/null`, so the volume prompt cannot block the run. `filter_bputil` keeps only lines that name the security mode, SIP, kernel extensions, or MDM, and drops any line that holds a UUID or a hex string of 32 characters or more. A security mode other than Full is MEDIUM.
- **Device profiles.** `profiles show -type configuration`. `filter_profiles` keeps only profile name, identifier, and organization lines.
- **Other accounts and root.** For each account in the rules:
  - `authorized_keys`: `ssh-keygen -l` output (bits, fingerprint, comment, type).
  - LaunchAgents: names, owners, and dates.
  - Shell startup files: owner, size, and date. A file owned by another account, or writable by group or others, is MEDIUM.
- **Crontabs.** `ls -ln /var/at/tabs`: one INFO flag per account with a crontab, with its date.

The existing root-only checks move to `priv`: `lsof` listeners, `sshd -T`, and `pf` in section 15, `sfltool dumpbtm` in section 9, and the two `du` lines in section 13. The per-PID `lsof -p` lookup in section 8 becomes one `lsof -nP -d txt -Fpn` map, built only when a listener has no absolute path. Without the rules, section 8 uses the user's own `lsof`, as now.

### New check in section 9: root-run programs that a user can write

For each `/Library/LaunchDaemons/*.plist` whose `UserName` is missing or `root`:

1. Read the program path with `plistprog`.
2. Build the chain: the plist, the program, the program's symlink target (`readlink -f`), and every folder above the program and the target, up to `/`.
3. Flag HIGH when any item in the chain is owned by an account other than root, or is writable by others, or is writable by the audit user (`[ -w ]`).

The finding names the plist, the program, and the first writable item. Group write by `admin` alone is covered by the audit user test when the audit user is an admin; its severity is confirmed in test T8.

## 1.1 fixes

| Fix | Requirement |
|---|---|
| Shell startup matches report file, line number, and pattern name, never the line text | No secrets |
| The startup scan adds `~/.zlogin`, `/etc/zshenv`, `/etc/zprofile`, `/etc/zlogin`, `/etc/bashrc`, and the patterns `bash -c "$(curl`, `wget ... \| sh`, `\| bash -s` | B1 |
| `authorized_keys` uses `ssh-keygen -l`, which also fixes the `awk \s` bug that printed the last word of an indented comment | No secrets, B1 |
| `kmutil` output drops the UUID column | No secrets |
| `clean_field` strips control characters, tabs, pipes, and backticks from every finding and table cell, so text from the audited Mac cannot add report rows | Security Context |
| Limitations says that evidence holds text from the audited Mac, to be treated as data, not instructions | Security Context |
| The SSH flag fires on `keyboard-interactive` as well as `password`; with the rules, it uses the `sshd -T` values | B1 |
| An option without its value exits 2 instead of looping | B1 |
| The home `du` passes `--` before the globs, so a file name that starts with `-` is not an option | Security Context, B1 |
| Truncated blocks end with "(truncated after N lines)" | B1 |
| The usage line names `mac-audit.sh`, not `scripts/mac-audit.sh` | B1 |
| `-h` prints the header block from line 2 to the first line that is not a comment, with examples and install steps | Requirement 4 |
| Homebrew is found at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`, because `PATH` is fixed. The fixed `PATH` keeps the installer's root run off user-writable folders | Security Context |

The root-mode crontab mix-up (`docs/ISSUES.md`) goes away with root mode.

## Report changes

- The header gains two lines: `Privileged checks: N ran, M skipped` and `Other checks skipped: K`.
- Limitations lists each skipped check with its reason. Its first bullet says that privileged checks need the mac-audit sudo rules.

## Side effects

`dev/HANDOFF.md` (Design constraints) lists the side effects of an audit. Version 1.2 adds or newly lists these, and the build updates that list and the `README.md` Limits:

- With the rules installed, sudo logs each privileged command. Without the rules, the script makes no sudo call.
- The SSH method check makes one SSH connection as `nobody` to `127.0.0.1`, which sshd logs.
- The installer, only when the user runs it, writes `/etc/sudoers.d/mac-audit`.
- The rules give the granted user password-free access to the listed commands outside the audit as well. Any process that runs as that user gets the same access. Only the sudoers files are shown in full.

## Out of scope

- The system TCC database. Reading it needs Full Disk Access as well as root, and a sudo rule cannot grant that.
- An `--uninstall-sudoers` option. The undo is one `rm` command, which the installer prints.
- Wrapping the 14 existing sections in functions, except where a section changes anyway.
- The other checks from the architecture review, planned for 1.3 in `docs/ISSUES.md`.

## How to continue if interrupted

- Branch: `feature/sudo-rules`. State lives in this doc, `sudo-rules-tests.md`, and `docs/ISSUES.md`.
- No code exists for 1.2 until the user approves the test plan.
- Installing the rules on any Mac needs the user's confirmation, per `AGENTS.md` (Security Context).
- Build order: mode dispatch and library guard, then the record helpers, then `gen_rules` and `dev/test.sh`, then the installer, then the checks and fixes, then the docs.
