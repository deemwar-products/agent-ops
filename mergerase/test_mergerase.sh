#!/usr/bin/env bash
# Tests for mergerase. Ground truth = REAL git repos with REAL merges.
# No synthetic fixtures: every case reproduces the actual failure mode in git.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
MR="$HERE/mergerase"
chmod +x "$MR"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1 -- $2"; }

newrepo() {
  R="$(mktemp -d)"
  git -C "$R" init -q
  git -C "$R" config user.email t@t.com
  git -C "$R" config user.name t
  git -C "$R" config commit.gpgsign false
}
commit() { git -C "$R" add -A; git -C "$R" commit -q -m "$1"; }

# ---------------------------------------------------------------------------
# T1: the real silent-erasure scenario — a merge drops a parent's export.
newrepo
printf 'export function alpha(){return 1}\n' > "$R/lib.ts"; commit base
git -C "$R" checkout -q -b feat
printf 'export function getExportDateFilter(){return "date"}\n' > "$R/export.ts"; commit "feat: date filter"
git -C "$R" checkout -q main 2>/dev/null || git -C "$R" checkout -q master
printf 'export function beta(){return 2}\n' > "$R/export.ts"; commit "main: beta in same file"
git -C "$R" merge -q --no-commit feat 2>/dev/null
git -C "$R" checkout -q --ours export.ts          # bad resolution: keep main, drop feat's fn
git -C "$R" add -A; git -C "$R" commit -q -m "merge feat (conflict resolved --ours)"
out="$(cd "$R" && "$MR" 2>&1)"; rc=$?
echo "$out" | grep -q "getExportDateFilter" && ok "T1 flags the silently-erased export" || bad "T1" "$out"
[ "$rc" -ne 0 ] && ok "T1b non-zero exit when a symbol was lost" || bad "T1b" "rc=$rc"
echo "$out" | grep -q "beta" && bad "T1c" "beta wrongly flagged" || ok "T1c kept symbol (beta) not flagged"
rm -rf "$R"

# T2: a clean merge that keeps both branches' work -> nothing lost, exit 0.
newrepo
printf 'export function alpha(){}\n' > "$R/lib.ts"; commit base
git -C "$R" checkout -q -b feat
printf 'export function featAdds(){}\n' > "$R/feat.ts"; commit "feat"
git -C "$R" checkout -q main 2>/dev/null || git -C "$R" checkout -q master
printf 'export function mainAdds(){}\n' > "$R/main.ts"; commit "main"
git -C "$R" merge -q --no-edit feat
out="$(cd "$R" && "$MR" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && echo "$out" | grep -q "no public symbols disappeared"; } \
  && ok "T2 clean merge = no losses, exit 0" || bad "T2" "rc=$rc :: $out"
rm -rf "$R"

# T3: two-ref compare flags a removed export.
newrepo
printf 'export const RoleGuard = 1\nexport function keepMe(){}\n' > "$R/perm.ts"; commit before
printf 'export function keepMe(){}\n' > "$R/perm.ts"; commit after   # RoleGuard deleted
out="$(cd "$R" && "$MR" 'HEAD~1' 'HEAD' 2>&1)"; rc=$?
{ echo "$out" | grep -q "RoleGuard" && [ "$rc" -ne 0 ]; } && ok "T3 two-ref compare flags removed export" || bad "T3" "$out"
echo "$out" | grep -q "keepMe" && bad "T3b" "keepMe wrongly flagged" || ok "T3b retained export not flagged"
rm -rf "$R"

# T4: a MOVED symbol (same name, different file) is NOT a loss.
newrepo
printf 'export function moveMe(){}\n' > "$R/a.ts"; commit before
git -C "$R" rm -q a.ts; printf 'export function moveMe(){}\n' > "$R/b.ts"; commit after
out="$(cd "$R" && "$MR" 'HEAD~1' 'HEAD' 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && ! echo "$out" | grep -q "moveMe"; } && ok "T4 moved symbol not flagged" || bad "T4" "$out"
rm -rf "$R"

# T5: Python — a removed top-level def is flagged.
newrepo
printf 'def compute_tax(x):\n    return x\ndef keep(x):\n    return x\n' > "$R/calc.py"; commit before
printf 'def keep(x):\n    return x\n' > "$R/calc.py"; commit after
out="$(cd "$R" && "$MR" 'HEAD~1' 'HEAD' 2>&1)"
echo "$out" | grep -q "compute_tax" && ok "T5 python: removed def flagged" || bad "T5" "$out"
rm -rf "$R"

# T6: Go — exported func loss flagged; unexported func loss ignored.
newrepo
printf 'package x\nfunc ExportData(){}\nfunc helper(){}\n' > "$R/x.go"; commit before
printf 'package x\n' > "$R/x.go"; commit after   # both removed
out="$(cd "$R" && "$MR" 'HEAD~1' 'HEAD' 2>&1)"
echo "$out" | grep -q "ExportData" && ok "T6 go: exported func loss flagged" || bad "T6" "$out"
echo "$out" | grep -q "helper" && bad "T6b" "unexported helper flagged" || ok "T6b go: unexported func ignored"
rm -rf "$R"

# T7: export { impl as publicName } list — removal of the public name flagged.
newrepo
printf 'function impl(){}\nexport { impl as publicName }\n' > "$R/idx.ts"; commit before
printf 'function impl(){}\n' > "$R/idx.ts"; commit after
out="$(cd "$R" && "$MR" 'HEAD~1' 'HEAD' 2>&1)"
echo "$out" | grep -q "publicName" && ok "T7 named-export (as) loss flagged" || bad "T7" "$out"
rm -rf "$R"

# T8: no-arg on a NON-merge HEAD errors clearly (exit 2).
newrepo
printf 'export function a(){}\n' > "$R/a.ts"; commit only
out="$(cd "$R" && "$MR" 2>&1)"; rc=$?
{ [ "$rc" -eq 2 ] && echo "$out" | grep -qi "not a merge"; } && ok "T8 non-merge HEAD = clear error (exit 2)" || bad "T8" "rc=$rc :: $out"
rm -rf "$R"

# T9: --help works.
"$MR" --help | grep -q "silent-erasure" && ok "T9 --help prints usage" || bad "T9" "no help"

echo "-----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
