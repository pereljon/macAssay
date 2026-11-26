---
kind: feature
lifecycle: designing
status: drafted 2026-11-26; waiting for the user's review
---

# Installed remote access, Find My, Homebrew detail, and run status (version 1.4)

This doc is the plan of record for version 1.4: three groups of new checks and two report display changes. Test cases and review findings live in `checks-1.4-tests.md`. Report formats, run comparison, CSV, and exit status by severity move to version 1.5 (decision 2026-11-26 below).

Investigated against macOS 27.2.1 (Darwin 27.2.0, arm64), Homebrew 7.0.16, and `macassay` 1.3.2 at commit `1cea63a`.

## Goal

Report remote-access tools that can start without the user, Find My and Activation Lock state, and Homebrew's supply-chain exposure. Show progress while the audit runs, and show the severity counts at the top of the report.

## Requirements

Each requirement traces to a `docs/ISSUES.md` item (Version 1.4), a user decision, or `AGENTS.md`.

1. The report lists each known remote-access tool that is installed, with where it was found, whether or not it runs. Source: `docs/ISSUES.md` (a run missed an installed Chrome Remote Desktop host).
2. The running-process match covers every tool in requirement 1. Source: `docs/ISSUES.md`.
3. The report states Find My Mac and Activation Lock status. No token or secret is read. Source: `docs/ISSUES.md`; `AGENTS.md` (No secrets).
4. The report counts outdated Homebrew formulae and casks separately and names them. It adds a count of casks that only `--greedy` reports. Source: `docs/ISSUES.md`.
5. The report lists third-party taps, the installed packages from each one, and the Homebrew security settings in register I018. Source: `docs/ISSUES.md`, `dev/prior-art-ideas.md` (I018).
6. The report lists cask apps whose quarantine attribute was removed. Source: `docs/ISSUES.md`.
7. After each section, the audit prints one status line on stderr with counts only. A total line ends the run. Source: `docs/ISSUES.md`.
8. The report header shows the per-severity counts, with HIGH and MEDIUM in bold. The counts below the findings table go away. Source: `docs/ISSUES.md`.
9. No emojis in the report or on stderr. Source: user decision B1, 2026-11-26.
10. No new sudo rule, no new side effect, stock tools under `/bin/bash` 3.2 only. Source: `AGENTS.md` (Design Principles).

## Decisions

- 2026-11-26: The 1.4 list splits in two. Version 1.4 takes the new checks (installed remote access, Find My, Homebrew detail). Version 1.5 takes `--format md|json|ocsf|html`, `--compare`, CSV, and exit status by severity. Rejected: one release, because the formats work is larger, needs its own review, and changes no check. Conviction: `ok`.
- 2026-11-26: No emojis in the report or the status line. Plain severity words read the same in a terminal, a Markdown viewer, and an LLM. They also keep column widths and `awk` fields simple under bash 3.2. Severity colors come with the 1.5 HTML format, through CSS. Rejected: an emoji before each severity word. Conviction: `ok`.
- Proposed, waiting for the user (question A3 in `docs/ISSUES.md`): the run status line and the header counts stay in 1.4. Neither depends on the 1.5 data export, and both are small.
- Proposed (question A4): `HOMEBREW_CASK_OPTS` is not checked for `--no-quarantine`. Homebrew 7.0.16 has no such option: `cask/download.rb` always quarantines a cask download, and `env_config.rb` lists the options that `HOMEBREW_CASK_OPTS` supports, which exclude it. The cask quarantine check (requirement 6) still finds apps installed by an older Homebrew with the option.
- Proposed (question A5): no notarization check for cask apps. `spctl --assess` can ask Apple's servers for a ticket when the app has none stapled. That is a new network side effect, and the `AGENTS.md` Read-only principle needs the user's approval for it. A stapled-ticket-only check (`stapler validate`) reports many notarized apps as not notarized. `codesign -dv` shows no notarization line for Docker.app, which is notarized.

## Verified facts

Checked on the development Mac (a Mac mini, M4 Pro), 2026-11-26, as the user without sudo:

- `system_profiler SPHardwareDataType` prints `Activation Lock Status: Disabled`. The Hardware block in section 1 already shows this line, because it removes only serial, UUID, and UDID lines.
- `/Library/Preferences/com.apple.FindMyMac.plist` is readable and holds one key, `FMMEnabled = 0`. The two sources agree on this Mac.
- `brew outdated --json=v2` takes 0.8 s, `brew outdated --quiet --cask --greedy` 0.3 s, `brew info --json=v2 --installed` 0.6 s, and `brew list --formula --full-name` 0.3 s, all with auto-update off.
- `brew tap` lists only third-party taps, because `homebrew/core` and `homebrew/cask` come from the API: `cirruslabs/cli`, `oven-sh/bun`, `pereljon/tap`, `steipete/tap` here.
- `brew list --formula --full-name` prints a tap-qualified name, such as `oven-sh/bun/bun`, for each package outside `homebrew/core`. `brew info --json=v2 --installed` left out `bun` here: it lists 200 formulae, while `brew list` lists 201. So the tap of each package comes from `brew list --full-name`.
- `osascript -l JavaScript` parses the 1 MB `brew info` JSON with `JSON.parse` in 0.06 s. It returns each cask's token, tap, app names, and `auto_updates` value. `JSON.parse` does not run code from its input.
- `plutil -extract formulae raw` reads JSON input and prints the array length (200).
- Cask apps installed by Homebrew carry `com.apple.quarantine` (Docker.app, OpenCode.app).
- Homebrew 7.0.16 (`bin/brew`, `export_homebrew_env_file`) reads `brew.env` from `/etc/homebrew/brew.env`, then `$HOMEBREW_PREFIX/etc/homebrew/brew.env`, then `$XDG_CONFIG_HOME/homebrew/brew.env` or `~/.homebrew/brew.env`. A line loads only when it starts with `HOMEBREW_`, `SUDO_ASKPASS=`, or a proxy variable. Proxy lines can hold a password, so the report never copies a line from these files.
- `HOMEBREW_VERIFY_ATTESTATIONS` (needs `gh`), `HOMEBREW_NO_VERIFY_ATTESTATIONS`, and `HOMEBREW_NO_INSECURE_REDIRECT` exist in `env_config.rb`.

## Assumptions to verify during the build

- `FMMEnabled` reads `1` when Find My is on (training knowledge; check on the MacBook).
- `Activation Lock Status` reads `Enabled` when Find My is on with a personal Apple Account (training knowledge; check on the MacBook).
- The remote-access names in "Check 1" come from the research in `checks-1.4-tests.md` (Sources). Each name without a primary source stays marked unverified there.

## Check 1: installed remote-access tools

### What it reads

A new function, `remote_access_installed`, lists names in these places, without opening any file:
- `/Applications`, `~/Applications`, and `/Library/Application Support`, one level deep.
- `/Library/LaunchDaemons`, `/Library/LaunchAgents`, and `~/Library/LaunchAgents`.
- `/Library/PrivilegedHelperTools`.
- `/opt`, one level deep, for agents that install there.

It matches each name, case-insensitively, against a fixed table of name fragments, one row per tool. The table lives in one variable, `REMOTE_TOOLS`, and both this check and `remote_support_names` read it, so requirement 2 holds by construction. Names on disk are untrusted input: they go through `clean_field` before they reach the report, and they are never run.

### Which tools

TeamViewer, AnyDesk, RustDesk, Chrome Remote Desktop, Splashtop, ConnectWise ScreenConnect, BeyondTrust (Bomgar), LogMeIn, GoTo Resolve, RealVNC Server, NoMachine, Parsec, Zoho Assist, Jump Desktop Connect, and Screens Connect. The fragments come from the research recorded in `checks-1.4-tests.md` (Sources). Viewer apps that only control other computers, such as RealVNC Viewer or Screens, do not count. Apple's own `AppleVNCServer` stays excluded.

### Report and findings

- The Sharing section lists each tool found, with the places it was found, such as `TeamViewer: app, launch daemon, helper`.
- MA-SHARING-013 stays as it is: MEDIUM when a tool runs.
- New, MA-SHARING-026, one finding per tool that is installed but not running:
  - MEDIUM when a launch daemon, launch agent, or privileged helper exists. That tool can start without the user and accept a connection.
  - LOW when only an app bundle exists. Someone must open it first.
- A tool that runs gives only MA-SHARING-013, so one tool never gives two findings.

## Check 2: Find My and Activation Lock

The Platform section gets two lines:
- `Find My Mac (FMMEnabled)`, read with `defaults read /Library/Preferences/com.apple.FindMyMac FMMEnabled`, through `default_line`.
- `Activation Lock`, taken from the Hardware output that section 1 already collects. The script keeps that output in a variable, so `system_profiler` runs once.

The check never reads NVRAM, so the `fmm-mobileme-token-FMM` variable stays unread.

New, MA-PLATFORM-019: Find My Mac is off. LOW on a Mac with an internal battery (a laptop can be stolen more easily), INFO otherwise. The battery test reuses the result of the 1.3 battery check's `pmset -g batt` test, kept in a variable. An MDM can turn off Activation Lock on purpose, so the finding text says to confirm the setting, not to change it.

## Check 3: Homebrew detail

### Outdated packages

With network checks on (no `--offline`):
1. `brew outdated --quiet --formula` and `brew outdated --quiet --cask` give two counts and two name lists. Each list prints through `block`, which truncates long lists.
2. `brew outdated --quiet --cask --greedy`, minus the plain cask list, gives the casks that update themselves or track `latest`. The report shows their count and names, with no finding: those apps update outside Homebrew.
3. MA-UPDATES-002 keeps its rule (LOW at 20 or more outdated packages), now counting formulae and casks together as before.

The first `brew outdated` call may run Homebrew's auto-update, as 1.3 does. The later calls fall within Homebrew's auto-update interval, so they add no network fetch. Under `--offline`, all three are skipped, as now.

### Taps and settings

These read only local files, so they run under `--offline` too:
1. `brew tap` lists third-party taps.
2. `brew list --formula --full-name` and `brew list --cask --full-name` give the packages from each third-party tap: a name with two slashes holds its tap.
3. The report lists each third-party tap with its packages.
4. New, MA-UPDATES-009, LOW: a third-party tap has no installed package. Its formula code still loads on `brew update`, for no use (register I018).
5. New, MA-UPDATES-010, INFO: installed packages come from third-party taps, with the count per tap.
6. For each name in `HOMEBREW_VERIFY_ATTESTATIONS`, `HOMEBREW_NO_VERIFY_ATTESTATIONS`, and `HOMEBREW_NO_INSECURE_REDIRECT`, the report says whether it is set, and from where: the audit's environment or a `brew.env` file. The check uses `grep -c` on each file for the exact `NAME=` prefix, so no line text reaches the report. Values are never printed.

The audit's environment is the shell that started it. In remote mode, it is the SSH session's environment, which can differ from the user's terminal. The Limitations section says so.

### Cask quarantine

1. `brew info --json=v2 --installed` writes JSON to the temporary folder.
2. A fixed JXA script (`osascript -l JavaScript`) prints each cask's token and app names. The script text is a constant in `macassay`.
3. Each app name must end in `.app` and contain no `/`. The check then reads `xattr -p com.apple.quarantine` on `/Applications/NAME` and `~/Applications/NAME`.
4. New, MA-UPDATES-011, LOW: one finding that lists each cask app with no quarantine attribute. One fix covers them all (1.3 rule on collapsing findings).

## Display 1: run status on stderr

`h2` already prints `== TITLE` on stderr when a section starts. At the start of the next section, and once before the report is assembled, the audit prints the finished section's line:

```text
[3/14] Updates and installs: 2 findings (1 MEDIUM, 1 LOW), 1 check skipped, 12 s
```

- The counts are the lines that `findings.tsv` and `skipped.tsv` gained during the section. Seconds come from bash's `SECONDS`.
- A severity with no finding is left out. A section with no finding prints `0 findings`.
- The line holds counts and the section title only, never finding text, which can hold text from the audited Mac.
- The total line reads `Total: 9 findings (2 HIGH, 3 MEDIUM, 4 LOW), 5 checks skipped, 3 min 4 s`.
- The section count, 14, is a constant. A fixture test counts the `h2` calls with a number in `macassay` and compares.
- A count of checks run is left out, per `docs/ISSUES.md`.

## Display 2: counts in the header

The header gets one line after "Other checks skipped":

```text
- Findings: **2 HIGH**, **3 MEDIUM**, 4 LOW, 1 INFO
```

The line shows all four severities, including a count of 0. With no findings, the line reads `- Findings: none`. The per-severity list below the findings table is removed.

## Side effects

No new side effect. `osascript` runs a fixed script that reads a file in the temporary folder. The `brew` calls are the read-only commands listed above. `brew outdated` keeps its existing, listed auto-update.

## Out of scope

- Version 1.5: report formats, `--compare`, CSV, exit status by severity.
- Notarization of cask apps (decision A5, proposed).
- Reading Find My state from iCloud account files.

## How to continue if interrupted

1. Read `docs/ISSUES.md` (Version 1.4 and the open questions A3 to A5).
2. Read this doc and `checks-1.4-tests.md`.
3. Run `git status` on `feature/checks-1.4`.
