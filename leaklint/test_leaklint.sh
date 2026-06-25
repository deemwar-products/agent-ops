#!/usr/bin/env bash
# Tests for leaklint. Ground truth = real secret SHAPES (vendor key formats, PEM headers,
# KEY=<random> assignments) + placeholder/env-ref negatives + a transcript with a key in a
# tool_use input. The DEFINING test asserts the tool never echoes a secret's value.
# NOTE: all "secrets" below are obviously-fake random strings generated at test time — no
# real credential is ever hardcoded here.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LL="$HERE/leaklint"; chmod +x "$LL"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1 -- $2"; }

# fake-but-shaped secrets (random tails so they trip format/entropy but are not real)
ANT="sk-ant-api03-$(python3 -c 'import random,string;print("".join(random.choice(string.ascii_letters+string.digits+"_-") for _ in range(90)))')"
GH="ghp_$(python3 -c 'import random,string;print("".join(random.choice(string.ascii_letters+string.digits) for _ in range(36)))')"
AWS="AKIA$(python3 -c 'import random,string;print("".join(random.choice(string.ascii_uppercase+string.digits) for _ in range(16)))')"
RAND="$(python3 -c 'import random,string;print("".join(random.choice(string.ascii_letters+string.digits) for _ in range(40)))')"

# T1: clean prose -> exit 0, "clean"
printf 'Here is the function you asked for. It reads the key from the environment.\nAll good.\n' > "$W/clean.txt"
out=$("$LL" "$W/clean.txt"); rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "clean"; } && ok "T1 clean prose = exit 0" || bad T1 "$out"

# T2: Anthropic key -> PROVIDER-KEY, exit 1
printf 'Sure, use this key: %s in your config.\n' "$ANT" > "$W/ant.txt"
out=$("$LL" "$W/ant.txt"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "PROVIDER-KEY" && echo "$out" | grep -q "Anthropic"; } && ok "T2 Anthropic key flagged + exit 1" || bad T2 "$out"

# T3 (DEFINING): the secret VALUE never appears in stdout, in any mode
out=$("$LL" "$W/ant.txt"); j=$("$LL" --json "$W/ant.txt")
if echo "$out$j" | grep -qF "$ANT"; then bad T3 "secret value LEAKED into output"; else ok "T3 DEFINING: value never printed (text+json)"; fi
# and the json must carry no "value" key
echo "$j" | grep -q '"value"' && bad T3b "json has a value key" || ok "T3b json has no value key"

# T4: GitHub token + AWS key both flagged
printf 'token=%s and aws=%s\n' "$GH" "$AWS" > "$W/multi.txt"
out=$("$LL" "$W/multi.txt"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "GitHub token" && echo "$out" | grep -q "AWS access key"; } && ok "T4 GitHub + AWS flagged" || bad T4 "$out"

# T5: PEM private-key header flagged, body bytes never printed
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAAB\n-----END OPENSSH PRIVATE KEY-----\n' > "$W/pem.txt"
out=$("$LL" "$W/pem.txt")
{ echo "$out" | grep -q "PRIVATE-KEY" && ! echo "$out" | grep -q "b3BlbnNz"; } && ok "T5 PEM header flagged, body not printed" || bad T5 "$out"

# T6: high-entropy KEY=<literal> assignment flagged (ASSIGNED-SECRET)
printf 'OPENAI_API_KEY = "%s"\n' "$RAND" > "$W/assign.txt"
out=$("$LL" "$W/assign.txt")
echo "$out" | grep -q "ASSIGNED-SECRET" && ok "T6 KEY=<random literal> flagged" || bad T6 "$out"

# T7: placeholder NOT flagged
printf 'OPENAI_API_KEY = "YOUR_KEY_HERE"\nANTHROPIC_API_KEY = "sk-ant-xxxxxxxxxxxxxxxxxxxx"\n' > "$W/ph.txt"
out=$("$LL" "$W/ph.txt"); rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "clean"; } && ok "T7 placeholders not flagged" || bad T7 "$out"

# T8: env-var REFERENCE (the correct pattern) NOT flagged
printf 'api_key = os.environ["OPENAI_API_KEY"]\nTOKEN="$GITHUB_TOKEN"\nkey: ${MY_SECRET}\n' > "$W/ref.txt"
out=$("$LL" "$W/ref.txt"); rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "clean"; } && ok "T8 env-var references not flagged" || bad T8 "$out"

# T9: UUID / git-SHA assigned to a token name NOT flagged (generic-detector guard)
printf 'request_token = "550e8400-e29b-41d4-a716-446655440000"\ncommit_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"\n' > "$W/uuid.txt"
out=$("$LL" "$W/uuid.txt"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T9 uuid + bare-hex not flagged as secrets" || bad T9 "$out"

# T10: transcript mode flags a key in a tool_use INPUT (the key divergence from langcheck)
W="$W" GH="$GH" python3 -c '
import json,os
key=os.environ["GH"]
rows=[
 {"type":"user","message":{"role":"user","content":[{"type":"text","text":"deploy it"}]}},
 {"type":"assistant","message":{"role":"assistant","content":[
   {"type":"text","text":"Running the deploy now."},
   {"type":"tool_use","name":"Bash","input":{"command":"curl -H \"Authorization: token "+key+"\" https://api.github.com"}}
 ]}},
]
open(os.environ["W"]+"/tx.jsonl","w").write("\n".join(json.dumps(r) for r in rows))
'
out=$("$LL" --transcript "$W/tx.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "tool_use:Bash" && ! echo "$out" | grep -qF "$GH"; } && ok "T10 transcript flags key in tool_use input, value redacted" || bad T10 "$out"

# T11: stdin mode
out=$(printf 'nothing secret here\n' | "$LL"); echo "$out" | grep -q "clean" && ok "T11 stdin clean" || bad T11 "$out"
out=$(printf 'leaked %s now\n' "$AWS" | "$LL"); echo "$out" | grep -q "AWS access key" && ok "T11b stdin flags AWS key" || bad T11b "$out"

# T12: --json structure
j=$(printf 'k=%s\n' "$GH" | "$LL" --json); echo "$j" | python3 -c 'import sys,json;d=json.load(sys.stdin);assert d["clean"] is False and d["findings"][0]["detector"]=="PROVIDER-KEY"' && ok "T12 --json well-formed" || bad T12 "$j"

# T13: --help
"$LL" --help | grep -q "LEAKED SECRETS in LLM" && ok "T13 --help" || bad T13 "no help"

# T14: missing file = exit 2
"$LL" "$W/nope.txt" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T14 missing file = exit 2" || bad T14 "rc"

# T15: short value reveals zero prefix chars (redaction floor)
printf 'sk_live_%s\n' "$(python3 -c 'import random,string;print("".join(random.choice(string.ascii_letters+string.digits) for _ in range(24)))')" > "$W/short.txt"
out=$("$LL" "$W/short.txt"); echo "$out" | grep -q "sha256:" && ok "T15 fingerprint present" || bad T15 "$out"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
