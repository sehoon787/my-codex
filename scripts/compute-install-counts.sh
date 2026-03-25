#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-counts.$$"
INSTALL_ROOT="$TMP_ROOT/install"
AGENTS_DIR="$INSTALL_ROOT/agents"
PACKS_DIR="$INSTALL_ROOT/agent-packs"
SKILLS_DIR="$INSTALL_ROOT/skills"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$AGENTS_DIR" "$PACKS_DIR" "$SKILLS_DIR"

copy_glob() {
  local pattern=$1
  local dest=$2
  local matches=()

  shopt -s nullglob
  matches=($pattern)
  shopt -u nullglob

  if [ ${#matches[@]} -gt 0 ]; then
    cp "${matches[@]}" "$dest/"
  fi
}

copy_glob "$SCRIPT_DIR/codex-agents/core/*.toml" "$AGENTS_DIR"
copy_glob "$SCRIPT_DIR/codex-agents/omo/*.toml" "$AGENTS_DIR"
copy_glob "$SCRIPT_DIR/codex-agents/omc/*.toml" "$AGENTS_DIR"
copy_glob "$SCRIPT_DIR/codex-agents/awesome-core/*.toml" "$AGENTS_DIR"

for cat_dir in "$SCRIPT_DIR/codex-agents/agency/"*/; do
  [ -d "$cat_dir" ] || continue
  cat_name=$(basename "$cat_dir")
  mkdir -p "$PACKS_DIR/$cat_name"
  copy_glob "${cat_dir}*.toml" "$PACKS_DIR/$cat_name"
done

for cat_dir in "$SCRIPT_DIR/codex-agents/agent-packs/"*/; do
  [ -d "$cat_dir" ] || continue
  cat_name=$(basename "$cat_dir")
  mkdir -p "$PACKS_DIR/$cat_name"
  copy_glob "${cat_dir}*.toml" "$PACKS_DIR/$cat_name"
done

for cat_dir in "$SCRIPT_DIR/codex-agents/awesome/"*/; do
  [ -d "$cat_dir" ] || continue
  cat_name=$(basename "$cat_dir")
  case "$cat_name" in
    01-core-development|03-infrastructure|04-quality-security|09-meta-orchestration)
      copy_glob "${cat_dir}*.toml" "$AGENTS_DIR"
      ;;
    *)
      mkdir -p "$PACKS_DIR/$cat_name"
      copy_glob "${cat_dir}*.toml" "$PACKS_DIR/$cat_name"
      ;;
  esac
done

if [ -d "$SCRIPT_DIR/skills/ecc" ]; then
  cp -R "$SCRIPT_DIR/skills/ecc/." "$SKILLS_DIR/"
fi

AUTO_LOADED_COUNT=$(find "$AGENTS_DIR" -name '*.toml' | wc -l | tr -d ' ')
AGENT_PACK_COUNT=$(find "$PACKS_DIR" -name '*.toml' | wc -l | tr -d ' ')
SKILL_COUNT=$(find "$SKILLS_DIR" -name 'SKILL.md' | wc -l | tr -d ' ')
# `npx skills add` should now install the same skill set as the bundled skills
# after all frontmatter fixes are applied.
SKILLS_ONLY_COUNT=$SKILL_COUNT
INSTALLED_AGENT_TOTAL=$((AUTO_LOADED_COUNT + AGENT_PACK_COUNT))
SOURCE_TOML_COUNT=$(find "$SCRIPT_DIR/codex-agents" -name '*.toml' | wc -l | tr -d ' ')

cat <<EOF
AUTO_LOADED_COUNT=$AUTO_LOADED_COUNT
AGENT_PACK_COUNT=$AGENT_PACK_COUNT
SKILL_COUNT=$SKILL_COUNT
SKILLS_ONLY_COUNT=$SKILLS_ONLY_COUNT
INSTALLED_AGENT_TOTAL=$INSTALLED_AGENT_TOTAL
SOURCE_TOML_COUNT=$SOURCE_TOML_COUNT
EOF
