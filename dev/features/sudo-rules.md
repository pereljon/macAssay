---
kind: feature
lifecycle: designing
status: 2026-11-24 drafted for review
---

# Privileged checks through per-command sudo rules (version 1.2)

This doc is the plan of record for version 1.2: how privileged checks get root, the installer, the new checks, and the help text. Test cases and review findings live in `sudo-rules-tests.md`.

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64), sudo 1.9.17p2, and `mac-audit.sh` 1.1 at commit `52251dc`.

## Goal

A normal-user run, local or remote, gets the privileged checks without full root. Root runs only fixed, read-only command lines that a sudoers file names exactly. The report says which privileged checks ran and which were skipped.

## Requirements

Each requirement traces to `dev/HANDOFF.md` (Requirements set by the user, Pending work).

1. Privileged checks run only through sudo rules for read-only commands with exact arguments.
2. An install command, run with sudo, adds the rules when they are not already present.
3. Remote mode gets the privileged checks without copying the script to the remote disk.
4. `-h` prints the whole header comment block, with examples and the install steps.
5. New checks: other users and root, sudoers contents, `bputil -d`, root `profiles show -type configuration`.
6. The remote `--sudo` option is removed.
7. The report lists the privileged checks that ran and the ones that were skipped.
8. The installer has the safeguards in `dev/HANDOFF.md` (item 5).
9. `VERSION` becomes 1.2.

## Decisions

- 2026-11-24: Approach B (per-command rules) over approach A (script in sudoers, pinned by SHA-256). Conviction: `ok`. Reasons: the Least privilege principle names exact commands, B keeps root away from the code that parses untrusted input, and remote mode stays copy-free. A was rejected for running the whole audit as root and for needing a reinstall on every script update.
- 2026-11-24: Run each privileged command directly with `sudo -n -k`, and detect a refusal from sudo's own error message. This replaces the `sudo -n -k -l` probe in the handoff (see Verified facts). A probe with `-ll` that looks for `!authenticate` was rejected: it parses verbose output, and it costs a second sudo call per check.
- 2026-11-24: The rules name each file explicitly. Regex arguments (`^/etc/sudoers\.d/[^/]+$`) were rejected for now: they need sudo 1.9.10 or later, and older macOS versions are unverified.
- 2026-11-24: The LaunchAgents of other users are listed by name and date (`ls -l`), not parsed for program and signer. Parsing needs a read rule for each plist, which is unknown at install time.
- 2026-11-24: The `--sudo` option is removed without a deprecation period, because it has no external users.

## Verified facts

These were checked on the Mac mini on 2026-11-24.

- `sudo -n -k -l /sbin/pfctl -s info` exits 0 for the audit user with no mac-audit rule installed. The user has `(ALL) ALL` with a password, and `-l COMMAND` reports any matching rule, not only NOPASSWD rules. The handoff's probe would pass every check, so it cannot tell whether a rule is installed.
- `sudo -n -k true` exits 1 and prints `sudo: a password is required`. A real run without a NOPASSWD rule is refused, and the refusal is recognizable.
- `sudo -l` works without a password for this user because the user has NOPASSWD entries. Under the default `listpw=any`, one NOPASSWD entry is enough.
- `env_reset` keeps the caller's `PATH` unless `secure_path` is set (`man sudoers`), and the Defaults for this user do not set `secure_path`. The user's `PATH` puts `~/.local/bin` and `/opt/homebrew/bin` before `/usr/bin`. A run of `sudo ./mac-audit.sh` today resolves tools such as `sed` and `awk` through user-writable folders, so root can run user-writable code. Version 1.2 fixes this (see Script changes).
- sudo reads every file in `sudoers.d` except names that end in `~` or contain a `.` (`man sudoers`). A temporary file named `.mac-audit.new` is therefore ignored until it is renamed.
- `visudo -c -f FILE` runs without root and reports `parsed OK`.
- `bputil -d` asks interactively for a volume when the Mac has more than one bootable OS (`man bputil`). The check passes `</dev/null` so that the prompt cannot block the run.
- `/var/root` is `root:wheel 750`. `/Users` is `root:admin 755`.
- Tool paths: `/usr/sbin/lsof`, `/usr/sbin/sshd`, `/sbin/pfctl`, `/usr/bin/sfltool`, `/usr/bin/du`, `/usr/bin/crontab`, `/usr/bin/profiles`, `/usr/bin/bputil`, `/bin/cat`, `/bin/ls`, `/usr/sbin/visudo`.

Assumptions not yet verified:

- `/etc/sudoers` contains an `includedir` line for `sudoers.d`. The installer checks it as root and warns when it is missing.
- The output formats of `bputil -d` and root `profiles show -type configuration` are unknown, because both need root. The first run with the rules installed confirms the line filters (test plan T9).

## Design

### Privileged command helper

A new helper `priv LABEL COMMAND ARGS...` runs every privileged command. Callers pipe its output into the existing parsing code, which keeps running as the user.

1. If the script runs as root, run the command directly.
2. Otherwise, run `sudo -n -k COMMAND ARGS...`, with standard error sent to a temporary file.
3. If sudo refused the command, record `LABEL` as skipped and print nothing. sudo refuses with exit status 1 and a standard error line that starts with `sudo: `.
4. Otherwise, record `LABEL` as ran, and append the command's standard error to its output.

`-k` makes sudo ignore cached credentials, so a check runs only through a NOPASSWD rule. A refused check never asks for a password, because `-n` forbids prompts.

The helper writes one line per label to `$TMP/priv.tsv`: the label and `ran` or `skipped`.

### Rule list

`--print-sudoers` and `--install-sudoers` generate the same file. The generator reads the local users and the `sudoers.d` folder, which needs no root.

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
    /bin/cat /etc/sudoers.d/FILE,              (one line per file present, and mac-audit)
    /usr/bin/crontab -u NAME -l,               (per account below)
    /bin/cat HOME/.ssh/authorized_keys,        (per account below)
    /bin/ls -l HOME/Library/LaunchAgents,      (per account below)
    /bin/cat HOME/.zshrc,                      (and .zprofile .zshenv .bashrc .bash_profile .profile)
USER ALL = (root) NOPASSWD: MACAUDIT
```

- The accounts are root (home `/var/root`) and each local user with UID 501 or above, except the granted user. The granted user reads their own files without sudo.
- Rules for the six shell startup files are written whether or not each file exists, so creating one later needs no reinstall.
- Each user name must match `^[A-Za-z0-9_][A-Za-z0-9_.-]*$`. Each home path must match `^/[A-Za-z0-9_./-]+$`. The generator skips an account that fails either test and prints a warning. This keeps directory data out of sudoers syntax.
- `bputil -d` is left out on Intel Macs, where the tool does not apply.
- The rules follow the handoff's rules for B: full paths, exact arguments, no `*`, no shell, interpreter, editor, or `sqlite3`.

### Installer

`--install-sudoers[=USER]` writes `/etc/sudoers.d/mac-audit`. `USER` defaults to `SUDO_USER`. The installer refuses to run when neither is set.

1. Refuse to run without root.
2. Run `visudo -c` on the current configuration, and stop if it fails. The installer never edits a configuration that is already broken.
3. Generate the rules into `$TMP`, and validate the file with `visudo -c -f`.
4. Check that the granted user cannot write any folder on the path to a file that a `cat` or `ls` rule names. The check runs `sudo -u USER /bin/test -w FOLDER` for each folder from the parent up to `/`. If any folder is writable, stop and name it. This blocks a symlink that would point a rule at another file.
5. If `/etc/sudoers.d/mac-audit` exists with identical content, print "already installed" and stop. If it differs, print the differences.
6. Copy the old file, if any, to `$TMP`. Write the new file to `/etc/sudoers.d/.mac-audit.new` with owner root:wheel and mode 0440, then rename it to `mac-audit`.
7. Run `visudo -c`. If it fails, restore the old file or remove the new one, and exit with an error.
8. Verify from the granted user with `sudo -u USER /usr/bin/sudo -n -k /sbin/pfctl -s info >/dev/null`. This runs one read-only rule for real; the `-l` form would pass without the rule. The check also fails when a later line in `/etc/sudoers` overrides the rule, because sudo applies the last matching entry. On failure, keep the file and print a warning, since the file is valid.
9. Warn when `/etc/sudoers` has no `#includedir` or `@includedir` line for `/private/etc/sudoers.d` or `/etc/sudoers.d`.
10. Print the undo command: `sudo rm /etc/sudoers.d/mac-audit`.

`--print-sudoers[=USER]` prints the generated file and exits. It needs no root. `USER` defaults to the current user.

`--install-sudoers` and `--print-sudoers` cannot be combined with each other; the script exits with status 2. Both ignore the audit options (`-o`, `--quick`, `--offline`, `--skip-du`, `--stdout`).

The rules list users and `sudoers.d` files as they were at install time. Rerun `--install-sudoers` after adding a user or a `sudoers.d` file. The audit flags a `sudoers.d` file that no rule covers (see New checks).

### Remote mode

- A remote audit runs as the SSH user. Each privileged check runs through `priv` on the remote Mac, so the rules installed there decide what runs.
- `--host ... --print-sudoers` runs the generator on the remote Mac through the same encoded command.
- `--host ... --install-sudoers[=USER]` runs the installer on the remote Mac with `ssh -t` and `sudo` before the encoded command, so sudo can ask for the password on the terminal. `USER` defaults to the SSH user, because sudo sets `SUDO_USER` on the remote Mac. Nothing is copied to the remote disk.
- `--sudo` is removed.

### New checks

All new checks go in section 15, renamed "Privileged checks". Section 15 always appears now. A check that was skipped prints one line naming the missing rule.

- **Sudoers contents.** Show the non-comment lines of `/etc/sudoers` and each readable `sudoers.d` file. A `NOPASSWD: ALL` rule is MEDIUM. Another NOPASSWD rule outside the mac-audit file is LOW. A `sudoers.d` file with no matching rule is INFO: "rerun --install-sudoers".
- **Secure boot policy.** `bputil -d </dev/null`. The report keeps lines that name the security mode, SIP, kernel extension and MDM settings, and drops any line with a hex string of 32 characters or more. A security mode other than Full is MEDIUM.
- **Device profiles.** `profiles show -type configuration`. The report keeps profile names and identifiers, and drops UUIDs.
- **Other accounts and root.** For each account in the rules:
  - `authorized_keys`: key type and comment only, as for the audit user.
  - LaunchAgents: names and dates.
  - crontab: entry count, and the entries.
  - Shell startup files: the same pattern search as the audit user's files. Matching lines are shown; whole files never are.

The existing root-only checks move to `priv`: `lsof` listeners and `sshd -T` and `pf` in section 15, `sfltool dumpbtm` in section 9, and the two `du` lines in section 13. The per-PID `lsof -p` lookup in section 8 becomes one `lsof -nP -d txt -Fpn` map, built only when a listener has no absolute path.

### Report changes

- The header gains a line: `Privileged checks: N ran, M skipped`.
- Limitations lists each skipped check by label. Its first bullet changes to say that privileged checks need the mac-audit sudo rules or a root run.

### Script changes outside the new features

- The script sets `PATH=/usr/bin:/bin:/usr/sbin:/sbin` at the top. Homebrew is found at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`. As root, Homebrew still runs through `sudo -u USER`. This closes the root `PATH` problem in Verified facts.
- `-h` prints the header block from line 2 to the first line that is not a comment. The header gains examples and the install steps, and its usage line names `mac-audit.sh` without the old `scripts/` folder. This fixes the bug in `docs/ISSUES.md`.

## Side effects

The installer adds one side effect, and only when the user runs it: the file `/etc/sudoers.d/mac-audit`. An audit run adds no side effect. The rules give the granted user password-free read access to the named files outside the audit as well. Any process that runs as that user gets the same access.

## Out of scope

- The system TCC database. Reading it needs Full Disk Access as well as root, and a sudo rule cannot grant that.
- An `--uninstall-sudoers` option. The undo is one `rm` command, which the installer prints.

## How to continue if interrupted

- Branch: `feature/sudo-rules`. State lives in this doc, `sudo-rules-tests.md`, and `docs/ISSUES.md`.
- No code exists for 1.2 until the user approves the test plan.
- Installing the rules on any Mac needs the user's confirmation, per `AGENTS.md` (Security Context).
