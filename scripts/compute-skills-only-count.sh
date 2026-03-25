#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills/ecc"

# Skills-only installs consume the validated local skills tree.
# Derive the expected count from source to avoid a second networked install in CI.
if [ -d "$SKILLS_DIR" ]; then
  SKILLS_ONLY_COUNT=$(find "$SKILLS_DIR" -name 'SKILL.md' | wc -l | tr -d ' ')
else
  SKILLS_ONLY_COUNT=0
fi

cat <<EOF
SKILLS_ONLY_COUNT=$SKILLS_ONLY_COUNT
EOF
