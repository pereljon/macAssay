# Remote mode guide: tests

This file holds the test plan for `remote-mode-guide.md` and the triage of its review findings. Results go under `## Results`.

## Test plan

The fixture suite cannot open an SSH connection, and no new fixture case is planned: the change is one message line and a README section.

### Run by the agent (no terminal)

- A1. `./macassay --host localhost --known-hosts EMPTY --quick --offline --skip-du -o TEMP`, where EMPTY is an empty file in the session temp folder. Pass: no prompt; the message shows SSH's error, then the README pointer; exit 1; EMPTY stays empty.
- A2. M8 from the password-prompt plan, kept as a regression check: an audit and `--print-sudoers` against a Linux host on the LAN with a working key. Pass: `not macOS (uname: Linux)` and exit 1.
- A3. `bash -n macassay`, `shellcheck macassay` (no finding beyond the three historical ones), and `dev/test.sh` (all cases pass).

### Run by the user (in iTerm)

- M1. Key mode, second Mac: from the Mac mini against the MacBook with `--key`, as in the 1.5 test M5. Pass: no prompt, and the report is written. The SSH code is unchanged, so this is a regression check only.
- M2. README walk-through: follow `## Remote mode` for a same-Mac audit (`localhost`) on a Mac with Remote Login off. Pass: each step, menu name, and command works as written, and the audit writes a report. The agent did not run `ssh-keygen`, `ssh-add`, or `ssh-copy-id`, because they change the user's keys and `authorized_keys`.

## Review findings

None yet.

## Results

- A1 (2026-11-27): pass. Output: `SSH to localhost failed: Host key verification failed.`, then the pointer line; exit 1.
- A2 (2026-11-27): pass. The audit and `--print-sudoers` each print `root@HOST is not macOS (uname: Linux).` and exit 1.
- A3 (2026-11-27): pass. Syntax check clean; ShellCheck shows only the three historical findings; 662 fixture cases pass.
- The password-prompt build ran A1 (pass) and M8 (fail, see Findings in `remote-mode-guide.md`) before it was replaced.
