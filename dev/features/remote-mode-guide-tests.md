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
- M2 (2026-11-27, the user, in iTerm on the Mac mini): pass. Remote Login menu path, "Allow access for", and "Allow full disk access for remote users" match the README. The user's key was already in `authorized_keys`, so step 4 was skipped; the first audit then failed with `Host key verification failed` and the README pointer, and the README's fix (connect once with `ssh`) worked. The audit over SSH wrote a report with no prompt (63 findings, 22 s). Follow-ups, approved by the user (G2, G3): step 4 now says what to do when the key is already on the Mac; the README and `docs/CHECKS.md` said one status line per section, while every run prints two (`h2`, `sect_end`), and now say two.
- M1: not run; optional, since the SSH code is unchanged.
- Release side-effect checks (2026-11-28, version 1.5.4, run over SSH to 127.0.0.1, a session with Full Disk Access, with the sudo rules installed; the user authorized the release):
  1. Login records: pass. Under `ssh -tt` (`/dev/ttys025`), `last | wc -l` read 152 before and after a `script -q /dev/null ./macassay --quick --offline --skip-du` run in which 15 privileged checks ran.
  2. Network: pass. `nettop -P -x -L 330 -s 1` logged a full `--offline` run (219 s, 17 privileged checks). The audit's processes with traffic were 13 `curl` probes and one `ssh` probe of the Mac's own listeners; `sshd-auth`, `smbd`, and `screensharingd` answered them. `trustd` (not started by the audit) exchanged about 13.2 KB in and 13.8 KB out in one second, 131 s into the run, during section 1 (System health, 0 to 180 s), then about 30 bytes every 6 to 20 s. Other processes with traffic (`dataaccessd`, `gh`, `node`, browsers, sync clients) belong to other apps.
- The password-prompt build ran A1 (pass) and M8 (fail, see Findings in `remote-mode-guide.md`) before it was replaced.
