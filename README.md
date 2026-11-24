# mac-audit

`mac-audit.sh` is a read-only health and security audit for macOS that writes one Markdown report.

## Why

The script turns a manual review of a Mac into a repeatable run. The report opens with a findings table sorted by severity (HIGH, MEDIUM, LOW, INFO), then a Limitations section, then the evidence for each check. A person or an LLM can review it.

## Usage

The script needs only stock macOS: `/bin/bash` 3.2 and built-in tools.

```sh
./mac-audit.sh                      # audit this Mac, write ./mac-audit-<host>-<date>.md
./mac-audit.sh --quick --offline    # skip log searches and update checks
./mac-audit.sh --host HOST --user USER --key ~/.ssh/KEY   # audit a remote Mac over SSH
./mac-audit.sh -h                   # all options
```

Remote mode sends the script inside the SSH command. Nothing is copied to the remote disk, and the report is saved on the local Mac.

## Limits

- The script makes no changes, with these side effects: a temporary folder under `/tmp` that is removed on exit, a refresh of Apple's update catalog cache (skip with `--offline`), one HTTP GET to each local network listener, and `nc -z` connect tests to the sharing ports.
- Without root, some checks are skipped. The sudo setup for privileged checks is planned for version 1.2 (`docs/ISSUES.md`).
- Remote mode has not been tested against a second Mac.

## Development

Check syntax with `bash -n mac-audit.sh`. The project history and verified facts are in `dev/HANDOFF.md`.
