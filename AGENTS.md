# AGENTS.md

## Project

**macassay**: `macassay`, a read-only macOS health and security audit in Bash. It writes one Markdown report for a person or an LLM to review. It runs locally, or on a remote Mac over SSH. The script came from the network-manager project; `dev/HANDOFF.md` records its requirements, history, and verified facts.

## Design Principles

- **Read-only:** the script never changes the audited Mac. Every side effect is listed in `dev/HANDOFF.md` (Design constraints), and a new one needs the user's approval.
- **Stock macOS only:** the script runs under `/bin/bash` 3.2 and calls only tools that ship with macOS. Homebrew checks stay optional.
- **No secrets in the report:** omit serial numbers and UUIDs. Report key type and comment only from `authorized_keys`. Never copy shell startup file contents.
- **Least privilege:** privileged checks run only through sudo rules for read-only commands with exact arguments.

## Security Context

- Users: the user, auditing their own Macs, locally or over SSH.
- Untrusted input: everything read from the audited Mac (file contents, process names, listener responses, log lines). It must never be executed or used unquoted in a command.
- Costliest mistakes: a sudoers rule that grants more than a read-only command; a root run that executes user-writable code; secrets copied into a report; a broken `/etc/sudoers.d` file that locks sudo.
- Before you install sudoers rules or a root-owned copy on any Mac, confirm with the user. State the impact and the undo command.
- The user's full name may appear in `LICENSE` as the copyright holder. Keep it out of every other project file.

## Read First

`docs/ISSUES.md`, then `dev/HANDOFF.md`.

## Workflow

- Check syntax with `bash -n macassay`.
- Lint with `shellcheck macassay`. ShellCheck comes from Homebrew and is a development tool only; the script still uses stock tools. Three historical findings remain (`ls` parsing, SC2010 and SC2012); compare against the base branch to find the ones a diff adds.
- Run the fixture tests with `dev/test.sh`; they need no root and no network.
- Test run: `./macassay -o <path in the session temp folder>`, then review the report. A full local run takes about 3 minutes; `--quick --offline --skip-du` is faster.
- Do not commit generated reports. They describe a real Mac.

## Change Checklist

Project rows, in addition to `../AGENTS.md`:

- Help text: the header comment block in `macassay` matches the options.
- Version: `VERSION` in `macassay`.
