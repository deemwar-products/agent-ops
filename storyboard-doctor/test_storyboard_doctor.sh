#!/usr/bin/env bash
# Tests for storyboard-doctor — feed synthetic storyboards, assert the findings.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$HERE/storyboard-doctor"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }
sbfile() { f=$(mktemp /tmp/sb.XXXXXX); printf '%s' "$1" > "$f"; echo "$f"; }

CLEAN='{"name":"ok","cards":[{"id":"open","duration":8}],
 "vhs":[{"id":"term","lines":["Show","Type \"ls\"","Type \"pwd\""]}],
 "captions":[{"segment":"vhs:term","text":"hi","from":1,"to":6}],
 "voiceover":{"parts":[{"at":"card:open","text":"short line"},{"at":"vhs:term","text":"a brief terminal narration that fits"}]},
 "timeline":["card:open","vhs:term","card:outro"]}'

f=$(sbfile "$CLEAN")
"$SD" "$f" >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T1 clean storyboard exits 0" || bad "T1 clean" "$("$SD" "$f")"
"$SD" "$f" | grep -q "clean" && ok "T2 clean prints clean" || bad "T2 clean msg" "$("$SD" "$f")"

# card VO overflow
CARD='{"name":"c","cards":[{"id":"open","duration":5}],"vhs":[{"id":"t","lines":["Show"]}],
 "voiceover":{"parts":[{"at":"card:open","text":"this is a long voiceover with far too many words to fit inside a five second brand card so it should warn"}]},
 "timeline":["card:open","vhs:t"]}'
f=$(sbfile "$CARD"); out=$("$SD" "$f"); echo "$out" | grep -q "card:open VO" && ok "T3 flags card VO overflow" || bad "T3 card overflow" "$out"

# vhs VO overflow
VHS='{"name":"v","cards":[{"id":"o","duration":8}],"vhs":[{"id":"term","lines":["Show"]}],
 "voiceover":{"parts":[{"at":"vhs:term","text":"this terminal narration is deliberately very long with many many words so that it exceeds the dead air trimmed command line segment ceiling and must be flagged by the linter as too long"}]},
 "timeline":["card:o","vhs:term"]}'
f=$(sbfile "$VHS"); out=$("$SD" "$f"); echo "$out" | grep -q "vhs:term VO" && ok "T4 flags vhs VO overflow" || bad "T4 vhs overflow" "$out"

# voiceover anchored to a missing timeline entry => ERROR
MISS='{"name":"m","cards":[{"id":"o","duration":8}],"vhs":[{"id":"t","lines":["Show"]}],
 "voiceover":{"parts":[{"at":"card:ghost","text":"hi"}]},"timeline":["card:o","vhs:t"]}'
f=$(sbfile "$MISS"); out=$("$SD" "$f" 2>&1); rc=$?
{ [ "$rc" -eq 1 ] && echo "$out" | grep -q "ERROR"; } && ok "T5 ERROR on bad VO anchor" || bad "T5 anchor" "$out"

# caption past the ceiling
CAP='{"name":"p","cards":[{"id":"o","duration":8}],"vhs":[{"id":"term","lines":["Show"]}],
 "captions":[{"segment":"vhs:term","text":"late","from":1,"to":17}],
 "voiceover":{"parts":[{"at":"card:o","text":"hi"}]},"timeline":["card:o","vhs:term"]}'
f=$(sbfile "$CAP"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -q "caption 0 on vhs:term ends at 17" && ok "T6 flags caption past segment" || bad "T6 caption" "$out"

# caption to a nonexistent segment => ERROR
CAPSEG='{"name":"cs","cards":[{"id":"o","duration":8}],"vhs":[{"id":"term","lines":["Show"]}],
 "captions":[{"segment":"vhs:ghost","text":"x","from":1,"to":3}],
 "voiceover":{"parts":[{"at":"card:o","text":"hi"}]},"timeline":["card:o","vhs:term"]}'
f=$(sbfile "$CAPSEG"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -q "ERROR: caption 0 targets segment" && ok "T7 ERROR on caption to missing segment" || bad "T7 capseg" "$out"

# timeline references a missing card => ERROR
TL='{"name":"tl","cards":[{"id":"o","duration":8}],"vhs":[{"id":"t","lines":["Show"]}],
 "voiceover":{"parts":[]},"timeline":["card:o","card:nope","vhs:t"]}'
f=$(sbfile "$TL"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -q "card:nope" && ok "T8 flags timeline missing card" || bad "T8 timeline" "$out"

# risky inline-JSON Type line => WARN
RISK='{"name":"r","cards":[{"id":"o","duration":8}],
 "vhs":[{"id":"term","lines":["Show","Type \"echo '"'"'{\\\"k\\\":1}'"'"' | tool | python3 -m json.tool\""]}],
 "voiceover":{"parts":[{"at":"card:o","text":"hi"}]},"timeline":["card:o","vhs:term"]}'
f=$(sbfile "$RISK"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -qi "break the VHS tape parser" && ok "T9 flags risky inline-JSON Type line" || bad "T9 risky type" "$out"

# --cli-ceiling override: a higher ceiling clears the vhs overflow warning
f=$(sbfile "$VHS"); out=$("$SD" "$f" --cli-ceiling 60 2>&1); echo "$out" | grep -q "vhs:term VO" && bad "T10 ceiling override" "still warned" || ok "T10 --cli-ceiling raises the bar"

# --- adaptive estimate: the same ~9s VO warns on a 2-command demo but not a 4-command one ---
# ~21 words ≈ 8.1s: ABOVE the new 2-command estimate (7.0s) but BELOW the old fixed
# 10.5s ceiling — i.e. exactly the cycle-19 case the old fixed ceiling let through.
VO9='this terminal narration runs about eight seconds with twenty one words so it slips past a short two command segment'
twocmd() { echo '{"name":"two","cards":[{"id":"o","duration":8}],"vhs":[{"id":"t","lines":["Show","Type \"a\"","Type \"b\""]}],
 "voiceover":{"parts":[{"at":"vhs:t","text":"'"$VO9"'"}]},"timeline":["card:o","vhs:t"]}'; }
fourcmd() { echo '{"name":"four","cards":[{"id":"o","duration":8}],"vhs":[{"id":"t","lines":["Show","Type \"a\"","Type \"b\"","Type \"c\"","Type \"d\""]}],
 "voiceover":{"parts":[{"at":"vhs:t","text":"'"$VO9"'"}]},"timeline":["card:o","vhs:t"]}'; }
f=$(sbfile "$(twocmd)"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -q "vhs:t VO" && ok "T11 adaptive: a ~7s VO warns on a 2-command segment (~7s)" || bad "T11 adaptive 2cmd" "$out"
f=$(sbfile "$(fourcmd)"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -q "vhs:t VO" && bad "T12 adaptive 4cmd" "warned but shouldn't ($out)" || ok "T12 adaptive: same VO is fine on a 4-command segment (~12s)"
# a comment line is NOT counted as a command (2 commands + a comment => still ~2-command estimate)
withcomment() { echo '{"name":"c","cards":[{"id":"o","duration":8}],"vhs":[{"id":"t","lines":["Show","Type \"# a comment\"","Type \"a\"","Type \"b\""]}],
 "voiceover":{"parts":[{"at":"vhs:t","text":"'"$VO9"'"}]},"timeline":["card:o","vhs:t"]}'; }
f=$(sbfile "$(withcomment)"); out=$("$SD" "$f" 2>&1); echo "$out" | grep -q "vhs:t VO" && ok "T13 comments aren't counted as commands" || bad "T13 comments" "$out"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
