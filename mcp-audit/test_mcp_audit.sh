#!/usr/bin/env bash
# Tests for mcp-audit — synthetic .mcp.json shapes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MA="$HERE/mcp-audit"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }
cfg() { f=$(mktemp /tmp/mcp.XXXXXX); printf '%s' "$1" > "$f"; echo "$f"; }
run() { "$MA" "$1" 2>&1; }

# remote url server => WARN
f=$(cfg '{"mcpServers":{"w":{"url":"https://x.example.com/mcp"}}}')
o=$(run "$f"); echo "$o" | grep -Eq "WARN.*remote server" && ok "T1 remote (url) server = WARN" || bad "T1" "$o"

# unpinned npx => WARN ; pinned => not
f=$(cfg '{"mcpServers":{"fs":{"command":"npx","args":["-y","@mcp/server-fs"]}}}')
o=$(run "$f"); echo "$o" | grep -Eq "WARN.*unpinned package" && ok "T2 unpinned npx package = WARN" || bad "T2" "$o"
f=$(cfg '{"mcpServers":{"fs":{"command":"npx","args":["-y","@mcp/server-fs@1.2.3"]}}}')
o=$(run "$f"); echo "$o" | grep -q "unpinned" && bad "T3 pinned package wrongly flagged" "$o" || ok "T3 pinned package not flagged"

# path arg after the package is NOT treated as a package
f=$(cfg '{"mcpServers":{"fs":{"command":"npx","args":["-y","@mcp/server-fs@1.2.3","./project"]}}}')
o=$(run "$f"); echo "$o" | grep -q "unpinned" && bad "T4 path arg flagged as package" "$o" || ok "T4 trailing path arg not flagged as package"

# inline secret in env => HIGH ; ${VAR} ref => not ; placeholder => not
f=$(cfg '{"mcpServers":{"gh":{"command":"x","env":{"GITHUB_TOKEN":"ghp_AbCdEf0123456789ZZ"}}}}')
o=$(run "$f"); echo "$o" | grep -Eq "HIGH.*inline secret" && ok "T5 inline secret in env = HIGH" || bad "T5" "$o"
f=$(cfg '{"mcpServers":{"gh":{"command":"x","env":{"GITHUB_TOKEN":"${GITHUB_TOKEN}"}}}}')
o=$(run "$f"); echo "$o" | grep -q "inline secret" && bad "T6 env var reference wrongly flagged" "$o" || ok "T6 \${VAR} reference not flagged"
f=$(cfg '{"mcpServers":{"gh":{"command":"x","env":{"API_KEY":"your-key-here"}}}}')
o=$(run "$f"); echo "$o" | grep -q "inline secret" && bad "T7 placeholder wrongly flagged" "$o" || ok "T7 placeholder value not flagged"

# broad filesystem path => WARN ; scoped path => not
f=$(cfg '{"mcpServers":{"fs":{"command":"x","args":["~"]}}}')
o=$(run "$f"); echo "$o" | grep -Eq "WARN.*broad path" && ok "T8 broad path (~) = WARN" || bad "T8" "$o"
f=$(cfg '{"mcpServers":{"fs":{"command":"x","args":["./project"]}}}')
o=$(run "$f"); echo "$o" | grep -q "broad path" && bad "T9 scoped path wrongly flagged" "$o" || ok "T9 scoped path not flagged"

# clean config => only INFO, exit 0
f=$(cfg '{"mcpServers":{"fs":{"command":"npx","args":["-y","@mcp/server-fs@1.0.0","./proj"],"env":{"TOKEN":"${TOKEN}"}}}}')
o=$(run "$f"); echo "$o" | grep -q "no risky server shapes" && ok "T10 clean config is clean" || bad "T10" "$o"
"$MA" "$f" >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T11 clean config exits 0" || bad "T11 exit" "rc"

# invalid JSON => HIGH, exit 1
f=$(cfg '{"mcpServers": {')
o=$(run "$f"); echo "$o" | grep -Eq "HIGH.*invalid JSON" && ok "T12 invalid JSON = HIGH" || bad "T12" "$o"

# server-count INFO present
f=$(cfg '{"mcpServers":{"a":{"command":"x","args":["./p"]},"b":{"command":"y","args":["./q"]}}}')
o=$(run "$f"); echo "$o" | grep -q "2 MCP server(s) configured" && ok "T13 reports the server count" || bad "T13" "$o"

# no .mcp.json => friendly, exit 0
( cd "$(mktemp -d)" && "$MA" >/dev/null 2>&1 ); [ "$?" -eq 0 ] && ok "T14 no .mcp.json = exit 0" || bad "T14" "rc"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
