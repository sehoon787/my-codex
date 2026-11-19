#!/usr/bin/env bash
#
# run-tests.sh — run every test in scripts/test-*.sh and tests/, the one test
# list CI and the upstream sync share.
#
# The validate job in .github/workflows/ci.yml and the update job in
# .github/workflows/update-upstream.yml (before it may auto-merge) both call
# this script, so a test file added there runs in both without editing either
# workflow.
#
# Runs scripts/test-*.sh (the installer smoke tests), tests/*.test.sh,
# tests/*.test.js and tests/validate-sync.sh, keeps going past a failure, and
# names every failed test at the end. Under GitHub Actions it also writes
# failed=<space-separated test paths> to $GITHUB_OUTPUT.
#
# Exit 0 = every test passed; exit 1 = at least one failed, or none ran.
# `bash scripts/run-tests.sh`

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# A test that cannot run on an ubuntu runner goes here, with its reason:
#   tests/<name>.test.sh) echo "<one-line reason>" ;;
skip_reason() {
  case "$1" in
    *) return 1 ;;
  esac
}

passed=0
skipped=0
failed=""
for t in scripts/test-*.sh tests/*.test.sh tests/*.test.js tests/validate-sync.sh; do
  [ -f "$t" ] || continue
  if reason="$(skip_reason "$t")"; then
    echo "SKIP  $t: $reason"
    skipped=$((skipped + 1))
    continue
  fi
  echo "==> $t"
  case "$t" in
    *.js) node "$t" </dev/null ;;
    *) bash "$t" </dev/null ;;
  esac
  rc=$?
  if [ "$rc" -eq 0 ]; then
    passed=$((passed + 1))
  else
    echo "FAIL  $t (exit $rc)"
    failed="${failed:+$failed }$t"
  fi
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "failed=$failed" >> "$GITHUB_OUTPUT"
fi

failed_count=$(echo "$failed" | wc -w | tr -d ' ')
echo ""
echo "Tests: $passed passed, $failed_count failed, $skipped skipped"
if [ "$failed_count" -gt 0 ]; then
  echo "Failed: $failed"
  exit 1
fi
if [ "$passed" -eq 0 ]; then
  echo "No tests ran."
  exit 1
fi
