---
kind: feature
lifecycle: designing
status: drafted 2026-11-27; B1 and B2 approved by the user 2026-11-27; awaiting review of this doc
---

# Password prompt and guide for remote mode

This doc is the plan of record for two remote-mode items in `docs/ISSUES.md`: an SSH password prompt when macAssay runs in a terminal, and a remote-mode section in `README.md`. Test cases and review findings live in `remote-password-tests.md`.

Investigated against `macassay` 1.5.3 at commit `795e95a` on the development Mac (macOS 27.2.1, OpenSSH 10.5p1).

## Goal

A user who runs `./macassay --host HOST` in a terminal can sign in with a password and types it once per run. A run without a terminal never waits for input. The README explains how to set up remote mode. No new finding ID and no new sudo rule.

## Requirements

1. In a terminal, remote mode lets SSH ask for a password. Source: the user, 2026-11-27 (`docs/ISSUES.md`, Planned).
2. One run asks for the password once. Source: approved by the user 2026-11-27 (B1).
3. A run without a terminal fails instead of waiting for input. Source: `--fail-on` exists for scheduled runs (`docs/FORMATS.md`), and a scheduled run that waits never ends.
4. macAssay creates no SSH key and does not edit `authorized_keys`. Source: decision of 2026-11-27 in `docs/ISSUES.md` (Decisions), `firm`.
5. In a terminal, SSH may ask to confirm an unknown host key, and a yes adds the key to the known-hosts file. The run lists this as a side effect. Source: approved by the user 2026-11-27 (B2); a new side effect needs the user's approval (`AGENTS.md`, Design Principles).
6. `README.md` gains a remote-mode section: turning on Remote Login, the trade-off of "Allow full disk access for remote users", key or password sign-in, and the first host-key prompt for `localhost`. Source: the user, 2026-11-27 (`docs/ISSUES.md`, Planned).
7. Stock tools under `/bin/bash` 3.2. Source: `AGENTS.md` (Design Principles).

## Current behavior

`remote_mode` (`macassay:1000`) opens two SSH connections for an audit. The first runs `/usr/bin/uname -s` and checks for `Darwin` (`macassay:1008`). The second runs the audit (`macassay:1022`). `--print-sudoers` and `--install-sudoers` also run the `uname` check first, then their own connection. Every connection passes `-o BatchMode=yes`, which turns off password, passphrase, and host-key prompts. A user with no working key, or with a host not yet in `known_hosts`, gets `SSH to HOST failed` with the SSH error.

## Verified facts

Checked on the development Mac on 2026-11-27, with `expect` giving SSH a pseudo-terminal:

- With a terminal and stdin redirected from `/dev/null`, SSH without `BatchMode` asks to confirm an unknown host key and then asks for the password, both on the terminal. Each `ssh` call in `remote_mode` redirects stdin from `/dev/null` (except `--install-sudoers`), so the prompts still reach the user.
- With no terminal, SSH without `BatchMode` prints `Host key verification failed.` and exits 255 at once. It does not wait.

From training knowledge, not verified: OpenSSH reads the password through `/dev/tty`, not stdin, and uses `SSH_ASKPASS` only when `DISPLAY` or `SSH_ASKPASS_REQUIRE` is set. `ConnectTimeout` covers the connection and the banner exchange, not the time a user takes to type the password. Test M2 checks the timeout point.

## Design

### 1. One connection per run

The `uname` check moves into the remote command, so each mode opens one connection.

1. Add a remote prefix: `[ "$(/usr/bin/uname -s)" = Darwin ] || exit 97;`. The remote login shell runs it before the script. The current remote command already relies on `$( )` in that shell.
2. The audit, `--print-sudoers`, and `--install-sudoers` each send the prefix followed by their current command. For `--install-sudoers`, the prefix runs before `/usr/bin/sudo`, so a non-macOS host never sees a sudo prompt.
3. Map the SSH exit status the same way for all three modes:
   - 255: `SSH to TARGET failed.` with exit 1. SSH has already printed its own error on stderr, because no call captures stderr.
   - 97: `TARGET is not macOS.` with exit 1.
   - Other non-zero, audit only: `Remote audit failed (exit N).`, as today. `--print-sudoers` and `--install-sudoers` pass the status through, as today.
4. Delete the separate `uname` call.

Exit 97 is outside the statuses macAssay uses (0 to 3), so a remote macAssay run cannot return it. The local exit statuses in `docs/FORMATS.md` do not change.

### 2. Prompts only in a terminal

`remote_mode` adds `-o BatchMode=yes` only when stdin is not a terminal (`[ -t 0 ]` fails). In a terminal, SSH may then ask for:
- the password, when no key works;
- a key passphrase, when the key is encrypted and not in the agent;
- a yes to an unknown host key. A yes writes the key to `~/.ssh/known_hosts`, or to the `--known-hosts` file.

`BatchMode` stays for runs without a terminal, although SSH already fails there (Verified facts). It keeps SSH from starting an askpass program in an environment that sets `SSH_ASKPASS`.

### 3. Side effect

Add one side effect to the list in `dev/SKELETON.md` (Key Invariants) and `README.md` (Limits): in remote mode in a terminal, a yes to an unknown host key adds it to the known-hosts file on the Mac that runs macAssay. In a same-Mac audit over SSH, that Mac is also the audited Mac. SSH writes the file only after the user types yes.

### 4. README section

Add `## Remote mode` after `## Full Disk Access (optional)`. Move the remote-mode sentence under the usage examples into it. The section covers, in this order:

1. What remote mode does: the script runs on the other Mac inside the SSH command, and the report is saved on this Mac.
2. Turn on Remote Login on the audited Mac: System Settings, General, Sharing, Remote Login. The menu path is from training knowledge and the existing guidance for MA-SHARING-008; test M6 checks it.
3. Sign-in: a key with `--key`, or a password typed at the prompt when run in a terminal. Without a terminal, only a key or the SSH agent works. macAssay never creates a key or edits `authorized_keys`.
4. The first connection asks to confirm the host key, also for `localhost`. A yes adds it to `~/.ssh/known_hosts`. `--known-hosts FILE` uses another file.
5. "Allow full disk access for remote users": it gives every account that may sign in over SSH (the "Allow access for" list) Full Disk Access, from any machine that reaches the Mac, while Remote Login is on. Turn it off after the run unless you need it. Link to `## Full Disk Access (optional)`.
6. Sudo rules on the remote Mac: `--host HOST --install-sudoers` asks for the SSH password if no key works, then for the remote sudo password.

### 5. Help text

In the header comment of `macassay`, add one line under Remote mode: in a terminal, SSH may ask for a password, a key passphrase, or a yes to a new host key; without a terminal it needs a key or the SSH agent.

## Files

- `macassay`: `remote_mode`, the header comment.
- `README.md`: the new section, the Limits list.
- `dev/SKELETON.md`: Logic Flow step 3 and the side-effect list.
- `CHANGELOG.md`, `docs/ISSUES.md`: the usual entries.

## Decisions

- 2026-11-27: One SSH connection per run, with the `uname` check in the remote command. Rejected: keeping the separate check, which asks for the password twice per audit; SSH connection sharing (`ControlMaster`), which leaves a background process and a socket to clean up when a run stops. `firm` (the user approved B1).
- 2026-11-27: In a terminal, let SSH ask to confirm an unknown host key, and list the known-hosts write as a side effect. Rejected: refusing unknown host keys and telling the user to connect once with `ssh` first. `firm` (the user approved B2).
- 2026-11-27: Decide interactivity with `[ -t 0 ]`. Rejected: testing whether `/dev/tty` opens, which also prompts when stdin is redirected in a terminal; a redirected stdin is the usual sign of a script.
- 2026-11-27: No option to force batch mode. Redirecting stdin from `/dev/null` already does it, and no requirement asks for an option.
