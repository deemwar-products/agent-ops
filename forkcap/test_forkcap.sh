#!/usr/bin/env bash
# Tests for forkcap. Ground truth = real PreToolUse hook JSON in, real decisions out.
# No synthetic seed: every assertion drives the actual hook the way Claude Code does.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FORKCAP="$HERE/forkcap"
chmod +x "$FORKCAP"

# Isolate state so tests never touch a real ~/.cache/forkcap.
export FORKCAP_STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$FORKCAP_STATE_DIR"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

# A PreToolUse payload for a spawn tool.
payload() { # <tool_name> <session_id> [agent_id] [agent_type]
  jq -nc --arg t "$1" --arg s "$2" --arg ai "${3:-main}" --arg at "${4:--}" \
    '{hook_event_name:"PreToolUse", tool_name:$t, session_id:$s, agent_id:$ai, agent_type:$at, tool_input:{description:"x", prompt:"y"}}'
}
# returns "deny" if the hook output denied, else "allow".
# An ALLOW is a PreToolUse "no decision": exit 0 with NO stdout. So empty
# output (or unparseable output) means allow.
decide() {
  local out; out="$(echo "$1" | "$FORKCAP")"
  [ -z "$out" ] && { echo allow; return; }
  echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo allow
}

# T1: a single spawn under budget is allowed
export FORKCAP_MAX=25
r=$(decide "$(payload Task s1)")
[ "$r" = "allow" ] && ok "T1 spawn under budget = allow" || bad "T1 got '$r'"

# T2: spawns up to MAX allowed, MAX+1 denied (the latch)
"$FORKCAP" reset s2 >/dev/null
export FORKCAP_MAX=5
last="allow"
for i in 1 2 3 4 5; do last=$(decide "$(payload Agent s2)"); done
[ "$last" = "allow" ] && ok "T2a spawn #5 (=MAX) still allowed" || bad "T2a got '$last'"
r=$(decide "$(payload Agent s2)")
[ "$r" = "deny" ] && ok "T2b spawn #6 (>MAX) denied" || bad "T2b got '$r'"

# T3: once over budget it STAYS denied (latched, not flapping)
r=$(decide "$(payload Agent s2)")
[ "$r" = "deny" ] && ok "T3 budget latches shut (still denied)" || bad "T3 got '$r'"

# T4: a different session has its own independent budget
export FORKCAP_MAX=5
r=$(decide "$(payload Agent s3-fresh)")
[ "$r" = "allow" ] && ok "T4 separate session = independent budget" || bad "T4 got '$r'"

# T5: a non-spawn tool is never counted or denied (defensive even past budget)
"$FORKCAP" reset s5 >/dev/null
export FORKCAP_MAX=1
decide "$(payload Task s5)" >/dev/null      # uses the 1 budget
bashpayload=$(jq -nc '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"s5",tool_input:{command:"ls"}}')
r=$(decide "$bashpayload")
[ "$r" = "allow" ] && ok "T5 non-spawn tool (Bash) never denied" || bad "T5 got '$r'"
n=$("$FORKCAP" status s5 | grep -o '[0-9]*/' | head -1 | tr -d '/')
[ "$n" = "1" ] && ok "T5b Bash not added to the ledger (count stays 1)" || bad "T5b count=$n"

# T6: FORKCAP_DISABLE forces allow and does not count
"$FORKCAP" reset s6 >/dev/null
export FORKCAP_MAX=1
FORKCAP_DISABLE=1 decide "$(payload Agent s6)" >/dev/null
FORKCAP_DISABLE=1 decide "$(payload Agent s6)" >/dev/null
r=$(FORKCAP_DISABLE=1 decide "$(payload Agent s6)")
[ "$r" = "allow" ] && ok "T6 FORKCAP_DISABLE always allows" || bad "T6 got '$r'"
n=$("$FORKCAP" status s6 | grep -o '[0-9]*/' | head -1 | tr -d '/')
[ "$n" = "0" ] && ok "T6b disabled hook keeps no ledger" || bad "T6b count=$n"
unset FORKCAP_DISABLE

# T7: empty/garbage stdin fails OPEN (never breaks the session)
out=$(printf '' | "$FORKCAP"); [ -z "$out" ] && ok "T7a empty stdin = fail open (allow)" || bad "T7a got '$out'"
out=$(printf 'not json at all' | "$FORKCAP"); [ -z "$out" ] && ok "T7b garbage stdin = fail open (allow)" || bad "T7b got '$out'"

# T8: nested-spawn origin (agent_id/agent_type) is recorded in the ledger
"$FORKCAP" reset s8 >/dev/null
export FORKCAP_MAX=10
decide "$(payload Agent s8 af_child_123 Explore)" >/dev/null
grep -q "af_child_123" "$FORKCAP_STATE_DIR/s8.ledger" && ok "T8 nested spawn origin recorded (agent_id)" || bad "T8 not recorded"
grep -q "Explore" "$FORKCAP_STATE_DIR/s8.ledger" && ok "T8b agent_type recorded" || bad "T8b not recorded"

# T9: status reports the count against the budget
"$FORKCAP" reset s9 >/dev/null
export FORKCAP_MAX=3
decide "$(payload Task s9)" >/dev/null; decide "$(payload Task s9)" >/dev/null
"$FORKCAP" status s9 | grep -q "2/3" && ok "T9 status shows count/budget" || bad "T9 status wrong"

# T10: reset clears a session's ledger
"$FORKCAP" reset s9 >/dev/null
"$FORKCAP" status s9 | grep -q "0/3" && ok "T10 reset clears the ledger" || bad "T10 reset failed"

# T11: a real whole-tree run — 1 parent + many nested children share ONE budget
"$FORKCAP" reset tree >/dev/null
export FORKCAP_MAX=8
allowed=0; denied=0
# parent spawns, then "children" (different agent_ids) spawn under the same session
for a in main main c1 c1 c2 c2 c3 c3 c4 c4 c5 c5; do
  d=$(decide "$(payload Agent tree "$a" general-purpose)")
  if [ "$d" = "deny" ]; then denied=$((denied+1)); else allowed=$((allowed+1)); fi
done
[ "$allowed" = "8" ] && [ "$denied" = "4" ] && ok "T11 one budget bounds the whole spawn tree (8 allowed, 4 denied)" || bad "T11 allowed=$allowed denied=$denied"

echo "-----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
