#!/usr/bin/env bash
# Tests for langcheck. Ground truth = real text samples (the actual bug shapes:
# CJK in English output, mojibake, runaway repetition) + a real transcript JSONL.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LC="$HERE/langcheck"; chmod +x "$LC"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
bad(){ FAIL=$((FAIL+1)); echo "FAIL: $1 -- $2"; }

# T1: clean English -> exit 0, "clean"
printf 'The quick brown fox jumps over the lazy dog.\nThis is a normal paragraph of English output.\n' > "$W/clean.txt"
out=$("$LC" "$W/clean.txt"); rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "clean"; } && ok "T1 clean English = exit 0" || bad T1 "$out"

# T2: English output with a random CJK run (the actual bug) -> SCRIPT-INTRUSION, exit 1
python3 -c 'open("'"$W/cjk.txt"'","w",encoding="utf-8").write("Here is the function you asked for. 这是一个 it returns the value.\nAll good otherwise.\n")'
out=$("$LC" "$W/cjk.txt"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "SCRIPT-INTRUSION" && echo "$out" | grep -q "CJK"; } && ok "T2 CJK-in-English flagged + exit 1" || bad T2 "$out"

# T3: a genuinely Chinese document is NOT flagged as intrusion
python3 -c 'open("'"$W/zh.txt"'","w",encoding="utf-8").write("这是一个完全用中文写的文档。它包含许多中文句子和段落。没有英文。\n第二行也是中文内容。\n")'
out=$("$LC" "$W/zh.txt"); rc=$?
{ [ "$rc" -eq 0 ] && ! echo "$out" | grep -q "SCRIPT-INTRUSION"; } && ok "T3 predominantly-Chinese doc not false-flagged" || bad T3 "$out"

# T4: mojibake replacement char -> MOJIBAKE
python3 -c 'open("'"$W/moji.txt"'","w",encoding="utf-8").write("The price is �25 today and the rest is fine.\n")'
out=$("$LC" "$W/moji.txt")
echo "$out" | grep -q "MOJIBAKE" && ok "T4 mojibake (U+FFFD) flagged" || bad T4 "$out"

# T5: runaway repetition -> REPETITION
{ echo "Generating the report now."; for i in 1 2 3 4 5; do echo "I will now continue."; done; echo "Done."; } > "$W/rep.txt"
out=$("$LC" "$W/rep.txt")
echo "$out" | grep -q "REPETITION" && echo "$out" | grep -q "5x" && ok "T5 runaway repetition flagged (5x)" || bad T5 "$out"

# T5b: below threshold (3x default 4) NOT flagged
{ for i in 1 2 3; do echo "ok line"; done; echo "end"; } > "$W/rep2.txt"
out=$("$LC" "$W/rep2.txt"); echo "$out" | grep -q "REPETITION" && bad T5b "3x wrongly flagged" || ok "T5b under-threshold repetition not flagged"

# T6: emoji / accented Latin in English NOT flagged as foreign-script
python3 -c 'open("'"$W/emoji.txt"'","w",encoding="utf-8").write("Great work \U0001F389 the café is naïve about résumés.\n")'
out=$("$LC" "$W/emoji.txt"); rc=$?
{ [ "$rc" -eq 0 ] && ! echo "$out" | grep -q "SCRIPT-INTRUSION"; } && ok "T6 emoji + accented Latin not flagged" || bad T6 "$out"

# T7: transcript mode extracts assistant text + flags the CJK in it
python3 -c '
import json
rows=[
 {"type":"user","message":{"role":"user","content":[{"type":"text","text":"hi"}]}},
 {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Sure, here is the plan 部署 and the steps."}]}},
]
open("'"$W/tx.jsonl"'","w").write("\n".join(json.dumps(r) for r in rows))
'
out=$("$LC" --transcript "$W/tx.jsonl"); rc=$?
{ [ "$rc" -ne 0 ] && echo "$out" | grep -q "SCRIPT-INTRUSION"; } && ok "T7 transcript mode flags CJK in assistant text" || bad T7 "$out"

# T8: stdin mode
out=$(printf 'normal english here\n' | "$LC"); echo "$out" | grep -q "clean" && ok "T8 stdin clean" || bad T8 "$out"
out=$(python3 -c 'print("english then 한국어 hangul intrusion")' | "$LC"); echo "$out" | grep -q "Hangul" && ok "T8b stdin flags Hangul intrusion" || bad T8b "$out"

# T9: --help
"$LC" --help | grep -q "contamination in LLM" && ok "T9 --help" || bad T9 "no help"

# T10: missing file = exit 2
"$LC" "$W/nope.txt" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T10 missing file = exit 2" || bad T10 "rc"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
