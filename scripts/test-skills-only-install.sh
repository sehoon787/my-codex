#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-skills-only-test.$$"
TEST_HOME="$TMP_ROOT/home"
INSTALL_OUT="$TMP_ROOT/install.out"
INSTALL_ERR="$TMP_ROOT/install.err"

cleanup() {
  rm -rf "$TMP_ROOT"
}

fail() {
  echo "$1" >&2
  echo "--- stderr ---" >&2
  cat "$INSTALL_ERR" >&2 || true
  echo "--- stdout ---" >&2
  cat "$INSTALL_OUT" >&2 || true
  echo "--- canonical skill count ---" >&2
  find "$TEST_HOME/.agents/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ' >&2
  echo "--- skill-stocktake canonical ---" >&2
  ls -la "$TEST_HOME/.agents/skills/skill-stocktake" 2>/dev/null >&2 || echo "(missing)" >&2
  echo "--- claude skills dir ---" >&2
  ls -la "$TEST_HOME/.claude/skills" 2>/dev/null >&2 || echo "(missing)" >&2
  echo "--- claude skill-stocktake ---" >&2
  ls -la "$TEST_HOME/.claude/skills/skill-stocktake" 2>/dev/null >&2 || echo "(missing)" >&2
  exit 1
}

trap cleanup EXIT

mkdir -p "$TEST_HOME"

count_env="$(bash "$REPO_ROOT/scripts/compute-skills-only-count.sh")" || exit 1
test -n "$count_env" || fail "compute-skills-only-count.sh returned no output"
eval "$count_env"
test -n "${SKILLS_ONLY_COUNT:-}" || fail "SKILLS_ONLY_COUNT was not set"

if ! HOME="$TEST_HOME" npx --yes skills add "$REPO_ROOT" -y -g >"$INSTALL_OUT" 2>"$INSTALL_ERR"; then
  fail "npx skills add failed during skills-only smoke test"
fi

actual_skills=$(find "$TEST_HOME/.agents/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')

test "$actual_skills" = "$SKILLS_ONLY_COUNT" || fail "Expected $SKILLS_ONLY_COUNT skills, found $actual_skills"
test -f "$TEST_HOME/.agents/skills/skill-stocktake/SKILL.md" || fail "skill-stocktake was not installed into ~/.agents/skills"
test -L "$TEST_HOME/.claude/skills/skill-stocktake" || fail "skill-stocktake was not symlinked into ~/.claude/skills"

echo "Skills-only smoke test passed"
