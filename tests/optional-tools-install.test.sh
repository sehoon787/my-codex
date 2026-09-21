#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/my-codex-optional-tools.XXXXXX")"
REAL_NODE="$(command -v node)"

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

make_case() {
  local name="$1" root bin
  root="$TEST_ROOT/$name"
  bin="$root/bin"
  mkdir -p "$root/home/.agents/skills" "$root/home/.claude/skills" "$bin"
  ln -s "$REAL_NODE" "$bin/node"

  cat > "$bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'codex %s\n' "$*" >> "${OPTIONAL_TOOLS_LOG:?}"
case "${1:-}" in
  --version) echo 'codex-test' ;;
  mcp) [ "${2:-}" = list ] && exit 0 ;;
esac
EOF
  cat > "$bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >> "${OPTIONAL_TOOLS_LOG:?}"
EOF
  cat > "$bin/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uv %s\n' "$*" >> "${OPTIONAL_TOOLS_LOG:?}"
case "$*" in
  '--version') echo 'uv 0-test' ;;
  'tool list') : ;;
esac
EOF
  cat > "$bin/curl" <<'EOF'
#!/usr/bin/env bash
echo 'FAIL: installer attempted network access' >&2
exit 97
EOF
  chmod +x "$bin/codex" "$bin/npm" "$bin/uv" "$bin/curl"
  : > "$root/calls.log"
}

install_args=(
  --skip-ecc
  --skip-omx
  --skip-gstack
  --skip-superpowers
)

run_plain() {
  local name="$1"
  shift
  make_case "$name"
  local root="$TEST_ROOT/$name"
  env -u CI HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@" \
    < /dev/null > "$root/output" 2>&1
}

run_tty() {
  local name="$1" answers="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  env -u CI HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, os, pty, select, sys
output, answers_text, *command = sys.argv[1:]
answers = answers_text.split("|")
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
data = bytearray()
sent = 0
while True:
    ready, _, _ = select.select([fd], [], [], 30)
    if not ready:
        os.kill(pid, 9)
        raise SystemExit("timed out waiting for installer")
    try:
        chunk = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    data.extend(chunk)
    prompts = data.count(b"Select: all / none / numbers like 1,3 [all]:")
    while sent < prompts and sent < len(answers):
        answer = answers[sent]
        os.write(fd, b"\x04" if answer == "<EOF>" else (answer + "\n").encode())
        sent += 1
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
if not sent:
    raise SystemExit("installer did not prompt")
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" "$answers" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

run_tty_no_prompt() {
  local name="$1" ci_mode="$2"
  shift 2
  make_case "$name"
  local root="$TEST_ROOT/$name"
  local -a env_prefix=(env -u CI)
  if [ "$ci_mode" = present ]; then
    env_prefix=(env CI=1)
  fi
  "${env_prefix[@]}" HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    python3 -c '
import errno, os, pty, select, sys
output, *command = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
data = bytearray()
while True:
    ready, _, _ = select.select([fd], [], [], 30)
    if not ready:
        os.kill(pid, 9)
        raise SystemExit("timed out waiting for installer")
    try:
        chunk = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    data.extend(chunk)
    if b"Select: all / none / numbers like 1,3 [all]:" in data:
        os.kill(pid, 9)
        raise SystemExit("installer prompted despite automation flag")
_, status = os.waitpid(pid, 0)
with open(output, "wb") as handle:
    handle.write(data.replace(b"\r", b""))
raise SystemExit(os.waitstatus_to_exitcode(status))
' "$root/output" bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@"
}

run_script_pipe() {
  local name="$1" answer="$2"
  shift 2
  if [ "$(uname -s)" != "Darwin" ]; then
    run_tty "$name" "$answer" "$@"
    return
  fi
  make_case "$name"
  local root="$TEST_ROOT/$name"
  # Keep the producer open after writing the selection. On macOS, closing the
  # pipe immediately can deliver EOF through script(1) before Bash reads it.
  { printf '%s\n' "$answer"; sleep 2; } | \
    env -u CI HOME="$root/home" PATH="$root/bin:/usr/bin:/bin" \
      OPTIONAL_TOOLS_LOG="$root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
      script -q /dev/null bash "$REPO_ROOT/install.sh" "${install_args[@]}" "$@" \
      > "$root/output" 2>&1
  tr -d '\r' < "$root/output" > "$root/output.clean"
  mv "$root/output.clean" "$root/output"
}

assert_common_install() {
  local root="$TEST_ROOT/$1"
  test -f "$root/home/.codex/AGENTS.md"
  test -f "$root/home/.codex/agents/boss.toml"
  test -f "$root/home/.codex/skills/archify/SKILL.md"
  test -f "$root/home/.codex/hooks.json"
  test ! -e "$root/home/.codex/auth.json"
}

has_selection() {
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}

assert_tools_selection() {
  local name="$1" selected="$2" root="$TEST_ROOT/$1" tool summary='Optional tools:'
  for tool in serena headroom codeburn; do
    if has_selection "$selected" "$tool"; then
      summary="$summary ${tool}=install"
      case "$tool" in
        serena)
          grep -q 'uv tool install --python 3.13 serena-agent==1.7.0' "$root/calls.log"
          grep -q '^\[mcp_servers\.serena\]' "$root/home/.codex/config.toml"
          grep -q 'localhost:24282/dashboard/index.html' "$root/output"
          ;;
        headroom)
          grep -q 'uv tool install --python 3.13 headroom-ai\[all\]==0.37.0' "$root/calls.log"
          grep -q '^\[mcp_servers\.headroom\]' "$root/home/.codex/config.toml"
          grep -q '127.0.0.1:8787/stats' "$root/output"
          ;;
        codeburn)
          grep -q 'npm i -g codeburn@0.9.23' "$root/calls.log"
          grep -q '127.0.0.1:4747/' "$root/output"
          ;;
      esac
      ! grep -q "^  ${tool}:.*SKIPPED" "$root/output"
    else
      summary="$summary ${tool}=skip"
      case "$tool" in
        serena)
          ! grep -q 'serena-agent==1.7.0' "$root/calls.log"
          ! grep -q '^\[mcp_servers\.serena\]' "$root/home/.codex/config.toml"
          ! grep -q 'localhost:24282/dashboard/index.html' "$root/output"
          ;;
        headroom)
          ! grep -q 'headroom-ai' "$root/calls.log"
          ! grep -q '^\[mcp_servers\.headroom\]' "$root/home/.codex/config.toml"
          ! grep -q '127.0.0.1:8787/stats' "$root/output"
          ;;
        codeburn)
          ! grep -q 'codeburn@0.9.23' "$root/calls.log"
          ! grep -q '127.0.0.1:4747/' "$root/output"
          ;;
      esac
      grep -q "^  ${tool}:.*SKIPPED (not selected)$" "$root/output"
    fi
  done
  # The installer prints this before any install phase. Normalize the spaces
  # added while building the expected literal into the documented CSV shape.
  summary="$(printf '%s' "$summary" | sed 's/ serena=/ serena=/; s/ headroom=/, headroom=/; s/ codeburn=/, codeburn=/')"
  grep -Fq "$summary" "$root/output"
  assert_common_install "$name"
}

run_tty interactive_enter ''
assert_tools_selection interactive_enter serena,headroom,codeburn

run_tty interactive_all all
assert_tools_selection interactive_all serena,headroom,codeburn

run_tty interactive_yes yes
assert_tools_selection interactive_yes serena,headroom,codeburn

run_tty interactive_none none
assert_tools_selection interactive_none ''

run_tty interactive_no n
assert_tools_selection interactive_no ''

run_script_pipe headroom_only 2
assert_tools_selection headroom_only headroom

run_tty serena_only 1
assert_tools_selection serena_only serena

run_tty codeburn_only 3
assert_tools_selection codeburn_only codeburn
! grep -q '^uv ' "$TEST_ROOT/codeburn_only/calls.log"

run_tty serena_codeburn '1,3'
assert_tools_selection serena_codeburn serena,codeburn

run_tty names 'headroom codeburn'
assert_tools_selection names headroom,codeburn

run_tty invalid_retry 'bogus|2'
assert_tools_selection invalid_retry headroom
grep -q '^Invalid selection. Choose all, none, or any of: 1,2,3,serena,headroom,codeburn.$' "$TEST_ROOT/invalid_retry/output"

run_tty invalid_fallback 'bogus|bad|still-bad'
assert_tools_selection invalid_fallback serena,headroom,codeburn
grep -q '^Too many invalid selections; using all optional tools.$' "$TEST_ROOT/invalid_fallback/output"

run_tty interactive_eof '<EOF>'
assert_tools_selection interactive_eof serena,headroom,codeburn

run_plain non_tty_default
assert_tools_selection non_tty_default serena,headroom,codeburn
! grep -q 'Select: all / none' "$TEST_ROOT/non_tty_default/output"

run_tty_no_prompt assume_yes unset --yes
assert_tools_selection assume_yes serena,headroom,codeburn

run_tty_no_prompt flag_headroom unset --tools=headroom
assert_tools_selection flag_headroom headroom

run_tty_no_prompt flag_mix unset --tools=1,3
assert_tools_selection flag_mix serena,codeburn

make_case flag_bogus
if env -u CI HOME="$TEST_ROOT/flag_bogus/home" PATH="$TEST_ROOT/flag_bogus/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/flag_bogus/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" --tools=bogus \
    </dev/null > "$TEST_ROOT/flag_bogus/output" 2>&1; then
  echo 'FAIL: invalid --tools selection succeeded' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: bogus$' "$TEST_ROOT/flag_bogus/output"

make_case flag_glob
if env -u CI HOME="$TEST_ROOT/flag_glob/home" PATH="$TEST_ROOT/flag_glob/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/flag_glob/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" '--tools=*' \
    </dev/null > "$TEST_ROOT/flag_glob/output" 2>&1; then
  echo 'FAIL: glob-like --tools selection succeeded' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: \*$' "$TEST_ROOT/flag_glob/output"

make_case flag_multiline
if env -u CI HOME="$TEST_ROOT/flag_multiline/home" PATH="$TEST_ROOT/flag_multiline/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/flag_multiline/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" $'--tools=serena\nbogus' \
    </dev/null > "$TEST_ROOT/flag_multiline/output" 2>&1; then
  echo 'FAIL: multiline --tools selection ignored an invalid token' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: serena$' "$TEST_ROOT/flag_multiline/output"
grep -q '^bogus$' "$TEST_ROOT/flag_multiline/output"

make_case invalid_skip_mix
if env -u CI HOME="$TEST_ROOT/invalid_skip_mix/home" PATH="$TEST_ROOT/invalid_skip_mix/bin:/usr/bin:/bin" \
    OPTIONAL_TOOLS_LOG="$TEST_ROOT/invalid_skip_mix/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
    bash "$REPO_ROOT/install.sh" "${install_args[@]}" --skip-tools --tools=bogus \
    </dev/null > "$TEST_ROOT/invalid_skip_mix/output" 2>&1; then
  echo 'FAIL: --skip-tools concealed an invalid --tools selection' >&2
  exit 1
fi
grep -q '^ERROR: invalid --tools selection: bogus$' "$TEST_ROOT/invalid_skip_mix/output"

run_plain skip_wins --tools=headroom --yes --skip-tools
assert_tools_selection skip_wins ''

# Declining optional tools does not delete MCP tables that the user already
# owns; it only suppresses this installer's managed writes.
cat >> "$TEST_ROOT/skip_wins/home/.codex/config.toml" <<'EOF'

[mcp_servers.serena]
command = "custom-serena"

[mcp_servers.headroom]
command = "custom-headroom"
EOF
run_root="$TEST_ROOT/skip_wins"
HOME="$run_root/home" PATH="$run_root/bin:/usr/bin:/bin" \
  OPTIONAL_TOOLS_LOG="$run_root/calls.log" AGENT_HARNESS_SERVICES_SKIP=1 \
  bash "$REPO_ROOT/install.sh" "${install_args[@]}" --skip-tools \
  < /dev/null > "$run_root/reinstall-output" 2>&1
grep -q '^command = "custom-serena"$' "$run_root/home/.codex/config.toml"
grep -q '^command = "custom-headroom"$' "$run_root/home/.codex/config.toml"

run_tty_no_prompt ci_present present
assert_tools_selection ci_present serena,headroom,codeburn
! grep -q 'Select: all / none' "$TEST_ROOT/ci_present/output"

echo "Optional tools installer test passed"
