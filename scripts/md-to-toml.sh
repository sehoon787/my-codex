#!/bin/bash
# md-to-toml.sh — Convert Claude Code agent .md files to Codex CLI .toml format.
# Usage: md-to-toml.sh <input_dir> <output_dir>

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input_dir> <output_dir>" >&2
  exit 1
fi

INPUT_DIR="${1%/}"
OUTPUT_DIR="${2%/}"

# Files to skip by basename
SKIP_FILES=("agent-teams-reference.md")

# Map a Claude model string to toml model + reasoning effort lines.
map_model() {
  local m="$1"
  case "$m" in
    claude-opus-4-5|claude-opus-4-6)
      echo 'model = "o3"'
      echo 'model_reasoning_effort = "high"'
      ;;
    claude-sonnet-4-6|claude-sonnet-4-5)
      echo 'model = "o3"'
      echo 'model_reasoning_effort = "medium"'
      ;;
    claude-haiku-4-5)
      echo 'model = "o4-mini"'
      echo 'model_reasoning_effort = "low"'
      ;;
    *)
      # default / unknown
      echo 'model = "o3"'
      echo 'model_reasoning_effort = "medium"'
      ;;
  esac
}

# Apply Claude→Codex API substitutions in body text (reads stdin, writes stdout).
apply_substitutions() {
  sed \
    -e 's/Agent(/spawn_agent(/g' \
    -e 's/Skill(skill:/$/g' \
    -e 's/SendMessage(/send_input(/g' \
    -e 's/subagent_type/agent_type/g'
}

process_file() {
  local src="$1"
  local basename
  basename="$(basename "$src")"

  # Skip known non-agent files
  for skip in "${SKIP_FILES[@]}"; do
    if [[ "$basename" == "$skip" ]]; then
      echo "  SKIP (blocklist): $src"
      return 0
    fi
  done

  # Must start with --- on line 1
  local first_line
  first_line="$(head -1 "$src")"
  if [[ "$first_line" != "---" ]]; then
    echo "  SKIP (no frontmatter): $src"
    return 0
  fi

  # Find line numbers of the two --- delimiters
  local delim_lines
  delim_lines=$(awk '/^---$/{print NR; count++; if(count==2) exit}' "$src")
  local line1 line2
  line1=$(echo "$delim_lines" | sed -n '1p')
  line2=$(echo "$delim_lines" | sed -n '2p')

  if [[ -z "$line2" ]]; then
    echo "  SKIP (unclosed frontmatter): $src"
    return 0
  fi

  # Extract frontmatter (lines between the two ---)
  local frontmatter
  frontmatter=$(awk "NR > $line1 && NR < $line2" "$src")

  # Parse fields from frontmatter
  local name description model

  name=$(echo "$frontmatter" | awk -F': ' '/^name:/{sub(/^name:[[:space:]]*/,"",$0); print; exit}')
  description=$(echo "$frontmatter" | awk '/^description:/{sub(/^description:[[:space:]]*/,"",$0); print; exit}')
  model=$(echo "$frontmatter" | awk '/^model:/{sub(/^model:[[:space:]]*/,"",$0); print; exit}')

  # Skip if no name field
  if [[ -z "$name" ]]; then
    echo "  SKIP (no name field): $src"
    return 0
  fi

  # Extract body (everything after the second ---)
  local body_raw body
  body_raw=$(awk "NR > $line2" "$src")

  # Apply API substitutions
  body=$(echo "$body_raw" | apply_substitutions)

  # Escape backslashes first (TOML treats \ as escape character in basic strings)
  body=$(echo "$body" | sed 's/\\/\\\\/g')
  # Then escape any literal """ sequences to prevent breaking TOML triple-quotes
  body=$(echo "$body" | sed 's/"""/\\"\\"\\"/g')

  # Determine output path, preserving relative directory structure
  local rel_path="${src#$INPUT_DIR/}"
  local out_path="$OUTPUT_DIR/${rel_path%.md}.toml"
  local out_dir
  out_dir="$(dirname "$out_path")"
  mkdir -p "$out_dir"

  # Build model lines
  local model_lines
  model_lines=$(map_model "$model")

  # Write TOML
  {
    printf 'name = "%s"\n' "$name"
    printf 'description = "%s"\n' "$description"
    echo "$model_lines"
    printf 'developer_instructions = """\n'
    printf '%s\n' "$body"
    printf '"""\n'
  } > "$out_path"

  echo "  OK: $src -> $out_path"
}

# Collect all .md files recursively (bash 3.2 compatible)
MD_FILES=()
while IFS= read -r -d '' f; do
  MD_FILES+=("$f")
done < <(find "$INPUT_DIR" -type f -name "*.md" -print0 | sort -z)

if [[ ${#MD_FILES[@]} -eq 0 ]]; then
  echo "No .md files found in $INPUT_DIR" >&2
  exit 1
fi

echo "Converting ${#MD_FILES[@]} .md files from '$INPUT_DIR' to '$OUTPUT_DIR'..."
echo ""

count_ok=0
count_skip=0

for f in "${MD_FILES[@]}"; do
  result=$(process_file "$f")
  echo "$result"
  if [[ "$result" == *"OK:"* ]]; then
    count_ok=$(( count_ok + 1 ))
  else
    count_skip=$(( count_skip + 1 ))
  fi
done

echo ""
echo "Done. Converted: $count_ok, Skipped: $count_skip"
