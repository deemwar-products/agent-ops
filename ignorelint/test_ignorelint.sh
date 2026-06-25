#!/usr/bin/env bash
# Tests for ignorelint — catches secret files git is tracking, or that aren't gitignored.
# Each case builds a throwaway GIT repo (git init + a local identity so commits work in CI)
# and asserts the finding code in --json and/or the process exit code.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IL="$HERE/ignorelint"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1 -- $2"; FAIL=$((FAIL+1)); }

# new_repo: a fresh git work tree with a usable identity (commits work headlessly)
new_repo() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  # hermetic: ignore the host's global excludes (~/.config/git/ignore) so a dev's
  # personal gitignore can't mask a fixture the test expects to be un-ignored.
  git -C "$d" config core.excludesFile /dev/null
  echo "$d"
}

# --- T1: a .env that is committed => TRACKED_SECRET (HIGH) + exit 1
r=$(new_repo); : > "$r/.env"
git -C "$r" add .env && git -C "$r" commit -qm init
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"TRACKED_SECRET"' && [ "$rc" -eq 1 ] \
  && ok "T1 committed .env => TRACKED_SECRET + exit 1" || bad "T1" "rc=$rc $o"

# --- T2: a .mcp.json present, untracked, not in .gitignore => UNIGNORED_SECRET (MED)
r=$(new_repo); printf '{}' > "$r/.mcp.json"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"UNIGNORED_SECRET"' && echo "$o" | grep -q '"MED"' && [ "$rc" -eq 1 ] \
  && ok "T2 untracked .mcp.json => UNIGNORED_SECRET (MED)" || bad "T2" "rc=$rc $o"

# --- T3: a .env.local listed in .gitignore and untracked => CLEAN (no finding)
r=$(new_repo); : > "$r/.env.local"; echo ".env.local" > "$r/.gitignore"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"findings": \[\]' && [ "$rc" -eq 0 ] \
  && ok "T3 ignored+untracked .env.local => CLEAN exit 0" || bad "T3" "rc=$rc $o"

# --- T4: a .env.example present and untracked => must NOT be flagged
r=$(new_repo); : > "$r/.env.example"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"findings": \[\]' && [ "$rc" -eq 0 ] \
  && ok "T4 .env.example never flagged" || bad "T4" "rc=$rc $o"

# --- T4b: id_ed25519.pub (public key) present+untracked => must NOT be flagged
r=$(new_repo); : > "$r/id_ed25519.pub"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"findings": \[\]' && [ "$rc" -eq 0 ] \
  && ok "T4b .pub public key never flagged" || bad "T4b" "rc=$rc $o"

# --- T5: a private key id_rsa untracked + unignored => UNIGNORED_SECRET
r=$(new_repo); : > "$r/id_rsa"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"UNIGNORED_SECRET"' && [ "$rc" -eq 1 ] \
  && ok "T5 id_rsa untracked+unignored => UNIGNORED_SECRET" || bad "T5" "rc=$rc $o"

# --- T6: a fully-clean repo (only ignored + example secret files) => exit 0 human + --json
r=$(new_repo); : > "$r/.env"; echo ".env" > "$r/.gitignore"; : > "$r/.env.sample"
o=$("$IL" "$r" 2>&1); rc=$?
echo "$o" | grep -qi "clean" && [ "$rc" -eq 0 ] \
  && ok "T6 clean repo human => exit 0" || bad "T6 human" "rc=$rc $o"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"findings": \[\]' && [ "$rc" -eq 0 ] \
  && ok "T6b clean repo --json => exit 0" || bad "T6b json" "rc=$rc $o"

# --- T7: run outside any git repo (a fresh mktemp NOT git-init'd) => exit 2
r=$(mktemp -d); : > "$r/.env"
o=$("$IL" "$r" 2>&1); rc=$?
[ "$rc" -eq 2 ] && echo "$o" | grep -qi "git" \
  && ok "T7 non-git dir => exit 2" || bad "T7" "rc=$rc $o"

# --- T8: --json shape/tallies — repo, scanned, findings[], summary{total,high,med}
r=$(new_repo); : > "$r/.env"; git -C "$r" add .env; git -C "$r" commit -qm init
printf '{}' > "$r/.mcp.json"
o=$("$IL" --json "$r" 2>&1)
echo "$o" | grep -q '"repo"' \
  && echo "$o" | grep -q '"scanned"' \
  && echo "$o" | grep -q '"summary"' \
  && echo "$o" | grep -q '"high": 1' \
  && echo "$o" | grep -q '"med": 1' \
  && echo "$o" | grep -q '"total": 2' \
  && ok "T8 --json shape + tallies (1 high, 1 med)" || bad "T8" "$o"

# --- T9: a file can be BOTH ignored AND tracked => still TRACKED_SECRET (HIGH)
r=$(new_repo); : > "$r/.env"; git -C "$r" add .env; git -C "$r" commit -qm init
echo ".env" > "$r/.gitignore"   # ignore added AFTER it was tracked — doesn't untrack
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"TRACKED_SECRET"' && [ "$rc" -eq 1 ] \
  && ok "T9 ignored+tracked still TRACKED_SECRET (HIGH)" || bad "T9" "rc=$rc $o"

# --- T10: --add '*.secret' catches a custom file (default set would NOT)
r=$(new_repo); : > "$r/vault.secret"
o=$("$IL" --json "$r" 2>&1)
echo "$o" | grep -q '"findings": \[\]' || bad "T10pre default flagged *.secret unexpectedly" "$o"
o=$("$IL" --add '*.secret' --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"UNIGNORED_SECRET"' && echo "$o" | grep -q 'vault.secret' && [ "$rc" -eq 1 ] \
  && ok "T10 --add '*.secret' catches custom file" || bad "T10" "rc=$rc $o"

# --- T11: default scan does NOT walk into node_modules / .git
r=$(new_repo); mkdir -p "$r/node_modules/pkg"; : > "$r/node_modules/pkg/.env"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"findings": \[\]' && [ "$rc" -eq 0 ] \
  && ok "T11 prunes node_modules" || bad "T11" "rc=$rc $o"

# --- T12: .claude/settings.local.json untracked+unignored => UNIGNORED_SECRET (agent-aware)
r=$(new_repo); mkdir -p "$r/.claude"; printf '{}' > "$r/.claude/settings.local.json"
o=$("$IL" --json "$r" 2>&1); rc=$?
echo "$o" | grep -q '"UNIGNORED_SECRET"' && echo "$o" | grep -q 'settings.local.json' && [ "$rc" -eq 1 ] \
  && ok "T12 .claude/settings.local.json flagged (agent-aware)" || bad "T12" "rc=$rc $o"

echo "-----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
