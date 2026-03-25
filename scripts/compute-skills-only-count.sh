#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-skills-only-count.$$"
TEST_HOME="$TMP_ROOT/home"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME"

HOME="$TEST_HOME" npx skills add "$REPO_ROOT" -y -g >/dev/null

SKILLS_ONLY_COUNT=$(find "$TEST_HOME/.agents/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
SKILLS_ONLY_COUNT=$SKILLS_ONLY_COUNT
EOF
