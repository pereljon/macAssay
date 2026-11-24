#!/bin/bash
# mac-audit.sh - read-only health and security review of a Mac, written as a Markdown report.
#
# The script makes no changes. It reads settings, logs and process state, and sends
# HTTP GET requests to this Mac's own network listeners to see which ones ask for a login.
# `softwareupdate -l` refreshes Apple's update catalog cache; use --offline to skip it.
#
# The only file it writes on the audited Mac is a temporary folder under /tmp, removed on exit.
#
# Usage: scripts/mac-audit.sh [options]
#   -o FILE          write the report to FILE (default: ./mac-audit-<host>-<date>.md)
#   --quick          skip the slow unified-log searches (XProtect, SSH failures)
#   --offline        skip softwareupdate and Homebrew update checks
#   --skip-du        skip the home-folder disk usage scan
#   --stdout         write the report to standard output instead of a file
# Remote mode (audit another Mac over SSH; the report is saved on this Mac):
#   --host HOST      remote host name or IP; without it the script audits this Mac
#   --user USER      remote user (default: your SSH config or local user name)
#   --key PATH       SSH private key (adds IdentitiesOnly=yes)
#   --port N         SSH port (default 22)
#   --known-hosts F  known_hosts file to use for the host key check
#   --sudo           run the remote audit as root with `sudo -n` (needs passwordless sudo)
# Run locally with sudo to add root-only checks (all listeners, sshd -T, pf, background items, /Users usage).
# Bash 3.2 compatible (macOS /bin/bash). No Python or Homebrew tools required.
# Remote mode sends the script inside the SSH command; nothing is copied to the remote disk.

VERSION="1.1 (2026-11-24)"
OUT=""; QUICK=0; OFFLINE=0; SKIPDU=0; STDOUT=0
RHOST=""; RUSER=""; RKEY=""; RPORT=""; RKH=""; RSUDO=0
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    --quick) QUICK=1; shift ;;
    --offline) OFFLINE=1; shift ;;
    --skip-du) SKIPDU=1; shift ;;
    --stdout) STDOUT=1; shift ;;
    --host) RHOST="$2"; shift 2 ;;
    --user) RUSER="$2"; shift 2 ;;
    --key) RKEY="$2"; shift 2 ;;
    --port) RPORT="$2"; shift 2 ;;
    --known-hosts) RKH="$2"; shift 2 ;;
    --sudo) RSUDO=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# ---------- remote mode ----------
if [ -n "$RHOST" ]; then
  [ -f "$0" ] || { echo "Remote mode needs the script file on disk." >&2; exit 2; }
  TARGET="$RHOST"; [ -n "$RUSER" ] && TARGET="$RUSER@$RHOST"
  SSHO=(-o BatchMode=yes -o ConnectTimeout=10)
  [ -n "$RKEY" ] && { [ -r "$RKEY" ] || { echo "Cannot read key: $RKEY" >&2; exit 2; }; SSHO+=(-i "$RKEY" -o IdentitiesOnly=yes); }
  [ -n "$RPORT" ] && SSHO+=(-p "$RPORT")
  [ -n "$RKH" ] && SSHO+=(-o UserKnownHostsFile="$RKH")
  OS=$(/usr/bin/ssh "${SSHO[@]}" "$TARGET" uname -s </dev/null 2>&1) || { echo "SSH to $TARGET failed: $OS" >&2; exit 1; }
  [ "$OS" = Darwin ] || { echo "$TARGET is not macOS (uname: $OS)." >&2; exit 1; }
  PASS="--stdout"; [ "$QUICK" -eq 1 ] && PASS="$PASS --quick"; [ "$OFFLINE" -eq 1 ] && PASS="$PASS --offline"; [ "$SKIPDU" -eq 1 ] && PASS="$PASS --skip-du"
  B64=$(base64 < "$0" | tr -d '\n')
  RCMD="bash -c \"\$(printf %s '$B64' | base64 -D)\" mac-audit $PASS"
  [ "$RSUDO" -eq 1 ] && RCMD="sudo -n $RCMD"
  [ -n "$OUT" ] || OUT="./mac-audit-${RHOST}-$(date +%Y%m%d-%H%M).md"
  echo "Auditing $TARGET over SSH..." >&2
  /usr/bin/ssh "${SSHO[@]}" "$TARGET" "$RCMD" </dev/null > "$OUT.part"; RC=$?
  if [ "$RC" -ne 0 ] || [ ! -s "$OUT.part" ]; then
    echo "Remote audit failed (exit $RC).$([ "$RSUDO" -eq 1 ] && echo ' With --sudo, the remote user needs passwordless sudo.')" >&2
    rm -f "$OUT.part"; exit 1
  fi
  mv "$OUT.part" "$OUT"; echo "Report written to $OUT" >&2; exit 0
fi

HOST=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
NOW=$(date "+%Y-%m-%d %H:%M %Z")
[ -n "$OUT" ] || OUT="./mac-audit-${HOST}-$(date +%Y%m%d-%H%M).md"
if [ "$(id -u)" -eq 0 ]; then ROOT=1; TUSER="${SUDO_USER:-$(stat -f %Su /dev/console)}"; else ROOT=0; TUSER="$(id -un)"; fi
THOME=$(dscl . -read "/Users/$TUSER" NFSHomeDirectory 2>/dev/null | awk '{print $2}'); [ -n "$THOME" ] || THOME="$HOME"

TMP=$(mktemp -d /tmp/mac-audit.XXXXXX) || exit 1
trap 'rm -rf "$TMP"' EXIT
BODY="$TMP/body.md"; FIND="$TMP/findings.tsv"; : > "$BODY"; : > "$FIND"

# ---------- helpers ----------
say()  { printf '%s\n' "$*" >> "$BODY"; }
h2()   { say ""; say "## $*"; say ""; echo "== $*" >&2; }
h3()   { say ""; say "### $*"; say ""; }
clean(){ sed -e 's/```/'"'''"'/g'; }                       # keep code fences intact
# run "title" command...  -> command and its output in a code block
run()  { local t="$1"; shift; say "**$t**"; say ""; say '```text'; say "\$ $*"
         ( "$@" ) 2>&1 | clean | head -n "${MAXL:-80}" >> "$BODY"; say '```'; say ""; }
# block "title" < text
block(){ say "**$1**"; say ""; say '```text'; clean | head -n "${MAXL:-80}" >> "$BODY"; say '```'; say ""; }
# flag SEVERITY "area" "finding"
flag() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$FIND"; }
sig()  { # signer summary for a path
  [ -e "$1" ] || { echo "missing"; return; }
  local o; o=$(codesign -dv "$1" 2>&1)
  case "$o" in
    *"not signed"*) echo "unsigned" ;;
    *"Signature=adhoc"*) echo "ad hoc" ;;
    *"Authority=Software Signing"*|*"Platform identifier"*) echo "Apple" ;;
    *) echo "$o" | awk -F= '/^TeamIdentifier=/{print "Team " $2; f=1} END{if(!f) print "signed"}' ;;
  esac; }
plistprog(){ plutil -extract Program raw -o - "$1" 2>/dev/null || plutil -extract ProgramArguments.0 raw -o - "$1" 2>/dev/null; }
mdesc(){ printf '%s' "$1" | tr '|' '/' | tr -d '\n'; }     # safe for table cells
LANIF=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
LANIP=$(ipconfig getifaddr "${LANIF:-en0}" 2>/dev/null)

# ---------- 1. System and hardware ----------
h2 "1. System and hardware"
run "macOS" sw_vers
run "Kernel" uname -a
system_profiler SPHardwareDataType 2>/dev/null | grep -vE 'Serial|UUID|UDID|^\s*$' | block "Hardware (serial and UUIDs omitted)"
run "Uptime and load" uptime

# ---------- 2. Memory ----------
h2 "2. Memory"
MEMGB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
SW=$(sysctl -n vm.swapusage)
say "- Installed memory: ${MEMGB} GB"; say "- Swap: \`$SW\`"
SWT=$(echo "$SW" | awk '{gsub("M","",$3); print int($3)}'); SWU=$(echo "$SW" | awk '{gsub("M","",$6); print int($6)}')
if [ "${SWT:-0}" -gt 0 ] && [ $(( SWU * 100 / SWT )) -ge 75 ]; then flag MEDIUM Memory "Swap ${SWU} of ${SWT} MB used ($(( SWU * 100 / SWT ))%)."; fi
run "Memory pressure" sh -c 'memory_pressure | tail -2; vm_stat | grep -E "Pageouts|Swapouts"'
ps -axo rss=,pcpu=,pid=,user=,comm= | sort -rn | head -15 | awk '{printf "%7.0f MB %5s%% %6s %-10s %s\n",$1/1024,$2,$3,$4,$5}' | block "Top 15 processes by memory"
ps -axo pcpu=,rss=,pid=,comm= | sort -rn | head -10 | block "Top 10 processes by CPU"
JET=$(find /Library/Logs/DiagnosticReports "$THOME/Library/Logs/DiagnosticReports" -name 'JetsamEvent-*' -mtime -7 2>/dev/null | wc -l | tr -d ' ')
say "- Out-of-memory (Jetsam) reports in the last 7 days: $JET"
[ "$JET" -ge 3 ] && flag MEDIUM Memory "$JET out-of-memory (Jetsam) events in 7 days; macOS is killing processes to free memory."

# ---------- 3. Storage and backups ----------
h2 "3. Storage and backups"
run "Volumes" df -h / /System/Volumes/Data
DPCT=$(df -k /System/Volumes/Data | awk 'NR==2{gsub("%","",$5); print $5}')
DFREE=$(df -k /System/Volumes/Data | awk 'NR==2{printf "%.1f", $4/1048576}')
if [ "${DPCT:-0}" -ge 95 ]; then flag HIGH Storage "Data volume ${DPCT}% used, ${DFREE} GB free.";
elif [ "${DPCT:-0}" -ge 85 ]; then flag MEDIUM Storage "Data volume ${DPCT}% used, ${DFREE} GB free."; fi
system_profiler SPStorageDataType 2>/dev/null | grep -E 'Mount Point|Device Name|S.M.A.R.T|Capacity|Free' | block "Drives and SMART status"
system_profiler SPStorageDataType 2>/dev/null | grep 'S.M.A.R.T' | grep -qv Verified && flag HIGH Storage "A drive reports a SMART status other than Verified."
run "Local snapshots" tmutil listlocalsnapshots /
NSNAP=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c TimeMachine)
TMP_PL=/Library/Preferences/com.apple.TimeMachine.plist
TMDEST=$(tmutil destinationinfo 2>/dev/null | awk -F': ' '/^Name/{print $2}' | paste -sd, -)
NSD=$(plutil -extract Destinations.0.SnapshotDates raw -o - "$TMP_PL" 2>/dev/null)
LASTBK=""; [ -n "$NSD" ] && [ "$NSD" -gt 0 ] 2>/dev/null && LASTBK=$(plutil -extract "Destinations.0.SnapshotDates.$((NSD-1))" raw -o - "$TMP_PL" 2>/dev/null)
TMENC=$(plutil -extract Destinations.0.LastKnownEncryptionState raw -o - "$TMP_PL" 2>/dev/null)
say "- Time Machine destinations: ${TMDEST:-none}"; say "- Local snapshots: $NSNAP"
say "- Latest backup on first destination: ${LASTBK:-unknown} (UTC); backups recorded: ${NSD:-unknown}"
say "- First destination encryption: ${TMENC:-unknown}"
[ -z "$TMDEST" ] && flag MEDIUM Backup "No Time Machine destination configured."
[ "$TMENC" = "NotEncrypted" ] && flag LOW Backup "Time Machine disk is not encrypted."
if [ -n "$LASTBK" ]; then
  AGE=$(( ( $(date +%s) - $(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$LASTBK" +%s 2>/dev/null || date +%s) ) / 3600 ))
  say "- Hours since latest backup: $AGE"; [ "$AGE" -ge 48 ] && flag MEDIUM Backup "Latest Time Machine backup is $AGE hours old."
fi

# ---------- 4. Updates ----------
h2 "4. Updates"
defaults read /Library/Preferences/com.apple.SoftwareUpdate 2>/dev/null | grep -E 'Automatic|Critical|ConfigData|LastSuccessfulDate' | block "Software Update settings"
if [ "$OFFLINE" -eq 0 ]; then
  SU=$(softwareupdate -l 2>&1); echo "$SU" | block "softwareupdate -l"
  echo "$SU" | grep -q '^\* Label' && flag MEDIUM Updates "macOS updates are available: $(echo "$SU" | awk -F': ' '/^\* Label/{print $2}' | paste -sd';' -)"
  if command -v brew >/dev/null 2>&1; then
    if [ "$ROOT" -eq 1 ]; then NB=$(sudo -u "$TUSER" brew outdated --quiet 2>/dev/null | wc -l | tr -d ' '); else NB=$(brew outdated --quiet 2>/dev/null | wc -l | tr -d ' '); fi
    say "- Homebrew packages outdated: $NB"; [ "$NB" -ge 20 ] && flag LOW Updates "$NB Homebrew packages are outdated."
  fi
else say "Skipped (--offline)."; fi
system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A1 -E '^\s+XProtect' | grep Version | tail -2 | block "XProtect versions (latest installs)"

# ---------- 5. Security baseline ----------
h2 "5. Security baseline"
SIP=$(csrutil status 2>&1); FV=$(fdesetup status 2>&1); GK=$(spctl --status 2>&1)
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
FWS=$($FW --getglobalstate 2>&1); FWST=$($FW --getstealthmode 2>&1); FWSIG=$($FW --getallowsigned 2>&1)
AUTOL=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null)
printf '%s\n' "$SIP" "$FV" "Gatekeeper: $GK" "$FWS" "$FWST" "$FWSIG" "Auto-login user: ${AUTOL:-none}" | block "Baseline"
run "MDM and profiles" sh -c 'profiles status -type enrollment 2>&1; profiles list 2>&1 | head -20'
echo "$SIP" | grep -q enabled || flag HIGH Security "System Integrity Protection is not enabled."
echo "$GK" | grep -q enabled || flag HIGH Security "Gatekeeper is disabled."
echo "$FWS" | grep -q 'enabled' || flag HIGH Firewall "Application firewall is off."
echo "$FWST" | grep -q 'on' || flag LOW Firewall "Firewall stealth mode is off (the Mac answers probes such as ping)."
echo "$FV" | grep -q 'On' || flag MEDIUM Security "FileVault is off${AUTOL:+ (auto-login as $AUTOL, which requires FileVault off)}."
[ -n "$AUTOL" ] && flag LOW Security "Automatic login is on for $AUTOL."
run "System extensions" systemextensionsctl list
systemextensionsctl list 2>/dev/null | grep -q 'waiting for user' && flag INFO Security "A system extension is waiting for user approval: $(systemextensionsctl list 2>/dev/null | grep 'waiting for user' | awk -F'\t' '{print $(NF-1)}' | paste -sd';' -)"
kmutil showloaded --list-only 2>/dev/null | grep -v com.apple | block "Third-party kernel extensions loaded"

# ---------- 6. Firewall ----------
h2 "6. Application firewall"
say "Each entry below needs a reason to stay Allow. The firewall filters by app, not by source address."
say ""; say "| Rule | Path | Signer |"; say "|---|---|---|"
$FW --listapps 2>/dev/null | awk '/^[0-9]+ :/{sub(/^[0-9]+ : /,""); sub(/ +$/,""); app=$0; next} /incoming/{r=($0 ~ /Allow/)?"Allow":"Block"; print r "|" app}' > "$TMP/fw"
NALLOW=0
while IFS='|' read -r r p; do
  s=$(sig "$p"); say "| $r | \`$(mdesc "$p")\` | $s |"
  if [ "$r" = Allow ]; then NALLOW=$((NALLOW+1)); case "$s" in "ad hoc"|unsigned|missing) flag MEDIUM Firewall "Allow rule for a program that is $s: $p";; esac; fi
done < "$TMP/fw"
say ""; say "- Entries: $(wc -l < "$TMP/fw" | tr -d ' '), Allow: $NALLOW"

# ---------- 7. Sharing and remote access ----------
h2 "7. Sharing and remote access"
launchctl print-disabled system 2>/dev/null | grep -E 'sshd|screensharing|smbd|tftpd|ftp|AppleFileServer|RemoteDesktop|ARDAgent' | block "launchd services (enabled means not disabled)"
NET_T=$(netstat -anv -p tcp 2>/dev/null | grep LISTEN); NET_U=$(netstat -anv -p udp 2>/dev/null)
# TCP connect test to this Mac (no data sent); works without sudo for root-owned services
listening(){ /usr/bin/nc -z -G 2 127.0.0.1 "$1" >/dev/null 2>&1 || { [ -n "$LANIP" ] && /usr/bin/nc -z -G 2 "$LANIP" "$1" >/dev/null 2>&1; }; }
for pair in "22:SSH" "445:SMB file sharing" "548:AFP file sharing" "5900:Screen Sharing (VNC)" "3283:Remote Management (ARD)" "88:Kerberos kdc"; do
  pt=${pair%%:*}; nm=${pair#*:}; if listening "$pt"; then say "- $nm: listening on TCP $pt"; else say "- $nm: not listening"; fi
done
echo "$NET_U" | awk '{print $4}' | grep -qE '[.]69$' && { say "- TFTP: listening on UDP 69"; flag MEDIUM Sharing "TFTP server is listening on UDP 69."; }
launchctl print-disabled system 2>/dev/null | grep -q '"com.apple.tftpd" => enabled' && [ -e /Library/LaunchDaemons/tftp.plist -o -e /System/Library/LaunchDaemons/tftp.plist ] && flag LOW Sharing "TFTP (com.apple.tftpd) is enabled in launchd; it starts on the first request."
listening 445 && flag LOW Sharing "SMB file sharing is on: $(sharing -l 2>/dev/null | awk -F'\t+' '/^name:/{print $2}' | paste -sd';' -)"
RM=/Library/Preferences/com.apple.RemoteManagement.plist
if listening 3283 || pgrep -x ARDAgent >/dev/null; then
  say ""; defaults read "$RM" 2>/dev/null | grep -E 'ARD_AllLocalUsers|VNCLegacy|allowInsecureDH|ScreenSharingReqPerm' | block "Remote Management settings"
  [ "$(defaults read "$RM" ARD_AllLocalUsers 2>/dev/null)" = 1 ] && flag MEDIUM Sharing "Remote Management (ARD) is on for all local users."
  [ "$(defaults read "$RM" VNCLegacyConnectionsEnabled 2>/dev/null)" = 1 ] && flag MEDIUM Sharing "Remote Management allows legacy VNC password connections."
  [ "$(defaults read "$RM" allowInsecureDH 2>/dev/null)" = 1 ] && flag MEDIUM Sharing "Remote Management allows insecure Diffie-Hellman key exchange (allowInsecureDH)."
fi
if listening 22; then
  AM=$(/usr/bin/ssh -F /dev/null -o PreferredAuthentications=none -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 nobody@127.0.0.1 true </dev/null 2>&1 | grep -o '([^)]*)' | tail -1)
  say "- SSH offers: ${AM:-unknown}"
  echo "$AM" | grep -q password && flag MEDIUM Sharing "SSH accepts password authentication."
  dscl . -read /Groups/com.apple.access_ssh >/dev/null 2>&1 && say "- SSH access group: $(dscl . -read /Groups/com.apple.access_ssh GroupMembership 2>/dev/null | cut -d: -f2)" \
    || { say "- SSH access group: absent (every local user may sign in)"; flag LOW Sharing "SSH is not limited to specific users (com.apple.access_ssh group absent)."; }
  cat /etc/ssh/sshd_config.d/* 2>/dev/null | grep -vE '^\s*(#|$)' | block "sshd_config.d (non-comment lines)"
fi
dscl . -read /Groups/com.apple.access_screensharing GroupMembership NestedGroups 2>/dev/null | block "Screen Sharing access group"
sharing -l 2>/dev/null | grep -E '^name:|path:' | block "File shares"

# ---------- 8. Network listeners ----------
h2 "8. Network listeners reachable from other devices"
say "Listeners bound to all interfaces or a LAN address. Each was sent one HTTP GET on ${LANIP:-the LAN address} to see whether it asks for a login (HTTP code only; 000 = not HTTP or no answer)."
say ""; say "| Address | Process | PID | Signer | HTTP GET / |"; say "|---|---|---|---|---|"
if [ -n "$NET_T" ]; then
  echo "$NET_T" | awk '{p=""; for(i=6;i<=NF;i++) if($i ~ /^[^ ]+:[0-9]+$/) p=$i; print $4, p}' | sort -u > "$TMP/lis"
else
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{a=$9; sub(/:([0-9]+)$/, ".&", a); sub(/\.:/, ".", a); print a, $1 ":" $2}' | sort -u > "$TMP/lis"
fi
SEEN=""
while read -r addr proc; do
  case "$addr" in 127.*|::1.*|fe80::1%lo0.*|localhost.*) continue ;; esac
  port=${addr##*.}; host=${addr%.*}; pid=${proc##*:}; name=${proc%:*}
  key="$port/$pid"; case " $SEEN " in *" $key "*) continue ;; esac; SEEN="$SEEN $key"
  path=$(ps -o comm= -p "$pid" 2>/dev/null); [ -n "$path" ] || path="$name"
  case "$path" in /*) ;; *) cwd=$(lsof -a -p "$pid" -d txt -Fn 2>/dev/null | awk '/^n\//{print substr($0,2); exit}'); [ -n "$cwd" ] && path="$cwd" ;; esac
  s=$(sig "$path")
  tgt="$host"; [ "$host" = "*" ] && tgt="$LANIP"; case "$tgt" in *:*) tgt="[$tgt]";; esac
  code=000; [ -n "$tgt" ] && code=$(/usr/bin/curl -s -o /dev/null -m 3 -w '%{http_code}' "http://$tgt:$port/" 2>/dev/null)
  say "| \`$addr\` | \`$(mdesc "$path")\` | $pid | $s | $code |"
  case "$s" in Apple) ;; *)
    case "$code" in 200) flag MEDIUM Network "Non-Apple listener answers HTTP 200 without a login on $addr ($path). Check whether it needs authentication.";;
                    *) [ "$host" = "*" ] && flag INFO Network "Non-Apple listener on all interfaces: $addr ($(basename "$path"), HTTP $code)." ;; esac ;;
  esac
done < "$TMP/lis"
[ "$ROOT" -eq 0 ] && say "" && say "Without sudo, ports owned by root may show without a process name."
pgrep -fl cloudflared >/dev/null 2>&1 && flag INFO Network "A Cloudflare tunnel (cloudflared) is running; its published hostnames are configured in the Cloudflare dashboard."
run "VPN and tunnel processes" sh -c 'ps -axo user=,pid=,comm= | grep -iE "cloudflared|tailscale|wireguard|openvpn|nordvpn|anyconnect|ngrok|frpc|zerotier" | grep -v grep'

# ---------- 9. Persistence and startup items ----------
h2 "9. Startup items and persistence"
say "| Location | Label file | Program | Signer | Modified |"; say "|---|---|---|---|---|"
for d in /Library/LaunchDaemons /Library/LaunchAgents "$THOME/Library/LaunchAgents"; do
  for f in "$d"/*.plist; do [ -e "$f" ] || continue
    prog=$(plistprog "$f"); s=$(sig "$prog"); m=$(stat -f %Sm -t %Y-%m-%d "$f")
    say "| \`$d\` | $(basename "$f") | \`$(mdesc "${prog:-?}")\` | $s | $m |"
    case "$prog" in /tmp/*|/private/tmp/*|/Users/Shared/*|*/.[!.]*/*) flag HIGH Persistence "Startup item runs from an unusual path: $f -> $prog";; esac
    [ "$s" = missing ] && [ -n "$prog" ] && case "$prog" in /*) flag LOW Persistence "Startup item points to a missing program: $f -> $prog";; esac
    if [ -n "$(find "$f" -mtime -14 2>/dev/null)" ]; then case "$s" in unsigned|"ad hoc") case "$prog" in /opt/homebrew/*|/usr/local/*) sv=LOW;; *) sv=MEDIUM;; esac
      flag $sv Persistence "Startup item added or changed in the last 14 days runs a program that is $s: $f";; esac; fi
  done
done
ls -l /Library/PrivilegedHelperTools 2>/dev/null | tail -n +2 | while read -r l; do f="/Library/PrivilegedHelperTools/${l##* }"; echo "$l  [$(sig "$f")]"; done | block "Privileged helper tools"
LH=$(defaults read com.apple.loginwindow LoginHook 2>/dev/null; defaults read /Library/Preferences/com.apple.loginwindow LoginHook 2>/dev/null)
say "- Login hook: ${LH:-none}"; [ -n "$LH" ] && flag HIGH Persistence "A login hook is set: $LH"
CT=$( ( [ "$ROOT" -eq 1 ] && crontab -u "$TUSER" -l || crontab -l ) 2>/dev/null | grep -vE '^\s*(#|$)' )
say "- User crontab entries: $(printf '%s' "$CT" | grep -c . )"; [ -n "$CT" ] && echo "$CT" | block "crontab"
ls /etc/periodic/daily /etc/periodic/weekly /etc/periodic/monthly 2>/dev/null | grep -vE '^[0-9]{3}\.|^$|:$' | block "Non-standard periodic scripts"
ls -l /etc/sudoers.d 2>&1 | block "/etc/sudoers.d"
[ -n "$(ls -A /etc/sudoers.d 2>/dev/null)" ] && flag INFO Security "Files present in /etc/sudoers.d: $(ls /etc/sudoers.d | paste -sd, -)"
[ -f "$THOME/.ssh/authorized_keys" ] && awk '!/^\s*(#|$)/{print $1, $NF}' "$THOME/.ssh/authorized_keys" | block "SSH authorized_keys (type and comment only)"
grep -nE 'curl[^|]*\|\s*(ba|z)?sh|base64 (-d|--decode)|eval "?\$\(curl|/dev/tcp/|nc -e|osascript -e' \
  "$THOME"/.zshrc "$THOME"/.zprofile "$THOME"/.zshenv "$THOME"/.bashrc "$THOME"/.bash_profile "$THOME"/.profile /etc/zshrc /etc/profile 2>/dev/null > "$TMP/rc"
if [ -s "$TMP/rc" ]; then block "Suspicious lines in shell startup files" < "$TMP/rc"; flag HIGH Persistence "Shell startup files contain download-and-run or decode patterns (see section 9)."; else say "- Shell startup files: no download-and-run or decode patterns"; fi
find /Users/Shared /private/tmp /private/var/tmp -maxdepth 3 -type f -perm -u+x 2>/dev/null | grep -v '/mac-audit\.' | head -20 > "$TMP/x"
if [ -s "$TMP/x" ]; then block "Executables in shared or temporary folders" < "$TMP/x"; flag MEDIUM Persistence "Executable files found in /Users/Shared or /tmp (see section 9)."; else say "- Executables in /Users/Shared and /tmp: none"; fi
if [ "$ROOT" -eq 1 ]; then MAXL=200 run "Background items (sfltool, non-Apple)" sh -c 'sfltool dumpbtm 2>/dev/null | grep -E "^\s+(Name|Developer Name|Type|Disposition|URL|Executable Path):" | grep -v "com.apple" '; fi

# ---------- 10. Accounts ----------
h2 "10. Accounts"
dscl . -list /Users UniqueID | awk '$2>=500' | block "Local users (UID 500 and above)"
ADM=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | cut -d: -f2)
say "- Admin group: $ADM"
for u in $ADM; do dscl . -read "/Users/$u" >/dev/null 2>&1 || flag LOW Accounts "Admin group lists a user that does not exist: $u"; done
RAA=$(dscl . -read /Users/root AuthenticationAuthority 2>/dev/null | grep -v 'No such key')
RPW=$(dscl . -read /Users/root Password 2>/dev/null | awk '{print $2}')
if { [ -n "$RAA" ] && ! echo "$RAA" | grep -q DisabledUser; } || { [ -n "$RPW" ] && [ "$RPW" != "*" ]; }; then
  say "- root account: appears enabled"; flag MEDIUM Accounts "The root account appears to be enabled."
else say "- root account: disabled"; fi
run "Recent logins" sh -c 'last -25 | grep -v "^$"'

# ---------- 11. Running processes outside standard locations ----------
h2 "11. Running programs outside standard locations"
say "| Program | Signer |"; say "|---|---|"
ps -axo comm= | sort -u | grep -E '^/' | grep -vE '^/(System|usr/(libexec|sbin|bin)|sbin|bin|Library/Apple|Applications/[^/]+\.app)/' | while read -r p; do
  s=$(sig "$p"); say "| \`$(mdesc "$p")\` | $s |"
  case "$p" in /tmp/*|/private/tmp/*|/private/var/folders/*|/Users/Shared/*) flag HIGH Processes "Program running from a temporary or shared folder: $p ($s)";; esac
done

# ---------- 12. Logs and crash reports ----------
h2 "12. Logs and crash reports"
find /Library/Logs/DiagnosticReports "$THOME/Library/Logs/DiagnosticReports" -type f -mtime -14 2>/dev/null | sed 's#.*/##' | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+.*//' | sort | uniq -c | sort -rn | head -25 | block "Crash and diagnostic reports, last 14 days (count by kind)"
NP=$(find /Library/Logs/DiagnosticReports -name '*.panic' -mtime -30 2>/dev/null | wc -l | tr -d ' ')
say "- Kernel panics in 30 days: $NP"; [ "$NP" -gt 0 ] && flag HIGH Stability "$NP kernel panic(s) in the last 30 days."
if [ "$QUICK" -eq 0 ]; then
  echo "Searching 7 days of logs (this can take a few minutes)..." >&2
  XP=$(log show --last 7d --style compact --predicate 'subsystem BEGINSWITH "com.apple.XProtect" AND (eventMessage CONTAINS[c] "detected" OR eventMessage CONTAINS[c] "remediat")' 2>/dev/null | grep -viE 'NoThreatDetected|no (threats|detections)|status: 0|^Timestamp ' | tail -20)
  XN=$(log show --last 7d --style compact --predicate 'subsystem BEGINSWITH "com.apple.XProtect" AND eventMessage CONTAINS "NoThreatDetected"' 2>/dev/null | grep -c NoThreatDetected)
  say "- XProtect scanner results reporting NoThreatDetected (7 days): $XN"
  if [ -n "$XP" ]; then echo "$XP" | block "XProtect detection or remediation messages (7 days)"; flag HIGH Malware "XProtect logged detection or remediation messages (see section 12)."; else say "- XProtect detections (7 days): none found"; fi
  SS=$(log show --last 7d --style compact --predicate 'process BEGINSWITH "sshd" AND (eventMessage CONTAINS "Failed" OR eventMessage CONTAINS "Invalid user" OR eventMessage CONTAINS "Accepted")' 2>/dev/null)
  say "- SSH log lines (7 days): accepted $(echo "$SS" | grep -c Accepted), failed $(echo "$SS" | grep -c Failed), invalid user $(echo "$SS" | grep -c 'Invalid user'). Without sudo these lines are often hidden."
  NF=$(echo "$SS" | grep -c -E 'Failed|Invalid user'); [ "$NF" -ge 20 ] && flag MEDIUM Security "$NF failed SSH sign-in attempts in 7 days."
else say "Log searches skipped (--quick)."; fi

# ---------- 13. Disk usage ----------
h2 "13. Disk usage"
if [ "$SKIPDU" -eq 0 ]; then
  echo "Measuring home folder usage..." >&2
  ( cd "$THOME" && du -sh -x .[!.]* * Library/* 2>/dev/null | sort -rh | head -25 ) | block "Largest items in $THOME (top 25)"
  [ "$ROOT" -eq 1 ] && ( du -sh -x /Users/* /Library /Applications /opt /private/var 2>/dev/null | sort -rh ) | block "Top-level usage (root)"
else say "Skipped (--skip-du)."; fi

# ---------- 14. Network configuration, trust and privacy ----------
h2 "14. Network configuration, trust and privacy"
scutil --dns 2>/dev/null | grep -E 'nameserver\[' | sort | uniq -c | block "DNS servers in use"
PX=$(scutil --proxy 2>/dev/null); echo "$PX" | block "Proxy settings"
echo "$PX" | grep -qE '(HTTPEnable|HTTPSEnable|SOCKSEnable|ProxyAutoConfigEnable) : 1' && flag MEDIUM Network "A system proxy or proxy auto-config is set; confirm it is intended."
HO=$(grep -vE '^\s*(#|$)' /etc/hosts | grep -vE '^(127\.0\.0\.1\s+localhost|255\.255\.255\.255\s+broadcasthost|::1\s+localhost)\s*$')
if [ -n "$HO" ]; then echo "$HO" | block "Non-default /etc/hosts entries"; flag LOW Network "/etc/hosts has $(echo "$HO" | wc -l | tr -d ' ') non-default entries."; else say "- /etc/hosts: default"; fi
DY=$(launchctl getenv DYLD_INSERT_LIBRARIES 2>/dev/null)
[ -n "$DY" ] && flag HIGH Persistence "launchd sets DYLD_INSERT_LIBRARIES=$DY (library injection)."
say "- launchd DYLD_INSERT_LIBRARIES: ${DY:-not set}"
NC=$(security find-certificate -a /Library/Keychains/System.keychain 2>/dev/null | grep -c '"labl"')
security find-certificate -a /Library/Keychains/System.keychain 2>/dev/null | awk -F'"' '/"labl"/{print $4}' | sort -u | block "Certificates in the System keychain ($NC)"
TS=$(security dump-trust-settings -d 2>&1 | grep -E '^Cert [0-9]+:' )
if [ -n "$TS" ]; then echo "$TS" | block "Admin trust settings (certificates trusted by an administrator)"; flag MEDIUM Security "Administrator-trusted certificates exist; a trusted root can intercept HTTPS. Confirm each one."; else say "- Admin-trusted certificates: none"; fi
NETE=$(netstat -anv -p tcp 2>/dev/null | grep ESTABLISHED | awk '{p=""; for(i=6;i<=NF;i++) if($i ~ /^[^ ]+:[0-9]+$/) p=$i; split(p,a,":"); r=$5; sub(/\.[0-9]+$/,"",r); if (r !~ /^(127\.|::1|fe80)/) print a[1], r}' | sort | uniq -c | sort -rn | head -30)
[ -n "$NETE" ] && echo "$NETE" | block "Established outbound TCP connections (count, process, remote address; top 30)"
GU=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null)
say "- Guest account enabled: ${GU:-not set (off)}"; [ "$GU" = 1 ] && flag LOW Accounts "The guest account is enabled."
SL=$(sysadminctl -screenLock status 2>&1 | sed 's/.*\] //'); say "- Screen lock: ${SL:-unknown}"
echo "$SL" | grep -qi 'off' && flag LOW Security "Screen lock after sleep or screen saver is off."
run "Power and sleep" pmset -g
TCCU="$THOME/Library/Application Support/com.apple.TCC/TCC.db"
if sqlite3 -readonly "$TCCU" 'select 1' >/dev/null 2>&1; then
  sqlite3 -readonly "$TCCU" "select service, client from access where auth_value=2 and service in ('kTCCServiceAccessibility','kTCCServiceScreenCapture','kTCCServiceSystemPolicyAllFiles','kTCCServiceListenEvent','kTCCServicePostEvent','kTCCServiceMicrophone','kTCCServiceCamera') order by service" 2>/dev/null | block "Privacy permissions granted (user database)"
else say "- Privacy permissions (TCC): not readable from this process (needs Full Disk Access for the terminal app)."; fi
if [ "$ROOT" -eq 1 ] && sqlite3 -readonly /Library/Application\ Support/com.apple.TCC/TCC.db 'select 1' >/dev/null 2>&1; then
  sqlite3 -readonly /Library/Application\ Support/com.apple.TCC/TCC.db "select service, client from access where auth_value=2 and service in ('kTCCServiceAccessibility','kTCCServiceScreenCapture','kTCCServiceSystemPolicyAllFiles','kTCCServiceListenEvent','kTCCServicePostEvent') order by service" | block "Privacy permissions granted (system database)"
fi
say ""; say "**Applications that Gatekeeper rejects**"; say ""
for a in /Applications/*.app "$THOME"/Applications/*.app; do [ -d "$a" ] || continue
  r=$(spctl -a -t exec "$a" 2>&1); case "$r" in *rejected*) say "- \`$(mdesc "$a")\`: rejected"; flag LOW Apps "Gatekeeper rejects $(basename "$a") (unsigned, ad hoc or not notarized).";; esac
done
say ""
for prof in "$THOME/Library/Application Support/Google/Chrome"/*/Extensions; do [ -d "$prof" ] || continue
  for m in "$prof"/*/*/manifest.json; do [ -f "$m" ] || continue
    n=$(grep -m1 -o '"name"[^,]*' "$m" | sed 's/"name" *: *//; s/"//g'); id=$(echo "$m" | awk -F/ '{print $(NF-2)}')
    echo "$(basename "$(dirname "$prof")") $id $n"; done
done | sort -u | block "Chrome extensions (profile, ID, name; __MSG_ names are localized)"
if command -v pluginkit >/dev/null; then pluginkit -mAvvv -p com.apple.Safari.web-extension 2>/dev/null | grep -E 'Path|Parent' | sed 's/^ *//' | block "Safari web extensions"; fi

# ---------- 15. Root-only checks ----------
if [ "$ROOT" -eq 1 ]; then
  h2 "15. Root-only checks"
  run "All TCP listeners (lsof)" sh -c 'lsof -nP -iTCP -sTCP:LISTEN | awk "{print \$1, \$2, \$3, \$9}" | sort -u'
  run "Effective sshd settings" sh -c 'sshd -T 2>/dev/null | grep -iE "^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication|allowusers|allowgroups|port) "'
  sshd -T 2>/dev/null | grep -qi '^permitrootlogin yes' && flag HIGH Sharing "sshd permits root login."
  run "Packet filter (pf)" sh -c 'pfctl -s info 2>/dev/null | head -5; pfctl -s rules 2>/dev/null | head -30'
fi

# ---------- assemble report ----------
{
  echo "# Mac health and security audit: $HOST"
  echo ""
  echo "- Date: $NOW"
  echo "- User: $TUSER; run as root: $([ "$ROOT" -eq 1 ] && echo yes || echo no)"
  echo "- Script: mac-audit.sh $VERSION (read-only; options: quick=$QUICK offline=$OFFLINE skip-du=$SKIPDU)"
  echo ""
  echo "## Findings"
  echo ""
  echo "Automatic flags, highest severity first. Each flag is a lead for review, not a verdict. Sections below hold the evidence."
  echo ""
  if [ -s "$FIND" ]; then
    echo "| Severity | Area | Finding |"; echo "|---|---|---|"
    for s in HIGH MEDIUM LOW INFO; do awk -F'\t' -v s="$s" '$1==s{gsub(/\|/,"/",$3); print "| " $1 " | " $2 " | " $3 " |"}' "$FIND"; done
    echo ""
    for s in HIGH MEDIUM LOW INFO; do printf -- "- %s: %s\n" "$s" "$(awk -F'\t' -v s="$s" '$1==s' "$FIND" | wc -l | tr -d ' ')"; done
  else echo "No automatic flags."; fi
  echo ""
  echo "## Limitations"
  echo ""
  echo "- No changes are made. Checks that need admin rights are skipped unless the script runs with sudo."
  echo "- \"No sign of compromise\" means the listed checks found nothing; it is not proof of absence."
  echo "- HTTP checks only show whether a page asks for a login; an API path may still be open when / redirects to a login page."
  echo "- Cloud-managed settings (Cloudflare tunnel hostnames, router rules) are outside this Mac and are not checked."
  cat "$BODY"
} > "$TMP/report.md"
if [ "$STDOUT" -eq 1 ]; then cat "$TMP/report.md"; echo "Report sent to stdout ($(grep -c . "$FIND") flags)" >&2
else cp "$TMP/report.md" "$OUT" && echo "Report written to $OUT ($(grep -c . "$FIND") flags)" >&2; fi
