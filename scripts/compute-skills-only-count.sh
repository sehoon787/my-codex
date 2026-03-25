#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ECC_SKILLS_DIR="$REPO_ROOT/skills/ecc"
CORE_SKILLS_DIR="$REPO_ROOT/skills/core"

# Skills-only installs consume the validated local skills tree.
# Derive the expected count from source to avoid a second networked install in CI.
ECC_COUNT=0
CORE_COUNT=0
if [ -d "$ECC_SKILLS_DIR" ]; then
  ECC_COUNT=$(find "$ECC_SKILLS_DIR" -name 'SKILL.md' | wc -l | tr -d ' ')
fi
if [ -d "$CORE_SKILLS_DIR" ]; then
  CORE_COUNT=$(find "$CORE_SKILLS_DIR" -name 'SKILL.md' | wc -l | tr -d ' ')
fi
SKILLS_ONLY_COUNT=$((ECC_COUNT + CORE_COUNT))

cat <<EOF
SKILLS_ONLY_COUNT=$SKILLS_ONLY_COUNT
EOF
