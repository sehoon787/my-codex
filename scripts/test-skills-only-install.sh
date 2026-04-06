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

if ! HOME="$TEST_HOME" npx --yes skills add "$REPO_ROOT" -y -g >"$INSTALL_OUT" 2>"$INSTALL_ERR"; then
  fail "npx skills add failed during skills-only smoke test"
fi

actual_skills=$(find "$TEST_HOME/.agents/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')

test "$actual_skills" -ge 1 || fail "Expected at least 1 skill, found $actual_skills"
test -f "$TEST_HOME/.agents/skills/boss-advanced/SKILL.md" || fail "boss-advanced was not installed into ~/.agents/skills"
test -L "$TEST_HOME/.claude/skills/boss-advanced" || fail "boss-advanced was not symlinked into ~/.claude/skills"

while IFS= read -r skill_file; do
  first_line="$(head -n 1 "$skill_file" | tr -d '\r' || true)"
  test "$first_line" = "---" || fail "Invalid frontmatter start in $skill_file"
done < <(find "$TEST_HOME/.agents/skills" -name 'SKILL.md' | sort)

echo "Skills-only smoke test passed"
