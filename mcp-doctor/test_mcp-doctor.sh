#!/usr/bin/env bash
# Tests for mcp-doctor — static health check for .mcp.json (will each server START?).
# Deterministic + offline: never starts a server, never hits the network. Fixtures inline.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MD="$HERE/mcp-doctor"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }
tmp() { mktemp /tmp/md.XXXXXX; }

# a command that exists on every machine (verify), and one that surely doesn't
GOOD=""
for c in sh python3 ls; do command -v "$c" >/dev/null 2>&1 && { GOOD="$c"; break; }; done
[ -n "$GOOD" ] || { echo "no usable base command found"; exit 2; }
BOGUS="definitely-not-a-real-binary-xyz"
# ensure the heuristic env var IS unset
unset MCPDOCTOR_TEST_UNSET 2>/dev/null || true

# --- T1: CMD_NOT_FOUND — stdio command that doesn't resolve => HIGH, exit 1
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"ghost": {"command": "$BOGUS"}}}
JSON
o=$("$MD" "$f" 2>&1); rc=$?
echo "$o" | grep -q "CMD_NOT_FOUND" && [ "$rc" -eq 1 ] && ok "T1 CMD_NOT_FOUND => HIGH, exit 1" || bad "T1" "rc=$rc $o"

# --- T2: RESOLVES — a real command => no CMD_NOT_FOUND, exit 0
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"realserver": {"command": "$GOOD", "args": ["--stdio"]}}}
JSON
o=$("$MD" "$f" 2>&1); rc=$?
echo "$o" | grep -q "CMD_NOT_FOUND" && bad "T2 real command falsely flagged" "$o" \
  || { [ "$rc" -eq 0 ] && ok "T2 resolvable command clean, exit 0" || bad "T2 exit" "rc=$rc $o"; }

# --- T3: NO_COMMAND_OR_URL — entry with neither command nor url => HIGH
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"empty": {"description": "nothing useful"}}}
JSON
o=$("$MD" "$f" 2>&1)
echo "$o" | grep -q "NO_COMMAND_OR_URL" && ok "T3 NO_COMMAND_OR_URL" || bad "T3" "$o"

# --- T4: BAD_URL — remote server with a missing/malformed url => HIGH
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"remote": {"type": "http", "url": "ftp:/not-a-real-url"}}}
JSON
o=$("$MD" "$f" 2>&1)
echo "$o" | grep -q "BAD_URL" && ok "T4 BAD_URL (bad scheme)" || bad "T4" "$o"

# --- T4b: a well-formed https remote => no BAD_URL, exit 0
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"remote": {"type": "sse", "url": "https://mcp.example.com/sse"}}}
JSON
o=$("$MD" "$f" 2>&1); rc=$?
echo "$o" | grep -q "BAD_URL" && bad "T4b good url flagged" "$o" \
  || { [ "$rc" -eq 0 ] && ok "T4b good https url clean" || bad "T4b exit" "rc=$rc $o"; }

# --- T5: ENV_UNSET — env references an unset var => MED, by NAME, value never printed
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"needsauth": {"command": "$GOOD", "env": {"API_TOKEN": "\${MCPDOCTOR_TEST_UNSET}"}}}}
JSON
o=$("$MD" "$f" 2>&1)
echo "$o" | grep -q "ENV_UNSET" && echo "$o" | grep -q "MCPDOCTOR_TEST_UNSET" \
  && ok "T5 ENV_UNSET names the unset var" || bad "T5" "$o"

# --- T6: LAZY_FETCH — npx-launched server => LOW info note (heuristic)
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"lazy": {"command": "npx", "args": ["-y", "some-mcp-pkg"]}}}
JSON
o=$("$MD" "$f" 2>&1)
# npx may or may not be installed; either LAZY_FETCH (resolvable) or CMD_NOT_FOUND (launcher missing)
echo "$o" | grep -Eq "LAZY_FETCH|CMD_NOT_FOUND" && ok "T6 npx => LAZY_FETCH or launcher-missing" || bad "T6" "$o"

# --- T7: malformed shapes — args not a list, entry not an object => findings, no crash
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"badargs": {"command": "$GOOD", "args": "should-be-a-list"}, "notobj": 42}}
JSON
o=$("$MD" "$f" 2>&1); rc=$?
echo "$o" | grep -Eq "SHAPE_ARGS" && echo "$o" | grep -Eq "SHAPE_ENTRY" && [ "$rc" -eq 1 ] \
  && ok "T7 malformed shapes reported, no crash" || bad "T7" "rc=$rc $o"

# --- T8: fully clean config — human output exit 0, AND --json well-formed exit 0
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"a": {"command": "$GOOD"}, "b": {"type": "http", "url": "https://ok.example/mcp"}}}
JSON
o=$("$MD" "$f" 2>&1); rc=$?
echo "$o" | grep -Eiq "runnable|clean" && [ "$rc" -eq 0 ] && ok "T8 clean human => exit 0" || bad "T8 human" "rc=$rc $o"
o=$("$MD" --json "$f" 2>&1); rc=$?
echo "$o" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["summary"]["total"]==0' 2>/dev/null \
  && [ "$rc" -eq 0 ] && ok "T8b clean --json => total 0, exit 0" || bad "T8b json" "rc=$rc $o"

# --- T9: --json on a findings config emits findings + summary counts, exit 1
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"ghost": {"command": "$BOGUS"}}}
JSON
o=$("$MD" --json "$f" 2>&1); rc=$?
echo "$o" | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d["summary"]["high"]>=1 and d["findings"][0]["code"]=="CMD_NOT_FOUND"' 2>/dev/null \
  && [ "$rc" -eq 1 ] && ok "T9 --json findings + summary, exit 1" || bad "T9" "rc=$rc $o"

# --- T10: missing file => exit 2
"$MD" /no/such/file/here.json >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T10 missing file => exit 2" || bad "T10" "rc=$?"

# --- T11: invalid JSON => exit 2
f=$(tmp); printf '{ this is not json ' > "$f"
"$MD" "$f" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T11 invalid JSON => exit 2" || bad "T11" "rc=$?"

# --- T12: no mcpServers block => exit 2
f=$(tmp); printf '{"somethingElse": {"x": 1}}' > "$f"
"$MD" "$f" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T12 no mcpServers => exit 2" || bad "T12" "rc=$?"

# --- T13: stdin input via '-' works
o=$(printf '{"mcpServers": {"ghost": {"command": "%s"}}}' "$BOGUS" | "$MD" - 2>&1); rc=$?
echo "$o" | grep -q "CMD_NOT_FOUND" && [ "$rc" -eq 1 ] && ok "T13 reads stdin via '-'" || bad "T13" "rc=$rc $o"

# --- T14: disclaimer is always printed (honest static-scope label)
f=$(tmp); cat > "$f" <<JSON
{"mcpServers": {"a": {"command": "$GOOD"}}}
JSON
o=$("$MD" "$f" 2>&1)
echo "$o" | grep -qi "does NOT start the server" && ok "T14 honest static disclaimer present" || bad "T14" "$o"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
