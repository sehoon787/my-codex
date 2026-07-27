#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-pack-test.$$"
BIN_DIR="$TMP_ROOT/bin"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version)
    echo "codex-test"
    ;;
  mcp)
    exit 0
    ;;
esac
EOF
chmod +x "$BIN_DIR/codex"

cat > "$BIN_DIR/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$BIN_DIR/npm"

cat > "$BIN_DIR/ast-grep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN_DIR/ast-grep"

first_home="$TMP_ROOT/home-defaults"
mkdir -p "$first_home"
HOME="$first_home" PATH="$BIN_DIR:$PATH" bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/defaults.out"

# No packs are enabled by default — the state file is written with no pack lines
# and nothing is symlinked into agents/.
if grep -qvE '^[[:space:]]*(#|$)' "$first_home/.codex/enabled-agent-packs.txt"; then
  echo "no packs should be enabled by default" >&2
  exit 1
fi
test "$(find "$first_home/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" -eq 0

cat > "$first_home/.codex/enabled-agent-packs.txt" <<'EOF'
data-ai
EOF
HOME="$first_home" PATH="$BIN_DIR:$PATH" bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/custom.out"

grep -q '^data-ai$' "$first_home/.codex/enabled-agent-packs.txt"
test -L "$first_home/.codex/agents/ai-engineer.toml"
if [ -e "$first_home/.codex/agents/eval-engineer.toml" ]; then
  echo "llmops link should not exist when only data-ai is enabled" >&2
  exit 1
fi

migration_home="$TMP_ROOT/home-migration"
mkdir -p "$migration_home/.codex/agents" "$migration_home/.codex/agent-packs/marketing"
printf 'name = "marketing-seo-specialist"\ndescription = "SEO specialist"\n[developer_instructions]\ncontent = "You are an SEO specialist"\n' > \
  "$migration_home/.codex/agent-packs/marketing/marketing-seo-specialist.toml"
ln -s "$migration_home/.codex/agent-packs/marketing/marketing-seo-specialist.toml" \
  "$migration_home/.codex/agents/marketing-seo-specialist.toml"

HOME="$migration_home" PATH="$BIN_DIR:$PATH" bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/migration.out"

grep -q '^marketing$' "$migration_home/.codex/enabled-agent-packs.txt"
if grep -q '^engineering$' "$migration_home/.codex/enabled-agent-packs.txt"; then
  echo "migration should preserve the existing marketing activation instead of writing defaults" >&2
  exit 1
fi
test -L "$migration_home/.codex/agents/marketing-seo-specialist.toml"

echo "Agent pack activation test passed"
