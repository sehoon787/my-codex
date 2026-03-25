#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-install-test.$$"
TEST_HOME="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
LOG_FILE="$TMP_ROOT/codex.log"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME" "$BIN_DIR"

cat > "$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${MY_CODEX_TEST_LOG:?}"
case "${1:-}" in
  --version)
    echo "codex-test"
    ;;
  mcp)
    if [ "${2:-}" = "add" ]; then
      echo "$*" >> "$LOG_FILE"
      exit 0
    fi
    ;;
esac
echo "$*" >> "$LOG_FILE"
EOF
chmod +x "$BIN_DIR/codex"

cat > "$BIN_DIR/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${MY_CODEX_TEST_LOG:?}"
exit 0
EOF
chmod +x "$BIN_DIR/npm"

cat > "$BIN_DIR/ast-grep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN_DIR/ast-grep"

eval "$("$REPO_ROOT/scripts/compute-install-counts.sh")"
expected_version="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
  bash "$REPO_ROOT/scripts/install.sh" > "$TMP_ROOT/install.out"

actual_auto=$(find "$TEST_HOME/.codex/agents" -name '*.toml' | wc -l | tr -d ' ')
actual_packs=$(find "$TEST_HOME/.codex/agent-packs" -name '*.toml' | wc -l | tr -d ' ')
actual_skills=$(find "$TEST_HOME/.codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')

test "$actual_auto" = "$AUTO_LOADED_COUNT"
test "$actual_packs" = "$AGENT_PACK_COUNT"
test "$actual_skills" = "$SKILL_COUNT"
test -f "$TEST_HOME/.codex/AGENTS.md"
test -x "$TEST_HOME/.codex/bin/codex"
test -x "$TEST_HOME/.codex/bin/codex-mark-used"
test -x "$TEST_HOME/.codex/git-hooks/commit-msg"
test -x "$TEST_HOME/.codex/git-hooks/post-commit"
grep -q 'multi_agent = true' "$TEST_HOME/.codex/config.toml"
grep -q 'child_agents_md = true' "$TEST_HOME/.codex/config.toml"
grep -q 'max_threads = 8' "$TEST_HOME/.codex/config.toml"
test "$(HOME="$TEST_HOME" git config --global --get core.hooksPath)" = "$TEST_HOME/.codex/git-hooks"
test "$(HOME="$TEST_HOME" git config --global --get my-codex.codexAttribution)" = "true"
test -f "$TEST_HOME/.codex/.my-codex-manifest.txt"
test "$(cat "$TEST_HOME/.codex/.my-codex-version")" = "$expected_version"

grep -q 'mcp add context7' "$LOG_FILE"
grep -q 'mcp add exa' "$LOG_FILE"
grep -q 'mcp add grep_app' "$LOG_FILE"

mkdir -p "$TEST_HOME/.codex/agent-packs/custom" "$TEST_HOME/.codex/skills/custom-skill"
printf 'name = "custom-user-agent"\ndescription = "custom"\n[developer_instructions]\ncontent = "custom"\n' > "$TEST_HOME/.codex/agents/custom-user-agent.toml"
printf 'name = "custom-pack-agent"\ndescription = "custom"\n[developer_instructions]\ncontent = "custom"\n' > "$TEST_HOME/.codex/agent-packs/custom/custom-pack-agent.toml"
printf -- '---\nname: custom-skill\n---\n' > "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
  bash "$REPO_ROOT/scripts/install.sh" > "$TMP_ROOT/reinstall.out"

test -f "$TEST_HOME/.codex/agents/custom-user-agent.toml"
test -f "$TEST_HOME/.codex/agent-packs/custom/custom-pack-agent.toml"
test -f "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"
test "$(cat "$TEST_HOME/.codex/.my-codex-version")" = "$expected_version"

echo "Install smoke test passed"
