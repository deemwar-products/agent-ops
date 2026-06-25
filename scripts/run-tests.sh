#!/usr/bin/env bash
# Standardized test harness for the agent-ops fleet.
#
#   scripts/run-tests.sh              # run every tool's test suite, print a summary
#   scripts/run-tests.sh agent-frisk  # run just one tool's suite
#
# Contract (every tool follows it): a tool lives in its own top-level directory and
# ships a bash test script named test_<tool>.sh (or test-<tool>.sh). The script tallies
# its own checks and EXITS NON-ZERO if any check failed. This harness simply discovers,
# runs, and aggregates them — pass/fail is the script's exit code, nothing is parsed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Find the test script inside a tool directory, tolerant of the test_ / test- split.
find_test() {
  local dir="$1" t
  for t in "$dir"/test_*.sh "$dir"/test-*.sh; do
    [ -f "$t" ] && { printf '%s\n' "$t"; return 0; }
  done
  return 1
}

# Every top-level directory that ships a test script is a tool.
list_tools() {
  local dir
  for dir in */; do
    dir="${dir%/}"
    [ "$dir" = ".git" ] || [ "$dir" = "scripts" ] && continue
    find_test "$dir" >/dev/null 2>&1 && printf '%s\n' "$dir"
  done
}

run_one() {
  local tool="$1" test_script
  if ! test_script="$(find_test "$tool")"; then
    echo "::ERROR:: $tool — no test script found"
    return 2
  fi
  echo "── $tool ($(basename "$test_script")) ──────────────────────────────"
  ( cd "$tool" && bash "$(basename "$test_script")" )
}

main() {
  if [ "$#" -ge 1 ]; then
    run_one "$1"
    exit $?
  fi

  local failed=() tool rc total=0
  while IFS= read -r tool; do
    total=$((total + 1))
    if ! run_one "$tool"; then
      failed+=("$tool")
    fi
    echo
  done < <(list_tools)

  echo "==================== SUMMARY ===================="
  echo "tools tested: $total   passed: $((total - ${#failed[@]}))   failed: ${#failed[@]}"
  if [ "${#failed[@]}" -gt 0 ]; then
    printf 'FAILED: %s\n' "${failed[*]}"
    exit 1
  fi
  echo "all green ✅"
}

main "$@"
