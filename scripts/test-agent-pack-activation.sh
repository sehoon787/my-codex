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

grep -q '^engineering$' "$first_home/.codex/enabled-agent-packs.txt"
grep -q '^language-specialists$' "$first_home/.codex/enabled-agent-packs.txt"
test -L "$first_home/.codex/agents/engineering-ai-engineer.toml"

cat > "$first_home/.codex/enabled-agent-packs.txt" <<'EOF'
marketing
EOF
HOME="$first_home" PATH="$BIN_DIR:$PATH" bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/custom.out"

grep -q '^marketing$' "$first_home/.codex/enabled-agent-packs.txt"
if grep -q '^engineering$' "$first_home/.codex/enabled-agent-packs.txt"; then
  echo "engineering should not remain after replacing the active set" >&2
  exit 1
fi
test -L "$first_home/.codex/agents/marketing-seo-specialist.toml"
if [ -e "$first_home/.codex/agents/engineering-ai-engineer.toml" ]; then
  echo "engineering link should be removed after switching to marketing only" >&2
  exit 1
fi

migration_home="$TMP_ROOT/home-migration"
mkdir -p "$migration_home/.codex/agents" "$migration_home/.codex/agent-packs/marketing"
cp "$REPO_ROOT/codex-agents/agent-packs/marketing/marketing-seo-specialist.toml" \
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
