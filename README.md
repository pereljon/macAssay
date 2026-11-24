# macassay

`macassay` is a read-only health and security audit for macOS that writes one Markdown report.

## Why

The script turns a manual review of a Mac into a repeatable run. The report opens with a findings table sorted by severity (HIGH, MEDIUM, LOW, INFO), then a Limitations section that lists every check that could not run, then the evidence for each check. A person or an LLM can review it.

## Usage

The script needs only stock macOS: `/bin/bash` 3.2 and built-in tools. Run it as a normal user; it refuses to audit as root.

```sh
./macassay                      # audit this Mac, write ./macassay-<host>-<date>.md
./macassay --quick --offline    # skip log searches and update checks
./macassay --host HOST --user USER --key ~/.ssh/KEY   # audit a remote Mac over SSH
./macassay -h                   # all options, examples, and install steps
```

Remote mode sends the script inside the SSH command. Nothing is copied to the remote disk, and the report is saved on the local Mac.

### Privileged checks

Some checks need root: all listeners, the packet filter, background items, sudoers contents, the secure boot policy, device profiles, and other accounts' keys, LaunchAgents, startup files, and crontabs. They run only through sudo rules that allow fixed read-only command lines. Without the rules, the report lists these checks as skipped.

1. Review the rules: `./macassay --print-sudoers`
2. Install them: `sudo ./macassay --install-sudoers`
3. Run the audit as usual.

The installer writes `/etc/sudoers.d/macassay` and checks it with `visudo` before and after. Undo it with `sudo rm /etc/sudoers.d/macassay`. Install again after you add a user or a `sudoers.d` file. For a remote Mac, run `./macassay --host HOST --install-sudoers`; it asks for the remote sudo password.

## Limits

- The audit makes no changes, with these side effects: a temporary folder under `/tmp` that is removed on exit; a refresh of Apple's update catalog cache and a Homebrew auto-update that changes no installed package (skip both with `--offline`); one HTTP GET to each local network listener; `nc -z` connect tests to the sharing ports; one SSH connection as `nobody` to this Mac; with the rules installed, sudo logs each privileged command.
- The rules let the granted user, and any process running as that user, run the listed commands without a password at any time. Only the sudoers files are shown in full; the other rules show fingerprints and file metadata.
- The system privacy (TCC) database is not checked: it needs Full Disk Access as well as root.
- Remote mode has not been tested against a second Mac.

## Development

- Check syntax with `bash -n macassay`, and lint with `shellcheck macassay` (ShellCheck from Homebrew, for development only).
- Run the fixture tests with `dev/test.sh`. They need no root and no network.
- The design of the sudo rules is in `dev/features/sudo-rules.md`. The project history and verified facts are in `dev/HANDOFF.md`.
