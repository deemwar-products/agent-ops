#!/usr/bin/env bash
# Tests for skill-doctor — builds throwaway skills directories with fixtures in
# known-broken and known-clean states, asserts the finding codes + exit codes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$HERE/skill-doctor"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/skill-doctor.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT

# helper: write a SKILL.md
skillmd() { # $1=dir $2=name(optional) $3=desc(optional) $4=raw(if "raw", write $5 verbatim)
  mkdir -p "$1"
  if [ "${4:-}" = "raw" ]; then
    printf '%s' "$5" > "$1/SKILL.md"
  elif [ -n "${2:-}" ]; then
    printf -- '---\nname: %s\ndescription: %s\n---\n\n# body\n' "$2" "${3:-a useful description here}" > "$1/SKILL.md"
  else
    printf -- '---\ndescription: %s\n---\n\n# body\n' "${3:-a useful description here}" > "$1/SKILL.md"
  fi
}

# ---- DIRTY skills dir: one of every fault + healthy controls -----------------
D="$ROOT/skills"; mkdir -p "$D"
skillmd "$D/healthy" "healthy" "a perfectly fine skill that should register cleanly"
ln -s /nonexistent/path/nowhere "$D/brokenskill"            # BROKEN_SYMLINK
mkdir -p "$D/nomd"                                          # NO_SKILL_MD
skillmd "$D/noframe" "" "" raw "$(printf '# just a heading\nno frontmatter here\n')"  # NO_FRONTMATTER
skillmd "$D/noname" "" "" raw "$(printf -- '---\ndescription: has frontmatter but no name\n---\n')"  # NO_NAME
skillmd "$D/dupa"  "samename" "first skill to claim this name"   # DUP_NAME (a)
skillmd "$D/dupb"  "samename" "second skill to claim this name"  # DUP_NAME (b)
skillmd "$D/mismatch" "actuallyfoo" "name differs from its directory"  # NAME_MISMATCH
echo "i am a stray file" > "$D/loose.txt"                  # STRAY_ENTRY

out=$("$SD" "$D" 2>/dev/null); rc=$?
js=$("$SD" --json "$D" 2>/dev/null)

echo "### dirty dir: exit code + summary"
[ "$rc" -eq 1 ] && ok "T1 exit 1 when findings exist" || bad "T1 exit" "got $rc"
echo "$out" | grep -q "skill-doctor —" && ok "T2 prints a report header" || bad "T2 header" "$out"

echo "### each check code appears in --json"
for code in BROKEN_SYMLINK NO_SKILL_MD NO_FRONTMATTER NO_NAME DUP_NAME NAME_MISMATCH STRAY_ENTRY; do
  echo "$js" | grep -q "\"$code\"" && ok "T-$code emitted" || bad "T-$code" "$js"
done

echo "### healthy skill produces no finding for itself"
echo "$js" | python3 -c '
import json,sys
d=json.load(sys.stdin)
bad=[f for f in d["findings"] if f["skill"]=="healthy"]
sys.exit(1 if bad else 0)
' && ok "T3 healthy skill has zero findings" || bad "T3 healthy clean" "$js"

echo "### dup name reported for BOTH owners"
dupcount=$(echo "$js" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(sum(1 for f in d["findings"] if f["code"]=="DUP_NAME"))')
[ "$dupcount" -eq 2 ] && ok "T4 DUP_NAME flagged on both skills" || bad "T4 dup count" "got $dupcount"

echo "### severities are well-formed"
echo "$js" | python3 -c '
import json,sys
d=json.load(sys.stdin)
allowed={"HIGH","MED","LOW"}
sys.exit(0 if all(f["severity"] in allowed for f in d["findings"]) else 1)
' && ok "T5 all severities in {HIGH,MED,LOW}" || bad "T5 severities" "$js"

echo "### json shape"
echo "$js" | python3 -c '
import json,sys
d=json.load(sys.stdin)
keys={"skills_dir","skills_scanned","findings","summary"}
s=d["summary"]
sk={"total","high","med","low"}
sys.exit(0 if keys<=set(d) and sk<=set(s) and s["total"]==len(d["findings"]) else 1)
' && ok "T6 json has skills_dir/skills_scanned/findings/summary + tallies" || bad "T6 json shape" "$js"

# ---- CLEAN skills dir: only healthy skills -> exit 0 both modes --------------
C="$ROOT/clean"; mkdir -p "$C"
skillmd "$C/alpha" "alpha" "the first clean skill, fully registrable and well-formed"
skillmd "$C/beta"  "beta"  "the second clean skill, also fully registrable and fine"

echo "### clean dir -> exit 0 (human)"
cout=$("$SD" "$C" 2>/dev/null); crc=$?
[ "$crc" -eq 0 ] && ok "T7 exit 0 on a fully-clean skills dir" || bad "T7 clean exit" "got $crc :: $cout"
echo "$cout" | grep -q "structurally sound" && ok "T8 clean dir prints the all-good line" || bad "T8 clean msg" "$cout"

echo "### clean dir -> exit 0 (--json) with empty findings"
cjs=$("$SD" --json "$C" 2>/dev/null); cjrc=$?
[ "$cjrc" -eq 0 ] && ok "T9 --json exit 0 on clean dir" || bad "T9 clean json exit" "got $cjrc"
echo "$cjs" | python3 -c 'import json,sys;d=json.load(sys.stdin);sys.exit(0 if d["findings"]==[] and d["skills_scanned"]==2 else 1)' \
  && ok "T10 clean --json: 0 findings, 2 skills scanned" || bad "T10 clean json body" "$cjs"

# ---- bad input -> exit 2 -----------------------------------------------------
echo "### bad input -> exit 2"
"$SD" "$ROOT/does-not-exist" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T11 missing dir exits 2" || bad "T11 missing" "expected 2"
TOUCHED="$ROOT/afile"; echo x > "$TOUCHED"
"$SD" "$TOUCHED" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T12 not-a-directory exits 2" || bad "T12 notdir" "expected 2"
EMPTY="$ROOT/empty"; mkdir -p "$EMPTY"
"$SD" "$EMPTY" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T13 empty dir exits 2" || bad "T13 empty" "expected 2"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
