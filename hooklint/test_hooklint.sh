#!/usr/bin/env bash
# Tests for hooklint — lints a Claude Code settings.json hooks block.
# Builds small settings.json fixtures inline and asserts exit code / finding codes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HL="$HERE/hooklint"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }
tmp() { mktemp /tmp/hl.XXXXXX; }

# --- T1: unknown / typo event name => UNKNOWN_EVENT, exit 1
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"PreToolUseX": [{"matcher": ".*", "hooks": [{"type":"command","command":"/bin/echo hi"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1); rc=$?
echo "$o" | grep -q "UNKNOWN_EVENT" && [ "$rc" -eq 1 ] && ok "T1 unknown event => UNKNOWN_EVENT, exit 1" || bad "T1" "rc=$rc $o"

# --- T2: hook entry missing type:command / empty command => HOOK_BAD_COMMAND
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"Stop": [{"hooks": [{"type":"command","command":""}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "HOOK_BAD_COMMAND" && ok "T2 empty command => HOOK_BAD_COMMAND" || bad "T2" "$o"

# --- T2b: missing type field => HOOK_BAD_COMMAND
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"Stop": [{"hooks": [{"command":"/bin/echo hi"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "HOOK_BAD_COMMAND" && ok "T2b missing type => HOOK_BAD_COMMAND" || bad "T2b" "$o"

# --- T3: matcher on an event that ignores it => MATCHER_IGNORED (MED)
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"Stop": [{"matcher": ".*", "hooks": [{"type":"command","command":"/bin/echo hi"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "MATCHER_IGNORED" && ok "T3 matcher on Stop => MATCHER_IGNORED" || bad "T3" "$o"

# --- T4: invalid matcher regex on PreToolUse => BAD_MATCHER_REGEX (HIGH)
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"PreToolUse": [{"matcher": "Bash(", "hooks": [{"type":"command","command":"/bin/echo hi"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "BAD_MATCHER_REGEX" && ok "T4 invalid regex => BAD_MATCHER_REGEX" || bad "T4" "$o"

# --- T5: relative / bare-script command => CMD_RELATIVE (LOW, heuristic)
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"PostToolUse": [{"matcher": "Edit", "hooks": [{"type":"command","command":"./run.sh"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "CMD_RELATIVE" && ok "T5 relative command => CMD_RELATIVE" || bad "T5" "$o"

# --- T6: risky command pattern => CMD_RISKY (MED, heuristic)
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"Stop": [{"hooks": [{"type":"command","command":"/bin/sh -c 'rm -rf /tmp/x'"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "CMD_RISKY" && ok "T6 rm -rf => CMD_RISKY" || bad "T6" "$o"

# --- T6b: curl | sh => CMD_RISKY
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"SessionStart": [{"hooks": [{"type":"command","command":"curl https://x.sh | bash"}]}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "CMD_RISKY" && ok "T6b curl|bash => CMD_RISKY" || bad "T6b" "$o"

# --- T7: empty event list => EMPTY_EVENT (LOW)
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"Notification": []}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "EMPTY_EVENT" && ok "T7 empty event => EMPTY_EVENT" || bad "T7" "$o"

# --- T7b: matcher-group with empty inner hooks => EMPTY_GROUP (LOW)
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": []}]}}
JSON
o=$("$HL" --json "$F" 2>&1)
echo "$o" | grep -q "EMPTY_GROUP" && ok "T7b empty group => EMPTY_GROUP" || bad "T7b" "$o"

# --- T8: structural robustness: hooks is a list, not an object => HOOKS_NOT_OBJECT, no crash
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": ["oops"]}
JSON
o=$("$HL" --json "$F" 2>&1); rc=$?
echo "$o" | grep -q "HOOKS_NOT_OBJECT" && [ "$rc" -eq 1 ] && ok "T8 hooks-as-list => HOOKS_NOT_OBJECT, no crash" || bad "T8" "rc=$rc $o"

# --- T8b: event value wrong type (dict where list expected) => EVENT_NOT_LIST, no traceback
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {"PreToolUse": {"matcher": ".*"}}}
JSON
o=$("$HL" "$F" 2>&1)
echo "$o" | grep -q "EVENT_NOT_LIST" && ! echo "$o" | grep -qi "Traceback" && ok "T8b event-as-dict => EVENT_NOT_LIST, no traceback" || bad "T8b" "$o"

# --- T9: fully clean config => exit 0, says clean
F=$(tmp); cat > "$F" <<'JSON'
{"hooks": {
  "PreToolUse": [{"matcher": "Bash", "hooks": [{"type":"command","command":"/usr/local/bin/guard.sh"}]}],
  "PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type":"command","command":"/usr/local/bin/fmt.sh"}]}],
  "Stop": [{"hooks": [{"type":"command","command":"/usr/local/bin/notify.sh"}]}]
}}
JSON
o=$("$HL" "$F" 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "$o" | grep -Eiq "no hook misconfigurations|clean" && ok "T9 clean config => exit 0" || bad "T9" "rc=$rc $o"

# --- T9b: clean config via --json => empty findings, exit 0
o=$("$HL" --json "$F" 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "$o" | grep -Eq '"findings": *\[\]' && ok "T9b clean --json => exit 0, empty findings" || bad "T9b" "rc=$rc $o"

# --- T10: missing file => exit 2
"$HL" /no/such/settings.json >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "T10 missing file => exit 2" || bad "T10" "rc=$rc"

# --- T10b: invalid JSON => exit 2
F=$(tmp); printf '{ this is not json ' > "$F"
"$HL" "$F" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "T10b invalid JSON => exit 2" || bad "T10b" "rc=$rc"

# --- T10c: valid JSON but no hooks block => exit 2
F=$(tmp); echo '{"permissions": {"allow": []}}' > "$F"
"$HL" "$F" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "T10c no hooks block => exit 2" || bad "T10c" "rc=$rc"

# --- T11: stdin input via '-'
o=$(echo '{"hooks":{"BogusEvent":[{"hooks":[{"type":"command","command":"/bin/echo hi"}]}]}}' | "$HL" --json - 2>&1); rc=$?
echo "$o" | grep -q "UNKNOWN_EVENT" && [ "$rc" -eq 1 ] && ok "T11 stdin '-' => UNKNOWN_EVENT, exit 1" || bad "T11" "rc=$rc $o"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
