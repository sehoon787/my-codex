#!/usr/bin/env bash
set -euo pipefail
trap 'echo "FAILED at line $LINENO (exit $?)" >&2' ERR

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_PARENT="${TMPDIR:-$REPO_ROOT/.tmp-install-tests}"
TMP_PARENT="${TMP_PARENT%/}"
mkdir -p "$TMP_PARENT"
TMP_ROOT="$TMP_PARENT/my-codex-install-test.$$"
TEST_HOME="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
LOG_FILE="$TMP_ROOT/codex.log"
SERVICE_STATE="$TMP_ROOT/shared-services"
VAULT_ONLY=0
GSTACK_ONLY=0
export AGENT_HARNESS_STATE_DIR="$SERVICE_STATE"

if [ "${1:-}" = "--vault-only" ]; then
  VAULT_ONLY=1
elif [ "${1:-}" = "--gstack-only" ]; then
  GSTACK_ONLY=1
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

# `hooks = true` must live inside the [features] table. Appending it at EOF would
# park it under whatever table comes last (usually an [mcp_servers.*] one), where
# Codex never reads it -- so assert placement, not mere presence.
assert_features_hooks_enabled() {
  awk '
    /^[[:space:]]*\[[[:space:]]*features[[:space:]]*\][[:space:]]*(#.*)?$/ { in_features = 1; next }
    /^[[:space:]]*\[/ { in_features = 0 }
    in_features && /^[[:space:]]*hooks[[:space:]]*=[[:space:]]*true/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

cleanup() {
  local pid_file pid
  for pid_file in "$SERVICE_STATE"/*.pid; do
    [ -f "$pid_file" ] || continue
    pid="$(cat "$pid_file")"
    kill "$pid" 2>/dev/null || true
  done
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

# Runtime verification shims. They exercise the installer's actual bounded
# probes without reading host state, opening a browser, starting a server, or
# relying on the CI machine to have the optional tools preinstalled.
cat > "$BIN_DIR/codeburn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "codeburn $*" >> "${MY_CODEX_TEST_LOG:?}"
if [ "${1:-}" = "--version" ]; then
  echo "0.9.23"
  exit 0
fi
[ "${1:-}" = "web" ] || exit 2
touch "${MY_CODEX_TEST_SERVICE_ROOT:?}/codeburn.healthy"
trap 'rm -f "$MY_CODEX_TEST_SERVICE_ROOT/codeburn.healthy"; exit 0' TERM INT
while :; do sleep 1; done
EOF
chmod +x "$BIN_DIR/codeburn"

cat > "$BIN_DIR/serena" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "serena $*" >> "${MY_CODEX_TEST_LOG:?}"
[ "${1:-}" = "--version" ] || exit 2
echo "Serena 1.7.0"
EOF
chmod +x "$BIN_DIR/serena"

cat > "$BIN_DIR/headroom" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "headroom $*" >> "${MY_CODEX_TEST_LOG:?}"
if [ "${1:-}" = "--version" ]; then
  echo "headroom, version 0.37.0"
  exit 0
fi
[ "${1:-}" = "install" ] && [ "${2:-}" = "apply" ] || exit 2
touch "${MY_CODEX_TEST_SERVICE_ROOT:?}/headroom.healthy"
EOF
chmod +x "$BIN_DIR/headroom"

SERVICE_ROOT="$TMP_ROOT/services"
mkdir -p "$SERVICE_ROOT"
export MY_CODEX_TEST_SERVICE_ROOT="$SERVICE_ROOT"

cat > "$BIN_DIR/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do url="$arg"; done
case "$url" in
  http://127.0.0.1:4747/)
    [ -f "${MY_CODEX_TEST_SERVICE_ROOT:?}/codeburn.healthy" ] || exit 7
    printf '<html><head><title>CodeBurn - Local Dashboard</title></head></html>\n'
    ;;
  http://127.0.0.1:8787/livez)
    [ -f "${MY_CODEX_TEST_SERVICE_ROOT:?}/headroom.healthy" ] || exit 7
    printf '{"service":"headroom-proxy","status":"healthy","alive":true}\n'
    ;;
  *) exec /usr/bin/curl "$@" ;;
esac
EOF
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/lsof" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$BIN_DIR/lsof"

# uv shim. Real `uv tool install` would download serena-agent and headroom-ai
# (hundreds of MB, minutes) on every CI run; what this test is about is the
# wiring -- that the installer resolves uv, asks for the pinned specs once, and
# skips them on re-run. `tool list` is backed by a state file so the installer's
# idempotency guard is exercised for real rather than stubbed out.
cat > "$BIN_DIR/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
STATE="${MY_CODEX_TEST_UV_STATE:?}"
echo "uv $*" >> "${MY_CODEX_TEST_LOG:?}"
if [ "${1:-}" = "tool" ]; then
  case "${2:-}" in
    list) [ -f "$STATE" ] && cat "$STATE"; exit 0 ;;
    install)
      # last argument is the pinned spec: name[extras]==version
      for spec in "$@"; do :; done
      name="${spec%%==*}"; name="${name%%[*}"
      printf '%s v%s\n' "$name" "${spec##*==}" >> "$STATE"
      exit 0
      ;;
  esac
fi
exit 0
EOF
chmod +x "$BIN_DIR/uv"
UV_STATE="$TMP_ROOT/uv-tools.txt"
: > "$UV_STATE"
export MY_CODEX_TEST_UV_STATE="$UV_STATE"

expected_version="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
HOSTILE_CODEX_HOME="$TMP_ROOT/hostile-codex-home"
mkdir -p "$HOSTILE_CODEX_HOME"
printf 'untouched\n' > "$HOSTILE_CODEX_HOME/sentinel"

# Reproduce the legacy whole-checkout layout that leaked gstack test fixtures
# into Codex's recursive skill discovery. The executable config sentinel makes
# a stale-runtime-only success check insufficient.
mkdir -p "$TEST_HOME/.codex/skills/gstack/test/fixtures/context-bill/tree-a/alpha" \
  "$TEST_HOME/.codex/skills/gstack/bin" "$TEST_HOME/.codex/skills/gstack/review"
printf '#!/usr/bin/env bash\n' > "$TEST_HOME/.codex/skills/gstack/setup"
printf '#!/usr/bin/env bash\n' > "$TEST_HOME/.codex/skills/gstack/bin/gstack-config"
printf -- '---\nname: alpha\ndescription: fixture\n---\n' > \
  "$TEST_HOME/.codex/skills/gstack/test/fixtures/context-bill/tree-a/alpha/SKILL.md"
printf -- '---\nname: review\ndescription: legacy\n---\n' > \
  "$TEST_HOME/.codex/skills/gstack/review/SKILL.md"
ln -s "$TEST_HOME/.codex/skills/gstack/review" "$TEST_HOME/.codex/skills/review"
chmod +x "$TEST_HOME/.codex/skills/gstack/setup" "$TEST_HOME/.codex/skills/gstack/bin/gstack-config"

HOME="$TEST_HOME" CODEX_HOME="$HOSTILE_CODEX_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" MY_CODEX_TEST_SERVICE_ROOT="$SERVICE_ROOT" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install.out"
test "$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).profile" "$TEST_HOME/.codex/my-codex/skill-catalog-state.json")" = "core"
test "$(cat "$HOSTILE_CODEX_HOME/sentinel")" = "untouched"
test ! -e "$HOSTILE_CODEX_HOME/skills"
grep -q '^  codeburn:      OK (0.9.23)$' "$TMP_ROOT/install.out"
grep -q '^  serena:        OK (Serena 1.7.0)$' "$TMP_ROOT/install.out"
grep -q '^  headroom:      OK (headroom, version 0.37.0)$' "$TMP_ROOT/install.out"
grep -q '^  archify:       OK (rendered and checked bundled workflow example)$' "$TMP_ROOT/install.out"
grep -q '^  Tool probes:   4 OK, 0 FAIL$' "$TMP_ROOT/install.out"
grep -q '^  Serena dashboard: http://localhost:24282/dashboard/index.html$' "$TMP_ROOT/install.out"
grep -q '^codeburn web: STARTED (http://127.0.0.1:4747/; log: ' "$TMP_ROOT/install.out"
grep -q '^Headroom proxy: STARTED (http://127.0.0.1:8787/stats; profile: agent-harness-shared; log: ' "$TMP_ROOT/install.out"
grep -q '^  codeburn dashboard: http://127.0.0.1:4747/$' "$TMP_ROOT/install.out"
grep -q '^  Headroom stats:     http://127.0.0.1:8787/stats$' "$TMP_ROOT/install.out"
grep -Fq "  Shared service logs: $SERVICE_STATE/logs" "$TMP_ROOT/install.out"
grep -q '^  Headroom does not route Claude or Codex traffic until you explicitly configure a client.$' "$TMP_ROOT/install.out"
grep -q '^  codeburn shared dashboard: http://127.0.0.1:4747/ (started or reused during installation)$' "$TMP_ROOT/install.out"
grep -q '^  Headroom proxy stats: http://127.0.0.1:8787/stats (empty until traffic is explicitly routed)$' "$TMP_ROOT/install.out"
grep -q '^  Serena/Headroom MCP: auto-start each Codex session$' "$TMP_ROOT/install.out"
grep -q '^codeburn --version$' "$LOG_FILE"
grep -q '^serena --version$' "$LOG_FILE"
grep -q '^headroom --version$' "$LOG_FILE"
grep -q '^codeburn web --provider all --port 4747 --no-open$' "$LOG_FILE"
grep -q '^headroom install apply --profile agent-harness-shared --preset persistent-service --runtime python --providers manual --port 8787 --no-telemetry --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1$' "$LOG_FILE"

test -f "$TEST_HOME/.agents/plugins/marketplace.json"
grep -q '"name": "my-codex"' "$TEST_HOME/.agents/plugins/marketplace.json"
test -L "$TEST_HOME/.agents/plugins/plugins/my-codex"
test "$(readlink "$TEST_HOME/.agents/plugins/plugins/my-codex")" = "$TEST_HOME/.codex/vendor/my-codex"
test -f "$TEST_HOME/.codex/vendor/my-codex/.codex-plugin/plugin.json"
! grep -q '"hooks"' "$TEST_HOME/.codex/vendor/my-codex/.codex-plugin/plugin.json"
test -f "$TEST_HOME/.codex/hooks/session-sync.js"
test -f "$TEST_HOME/.codex/hooks/briefing-runtime.js"
test -f "$TEST_HOME/.codex/hooks/session-start-state.js"

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
  decision_auto="$PROJECT_ROOT/.briefing/decisions/$today-auto.md"
  session_topic_count="$(find "$PROJECT_ROOT/.briefing/sessions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
  learning_topic_count="$(find "$PROJECT_ROOT/.briefing/learnings" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto-session.md" | wc -l | tr -d ' ')"
  decision_topic_count="$(find "$PROJECT_ROOT/.briefing/decisions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
  test -f "$PROJECT_ROOT/.briefing/INDEX.md"
  test -f "$PROJECT_ROOT/.briefing/state.json"
  test -f "$PROJECT_ROOT/.briefing/persona/persona-policy.json"
  test -f "$PROJECT_ROOT/.briefing/agents/agent-log.jsonl"
  test -f "$session_auto"
  test -f "$learning_auto"
  test -f "$decision_auto"
  grep -q 'tracked.txt' "$session_auto"
  grep -q 'tracked.txt' "$learning_auto"
  grep -q 'tracked.txt' "$decision_auto"
  grep -q '## Work Completed' "$session_auto"
  grep -q '## What Seems Reusable' "$learning_auto"
  grep -q '## Candidate Decisions' "$decision_auto"
  test "$session_topic_count" -ge 1
  test "$learning_topic_count" = "0"
  test "$decision_topic_count" = "0"
  ! grep -q '\.gitignore' "$session_auto"
  ! grep -q '\.gitignore' "$learning_auto"
  test ! -e "$PROJECT_ROOT/.briefing/.session-start-head"
  test ! -e "$PROJECT_ROOT/.briefing/.session-start-status"
  test ! -e "$PROJECT_ROOT/.briefing/.session-message-count"
  test ! -e "$PROJECT_ROOT/.briefing/.session-hook-noise"

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
        "cd '$hook_project_path' && HOME='$test_home_path' bash '$test_home_path/.codex/hooks/session-start.sh' > /dev/null && printf 'edited\n' >> tracked.txt && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' edit > '$tmp_root_path/hook-edit.out' && printf '{\"tool_input\":{\"url\":\"https://example.com/docs\",\"query\":\"BriefingVault docs\"},\"prompt\":\"Check the vault docs\"}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' search > '$tmp_root_path/hook-search.out' && printf '{\"prompt\":\"Improve BriefingVault content quality\"}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-1.out' && printf '{\"prompt\":\"Capture the routing policy decision\"}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-2.out' && printf '{\"prompt\":\"List missing follow-ups\"}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-3.out' && printf '{\"prompt\":\"Capture reusable patterns\"}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-4.out' && printf '{\"prompt\":\"Finalize the vault note\"}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-sync.js' prompt > '$tmp_root_path/hook-prompt-5.out' && printf '{}' | HOME='$test_home_path' node '$test_home_path/.codex/hooks/session-end.js' > '$tmp_root_path/hook-session-end.out'"
    else
      HOME="$TEST_HOME" bash "$TEST_HOME/.codex/hooks/session-start.sh" > /dev/null
      printf 'edited\n' >> tracked.txt
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" edit > "$TMP_ROOT/hook-edit.out"
      printf '{"tool_input":{"url":"https://example.com/docs","query":"BriefingVault docs"},"prompt":"Check the vault docs"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" search > "$TMP_ROOT/hook-search.out"
      printf '{"prompt":"Improve BriefingVault content quality"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-1.out"
      printf '{"prompt":"Capture the routing policy decision"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-2.out"
      printf '{"prompt":"List missing follow-ups"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-3.out"
      printf '{"prompt":"Capture reusable patterns"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-4.out"
      printf '{"prompt":"Finalize the vault note"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-5.out"
      printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-end.js" > "$TMP_ROOT/hook-session-end.out"
    fi
  )

  hook_session_auto="$HOOK_PROJECT/.briefing/sessions/$today-auto.md"
  hook_learning_auto="$HOOK_PROJECT/.briefing/learnings/$today-auto-session.md"
  hook_decision_auto="$HOOK_PROJECT/.briefing/decisions/$today-auto.md"
  hook_session_topic_count="$(find "$HOOK_PROJECT/.briefing/sessions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
  hook_learning_topic_count="$(find "$HOOK_PROJECT/.briefing/learnings" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto-session.md" | wc -l | tr -d ' ')"
  hook_decision_topic_count="$(find "$HOOK_PROJECT/.briefing/decisions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
  hook_profile_md="$HOOK_PROJECT/.briefing/persona/profile.md"
  hook_links_md="$HOOK_PROJECT/.briefing/references/auto-links.md"
  test -f "$hook_session_auto"
  test -f "$hook_learning_auto"
  test -f "$hook_decision_auto"
  test -f "$hook_profile_md"
  test -f "$hook_links_md"
  test -f "$HOOK_PROJECT/.briefing/state.json"
  test -f "$HOOK_PROJECT/.briefing/persona/persona-policy.json"
  grep -q 'tracked.txt' "$hook_session_auto"
  grep -q 'tracked.txt' "$hook_learning_auto"
  grep -q 'tracked.txt' "$hook_decision_auto"
  grep -q 'Improve BriefingVault content quality' "$hook_session_auto"
  grep -q 'https://example.com/docs -- Check the vault docs' "$hook_links_md"
  grep -q 'Latest user intent: Finalize the vault note' "$hook_learning_auto"
  grep -q 'Candidate Decisions' "$hook_decision_auto"
  test "$hook_session_topic_count" -ge 1
  test "$hook_learning_topic_count" -ge 1
  test "$hook_decision_topic_count" -ge 1
  grep -q '## Current Session Snapshot' "$hook_profile_md"
  grep -q 'https://example.com/docs' "$hook_links_md"
  grep -q 'BriefingVault' "$TMP_ROOT/hook-prompt-3.out"
  grep -q 'Only wrapper/session-level signals have been observed so far.\|Insufficient signal.' "$hook_profile_md"

  echo "Vault smoke test passed"
  exit 0
fi

actual_core=$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type f -name '*.toml' | wc -l | tr -d ' ')
actual_active_pack_links=$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')
actual_packs=$(find "$TEST_HOME/.codex/agent-packs" -name '*.toml' | wc -l | tr -d ' ')
actual_skills=$(find "$TEST_HOME/.codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')



# Post-dedup contract (2026-07-27): 17 auto-loaded agents (10 core/omo + 7 omx),
# 17 vendored pack agents (data-ai 13 + llmops 4), packs disabled by default,
# 105 allowlisted skills on a real install. In this sandboxed harness the
# gstack network clone is unavailable, so assert a conservative physical floor.
# Optional lane payloads are copied when first requested, then retained across
# later profile changes and reinstalls.
test "$actual_core" -ge 17
test "$actual_active_pack_links" -eq 0
test "$actual_packs" -eq 17
test "$actual_skills" -ge 75
test -f "$TEST_HOME/.codex/AGENTS.md"
test -f "$TEST_HOME/.codex/agent-packs/data-ai/llm-architect.toml"
# Allowlists (scripts/skill-allowlists.sh): kept entries land, dropped ones do not.
test -f "$TEST_HOME/.codex/agents/executor.toml"
test ! -e "$TEST_HOME/.codex/agents/analyst.toml"
test ! -e "$TEST_HOME/.codex/agents/superpowers-code-reviewer.toml"
test -f "$TEST_HOME/.codex/skills/api-design/SKILL.md"
test ! -e "$TEST_HOME/.codex/skills/laravel-patterns"
test ! -e "$TEST_HOME/.codex/skills/react-patterns"
test ! -e "$TEST_HOME/.codex/skills/vue-patterns"
test -f "$TEST_HOME/.codex/enabled-skill-lanes.txt"
! grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"
test -f "$TEST_HOME/.codex/skills/brainstorming/SKILL.md"
test ! -e "$TEST_HOME/.codex/skills/dispatching-parallel-agents"
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

# Codex reads lifecycle hooks from $CODEX_HOME/hooks.json (root) and only when
# features.hooks is on. The pre-fix installer wrote hooks/hooks.json and never set
# the flag, so every hook was silently dead.
test -f "$TEST_HOME/.codex/hooks.json"
test ! -f "$TEST_HOME/.codex/hooks/hooks.json"
assert_features_hooks_enabled "$TEST_HOME/.codex/config.toml"
grep -q '<!-- my-codex:calibrated-response -->' "$TEST_HOME/.codex/AGENTS.md"
grep -q '<!-- my-codex:default-agent -->' "$TEST_HOME/.codex/AGENTS.md"
grep -q '<!-- my-codex:boss-first -->' "$TEST_HOME/.codex/AGENTS.md"
grep -q '<!-- my-codex:final-report -->' "$TEST_HOME/.codex/AGENTS.md"
grep -q '<!-- my-codex:context-hygiene -->' "$TEST_HOME/.codex/AGENTS.md"
grep -q '<!-- my-codex:tooling-mcp -->' "$TEST_HOME/.codex/AGENTS.md"
test "$(grep -c 'my-codex:' "$TEST_HOME/.codex/AGENTS.md")" = "6"
grep -q 'The root agent is the \*\*Boss orchestrator\*\*' "$TEST_HOME/.codex/AGENTS.md"
! grep -q 'spawn_agent(prompt="<user.s full request>", agent_type="boss")' "$TEST_HOME/.codex/AGENTS.md"
# A successful gstack install keeps the checkout outside Codex's recursively
# scanned skills root and exposes only the upstream minimal runtime facade.
if [ -f "$TEST_HOME/.codex/vendor/gstack/setup" ]; then
  test ! -e "$TEST_HOME/.codex/skills/gstack/test"
  test ! -e "$TEST_HOME/.codex/skills/gstack/test/fixtures/context-bill/tree-a/alpha/SKILL.md"
  if [ -x "$TEST_HOME/.codex/skills/gstack/bin/gstack-config" ]; then
    test -x "$TEST_HOME/.codex/skills/gstack/bin/gstack-paths"
  fi
fi
test ! -e "$TEST_HOME/.codex/skills/gstack/test/fixtures/context-bill/tree-a/alpha/SKILL.md"
test "$(find "$TEST_HOME/.codex/backups" -path '*/test/fixtures/context-bill/tree-a/alpha/SKILL.md' 2>/dev/null | wc -l | tr -d ' ')" = "1"
test -e "$TEST_HOME/.codex/skills/review/SKILL.md"
test ! -e "$TEST_HOME/.codex/skills/gstack-review"
test -f "$TEST_HOME/.codex/skills/gstack/SKILL.md"
test ! -L "$TEST_HOME/.codex/skills/gstack/SKILL.md"
grep -q '^name: gstack$' "$TEST_HOME/.codex/skills/gstack/SKILL.md"
grep -q '^name: codex$' "$TEST_HOME/.codex/skills/codex/SKILL.md"
grep -q '^name: gstack-upgrade$' "$TEST_HOME/.codex/skills/gstack-upgrade/SKILL.md"
grep -q '^name: hackernews-frontpage$' "$TEST_HOME/.codex/skills/hackernews-frontpage/SKILL.md"

# gstack setup currently generates every upstream gstack-* skill. my-codex's
# public Codex catalog is narrower: only names in GSTACK_SKILL_ALLOWLIST may be
# exposed at ~/.codex/skills. The full source remains available in vendor/gstack.
# Check the installed result rather than the installer's source text so this
# catches future setup changes that add another generated skill.
# shellcheck source=skill-allowlists.sh
source "$REPO_ROOT/scripts/skill-allowlists.sh"
gstack_allowed=" $({ printf '%s\n' $GSTACK_SKILL_ALLOWLIST; } | tr '\n' ' ') gstack-upgrade "
for generated_source in "$TEST_HOME/.codex/vendor/gstack/.agents/skills/"gstack-*; do
  [ -f "$generated_source/SKILL.md" ] || continue
  skill_name="$(sed -n 's/^name:[[:space:]]*//p' "$generated_source/SKILL.md" | head -n 1 | tr -d '\r')"
  [ -n "$skill_name" ] || continue
  case "$gstack_allowed" in *" $skill_name "*) continue ;; esac
  test ! -e "$TEST_HOME/.codex/skills/$skill_name"
  test ! -L "$TEST_HOME/.codex/skills/$skill_name"
done

# A user-owned symlink that collides with an unallowlisted generated name must
# survive a later install. Exact provenance, rather than the target name, owns
# the cleanup decision.
custom_design_html_source="$TEST_HOME/custom-skills/design-html"
custom_design_html="$TEST_HOME/.codex/skills/design-html"
mkdir -p "$custom_design_html_source"
printf -- '---\nname: design-html\ndescription: user owned\n---\n' > \
  "$custom_design_html_source/SKILL.md"
ln -s "$custom_design_html_source" "$custom_design_html"

# A directory at the generated prefixed path is not safe to delete based on
# byte equality alone: on platforms without symlinks it may be a user copy.
custom_generated_design_html="$TEST_HOME/.codex/skills/gstack-design-html"
cp -R "$TEST_HOME/.codex/vendor/gstack/.agents/skills/gstack-design-html" \
  "$custom_generated_design_html"

# A real gstack-prefixed directory can share the generated SKILL.md bytes while
# carrying user-owned files. Matching only SKILL.md would wrongly classify the
# whole directory as generated and delete the note during prefix normalization.
generated_review="$TEST_HOME/.codex/vendor/gstack/.agents/skills/gstack-review/SKILL.md"
custom_gstack_review="$TEST_HOME/.codex/skills/gstack-review"
test -f "$generated_review"
test ! -e "$custom_gstack_review"
mkdir -p "$custom_gstack_review"
cp "$generated_review" "$custom_gstack_review/SKILL.md"
printf 'keep this user note\n' > "$custom_gstack_review/user-notes.md"
test -d "$custom_gstack_review"
test ! -L "$custom_gstack_review"
cmp -s "$generated_review" "$custom_gstack_review/SKILL.md"

if [ "$GSTACK_ONLY" = "1" ]; then
  HOME="$TEST_HOME" CODEX_HOME="$HOSTILE_CODEX_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
    bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-gstack-repeat.out"
  test -d "$custom_gstack_review"
  test ! -L "$custom_gstack_review"
  test -f "$custom_gstack_review/SKILL.md"
  test "$(cat "$custom_gstack_review/user-notes.md")" = "keep this user note"
  ! grep -qx 'skills/gstack-review' "$TEST_HOME/.codex/.my-codex-manifest.txt"
  test -L "$custom_design_html"
  test "$(readlink "$custom_design_html")" = "$custom_design_html_source"
  test -f "$custom_design_html/SKILL.md"
  ! grep -qx 'skills/design-html' "$TEST_HOME/.codex/.my-codex-manifest.txt"
  test -d "$custom_generated_design_html"
  test ! -L "$custom_generated_design_html"
  test -f "$custom_generated_design_html/SKILL.md"
  echo "Gstack install isolation and ownership test passed"
  exit 0
fi
grep -q '^compact_prompt = ' "$TEST_HOME/.codex/config.toml"
test "$(grep -c '^compact_prompt = ' "$TEST_HOME/.codex/config.toml")" = "1"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # Windows has no usable symlinks, so gstack's benchmark is copied by
    # fix_windows_gstack_skill_aliases after the supersede sweep removes it.
    test -f "$TEST_HOME/.codex/skills/benchmark/SKILL.md"
    # connect-chrome aliased open-gstack-browser, which is no longer allowlisted.
    test ! -e "$TEST_HOME/.codex/skills/connect-chrome"
    ;;
esac
test "$(HOME="$TEST_HOME" git config --global --get core.hooksPath)" = "$TEST_HOME/.codex/git-hooks"
test "$(HOME="$TEST_HOME" git config --global --get my-codex.codexAttribution)" = "true"
test -f "$TEST_HOME/.codex/.my-codex-manifest.txt"
test "$(cat "$TEST_HOME/.codex/.my-codex-version")" = "$expected_version"
# Post-dedup contract: no packs enabled by default (opt-in only).
test -f "$TEST_HOME/.codex/enabled-agent-packs.txt"
! grep -q '^[a-z]' "$TEST_HOME/.codex/enabled-agent-packs.txt"
grep -q 'mcp add context7' "$LOG_FILE"
grep -q 'mcp add exa' "$LOG_FILE"
grep -q 'mcp add grep_app' "$LOG_FILE"

# ── Serena / Headroom / Archify ──
# The two stdio MCP servers are registered as config.toml tables rather than via
# `codex mcp add` (no --startup-timeout-sec flag there), so assert the tables and
# the keys that make them work, then assert the file still parses as TOML.
assert_toml_parses() {
  python3 -c "import sys, tomllib; tomllib.load(open(sys.argv[1], 'rb'))" "$1"
}
grep -q '^\[mcp_servers\.serena\]' "$TEST_HOME/.codex/config.toml"
grep -q '^\[mcp_servers\.headroom\]' "$TEST_HOME/.codex/config.toml"
grep -q '^startup_timeout_sec = 15$' "$TEST_HOME/.codex/config.toml"
grep -q -- '--open-web-dashboard' "$TEST_HOME/.codex/config.toml"
grep -q '"mcp", "serve"' "$TEST_HOME/.codex/config.toml"
assert_toml_parses "$TEST_HOME/.codex/config.toml"

# Pinned Python tools: asked for once, by exact spec, through uv.
grep -q 'uv tool install --python 3.13 serena-agent==1.7.0' "$LOG_FILE"
grep -q 'uv tool install --python 3.13 headroom-ai\[all\]==0.37.0' "$LOG_FILE"
grep -q '^serena-agent v1.7.0$' "$UV_STATE"
grep -q '^headroom-ai v0.37.0$' "$UV_STATE"

# Archify ships as one skill directory copied out of the tag-pinned submodule.
test -f "$TEST_HOME/.codex/skills/archify/SKILL.md"
test -f "$TEST_HOME/.codex/skills/archify/bin/archify.mjs"

HOME="$TEST_HOME" "$TEST_HOME/.codex/bin/my-codex-packs" set-profile minimal
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" = "0"

HOME="$TEST_HOME" "$TEST_HOME/.codex/bin/my-codex-packs" set-profile dev
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" -ge 1

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" --profile minimal > "$TMP_ROOT/install-minimal.out"
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')" = "0"

HOME="$TEST_HOME" "$TEST_HOME/.codex/bin/my-codex-packs" enable data-ai
grep -q '^data-ai$' "$TEST_HOME/.codex/enabled-agent-packs.txt"
test "$(find "$TEST_HOME/.codex/agents" -maxdepth 1 -type f -name '*.toml' | wc -l | tr -d ' ')" -ge 10

mkdir -p "$TEST_HOME/.codex/agent-packs/custom" \
  "$TEST_HOME/.codex/skills/custom-skill" \
  "$TEST_HOME/.agents/skills/external-normalizer-trap"
printf 'name = "custom-user-agent"\ndescription = "custom"\n[developer_instructions]\ncontent = "custom"\n' > "$TEST_HOME/.codex/agents/custom-user-agent.toml"
printf 'name = "custom-pack-agent"\ndescription = "custom"\n[developer_instructions]\ncontent = "custom"\n' > "$TEST_HOME/.codex/agent-packs/custom/custom-pack-agent.toml"
printf -- '---\nname: custom-skill\n---\nUser text: \u76f4\u63a5\u505a\n' > "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"
printf -- '---\nname: external-normalizer-trap\n---\nUser text: \u76f4\u63a5\u505a\n' > \
  "$TEST_HOME/.agents/skills/external-normalizer-trap/SKILL.md"
mkdir -p "$TEST_HOME/.codex/skills/docx" "$TEST_HOME/.codex/skills/pdf"
[ -f "$TEST_HOME/.codex/skills/docx/SKILL.md" ] || \
  printf -- '---\nname: docx\n---\nUser text: \u76f4\u63a5\u505a\n' > "$TEST_HOME/.codex/skills/docx/SKILL.md"
[ -f "$TEST_HOME/.codex/skills/pdf/SKILL.md" ] || \
  printf -- '---\nname: pdf\n---\nUser text: \u76f4\u63a5\u505a\n' > "$TEST_HOME/.codex/skills/pdf/SKILL.md"
custom_skill_checksum="$(cksum "$TEST_HOME/.codex/skills/custom-skill/SKILL.md")"
external_skill_checksum="$(cksum "$TEST_HOME/.agents/skills/external-normalizer-trap/SKILL.md")"
docx_checksum="$(cksum "$TEST_HOME/.codex/skills/docx/SKILL.md")"
pdf_checksum="$(cksum "$TEST_HOME/.codex/skills/pdf/SKILL.md")"

# A second install must not re-append AGENTS.md sections, re-insert hooks = true,
# or move hooks.json: snapshot the three managed files and diff them after.
mkdir -p "$TMP_ROOT/idempotency-before"
cp "$TEST_HOME/.codex/hooks.json" "$TMP_ROOT/idempotency-before/hooks.json"
cp "$TEST_HOME/.codex/config.toml" "$TMP_ROOT/idempotency-before/config.toml"
cp "$TEST_HOME/.codex/AGENTS.md" "$TMP_ROOT/idempotency-before/AGENTS.md"

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/reinstall.out"

diff -u "$TMP_ROOT/idempotency-before/hooks.json" "$TEST_HOME/.codex/hooks.json"
diff -u "$TMP_ROOT/idempotency-before/config.toml" "$TEST_HOME/.codex/config.toml"
diff -u "$TMP_ROOT/idempotency-before/AGENTS.md" "$TEST_HOME/.codex/AGENTS.md"
test "$(cksum "$TEST_HOME/.codex/skills/custom-skill/SKILL.md")" = "$custom_skill_checksum"
test "$(cksum "$TEST_HOME/.agents/skills/external-normalizer-trap/SKILL.md")" = "$external_skill_checksum"
test "$(cksum "$TEST_HOME/.codex/skills/docx/SKILL.md")" = "$docx_checksum"
test "$(cksum "$TEST_HOME/.codex/skills/pdf/SKILL.md")" = "$pdf_checksum"
test ! -f "$TEST_HOME/.codex/hooks/hooks.json"

# The config.toml diff above already proves the MCP tables were not re-appended;
# assert the count directly too, since a duplicate table is the failure mode that
# would make Codex reject the whole file.
test "$(grep -c '^\[mcp_servers\.serena\]' "$TEST_HOME/.codex/config.toml")" = "1"
test "$(grep -c '^\[mcp_servers\.headroom\]' "$TEST_HOME/.codex/config.toml")" = "1"
assert_toml_parses "$TEST_HOME/.codex/config.toml"
test "$(grep -c '^serena-agent v1.7.0$' "$UV_STATE")" = "1"
test "$(grep -c '^headroom-ai v0.37.0$' "$UV_STATE")" = "1"
test -f "$TEST_HOME/.codex/skills/archify/SKILL.md"

test -f "$TEST_HOME/.codex/agents/custom-user-agent.toml"
test -f "$TEST_HOME/.codex/agent-packs/custom/custom-pack-agent.toml"
test -f "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"
test -d "$custom_gstack_review"
test ! -L "$custom_gstack_review"
test -f "$custom_gstack_review/SKILL.md"
test "$(cat "$custom_gstack_review/user-notes.md")" = "keep this user note"
! grep -qx 'skills/gstack-review' "$TEST_HOME/.codex/.my-codex-manifest.txt"
test "$(cat "$TEST_HOME/.codex/.my-codex-version")" = "$expected_version"

# ── Optional skill lane (--skills=web) ──
# The 18 web/UI skills are the context diet's payload: off by default, added on
# request, persisted so the flag is needed once, and removed again through the
# manifest when the lane is turned off. A skill the user created themselves is
# unmanaged and must survive every one of those transitions.
mkdir -p "$TEST_HOME/.codex/skills/unmanaged-web-note"
printf -- '---\nname: unmanaged-web-note\n---\n' > "$TEST_HOME/.codex/skills/unmanaged-web-note/SKILL.md"
skills_default_count=$(find "$TEST_HOME/.codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')

HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" --skills=web > "$TMP_ROOT/install-skills-web.out"
test -f "$TEST_HOME/.codex/skills/react-patterns/SKILL.md"
test -f "$TEST_HOME/.codex/skills/vue-patterns/SKILL.md"
test -f "$TEST_HOME/.codex/skills/accessibility/SKILL.md"
grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"
skills_web_count=$(find "$TEST_HOME/.codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')
test "$skills_web_count" -gt "$skills_default_count"
react_skill_path="$TEST_HOME/.codex/skills/react-patterns/SKILL.md"
awk -v wanted="$react_skill_path" '
  /^\[\[skills\.config\]\]$/ { in_entry=1; path=""; enabled=""; next }
  in_entry && /^path = / { path=$0; gsub(/^path = "|"$/, "", path) }
  in_entry && /^enabled = / { enabled=$3; if (path == wanted && enabled == "true") found=1; in_entry=0 }
  END { exit(found ? 0 : 1) }
' "$TEST_HOME/.codex/config.toml"

# The lane persists: a plain re-run keeps it without repeating the flag.
HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-skills-persist.out"
test -f "$TEST_HOME/.codex/skills/react-patterns/SKILL.md"
grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"

# Turning a lane off preserves its physical payload for fast re-enable and
# disables each SKILL.md through path-scoped skills.config entries.
HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" --skills=none > "$TMP_ROOT/install-skills-none.out"
test -f "$TEST_HOME/.codex/skills/react-patterns/SKILL.md"
test -f "$TEST_HOME/.codex/skills/vue-patterns/SKILL.md"
test -f "$TEST_HOME/.codex/skills/accessibility/SKILL.md"
awk -v wanted="$react_skill_path" '
  /^\[\[skills\.config\]\]$/ { in_entry=1; path=""; enabled=""; next }
  in_entry && /^path = / { path=$0; gsub(/^path = "|"$/, "", path) }
  in_entry && /^enabled = / { enabled=$3; if (path == wanted && enabled == "false") found=1; in_entry=0 }
  END { exit(found ? 0 : 1) }
' "$TEST_HOME/.codex/config.toml"
! grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"
test -f "$TEST_HOME/.codex/skills/unmanaged-web-note/SKILL.md"
test -f "$TEST_HOME/.codex/skills/custom-skill/SKILL.md"
test "$(find "$TEST_HOME/.codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')" = "$skills_web_count"
node -e 'const s=require(process.argv[1]);if(s.enabledLanes.length)process.exit(1)' \
  "$TEST_HOME/.codex/my-codex/skill-catalog-state.json"

# The environment compatibility path uses the same explicit-none semantics and
# must not be mistaken for an unspecified default selection.
HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  MY_CODEX_SKILLS=web bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-skills-env-web.out"
grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"
HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  MY_CODEX_SKILLS=none bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-skills-env-none.out"
! grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"
node -e 'const s=require(process.argv[1]);if(s.enabledLanes.length)process.exit(1)' \
  "$TEST_HOME/.codex/my-codex/skill-catalog-state.json"
test -f "$TEST_HOME/.codex/skills/react-patterns/SKILL.md"
awk -v wanted="$react_skill_path" '
  /^\[\[skills\.config\]\]$/ { in_entry=1; path=""; enabled=""; next }
  in_entry && /^path = / { path=$0; gsub(/^path = "|"$/, "", path) }
  in_entry && /^enabled = / { enabled=$3; if (path == wanted && enabled == "false") found=1; in_entry=0 }
  END { exit(found ? 0 : 1) }
' "$TEST_HOME/.codex/config.toml"

# An unknown lane fails loudly instead of silently installing nothing. Assert
# the reason, not just the exit code: a bare non-zero check would also pass if
# the installer died for some unrelated reason.
if HOME="$TEST_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" \
     bash "$REPO_ROOT/install.sh" --skills=nope > "$TMP_ROOT/install-skills-bad.out" 2>&1; then
  echo "FAIL: --skills=nope should have exited non-zero" >&2
  exit 1
fi
grep -q 'unknown skill lane: nope' "$TMP_ROOT/install-skills-bad.out"
# ...and it rejects before touching anything: the persisted set stays empty.
! grep -q '^web$' "$TEST_HOME/.codex/enabled-skill-lanes.txt"
test -f "$TEST_HOME/.codex/skills/react-patterns/SKILL.md"

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
decision_auto="$PROJECT_ROOT/.briefing/decisions/$today-auto.md"
session_topic_count="$(find "$PROJECT_ROOT/.briefing/sessions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
learning_topic_count="$(find "$PROJECT_ROOT/.briefing/learnings" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto-session.md" | wc -l | tr -d ' ')"
decision_topic_count="$(find "$PROJECT_ROOT/.briefing/decisions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
signal_summary="$PROJECT_ROOT/.briefing/agents/$today-summary.md"
profile_md="$PROJECT_ROOT/.briefing/persona/profile.md"
test -f "$PROJECT_ROOT/.briefing/INDEX.md"
test -f "$PROJECT_ROOT/.briefing/state.json"
test -f "$PROJECT_ROOT/.briefing/persona/persona-policy.json"
test -f "$profile_md"
test -f "$PROJECT_ROOT/.briefing/agents/agent-log.jsonl"
test -f "$signal_summary"
test -f "$session_auto"
test -f "$learning_auto"
test -f "$decision_auto"
grep -q 'tracked.txt' "$session_auto"
grep -q 'tracked.txt' "$learning_auto"
grep -q 'tracked.txt' "$decision_auto"
grep -q '## Work Completed' "$session_auto"
grep -q '## References Consulted' "$session_auto"
grep -q '## What Seems Reusable' "$learning_auto"
grep -q '## Candidate Decisions' "$decision_auto"
test "$session_topic_count" -ge 1
test "$learning_topic_count" = "0"
test "$decision_topic_count" = "0"
! grep -q '\.gitignore' "$session_auto"
! grep -q '\.gitignore' "$learning_auto"
test ! -e "$PROJECT_ROOT/.briefing/.session-start-head"
test ! -e "$PROJECT_ROOT/.briefing/.session-start-status"
test ! -e "$PROJECT_ROOT/.briefing/.session-message-count"
grep -q 'Only wrapper/session-level signals have been observed so far.' "$profile_md"
grep -q '## Current Session Snapshot' "$profile_md"
grep -q '## Recent Prompt Themes' "$profile_md"
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
  printf '{"tool_input":{"url":"https://example.com/docs","query":"BriefingVault docs"},"prompt":"Check the vault docs"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" search > "$TMP_ROOT/hook-search.out"
  printf '{"prompt":"Improve BriefingVault content quality"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-1.out"
  printf '{"prompt":"Capture the routing policy decision"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-2.out"
  printf '{"prompt":"List missing follow-ups"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-3.out"
  printf '{"prompt":"Capture reusable patterns"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-4.out"
  printf '{"prompt":"Finalize the vault note"}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-sync.js" prompt > "$TMP_ROOT/hook-prompt-5.out"
  printf '{}' | HOME="$TEST_HOME" node "$TEST_HOME/.codex/hooks/session-end.js" > "$TMP_ROOT/hook-session-end.out"
)

hook_session_auto="$HOOK_PROJECT/.briefing/sessions/$today-auto.md"
hook_learning_auto="$HOOK_PROJECT/.briefing/learnings/$today-auto-session.md"
hook_decision_auto="$HOOK_PROJECT/.briefing/decisions/$today-auto.md"
hook_session_topic_count="$(find "$HOOK_PROJECT/.briefing/sessions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
hook_learning_topic_count="$(find "$HOOK_PROJECT/.briefing/learnings" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto-session.md" | wc -l | tr -d ' ')"
hook_decision_topic_count="$(find "$HOOK_PROJECT/.briefing/decisions" -maxdepth 1 -type f -name "$today-*.md" ! -name "$today-auto.md" | wc -l | tr -d ' ')"
hook_profile_md="$HOOK_PROJECT/.briefing/persona/profile.md"
hook_links_md="$HOOK_PROJECT/.briefing/references/auto-links.md"
test -f "$hook_session_auto"
test -f "$hook_learning_auto"
test -f "$hook_decision_auto"
test -f "$hook_profile_md"
test -f "$hook_links_md"
test -f "$HOOK_PROJECT/.briefing/state.json"
test -f "$HOOK_PROJECT/.briefing/persona/persona-policy.json"
grep -q 'tracked.txt' "$hook_session_auto"
grep -q 'tracked.txt' "$hook_learning_auto"
grep -q 'tracked.txt' "$hook_decision_auto"
grep -q 'Improve BriefingVault content quality' "$hook_session_auto"
grep -q 'Latest user intent: Finalize the vault note' "$hook_learning_auto"
grep -q 'Candidate Decisions' "$hook_decision_auto"
test "$hook_session_topic_count" -ge 1
test "$hook_learning_topic_count" -ge 1
test "$hook_decision_topic_count" -ge 1
grep -q 'https://example.com/docs -- Check the vault docs' "$hook_links_md"
grep -q 'BriefingVault' "$TMP_ROOT/hook-prompt-3.out"
grep -q '## Current Session Snapshot' "$hook_profile_md"
grep -q 'Only wrapper/session-level signals have been observed so far.\|Insufficient signal.' "$hook_profile_md"

# Upgrade path: a config.toml that already has [features] (so the fresh-config
# heredoc is skipped) and a trailing [mcp_servers.*] table. hooks = true has to land
# under [features], not at EOF where it would belong to the mcp_servers table.
# The header carries a trailing comment, which is legal TOML. A tighter regex
# misses it, takes the "no [features] table" branch, and appends a second one --
# tomllib then refuses the file with "Cannot declare ('features',) twice".
LEGACY_HOME="$TMP_ROOT/legacy-home"
mkdir -p "$LEGACY_HOME/.codex" "$LEGACY_HOME/.agents/skills" "$LEGACY_HOME/.claude/skills"
printf 'pre-catalog-install\n' > "$LEGACY_HOME/.codex/.my-codex-version"
cat > "$LEGACY_HOME/.codex/config.toml" << 'LEGACY_TOML'
[features]  # my flags
multi_agent = true
child_agents_md = true

[agents]
max_threads = 8

[mcp_servers.context7]
command = "npx"
LEGACY_TOML
mkdir -p "$LEGACY_HOME/.codex/hooks"
printf '{}' > "$LEGACY_HOME/.codex/hooks/hooks.json"
# Exact pre-marker Default/Boss sections exercise the conservative migration
# branch; unrelated user content must remain byte-for-byte around them.
cat > "$LEGACY_HOME/.codex/AGENTS.md" <<'LEGACY_AGENTS'
# Legacy AGENTS

## Default Agent

When starting a new session, always use the **boss** agent as the primary orchestrator.
Boss discovers available agents, classifies user intent, and delegates to the best specialist.
Do not bypass Boss for direct implementation unless the user explicitly requests a specific agent.

## Boss-First Routing (Default Behavior)

Before executing any task, first scan `~/.codex/agents/*.toml` to discover active specialists and `~/.codex/agent-packs/*/*.toml` to discover installed-but-inactive specialists. For any non-trivial request (multi-file changes, architecture decisions, debugging, refactoring, code review, or unfamiliar domains), route through the Boss meta-orchestrator:

```
spawn_agent(prompt="<user's full request>", agent_type="boss")
```

Boss will classify intent, match the task to the optimal specialist from the discovered registry, delegate with structured prompts, and verify results independently. Only handle trivial single-command tasks (ls, git status, simple questions) directly. If the best specialist is installed only in an inactive pack, activate the smallest matching pack with `~/.codex/bin/my-codex-packs enable <pack>` before delegating.

## Something
text
LEGACY_AGENTS

HOME="$LEGACY_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-legacy.out"
test ! -e "$LEGACY_HOME/.codex/my-codex/skill-catalog-state.json"
grep -q 'Existing noninteractive install: preserving current skill exposure' "$TMP_ROOT/install-legacy.out"

assert_features_hooks_enabled "$LEGACY_HOME/.codex/config.toml"
test "$(awk 'f && /^\[/ { exit } /^[[:space:]]*\[[[:space:]]*features[[:space:]]*\][[:space:]]*(#.*)?$/ { f = 1 } f' "$LEGACY_HOME/.codex/config.toml" | grep -c '^hooks = true$')" = "1"
test "$(grep -cE '^[[:space:]]*\[[[:space:]]*features[[:space:]]*\][[:space:]]*(#.*)?$' "$LEGACY_HOME/.codex/config.toml")" = "1"
python3 -c "import sys,tomllib; tomllib.load(open(sys.argv[1],'rb'))" "$LEGACY_HOME/.codex/config.toml"
grep -q '^command = "npx"$' "$LEGACY_HOME/.codex/config.toml"
# The pre-existing trailing [mcp_servers.context7] table must stay intact. The
# installer appends the serena and headroom tables after it, which is legal, but
# a bare KEY appended at EOF would silently join context7 -- so the first
# non-blank line after `command = "npx"` has to be a table header or nothing.
line_after_context7="$(awk '/^command = "npx"$/ { found = 1; next } found && NF { print; exit }' "$LEGACY_HOME/.codex/config.toml")"
case "${line_after_context7:-[}" in
  '['*) ;;
  *) echo "FAIL: bare key appended after the context7 table: $line_after_context7" >&2; exit 1 ;;
esac
test -f "$LEGACY_HOME/.codex/hooks.json"
test ! -f "$LEGACY_HOME/.codex/hooks/hooks.json"
test "$(grep -c '<!-- my-codex:calibrated-response -->' "$LEGACY_HOME/.codex/AGENTS.md")" = "1"
test "$(grep -c '<!-- my-codex:default-agent -->' "$LEGACY_HOME/.codex/AGENTS.md")" = "1"
test "$(grep -c '<!-- my-codex:boss-first -->' "$LEGACY_HOME/.codex/AGENTS.md")" = "1"
test "$(grep -c '<!-- my-codex:final-report -->' "$LEGACY_HOME/.codex/AGENTS.md")" = "1"
grep -q '^## Something$' "$LEGACY_HOME/.codex/AGENTS.md"

cp "$LEGACY_HOME/.codex/config.toml" "$TMP_ROOT/legacy-config-before.toml"
# A user section with the same heading before the marked managed section must
# survive refresh; replacement is anchored by the marker, not the first heading.
{
  printf '## Default Agent\n\nUser-custom routing stays here.\n\n'
  cat "$LEGACY_HOME/.codex/AGENTS.md"
} > "$LEGACY_HOME/.codex/AGENTS.md.tmp"
mv "$LEGACY_HOME/.codex/AGENTS.md.tmp" "$LEGACY_HOME/.codex/AGENTS.md"
cp "$LEGACY_HOME/.codex/AGENTS.md" "$TMP_ROOT/legacy-agents-before.md"
HOME="$LEGACY_HOME" PATH="$BIN_DIR:$PATH" MY_CODEX_TEST_LOG="$LOG_FILE" MY_CODEX_TEST_UV_STATE="$UV_STATE" \
  bash "$REPO_ROOT/install.sh" > "$TMP_ROOT/install-legacy-2.out"
diff -u "$TMP_ROOT/legacy-config-before.toml" "$LEGACY_HOME/.codex/config.toml"
diff -u "$TMP_ROOT/legacy-agents-before.md" "$LEGACY_HOME/.codex/AGENTS.md"

# Daily self-heal: merge-hooks.js must refresh the hook scripts without restoring
# the stale hooks/hooks.json that Codex never reads.
printf '{"stale":true}' > "$LEGACY_HOME/.codex/hooks/hooks.json"
HOME="$LEGACY_HOME" node "$REPO_ROOT/scripts/merge-hooks.js" > "$TMP_ROOT/merge-hooks.out"
test -f "$LEGACY_HOME/.codex/hooks.json"
test ! -f "$LEGACY_HOME/.codex/hooks/hooks.json"
diff -u "$REPO_ROOT/hooks/hooks.json" "$LEGACY_HOME/.codex/hooks.json"

echo "Install smoke test passed"
