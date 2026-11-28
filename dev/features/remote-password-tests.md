# Password prompt and guide for remote mode: tests

This file holds the test plan for `remote-password.md` and the triage of its review findings. Results go under `## Results` after the build.

## Test plan

The fixture suite cannot open an SSH connection, so most cases are manual. `remote_mode` calls `/usr/bin/ssh` by its absolute path, and no stub can replace it. No new fixture case is planned: a test of the option list would only mirror the code.

### Run by the agent (no terminal)

- A1. `./macassay --host localhost --known-hosts EMPTY --quick --offline --skip-du -o TEMP`, where EMPTY is an empty file in the session temp folder. Pass: the run ends at once with `SSH to localhost failed.` and exit 1, and no prompt appears. Stdin is not a terminal, so `BatchMode=yes` applies.
- A2. The same run with a key that works for `localhost`, if one exists. Pass: a report is written, and SSH logs one connection, not two. If no key exists, skip and record it.
- A3. `bash -n macassay`, `shellcheck macassay` (no finding beyond the three historical ones), and `dev/test.sh` (all cases pass).

### Run by the user (in iTerm)

Run these from the user's terminal (`AGENTS.md`, Workflow). Each uses `--known-hosts TEMPFILE` unless it says otherwise, so the real `~/.ssh/known_hosts` stays untouched.

- M1. Password, same Mac: Remote Login on, no key that `localhost` accepts, in the agent or in `~/.ssh` (`SSH_AUTH_SOCK= ./macassay --host localhost --known-hosts TEMPFILE --quick --offline --skip-du -o TEMP`). Pass: one host-key prompt; after yes, one password prompt; the report is written; `TEMPFILE` now holds the `localhost` key.
- M2. Slow password: as M1 with `TEMPFILE` from M1, and wait 20 seconds before typing the password. Pass: the run still signs in (`ConnectTimeout` is 10 seconds).
- M3. Wrong password three times. Pass: SSH's own error, then `SSH to localhost failed.` and exit 1.
- M4. Not a terminal: `./macassay --host localhost --known-hosts TEMPFILE --quick --offline --skip-du -o TEMP </dev/null`. Pass: no prompt, `SSH to localhost failed.`, exit 1, within a few seconds.
- M5. Key mode, second Mac: from the Mac mini against the MacBook with `--key`, as in the 1.5 test M5. Pass: no prompt, the report is written, and it matches a 1.5.3 report from the same pair in layout.
- M6. README walk-through: follow the new `## Remote mode` section on a Mac with Remote Login off. Pass: each step and menu name matches the Mac.
- M7. `--host localhost --print-sudoers` and `--host localhost --install-sudoers` with password sign-in. Pass: one SSH password prompt each; the installer then asks for the sudo password and installs the rules. Before running the installer, the agent confirms with the user, with the impact and the undo command (`AGENTS.md`, Security Context).
- M8. Non-macOS host, if the user has one (for example a Linux server or a container with SSH). Pass: `HOST is not macOS.` and exit 1, with no sudo prompt for `--install-sudoers`. If none exists, skip and record it.

### Edge cases covered by review

- The prefix runs in the remote login shell. A shell that cannot parse `$( )` already fails the current remote command, so the prefix adds no new failure.
- A remote startup file that prints to stdout puts text before the bundle, and `read_bundle` rejects it, as today.

## Review findings

None yet.

## Results

None yet.
