#!/usr/bin/env bash
set -euo pipefail
trap 'echo "FAILED at line $LINENO (exit $?)" >&2' ERR

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_PARENT="${TMPDIR:-$REPO_ROOT/.tmp-install-tests}"
mkdir -p "$TMP_PARENT"
TMP_ROOT="$TMP_PARENT/my-codex-install-test.$$"
TEST_HOME="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
LOG_FILE="$TMP_ROOT/codex.log"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME" "$BIN_DIR"
mkdir -p "$TEST_HOME/.agents/skills" "$TEST_HOME/.claude/skills"

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

expected_version="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install.out"

actual_core=$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type f -name '*.toml' | wc -l | tr -d ' ')
actual_active_pack_links=$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')
actual_packs=$(find "$TEST_HOME/.codex/agent-packs" -name '*.toml' | wc -l | tr -d ' ')
actual_skills=$(find "$TEST_HOME/.codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')



test "$actual_core" -ge 10
test "$actual_active_pack_links" -ge 1
test "$actual_packs" -ge 100
test "$actual_skills" -ge 50
test -f "$TEST_HOME/.codex/AGENTS.md"
test -f "$TEST_HOME/.codex/agents/analyst.toml"
test -f "$TEST_HOME/.codex/agents/superpowers-code-reviewer.toml"
test -f "$TEST_HOME/.codex/agent-packs/engineering/engineering-ai-engineer.toml"
test -f "$TEST_HOME/.codex/enabled-agent-packs.txt"
test -x "$TEST_HOME/.codex/bin/codex"
test -x "$TEST_HOME/.codex/bin/codex-mark-used"
test -x "$TEST_HOME/.codex/bin/my-codex-packs"
test -f "$TEST_HOME/.agents/plugins/marketplace.json"
grep -q '"name": "my-codex"' "$TEST_HOME/.agents/plugins/marketplace.json"
test -L "$TEST_HOME/.agents/plugins/plugins/my-codex"
test "$(readlink "$TEST_HOME/.agents/plugins/plugins/my-codex")" = "$TEST_HOME/.codex/vendor/my-codex"
test -f "$TEST_HOME/.codex/vendor/my-codex/install.sh"
test -x "$TEST_HOME/.codex/git-hooks/prepare-commit-msg"
test -x "$TEST_HOME/.codex/git-hooks/commit-msg"
test -x "$TEST_HOME/.codex/git-hooks/post-commit"
grep -q 'multi_agent = true' "$TEST_HOME/.codex/config.toml"
grep -q 'child_agents_md = true' "$TEST_HOME/.codex/config.toml"
grep -q 'max_threads = 8' "$TEST_HOME/.codex/config.toml"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    test -f "$TEST_HOME/.codex/skills/connect-chrome/SKILL.md"
    grep -q '^name: connect-chrome$' "$TEST_HOME/.codex/skills/connect-chrome/SKILL.md"
    grep -q '^description: |$' "$TEST_HOME/.codex/skills/connect-chrome/SKILL.md"
    grep -q 'open gstack browser' "$TEST_HOME/.codex/skills/connect-chrome/SKILL.md"
    python - <<'PY' "$TEST_HOME/.codex/skills/connect-chrome/SKILL.md"
import sys
from pathlib import Path

raw = Path(sys.argv[1]).read_bytes()
assert not raw.startswith(b"\xef\xbb\xbf"), "skill file still starts with a UTF-8 BOM"
skill = raw.decode("utf-8")
parts = skill.split("---", 2)
assert len(parts) >= 3, "missing frontmatter delimiters"
frontmatter = parts[1]
assert skill.startswith("---\n") or skill.startswith("---\r\n"), "frontmatter must start at byte 0"
assert 'description: "' not in frontmatter, "description was rewritten as a quoted scalar"
assert 'description: |' in frontmatter, "description block scalar missing"
assert "allowed-tools:" in frontmatter, "frontmatter truncated before allowed-tools"
PY
    ;;
esac
test "$(HOME="$TEST_HOME" git config --global --get core.hooksPath)" = "$TEST_HOME/.codex/git-hooks"
test "$(HOME="$TEST_HOME" git config --global --get my-codex.codexAttribution)" = "true"
test -f "$TEST_HOME/.codex/.my-codex-manifest.txt"
test "$(cat "$TEST_HOME/.codex/.my-codex-version")" = "$expected_version"
grep -q '^engineering$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
grep -q '^design$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
grep -q '^testing$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
grep -q '^marketing$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
grep -q '^support$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
grep -q 'mcp add context7' "$LOG_FILE"
grep -q 'mcp add exa' "$LOG_FILE"
grep -q 'mcp add grep_app' "$LOG_FILE"

HOME="$TEST_HOME" "$TEST_HOME/.codex/bin/my-codex-packs" set-profile minimal
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" = "0"

HOME="$TEST_HOME" "$TEST_HOME/.codex/bin/my-codex-packs" set-profile dev
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" -ge 1

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
  bash "$REPO_ROOT/install.sh" --profile minimal > "$TMP_ROOT/install-minimal.out"
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" = "0"

HOME="$TEST_HOME" "$TEST_HOME/.codex/bin/my-codex-packs" enable marketing
grep -q '^marketing$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type f -name '*.toml' | wc -l | tr -d ' ')" -ge 10

mkdir -p "$TEST_HOME/.codex/agent-packs/custom" "$TEST_HOME/.codex/skills/custom-skill"
printf 'name = "custom-user-agent"\ndescription = "custom"\n[developer_instructions]\ncontent = "custom"\n' > "$TEST_HOME/.codex/agents/custom-user-agent.toml"
printf 'name = "custom-pack-agent"\ndescription = "custom"\n[developer_instructions]\ncontent = "custom"\n' > "$TEST_HOME/.codex/agent-packs/custom/custom-pack-agent.toml"
printf -- '---\nname: custom-skill\n---\n' > "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"
HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/reinstall.out"

test -f "$TEST_HOME/.codex/agents/custom-user-agent.toml"
test -f "$TEST_HOME/.codex/agent-packs/custom/custom-pack-agent.toml"
test -f "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"
test "$(cat "$TEST_HOME/.codex/.my-codex-version")" = "$expected_version"

PIPE_HOME="$TMP_ROOT/pipe-home"
mkdir -p "$PIPE_HOME" "$PIPE_HOME/.agents/skills" "$PIPE_HOME/.claude/skills"
HOME="$PIPE_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_BOOTSTRAP_REPO="$REPO_ROOT" \
  bash < "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-pipe.out"
test -f "$PIPE_HOME/.codex/.my-codex-version"
test "$(cat "$PIPE_HOME/.codex/.my-codex-version")" = "$expected_version"
test -L "$PIPE_HOME/.agents/plugins/plugins/my-codex"
test "$(readlink "$PIPE_HOME/.agents/plugins/plugins/my-codex")" = "$PIPE_HOME/.codex/vendor/my-codex"
test -f "$PIPE_HOME/.codex/vendor/my-codex/install.sh"

echo "Install smoke test passed"
