# Security policy

This file says how to report a security problem in macassay and what counts as one. It does not cover the findings that an audit reports about a Mac.

## Reporting a vulnerability

Report privately through a GitHub security advisory: open the repository's **Security** tab and choose **Report a vulnerability**. Do not open a public issue for a security problem. There is no email address for reports.

## Supported versions

Only the latest release gets security fixes.

## In scope

- The sudoers rules that `--install-sudoers` writes, when a rule grants more than a read-only command with exact arguments.
- The installer, when it can leave `/etc/sudoers.d` in a state that breaks sudo.
- The audit changing the audited Mac beyond the side effects listed in `dev/HANDOFF.md`.
- Secrets reaching the report, such as serial numbers, UUIDs, key material, or shell startup file contents.
- Command injection from data read off the audited Mac, such as file contents, process names, or log lines.

## Out of scope

Findings in an audit's results are not security issues in macassay. A HIGH finding about your Mac describes your Mac, not a flaw in this project.
