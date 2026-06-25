#!/usr/bin/env bash
# Tests for agent-doctor — lints Claude Code custom subagent definitions for the
# frontmatter/registration mistakes that silently stop an agent from registering or
# being routed to. Deterministic: builds synthetic .claude/agents fixtures and asserts
# on exit codes and the stable check codes in --json.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
AD="$HERE/agent-doctor"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }
mkd() { mktemp -d; }

# A healthy agent file: frontmatter with name + description, plus a body.
healthy() {  # $1=dir $2=name
  printf -- '---\nname: %s\ndescription: Use this agent when the user wants to review Go code for bugs.\nmodel: sonnet\n---\n\nYou are a careful Go code reviewer. Find real bugs.\n' "$2" "$2" > "$1/$2.md"
}

# --- T1: a healthy agent => clean, exit 0
d=$(mkd); healthy "$d" reviewer
"$AD" "$d" >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T1 healthy agent exit 0" || bad "T1 exit" "rc=$?"
o=$("$AD" "$d" 2>&1)
echo "$o" | grep -Eiq "nothing to fix|✓" && ok "T1b healthy = clean text" || bad "T1b" "$o"

# --- T2: no frontmatter => NO_FRONTMATTER, exit 1
d=$(mkd); printf 'just a markdown body, no frontmatter at all.\n' > "$d/loose.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "NO_FRONTMATTER" && ok "T2 NO_FRONTMATTER flagged" || bad "T2" "$o"
"$AD" "$d" >/dev/null 2>&1; [ "$?" -eq 1 ] && ok "T2b findings exit 1" || bad "T2b exit" "rc=$?"

# --- T3: frontmatter missing name => NO_NAME
d=$(mkd); printf -- '---\ndescription: Reviews code for security issues when asked.\n---\n\nYou are a reviewer.\n' > "$d/noname.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "NO_NAME" && ok "T3 NO_NAME flagged" || bad "T3" "$o"

# --- T4: frontmatter missing description => NO_DESCRIPTION
d=$(mkd); printf -- '---\nname: nodesc\n---\n\nYou are a reviewer.\n' > "$d/nodesc.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "NO_DESCRIPTION" && ok "T4 NO_DESCRIPTION flagged" || bad "T4" "$o"

# --- T5: name does not match filename => NAME_MISMATCH (heuristic, MED)
d=$(mkd); printf -- '---\nname: actual-name\ndescription: Use when the user wants a doc writer.\n---\n\nWrite docs.\n' > "$d/different-file.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "NAME_MISMATCH" && ok "T5 NAME_MISMATCH flagged" || bad "T5" "$o"

# --- T6: two agents declaring the SAME name => DUP_NAME on BOTH files
d=$(mkd)
printf -- '---\nname: twin\ndescription: Use when the user wants foo done.\n---\n\nDo foo.\n' > "$d/one.md"
printf -- '---\nname: twin\ndescription: Use when the user wants bar done.\n---\n\nDo bar.\n' > "$d/two.md"
o=$("$AD" "$d" --json 2>&1)
n=$(echo "$o" | grep -c '"code": "DUP_NAME"')
[ "$n" -eq 2 ] && ok "T6 DUP_NAME flags both files" || bad "T6 dup count" "got $n :: $o"

# --- T7: frontmatter present but empty body => EMPTY_BODY (LOW)
d=$(mkd); printf -- '---\nname: empty\ndescription: Use when the user wants an empty agent.\n---\n' > "$d/empty.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "EMPTY_BODY" && ok "T7 EMPTY_BODY flagged" || bad "T7" "$o"

# --- T8: tools is a number/dict (malformed) => TOOLS_MALFORMED (LOW, heuristic)
d=$(mkd); printf -- '---\nname: badtools\ndescription: Use when the user wants a tool-using agent.\ntools: 42\n---\n\nDo things.\n' > "$d/badtools.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "TOOLS_MALFORMED" && ok "T8 TOOLS_MALFORMED flagged" || bad "T8" "$o"

# --- T8a: tools is an inline dict/mapping (malformed) => TOOLS_MALFORMED
d=$(mkd); printf -- '---\nname: dicttools\ndescription: Use when the user wants a dict-tools agent.\ntools: {Read: true}\n---\n\nDo things.\n' > "$d/dicttools.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "TOOLS_MALFORMED" && ok "T8a dict tools flagged" || bad "T8a" "$o"

# --- T8b: a well-formed comma-string tools list is NOT flagged (conservative)
d=$(mkd); printf -- '---\nname: oktools\ndescription: Use when the user wants a tool-using agent.\ntools: Read, Grep, Bash\n---\n\nDo things.\n' > "$d/oktools.md"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q "TOOLS_MALFORMED" && bad "T8b string tools wrongly flagged" "$o" || ok "T8b string tools not flagged"
# ... and we never validate individual tool NAMES (no such code exists)
echo "$o" | grep -Eiq "unknown tool|invalid tool name|not a known tool" && bad "T8c validates tool names" "$o" || ok "T8c does not validate tool names"

# --- T9: a YAML block-list tools value is accepted (not malformed)
d=$(mkd); printf -- '---\nname: listtools\ndescription: Use when the user wants a list-tools agent.\ntools:\n  - Read\n  - Bash\n---\n\nDo things.\n' > "$d/listtools.md"
"$AD" "$d" >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T9 list-form tools = clean exit 0" || bad "T9 exit" "rc=$? :: $("$AD" "$d" --json 2>&1)"

# --- T10: a fully-clean directory => exit 0 in BOTH human and --json
d=$(mkd); healthy "$d" alpha; healthy "$d" beta; healthy "$d" gamma
"$AD" "$d" >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T10 clean dir human exit 0" || bad "T10 human exit" "rc=$?"
"$AD" "$d" --json >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T10b clean dir --json exit 0" || bad "T10b json exit" "rc=$?"
o=$("$AD" "$d" --json 2>&1)
echo "$o" | grep -q '"agents_scanned": 3' && ok "T10c reports agents_scanned" || bad "T10c" "$o"
echo "$o" | grep -q '"summary"' && ok "T10d --json has summary" || bad "T10d" "$o"

# --- T11: missing path => exit 2
"$AD" "$d/does-not-exist" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T11 missing path exit 2" || bad "T11 exit" "rc=$?"

# --- T12: a path that is neither a dir nor a .md => exit 2
d=$(mkd); printf 'hello\n' > "$d/notes.txt"
"$AD" "$d/notes.txt" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T12 non-.md file exit 2" || bad "T12 exit" "rc=$?"

# --- T13: an empty dir (no .md files) => exit 2
d=$(mkd)
"$AD" "$d" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "T13 empty dir exit 2" || bad "T13 exit" "rc=$?"

# --- T14: pointing at a SINGLE healthy .md file works (clean, exit 0)
d=$(mkd); healthy "$d" solo
"$AD" "$d/solo.md" >/dev/null 2>&1; [ "$?" -eq 0 ] && ok "T14 single .md healthy exit 0" || bad "T14 exit" "rc=$?"

# --- T15: a single broken .md file => exit 1 and the right code
d=$(mkd); printf 'no frontmatter here\n' > "$d/broken.md"
o=$("$AD" "$d/broken.md" --json 2>&1)
echo "$o" | grep -q "NO_FRONTMATTER" && ok "T15 single broken .md flagged" || bad "T15" "$o"
"$AD" "$d/broken.md" >/dev/null 2>&1; [ "$?" -eq 1 ] && ok "T15b single broken .md exit 1" || bad "T15b exit" "rc=$?"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
