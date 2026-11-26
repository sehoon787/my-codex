#!/usr/bin/env bash
#
# run-tests.sh — run every test in scripts/test-*.sh and tests/, the one test
# list CI and the upstream sync share.
#
# The validate job in .github/workflows/ci.yml and the test job in
# .github/workflows/update-upstream.yml (before the sync may auto-merge) both
# call this script, so a test file added there runs in both without editing
# either workflow.
#
# Runs scripts/test-*.sh (the installer smoke tests), tests/*.test.sh,
# tests/*.test.js and tests/validate-sync.sh, keeps going past a failure, and
# names every failed test at the end. Each test gets its own throwaway HOME,
# XDG_CONFIG_HOME and TMPDIR, removed when it ends, and no CLAUDE_CONFIG_DIR
# or CODEX_HOME, so a test that forgets to isolate one cannot reach the real
# one. Under GitHub Actions it also writes failed=<space-separated test paths>
# to $GITHUB_OUTPUT.
#
# Exit 0 = every test passed; exit 1 = at least one failed, or none ran.
# `bash scripts/run-tests.sh`

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# A session can point CODEX_HOME at the real ~/.codex, and CLAUDE_CONFIG_DIR
# at a real Claude config dir, that a throwaway HOME does not cover: Codex
# tools follow the first, and the claude CLI, `npx skills`, omc and gstack's
# setup the second. A test that wants one sets its own.
unset CLAUDE_CONFIG_DIR CODEX_HOME

passed=0
failed=""
for t in scripts/test-*.sh tests/*.test.sh tests/*.test.js tests/validate-sync.sh; do
  [ -f "$t" ] || continue
  echo "==> $t"
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/run-tests.XXXXXX")" || { echo "mktemp failed"; exit 1; }
  mkdir -p "$sandbox/home" "$sandbox/config" "$sandbox/tmp"
  case "$t" in
    *.js) interpreter=node ;;
    *) interpreter=bash ;;
  esac
  HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" TMPDIR="$sandbox/tmp" \
    "$interpreter" "$t" </dev/null
  rc=$?
  rm -rf "${sandbox:?}"
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
echo "Tests: $passed passed, $failed_count failed"
if [ "$failed_count" -gt 0 ]; then
  echo "Failed: $failed"
  exit 1
fi
if [ "$passed" -eq 0 ]; then
  echo "No tests ran."
  exit 1
fi
