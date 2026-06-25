#!/usr/bin/env bash
# Tests for spinlint. Ground truth = synthesized Claude-Code-shaped transcripts covering the
# real loop shapes (repeated identical call, repeated error, ping-pong edits) AND the
# productive-repetition negatives that must NOT trip it (retry that succeeds, batch reads,
# varying-input polling, monotonic edits). Built with python3 to match the real JSONL schema.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SL="$HERE/spinlint"; chmod +x "$SL"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1 -- $2"; }

mk(){ # mk <outfile> <python-body-building-list-`rows`>
  local out="$1"; shift
  W="$W" OUT="$out" python3 -c "
import json,os
rows=[]
$*
open(os.environ['OUT'],'w').write('\n'.join(json.dumps(r) for r in rows))
"
}
asst_tool(){ echo "rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':'$1','name':'$2','input':$3}]}})"; }
asst_text(){ echo "rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'text','text':'$1'}]}})"; }
result(){ echo "rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':'$1','is_error':$2,'content':$3}]}})"; }

# T1: a clean, progressing session -> exit 0
mk "$W/clean.jsonl" "
$(asst_tool t1 Read "{'file_path':'a.py'}")
$(result t1 False "'ok'")
$(asst_tool t2 Edit "{'file_path':'a.py','old_string':'x','new_string':'y'}")
$(result t2 False "'done'")
$(asst_tool t3 Bash "{'command':'pytest'}")
$(result t3 False "'2 passed'")
"
out=$("$SL" "$W/clean.jsonl"); rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "clean"; } && ok "T1 clean session = exit 0" || bad T1 "$out"

# T2: 5x identical failing Bash -> REPEAT-CALL + exit 1
mk "$W/repeat.jsonl" "
for i in range(5):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f't{i}','name':'Bash','input':{'command':'npm run build'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f't{i}','is_error':True,'content':\"error TS2304: name 'foo'\"}]}})
"
out=$("$SL" "$W/repeat.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "REPEAT-CALL" && echo "$out" | grep -q "all failing"; } && ok "T2 5x identical failing Bash flagged + exit 1" || bad T2 "$out"

# T3: error->error->error (>=3 same error) -> REPEAT-ERROR
mk "$W/err.jsonl" "
for i in range(3):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'e{i}','name':'Edit','input':{'file_path':f'f{i}.py','old_string':'a','new_string':'b'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'e{i}','is_error':True,'content':'File has not been read yet. Read it first.'}]}})
"
out=$("$SL" "$W/err.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "REPEAT-ERROR"; } && ok "T3 repeated identical error flagged" || bad T3 "$out"

# T4 (DEFINING): error -> error -> SUCCESS must NOT be flagged (success breaks the streak)
mk "$W/recover.jsonl" "
for i,err in enumerate([True,True,False]):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f's{i}','name':'Bash','input':{'command':f'attempt {i}'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f's{i}','is_error':err,'content':'compile error' if err else 'success'}]}})
"
out=$("$SL" "$W/recover.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T4 DEFINING: error->error->success NOT flagged" || bad T4 "$out"

# T5: batch reads of DIFFERENT files -> NOT flagged
mk "$W/batch.jsonl" "
for i in range(8):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'b{i}','name':'Read','input':{'file_path':f'src/mod{i}.py'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'b{i}','content':'contents'}]}})
"
out=$("$SL" "$W/batch.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T5 batch reads of different files NOT flagged" || bad T5 "$out"

# T6: polling with VARYING input -> NOT flagged
mk "$W/poll.jsonl" "
for i in range(6):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'p{i}','name':'Bash','input':{'command':f'sleep {i} && curl host?cursor={i}'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'p{i}','content':'pending'}]}})
"
out=$("$SL" "$W/poll.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T6 varying-input polling NOT flagged" || bad T6 "$out"

# T7: PING-PONG oscillating edits to one file -> flagged
mk "$W/pingpong.jsonl" "
edits=[('A','B'),('B','A'),('A','B'),('B','A')]
for i,(o,n) in enumerate(edits):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'pp{i}','name':'Edit','input':{'file_path':'src/auth.go','old_string':o,'new_string':n}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'pp{i}','content':'edited'}]}})
"
out=$("$SL" "$W/pingpong.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "PING-PONG" && echo "$out" | grep -q "auth.go"; } && ok "T7 oscillating edits flagged" || bad T7 "$out"

# T8: monotonic forward edits to one file (all distinct) -> NOT flagged
mk "$W/forward.jsonl" "
for i in range(6):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'fw{i}','name':'Edit','input':{'file_path':'big.py','old_string':f'line{i}', 'new_string':f'newline{i}'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'fw{i}','content':'edited'}]}})
"
out=$("$SL" "$W/forward.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T8 monotonic forward edits NOT flagged" || bad T8 "$out"

# T9: --json well-formed + carries no raw command beyond truncated signature
mk "$W/j.jsonl" "
for i in range(4):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'j{i}','name':'Bash','input':{'command':'go test ./...'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'j{i}','is_error':True,'content':'FAIL'}]}})
"
j=$("$SL" --json "$W/j.jsonl")
echo "$j" | python3 -c 'import sys,json;d=json.load(sys.stdin);assert d["clean"] is False and d["estimated_wasted_calls"]>=3 and d["findings"][0]["detector"]=="REPEAT-CALL"' && ok "T9 --json well-formed + wasted count" || bad T9 "$j"

# T10: stdin mode
out=$(cat "$W/repeat.jsonl" | "$SL"); echo "$out" | grep -q "REPEAT-CALL" && ok "T10 stdin mode" || bad T10 "$out"

# T11: --repeat threshold tunable (4 identical, default 3 flags; --repeat 5 does NOT)
mk "$W/four.jsonl" "
for i in range(4):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'q{i}','name':'Bash','input':{'command':'ls'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'q{i}','content':'ok'}]}})
"
"$SL" "$W/four.jsonl" >/dev/null 2>&1; d3=$?
"$SL" --repeat 5 "$W/four.jsonl" >/dev/null 2>&1; d5=$?
{ [ "$d3" -ne 0 ] && [ "$d5" -eq 0 ]; } && ok "T11 --repeat threshold tunable" || bad T11 "default=$d3 repeat5=$d5"

# T12: --help
"$SL" --help | grep -q "WASTED-LOOP" && ok "T12 --help" || bad T12 "no help"

# T13: missing file = exit 2
"$SL" "$W/nope.jsonl" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T13 missing file = exit 2" || bad T13 "rc"

# T14: list-shaped tool_result.content parsed (error in list content still counts)
mk "$W/listcontent.jsonl" "
for i in range(3):
    rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':f'l{i}','name':'Bash','input':{'command':'make'}}]}})
    rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':f'l{i}','is_error':True,'content':[{'type':'text','text':'make: *** error'}]}]}})
"
out=$("$SL" "$W/listcontent.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -qE "REPEAT-(CALL|ERROR)"; } && ok "T14 list-shaped tool_result content parsed" || bad T14 "$out"

# T15: wasted-calls estimate present in human output
out=$("$SL" "$W/repeat.jsonl"); echo "$out" | grep -q "wasted tool-calls" && ok "T15 wasted-calls estimate shown" || bad T15 "$out"

# T16: not-a-transcript = exit 2
printf 'just some text\nnot jsonl\n' > "$W/plain.txt"
"$SL" "$W/plain.txt" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T16 non-transcript = exit 2" || bad T16 "rc"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
