#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_SKILLS="${TMPDIR:-/tmp}/my-codex-skills-only.$$"
cleanup() { rm -rf "$TMP_SKILLS"; }
trap cleanup EXIT

mkdir -p "$TMP_SKILLS"
if [ -d "$REPO_ROOT/skills/ecc" ]; then
  cp -R "$REPO_ROOT/skills/ecc/." "$TMP_SKILLS/"
fi
if [ -d "$REPO_ROOT/skills/core" ]; then
  cp -R "$REPO_ROOT/skills/core/." "$TMP_SKILLS/"
fi
# Remove superseded ECC skills
for d in benchmark canary-watch safety-guard browser-qa verification-loop security-review design-system; do
  rm -rf "$TMP_SKILLS/$d" 2>/dev/null || true
done
if [ -d "$REPO_ROOT/skills/gstack" ]; then
  cp -R "$REPO_ROOT/skills/gstack/." "$TMP_SKILLS/"
fi
SKILLS_ONLY_COUNT=$(find "$TMP_SKILLS" -name 'SKILL.md' | wc -l | tr -d ' ')

cat <<EOF
SKILLS_ONLY_COUNT=$SKILLS_ONLY_COUNT
EOF
