#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/my-codex-attribution-test.$$"
TEST_HOME="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
REPO_DIR="$TMP_ROOT/repo"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME" "$BIN_DIR" "$REPO_DIR"

cat > "$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ -n "${FAKE_CODEX_TOUCH_FILE:-}" ]; then
  printf 'updated by fake codex\n' >> "$FAKE_CODEX_TOUCH_FILE"
fi
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

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install.out"

test -x "$TEST_HOME/.codex/bin/codex"
test -x "$TEST_HOME/.codex/bin/codex-mark-used"
test -x "$TEST_HOME/.codex/git-hooks/prepare-commit-msg"
test -x "$TEST_HOME/.codex/git-hooks/commit-msg"
test -x "$TEST_HOME/.codex/git-hooks/post-commit"
test "$(HOME="$TEST_HOME" git config --global --get core.hooksPath)" = "$TEST_HOME/.codex/git-hooks"
if HOME="$TEST_HOME" git config --global --get my-codex.codexContributorName >/dev/null 2>&1; then
  echo "co-author name should not be configured by default" >&2
  exit 1
fi

git -C "$REPO_DIR" init -q
git -C "$REPO_DIR" config user.name "Test User"
git -C "$REPO_DIR" config user.email "test@example.com"

printf 'initial\n' > "$REPO_DIR/demo.txt"
git -C "$REPO_DIR" add demo.txt
git -C "$REPO_DIR" commit -q -m "chore: initial"

(
  cd "$REPO_DIR"
  export HOME="$TEST_HOME"
  export PATH="$TEST_HOME/.codex/bin:$BIN_DIR:$PATH"
  export FAKE_CODEX_TOUCH_FILE="$REPO_DIR/demo.txt"
  "$TEST_HOME/.codex/bin/codex" >/dev/null 2>&1
  git add demo.txt
  git commit -q -m "feat: codex change"
)

git -C "$REPO_DIR" log -1 --pretty=%B > "$TMP_ROOT/codex-commit.txt"
test "$(git -C "$REPO_DIR" log -1 --pretty='%an <%ae>')" = "Test User <test@example.com>"
grep -F -q 'Generated with Codex CLI: https://github.com/openai/codex' "$TMP_ROOT/codex-commit.txt"
grep -q '^AI-Contributed-By: Codex$' "$TMP_ROOT/codex-commit.txt"
if grep -qi '^Co-authored-by:' "$TMP_ROOT/codex-commit.txt"; then
  echo "co-author trailer should not be added without explicit configuration" >&2
  exit 1
fi

HOME="$TEST_HOME" git config --global my-codex.codexContributorName "Pair Programmer"
HOME="$TEST_HOME" git config --global my-codex.codexContributorEmail "codex@example.com"

(
  cd "$REPO_DIR"
  export HOME="$TEST_HOME"
  export PATH="$TEST_HOME/.codex/bin:$BIN_DIR:$PATH"
  export FAKE_CODEX_TOUCH_FILE="$REPO_DIR/demo.txt"
  "$TEST_HOME/.codex/bin/codex" >/dev/null 2>&1
  git add demo.txt
  git commit -q -m "feat: codex coauthor"
)

git -C "$REPO_DIR" log -1 --pretty=%B > "$TMP_ROOT/codex-coauthor-commit.txt"
test "$(git -C "$REPO_DIR" log -1 --pretty='%an <%ae>')" = "Test User <test@example.com>"
grep -F -q 'Generated with Codex CLI: https://github.com/openai/codex' "$TMP_ROOT/codex-coauthor-commit.txt"
grep -q '^AI-Contributed-By: Codex$' "$TMP_ROOT/codex-coauthor-commit.txt"
grep -q '^Co-authored-by: Pair Programmer <codex@example.com>$' "$TMP_ROOT/codex-coauthor-commit.txt"

printf 'manual\n' >> "$REPO_DIR/manual.txt"
git -C "$REPO_DIR" add manual.txt
git -C "$REPO_DIR" commit -q -m "docs: manual change"
git -C "$REPO_DIR" log -1 --pretty=%B > "$TMP_ROOT/manual-commit.txt"
if grep -F -q 'Generated with Codex CLI: https://github.com/openai/codex' "$TMP_ROOT/manual-commit.txt"; then
  echo "manual commit was incorrectly marked as generated with Codex" >&2
  exit 1
fi
if grep -q '^AI-Contributed-By: Codex$' "$TMP_ROOT/manual-commit.txt"; then
  echo "manual commit was incorrectly attributed to Codex" >&2
  exit 1
fi

echo "Codex attribution test passed"
