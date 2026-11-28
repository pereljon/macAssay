---
kind: feature
lifecycle: shipped
status: drafted 2026-11-27 as a password prompt (B1, B2); replaced the same day by a key-only guide (E1, E2) after test M8; shipped in v1.5.4 (2026-11-28)
---

# Remote mode guide

This doc is the plan of record for the remote-mode section in `README.md` and a pointer to it in the SSH failure message. It also records why remote mode keeps requiring an SSH key instead of asking for a password. Test cases and review findings live in `remote-mode-guide-tests.md`.

Investigated against `macassay` 1.5.3 at commit `795e95a` on the development Mac (macOS 27.2.1, OpenSSH 10.5p1).

## Goal

A user who has never used remote mode can set it up from the README alone. When SSH fails, the error points to that section. Remote mode keeps signing in only with a key or the SSH agent, so a run never waits for input. No new finding ID, no new sudo rule, and no new side effect.

## Requirements

1. `README.md` has a remote-mode section: turning on Remote Login, the trade-off of "Allow full disk access for remote users", key setup, and the first host-key prompt for `localhost`. Source: the user, 2026-11-27 (`docs/ISSUES.md`, Planned).
2. Remote mode requires an SSH key or the SSH agent and never prompts. Source: approved by the user 2026-11-27 (E1).
3. The SSH failure message points to the README section. Source: approved by the user 2026-11-27 (E2).
4. macAssay creates no SSH key and does not edit `authorized_keys`. Source: decision of 2026-11-27 in `docs/ISSUES.md` (Decisions), `firm`.

## Current behavior

`remote_mode` (`macassay:1000`) opens one SSH connection to run `/usr/bin/uname -s` and check for `Darwin` (`macassay:1008`), then one for the audit (`macassay:1022`). Every connection passes `-o BatchMode=yes`, which turns off password, passphrase, and host-key prompts. A user with no working key, or with a host not yet in `known_hosts`, gets `SSH to HOST failed:` with the SSH error. The README mentions remote mode in two sentences and one example.

## Design

1. In `remote_mode`, add a second line to the message of the first SSH failure: `Remote mode signs in with an SSH key or the SSH agent; see Remote mode in README.md.` The later SSH calls run only after the first one succeeded, so they keep their messages.
2. Add `## Remote mode` to `README.md` after `## Full Disk Access (optional)`. It covers what remote mode does, that it never prompts, the one-time setup in numbered steps (Remote Login, `ssh-keygen`, the SSH agent for a key with a passphrase, `ssh-copy-id`, the first run), the host-key failure and `--known-hosts`, Full Disk Access over SSH and its trade-off, and installing the sudo rules over SSH.
3. Replace the remote-mode sentence under the usage examples with a link to the new section, and link the section from the Full Disk Access list.

The setup uses stock tools: `/usr/bin/ssh-keygen`, `/usr/bin/ssh-add`, and `/usr/bin/ssh-copy-id`, all present on the development Mac. The menu path for Remote Login comes from training knowledge and matches the guidance for MA-SHARING-008; test M2 checks it.

## Files

- `macassay`: the SSH failure message in `remote_mode`; `VERSION` becomes `1.5.3+dev`, as the version rule (fixture P16) requires for a changed script.
- `README.md`: the new section and two links.
- `CHANGELOG.md`, `docs/ISSUES.md`: the usual entries.

## Findings

M8 (2026-11-27), from the password-prompt build: to keep one password prompt per run, the build moved the `uname` check into the audit command and dropped the separate connection. Against a Linux host, `sshd` then refused the command with `/bin/bash: Argument list too long` before the check could run. The command holds the script as one base64 string of 245,032 bytes. Linux caps one argument at 128 KiB (`MAX_ARG_STRLEN`, training knowledge, consistent with the result). macOS caps all arguments together at 1 MiB (`getconf ARG_MAX`). The 1.5.3 code, with its short separate `uname` connection, reports `not macOS (uname: Linux)` on the same host (verified 2026-11-27). Fixes for a password prompt (compressing the script, sending it on stdin, or keeping two connections and two prompts) all cost more than requiring a key.

## Decisions

- 2026-11-27: One SSH connection per run, with the `uname` check in the remote command. Rejected: keeping the separate check, which asks for the password twice per audit; SSH connection sharing (`ControlMaster`), which leaves a background process and a socket to clean up when a run stops. `firm` (the user approved B1). Superseded by the entry of 2026-11-27 below (E1).
- 2026-11-27: In a terminal, let SSH ask to confirm an unknown host key, and list the known-hosts write as a side effect. Rejected: refusing unknown host keys and telling the user to connect once with `ssh` first. `firm` (the user approved B2). Superseded by the entry of 2026-11-27 below (E1).
- 2026-11-27: Remote mode requires an SSH key or the SSH agent, keeps `BatchMode=yes` for every connection, and never prompts. The README shows the one-time key setup. Reason: finding M8; every way to keep one password prompt per run adds code or a second transport, and key setup is a one-time step. Rejected: a password prompt with the script compressed (`gzip`, 81,656 bytes); a password prompt with the script on stdin; a password prompt with two connections and two prompts; copying the script with `scp`, which writes to the audited Mac, adds a connection, and would run a copied file as root for `--install-sudoers`. This withdraws the password-prompt item requested by the user on 2026-11-27. `firm` (the user approved E1).
- 2026-11-27: The first SSH failure message points to the README section. `firm` (the user approved E2).
