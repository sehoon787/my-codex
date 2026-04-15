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
VAULT_ONLY=0

if [ "${1:-}" = "--vault-only" ]; then
  VAULT_ONLY=1
fi

find_git_bash() {
  local candidate
  local program_files="${ProgramFiles:-}"
  local program_files_x86
  program_files_x86="$(printenv 'ProgramFiles(x86)' 2>/dev/null || true)"
  for candidate in \
    "$program_files/Git/bin/bash.exe" \
    "$program_files/Git/usr/bin/bash.exe" \
    "$program_files_x86/Git/bin/bash.exe" \
    "$program_files_x86/Git/usr/bin/bash.exe" \
    "/c/Program Files/Git/bin/bash.exe" \
    "/c/Program Files/Git/usr/bin/bash.exe" \
    "/mnt/c/Program Files/Git/bin/bash.exe" \
    "/mnt/c/Program Files/Git/usr/bin/bash.exe"
  do
    [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

to_git_bash_path() {
  local value="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$value" 2>/dev/null && return 0
  fi
  case "$value" in
    /mnt/[A-Za-z]/*)
      printf '%s' "$value" | sed -E 's#^/mnt/([A-Za-z])#/\L\1#'
      return 0
      ;;
  esac
  printf '%s' "$value" | sed -E 's#^([A-Za-z]):#/\L\1#; s#\\#/#g'
}

cleanup() {
  if [ "${KEEP_TMP_ROOT:-0}" = "1" ]; then
    echo "Preserving test root: $TMP_ROOT" >&2
    return
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME" "$BIN_DIR"
mkdir -p "$TEST_HOME/.agents/skills" "$TEST_HOME/.claude/skills"

cat > "$BIN_DIR/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${MY_CODEX_TEST_LOG:?}"
if [ -n "${MY_CODEX_TEST_TOUCH_FILE:-}" ]; then
  printf 'codex touched\n' >> "${MY_CODEX_TEST_TOUCH_FILE}"
fi
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

test -f "$TEST_HOME/.agents/plugins/marketplace.json"
grep -q '"name": "my-codex"' "$TEST_HOME/.agents/plugins/marketplace.json"
test -L "$TEST_HOME/.agents/plugins/plugins/my-codex"
test "$(readlink "$TEST_HOME/.agents/plugins/plugins/my-codex")" = "$TEST_HOME/.codex/vendor/my-codex"
test -f "$TEST_HOME/.codex/vendor/my-codex/.codex-plugin/plugin.json"
! grep -q '"hooks"' "$TEST_HOME/.codex/vendor/my-codex/.codex-plugin/plugin.json"
test -f "$TEST_HOME/.codex/hooks/session-sync.js"

if [ "$VAULT_ONLY" = "1" ]; then
  GIT_BASH=""
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Linux)
      GIT_BASH="$(find_git_bash || true)"
      ;;
  esac
  PROJECT_ROOT="$TMP_ROOT/project"
  mkdir -p "$PROJECT_ROOT"
  (
    cd "$PROJECT_ROOT"
    git init -q
    git config user.name test
    git config user.email test@example.com
    printf 'baseline\n' > tracked.txt
    git add tracked.txt
    git commit -q -m "baseline"
    if [ -n "$GIT_BASH" ]; then
      wrapper_path="$(to_git_bash_path "$TEST_HOME/.codex/bin/codex")"
      project_path="$(to_git_bash_path "$(pwd)")"
      test_home_path="$(to_git_bash_path "$TEST_HOME")"
      bin_path="$(to_git_bash_path "$BIN_DIR")"
      log_path="$(to_git_bash_path "$LOG_FILE")"
      touch_path="$(to_git_bash_path "$PROJECT_ROOT/tracked.txt")"
      "$GIT_BASH" -lc \
        "cd '$project_path' && HOME='$test_home_path' PATH=\"$test_home_path/.codex/bin:$bin_path:\$PATH\" MY_CODEX_TEST_LOG='$log_path' MY_CODEX_TEST_TOUCH_FILE='$touch_path' '$wrapper_path' run" \
        > "$TMP_ROOT/vault.out"
    else
      HOME="$TEST_HOME" PATH="$TEST_HOME/.codex/bin:$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
        MY_CODEX_TEST_TOUCH_FILE="$PROJECT_ROOT/tracked.txt" \
        "$TEST_HOME/.codex/bin/codex" run > "$TMP_ROOT/vault.out"
    fi
  )

  today="$(date -u +%Y-%m-%d)"
  session_auto="$PROJECT_ROOT/.briefing/sessions/$today-auto.md"
  learning_auto="$PROJECT_ROOT/.briefing/learnings/$today-auto-session.md"
  test -f "$PROJECT_ROOT/.briefing/INDEX.md"
  test -f "$PROJECT_ROOT/.briefing/agents/agent-log.jsonl"
  test -f "$session_auto"
  test -f "$learning_auto"
  grep -q 'tracked.txt' "$session_auto"
  grep -q 'tracked.txt' "$learning_auto"
  ! grep -q '\.gitignore' "$session_auto"
  ! grep -q '\.gitignore' "$learning_auto"

  HOOK_PROJECT="$TMP_ROOT/hook-project"
  mkdir -p "$HOOK_PROJECT"
  (
    cd "$HOOK_PROJECT"
    git init -q
    git config user.name test
    git config user.email test@example.com
    printf 'baseline\n' > tracked.txt
    git add tracked.txt
    git commit -q -m "baseline"

    if [ -n "$GIT_BASH" ]; then
      hook_project_path="$(to_git_bash_path "$HOOK_PROJECT")"
      test_home_path="$(to_git_bash_path "$TEST_HOME")"
      tmp_root_path="$(to_git_bash_path "$TMP_ROOT")"
      "$GIT_BASH" -lc \
        "cd '$hook_project_path' && HOME='$test_home_path' bash '$test_home_path/.codex/hooks/session-start.sh' > /dev/null && printf 'edited\n' >> tracked.txt && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' edit > '$tmp_root_path/hook-edit.out' && printf '{\"tool_input\":{\"url\":\"https://example.com/docs\"}}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' search > '$tmp_root_path/hook-search.out' && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-1.out' && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-2.out' && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-3.out' && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-4.out' && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-5.out'"
    else
      HOME="$TEST_HOME" bash "$TEST_HOME/.codex/hooks/session-start.sh" > /dev/null
      printf 'edited\n' >> tracked.txt
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" edit > "$TMP_ROOT/hook-edit.out"
      printf '{"tool_input":{"url":"https://example.com/docs"}}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" search > "$TMP_ROOT/hook-search.out"
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-1.out"
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-2.out"
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-3.out"
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-4.out"
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-5.out"
    fi
  )

  hook_session_auto="$HOOK_PROJECT/.briefing/sessions/$today-auto.md"
  hook_learning_auto="$HOOK_PROJECT/.briefing/learnings/$today-auto-session.md"
  hook_profile_md="$HOOK_PROJECT/.briefing/persona/profile.md"
  hook_links_md="$HOOK_PROJECT/.briefing/references/auto-links.md"
  test -f "$hook_session_auto"
  test -f "$hook_learning_auto"
  test -f "$hook_profile_md"
  test -f "$hook_links_md"
  grep -q 'tracked.txt' "$hook_session_auto"
  grep -q 'tracked.txt' "$hook_learning_auto"
  grep -q 'https://example.com/docs' "$hook_links_md"
  grep -q 'BriefingVault' "$TMP_ROOT/hook-prompt-3.out"
  grep -q '(insufficient data)\|Only wrapper/session-level signals have been observed so far.' "$hook_profile_md"

  echo "Vault smoke test passed"
  exit 0
fi

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
(
  cd "$TMP_ROOT"
  HOME="$PIPE_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_BOOTSTRAP_REPO="$REPO_ROOT" \
    bash < "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-pipe.out"
)
test -f "$PIPE_HOME/.codex/.my-codex-version"
test "$(cat "$PIPE_HOME/.codex/.my-codex-version")" = "$expected_version"
test -L "$PIPE_HOME/.agents/plugins/plugins/my-codex"
test "$(readlink "$PIPE_HOME/.agents/plugins/plugins/my-codex")" = "$PIPE_HOME/.codex/vendor/my-codex"
test -f "$PIPE_HOME/.codex/vendor/my-codex/install.sh"

PROJECT_ROOT="$TMP_ROOT/project"
mkdir -p "$PROJECT_ROOT"
(
  cd "$PROJECT_ROOT"
  git init -q
  git config user.name test
  git config user.email test@example.com
  printf 'baseline\n' > tracked.txt
  git add tracked.txt
  git commit -q -m "baseline"
  HOME="$TEST_HOME" PATH="$TEST_HOME/.codex/bin:$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
    MY_CODEX_TEST_TOUCH_FILE="$PROJECT_ROOT/tracked.txt" \
    "$TEST_HOME/.codex/bin/codex" run > "$TMP_ROOT/vault.out"
)

today="$(date -u +%Y-%m-%d)"
session_auto="$PROJECT_ROOT/.briefing/sessions/$today-auto.md"
learning_auto="$PROJECT_ROOT/.briefing/learnings/$today-auto-session.md"
signal_summary="$PROJECT_ROOT/.briefing/agents/$today-summary.md"
profile_md="$PROJECT_ROOT/.briefing/persona/profile.md"
test -f "$PROJECT_ROOT/.briefing/INDEX.md"
test -f "$profile_md"
test -f "$PROJECT_ROOT/.briefing/agents/agent-log.jsonl"
test -f "$signal_summary"
test -f "$session_auto"
test -f "$learning_auto"
grep -q 'tracked.txt' "$session_auto"
grep -q 'tracked.txt' "$learning_auto"
grep -q 'tracked diff vs session-start HEAD for recorded files:' "$session_auto"
grep -q '## End-of-Session Status For Recorded Files' "$session_auto"
grep -q '## Logged Session Signals' "$session_auto"
grep -q 'wrapper-managed session stop: 1 logged event' "$session_auto"
grep -q '## Logged Session Signals' "$learning_auto"
! grep -q '\.gitignore' "$session_auto"
! grep -q '\.gitignore' "$learning_auto"
! grep -q 'no committed diff since session start' "$session_auto"
grep -q 'Only wrapper/session-level signals have been observed so far.' "$profile_md"
grep -q '## Logged Signals' "$profile_md"
grep -q '## Specialist Preferences' "$profile_md"
grep -q 'wrapper-managed session stop: 1 logged event' "$signal_summary"
grep -q 'Total logged signals today: 1' "$signal_summary"

HOOK_PROJECT="$TMP_ROOT/hook-project"
mkdir -p "$HOOK_PROJECT"
(
  cd "$HOOK_PROJECT"
  git init -q
  git config user.name test
  git config user.email test@example.com
  printf 'baseline\n' > tracked.txt
  git add tracked.txt
  git commit -q -m "baseline"
  HOME="$TEST_HOME" bash "$TEST_HOME/.codex/hooks/session-start.sh" > /dev/null
  printf 'edited\n' >> tracked.txt
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" edit > "$TMP_ROOT/hook-edit.out"
  printf '{"tool_input":{"url":"https://example.com/docs"}}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" search > "$TMP_ROOT/hook-search.out"
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-1.out"
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-2.out"
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-3.out"
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-4.out"
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-5.out"
)

hook_session_auto="$HOOK_PROJECT/.briefing/sessions/$today-auto.md"
hook_learning_auto="$HOOK_PROJECT/.briefing/learnings/$today-auto-session.md"
hook_profile_md="$HOOK_PROJECT/.briefing/persona/profile.md"
hook_links_md="$HOOK_PROJECT/.briefing/references/auto-links.md"
test -f "$hook_session_auto"
test -f "$hook_learning_auto"
test -f "$hook_profile_md"
test -f "$hook_links_md"
grep -q 'tracked.txt' "$hook_session_auto"
grep -q 'tracked.txt' "$hook_learning_auto"
grep -q 'wrapper-managed session stop: 1 logged event\|mid-session-sync' "$hook_session_auto"
grep -q 'https://example.com/docs' "$hook_links_md"
grep -q 'BriefingVault' "$TMP_ROOT/hook-prompt-3.out"
grep -q 'Only wrapper/session-level signals have been observed so far.\|no specialist-level signals yet' "$hook_profile_md"

echo "Install smoke test passed"
