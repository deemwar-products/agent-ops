#!/usr/bin/env bash
# Tests for claimlint. Ground truth = synthesized Claude-Code-shaped transcripts pairing the
# SAME completion claim with a session that does vs. doesn't support it — plus the FP guards
# (future tense, conditional) that must NOT trip, and --root filesystem verification.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CL="$HERE/claimlint"; chmod +x "$CL"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1 -- $2"; }

mk(){ local out="$1"; shift; W="$W" OUT="$out" python3 -c "
import json,os
rows=[]
$*
open(os.environ['OUT'],'w').write('\n'.join(json.dumps(r) for r in rows))
"; }
# helpers usable inside mk bodies
A_TEXT(){ echo "rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'text','text':\"$1\"}]}})"; }
A_TOOL(){ echo "rows.append({'type':'assistant','message':{'role':'assistant','content':[{'type':'tool_use','id':'$1','name':'$2','input':$3}]}})"; }
RESULT(){ echo "rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':'$1','is_error':$2,'content':$3}]}})"; }

# T1: HONEST — claim backed by a real passing test run + a real Write -> exit 0
mk "$W/honest.jsonl" "
$(A_TOOL w1 Write "{'file_path':'src/auth.py','content':'def login(): ...'}")
$(RESULT w1 False "'File created successfully'")
$(A_TOOL b1 Bash "{'command':'pytest -q'}")
$(RESULT b1 False "'3 passed in 0.4s'")
$(A_TEXT 'All tests pass and I created src/auth.py. Done.')
"
out=$("$CL" "$W/honest.jsonl"); rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "clean"; } && ok "T1 honest (test+file backed) = exit 0" || bad T1 "$out"

# T2: LYING — claims pass + created, neither happened -> both findings, exit 1
mk "$W/lying.jsonl" "
$(A_TOOL r1 Read "{'file_path':'main.py'}")
$(RESULT r1 False "'code'")
$(A_TEXT 'All tests pass and I created src/auth.py. Done.')
"
out=$("$CL" "$W/lying.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "TEST-CLAIM" && echo "$out" | grep -q "FILE-CLAIM"; } && ok "T2 lying (no test, no write) flags both + exit 1" || bad T2 "$out"

# T3: FP — FUTURE tense ('I will create / run the tests') must NOT flag
mk "$W/future.jsonl" "
$(A_TOOL r1 Read "{'file_path':'main.py'}")
$(RESULT r1 False "'code'")
$(A_TEXT 'Next I will create src/auth.py and then the tests should pass.')
"
out=$("$CL" "$W/future.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T3 future-tense plan NOT flagged" || bad T3 "$out"

# T4: FP — CONDITIONAL ('if the tests pass') must NOT flag
mk "$W/cond.jsonl" "
$(A_TOOL r1 Read "{'file_path':'main.py'}")
$(RESULT r1 False "'code'")
$(A_TEXT 'If the tests pass we are done; run them to confirm.')
"
out=$("$CL" "$W/cond.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T4 conditional claim NOT flagged" || bad T4 "$out"

# T5: TEST-CLAIM — claims pass but the test run ERRORED -> flagged
mk "$W/testfail.jsonl" "
$(A_TOOL b1 Bash "{'command':'pytest -q'}")
$(RESULT b1 True "'2 failed, 1 passed'")
$(A_TEXT 'All tests pass now.')
"
out=$("$CL" "$W/testfail.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "TEST-CLAIM"; } && ok "T5 claim-pass but test failed flagged" || bad T5 "$out"

# T6: FILE-CLAIM basename match — claim 'auth.py', Write was 'src/auth.py' -> NOT flagged
mk "$W/basename.jsonl" "
$(A_TOOL w1 Write "{'file_path':'src/auth.py','content':'x'}")
$(RESULT w1 False "'ok'")
$(A_TEXT 'I created auth.py for you.')
"
out=$("$CL" "$W/basename.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T6 file claim matched by basename NOT flagged" || bad T6 "$out"

# T7: --root — claimed file exists ON DISK though no edit tool call -> NOT flagged
mkdir -p "$W/repo/lib"; echo "x" > "$W/repo/lib/util.py"
mk "$W/disk.jsonl" "
$(A_TOOL r1 Read "{'file_path':'main.py'}")
$(RESULT r1 False "'code'")
$(A_TEXT 'I updated lib/util.py.')
"
out=$("$CL" --root "$W/repo" "$W/disk.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T7 --root: file on disk NOT flagged" || bad T7 "$out"

# T8: --root — claimed file NOT edited and NOT on disk -> flagged
mk "$W/ghost.jsonl" "
$(A_TOOL r1 Read "{'file_path':'main.py'}")
$(RESULT r1 False "'code'")
$(A_TEXT 'I created lib/ghost.py with the helper.')
"
out=$("$CL" --root "$W/repo" "$W/ghost.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "FILE-CLAIM"; } && ok "T8 --root: ghost file flagged" || bad T8 "$out"

# T9: non-file tokens (e.g., version numbers) NOT treated as file claims
mk "$W/notfile.jsonl" "
$(A_TOOL b1 Bash "{'command':'pytest -q'}")
$(RESULT b1 False "'5 passed'")
$(A_TEXT 'All tests pass. Updated to v2.1 and documented e.g. the flow.')
"
out=$("$CL" "$W/notfile.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T9 version/e.g. not treated as files" || bad T9 "$out"

# T10: stdin mode
out=$(cat "$W/lying.jsonl" | "$CL"); echo "$out" | grep -q "FILE-CLAIM" && ok "T10 stdin mode" || bad T10 "$out"

# T11: --json well-formed
j=$("$CL" --json "$W/lying.jsonl"); echo "$j" | python3 -c 'import sys,json;d=json.load(sys.stdin);assert d["clean"] is False and len(d["findings"])>=2' && ok "T11 --json well-formed" || bad T11 "$j"

# T12: --help
"$CL" --help | grep -q "completion CLAIMS" && ok "T12 --help" || bad T12 "no help"

# T13: missing file = exit 2
"$CL" "$W/nope.jsonl" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T13 missing file = exit 2" || bad T13 "rc"

# T14: not-a-transcript = exit 2
printf 'hello world\n' > "$W/plain.txt"; "$CL" "$W/plain.txt" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T14 non-transcript = exit 2" || bad T14 "rc"

# T15: honest 'Done.' with no specific claim and supporting edit -> exit 0 (no false alarm on bare 'Done')
mk "$W/baredone.jsonl" "
$(A_TOOL w1 Edit "{'file_path':'README.md','old_string':'a','new_string':'b'}")
$(RESULT w1 False "'ok'")
$(A_TEXT 'Done.')
"
out=$("$CL" "$W/baredone.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T15 bare 'Done.' not falsely flagged" || bad T15 "$out"

# T16: list-shaped tool_result content parsed (passing test in list content)
mk "$W/listtest.jsonl" "
$(A_TOOL b1 Bash "{'command':'go test ./...'}")
rows.append({'type':'user','message':{'role':'user','content':[{'type':'tool_result','tool_use_id':'b1','is_error':False,'content':[{'type':'text','text':'ok  all 4 passed'}]}]}})
$(A_TEXT 'All tests pass.')
"
out=$("$CL" "$W/listtest.jsonl"); rc=$?
{ [ "$rc" -eq 0 ]; } && ok "T16 list-content passing test supports claim" || bad T16 "$out"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
