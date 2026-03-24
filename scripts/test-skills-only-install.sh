#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-skills-only-test.$$"
TEST_HOME="$TMP_ROOT/home"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME"

eval "$("$REPO_ROOT/scripts/compute-install-counts.sh")"

HOME="$TEST_HOME" npx skills add "$REPO_ROOT" -y -g > "$TMP_ROOT/install.out"

actual_skills=$(find "$TEST_HOME/.agents/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')

test "$actual_skills" = "$SKILLS_ONLY_COUNT"
test -f "$TEST_HOME/.agents/skills/skill-stocktake/SKILL.md"
test -L "$TEST_HOME/.claude/skills/skill-stocktake"

echo "Skills-only smoke test passed"
