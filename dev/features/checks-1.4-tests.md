# Test plan: installed remote access, Find My, Homebrew detail, and run status

This file holds the test cases, review findings, results, and research sources for `checks-1.4.md`. It does not repeat the design.

Two kinds of test cover version 1.4:
- `dev/test.sh` runs the new functions on fixtures, without root and without the network. The new cases are R1 to R10.
- Manual runs on the development Mac and the MacBook cover real output. Reports go to the session temp folder and are never committed.

## Before code

- B1. Run `dev/test.sh`, `bash -n macassay`, and `shellcheck macassay` on `master`, and record the counts. ShellCheck should show the three historical findings (SC2010, SC2012).

## dev/test.sh (fixture tests)

- R1. `remote_access_installed` on a fixture tree (fake `/Applications`, LaunchDaemons, LaunchAgents, PrivilegedHelperTools, and `/opt` folders under the test folder):
  - A Chrome Remote Desktop helper with no app reports as `helper`.
  - A TeamViewer app plus a launch daemon reports once, with both places.
  - `AppleVNCServer`, `RealVNC Viewer.app`, and `Screens 5.app` report nothing.
  - A name with spaces, a leading `-`, or `$(touch PWNED)` is matched or ignored as text, and no `PWNED` file appears.
- R2. `remote_support_names` matches each tool's process fragment from `REMOTE_TOOLS`, and still excludes `AppleVNCServer`. The existing `rs` cases pass.
- R3. The MA-SHARING-026 rule: a launchd plist or helper gives MEDIUM; an app alone gives LOW; a tool that also runs gives no MA-SHARING-026.
- R4. Find My: `FMMEnabled` 0 with a battery gives MA-PLATFORM-019 LOW; 0 without a battery gives INFO; 1 gives nothing; a missing key prints the `default_line` text and gives nothing.
- R5. Greedy casks: the greedy list minus the plain list keeps only the casks absent from the plain list, and an empty difference prints "none".
- R6. Taps: fake `brew tap` and `brew list --full-name` output gives each third-party tap with its packages. A tap with no package gives MA-UPDATES-009. Core packages (no slash) do not count.
- R7. Homebrew settings: fake `brew.env` files with the three names, a proxy line holding `user:secret@`, and a comment. The report says which names are set and where. No line text, and no `secret`, appears in the output.
- R8. Cask quarantine: the JXA script on a fixture JSON prints token and app names. An app name holding `/` or `..`, or not ending in `.app`, is skipped. A test app with no quarantine attribute gives one MA-UPDATES-011 finding that lists it.
- R9. Status line: a fake section that adds two findings (MEDIUM, LOW) and one skip prints `[3/14] TITLE: 2 findings (1 MEDIUM, 1 LOW), 1 check skipped, N s`. A section with none prints `0 findings` and `0 checks skipped`. The line holds no finding text.
- R10. Header and section count:
  - The header line reads `- Findings: **2 HIGH**, **1 MEDIUM**, 3 LOW, 0 INFO` for a fixture `findings.tsv`, and `- Findings: none` for an empty one.
  - The number of numbered `h2` calls in `macassay` equals the section constant.

## Manual tests

- M1. On the development Mac, run `./macassay --quick --skip-du -o <session temp folder>/m1.md`. Pass:
  - The Sharing section lists installed remote-access tools, or "none".
  - The Platform section shows `Find My Mac` and `Activation Lock`.
  - The Updates section shows formula, cask, and greedy counts, the four third-party taps with their packages, the three settings, and the cask quarantine result.
  - stderr shows 14 status lines and one total line, with no finding text.
  - The header shows the severity counts, and the findings table has no counts below it.
- M2. Run `./macassay --quick --offline --skip-du`. Pass: outdated counts are skipped; taps, settings, and cask quarantine still run.
- M3. On the MacBook, with Find My on, run a full audit. Pass: `FMMEnabled` reads 1 and Activation Lock reads `Enabled` (the two assumptions in the design).
- M4. Check the report from M1 for secrets: no `brew.env` line text, no proxy value, no NVRAM read.

## Sources

The research on remote-access tool names (bundle, process, launchd, helper) is recorded here with its URLs once it returns.

## Review findings

None yet.

## Results

None yet.
