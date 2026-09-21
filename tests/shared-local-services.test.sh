#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SHIM="$TMP/shim"
mkdir -p "$SHIM"

cat > "$SHIM/curl" <<'EOF'
#!/usr/bin/env bash
url="${*: -1}"
state="${SHIM_STATE:?}"
case "$url" in
  http://127.0.0.1:4747/)
    if [ -f "$state/codeburn-transient" ]; then
      if [ ! -f "$state/codeburn-transient-seen" ]; then
        touch "$state/codeburn-transient-seen"
        exit 7
      fi
      printf '<html><title>CodeBurn - Local Dashboard</title></html>'
      exit 0
    fi
    if [ -f "$state/codeburn-healthy" ]; then
      printf '<html><title>CodeBurn - Local Dashboard</title></html>'
      exit 0
    fi
    if [ -f "$state/codeburn-foreign" ]; then
      printf '<html><title>Another service</title></html>'
      exit 0
    fi
    ;;
  http://127.0.0.1:8787/livez)
    if [ -f "$state/headroom-healthy" ]; then
      printf '{"service":"headroom-proxy","status":"healthy","alive":true}'
      exit 0
    fi
    if [ -f "$state/headroom-alive-false" ]; then
      printf '{"service":"headroom-proxy","status":"healthy","alive":false}'
      exit 0
    fi
    if [ -f "$state/headroom-foreign" ]; then
      printf '{"service":"another-service","status":"healthy"}'
      exit 0
    fi
    ;;
esac
exit 7
EOF

cat > "$SHIM/codeburn" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SHIM_STATE:?}/codeburn-calls"
printf '%s\n' "$$" > "$SHIM_STATE/codeburn-shim.pid"
printf '%s\n' "$PPID" > "$SHIM_STATE/codeburn-parent.pid"
case "${CODEBURN_SHIM_MODE:-success}" in
  success)
    touch "$SHIM_STATE/codeburn-healthy"
    trap 'rm -f "$SHIM_STATE/codeburn-healthy"; exit 0' TERM INT EXIT
    while :; do sleep 0.1; done
    ;;
  failure)
    trap 'exit 0' TERM INT
    while :; do sleep 0.1; done
    ;;
  *) exit 1 ;;
esac
EOF

cat > "$SHIM/lsof" <<'EOF'
#!/usr/bin/env bash
state="${SHIM_STATE:?}"
case "$*" in
  *-iTCP:4747*) [ -f "$state/codeburn-listener" ] ;;
  *-iTCP:8787*) [ -f "$state/headroom-listener" ] ;;
  *) exit 1 ;;
esac
EOF

cat > "$SHIM/headroom" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SHIM_STATE:?}/headroom-calls"
env | grep -E '^(ANTHROPIC_TARGET_API_URL|ANTHROPIC_FOUNDRY_BASE_URL|OPENAI_TARGET_API_URL|GEMINI_TARGET_API_URL|CLOUDCODE_TARGET_API_URL|VERTEX_TARGET_API_URL|BEDROCK_TARGET_API_URL)=' \
  > "${SHIM_STATE:?}/headroom-inherited-targets" || true
if [ "${1:-}" = "install" ]; then
  case "${HEADROOM_SHIM_MODE:-native}" in
    native) touch "$SHIM_STATE/headroom-healthy"; exit 0 ;;
    failure) exit 1 ;;
  esac
fi
exit 1
EOF
chmod +x "$SHIM/curl" "$SHIM/codeburn" "$SHIM/headroom" "$SHIM/lsof"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  _file="$1"
  _text="$2"
  grep -Fq -- "$_text" "$_file" || fail "missing '$_text' in $_file"
}

assert_not_contains() {
  _file="$1"
  _text="$2"
  ! grep -Fq -- "$_text" "$_file" || fail "unexpected '$_text' in $_file"
}

run_helper() {
  _case="$1"
  shift
  _root="$TMP/$_case"
  mkdir -p "$_root/state"
  env PATH="$SHIM:$PATH" SHIM_STATE="$_root/state" \
    AGENT_HARNESS_STATE_DIR="$_root/shared" \
    AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS=1 \
    "$@" bash "$REPO/scripts/ensure-shared-local-services.sh" > "$_root/output" 2>&1
}

run_selected_helper() {
  _case="$1"
  _service="$2"
  _root="$TMP/$_case"
  mkdir -p "$_root/state"
  env PATH="$SHIM:$PATH" SHIM_STATE="$_root/state" \
    AGENT_HARNESS_STATE_DIR="$_root/shared" \
    AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS=1 \
    CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native \
    bash "$REPO/scripts/ensure-shared-local-services.sh" "$_service" > "$_root/output" 2>&1
}

cleanup_pid() {
  _file="$1"
  if [ -f "$_file" ]; then
    _pid=$(cat "$_file")
    kill "$_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$_pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$_pid" 2>/dev/null || true
  fi
}

# First installer starts one shared codeburn process and a mutation-free native
# Headroom profile. Its command line is the cross-harness compatibility contract.
run_helper start env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native \
  ANTHROPIC_TARGET_API_URL=https://user:secret@anthropic.example \
  ANTHROPIC_FOUNDRY_BASE_URL=https://user:secret@foundry.example \
  OPENAI_TARGET_API_URL=https://user:secret@openai.example \
  GEMINI_TARGET_API_URL=https://user:secret@gemini.example \
  CLOUDCODE_TARGET_API_URL=https://user:secret@cloudcode.example \
  VERTEX_TARGET_API_URL=https://user:secret@vertex.example \
  BEDROCK_TARGET_API_URL=https://user:secret@bedrock.example
assert_contains "$TMP/start/output" "codeburn web: STARTED"
assert_contains "$TMP/start/output" "Headroom proxy: STARTED"
assert_contains "$TMP/start/state/codeburn-calls" "web --provider all --port 4747 --no-open"
assert_contains "$TMP/start/state/headroom-calls" "install apply --profile agent-harness-shared"
assert_contains "$TMP/start/state/headroom-calls" "--providers manual"
assert_contains "$TMP/start/state/headroom-calls" "--no-telemetry"
assert_not_contains "$TMP/start/state/headroom-calls" "--target"
[ ! -s "$TMP/start/state/headroom-inherited-targets" ] || fail "Headroom inherited target URLs"
assert_contains "$TMP/start/output" "http://127.0.0.1:4747/"
assert_contains "$TMP/start/output" "http://127.0.0.1:8787/stats"
cleanup_pid "$TMP/start/shared/codeburn.pid"

# A caller can request either service independently. The selection must survive
# the Python lock supervisor recursion, and unselected services must not be
# probed, started, or advertised.
run_selected_helper codeburn-only codeburn
assert_contains "$TMP/codeburn-only/output" "codeburn web: STARTED"
assert_not_contains "$TMP/codeburn-only/output" "Headroom"
[ ! -e "$TMP/codeburn-only/state/headroom-calls" ] || fail "codeburn-only run started Headroom"
cleanup_pid "$TMP/codeburn-only/shared/codeburn.pid"

run_selected_helper headroom-only headroom
assert_contains "$TMP/headroom-only/output" "Headroom proxy: STARTED"
assert_not_contains "$TMP/headroom-only/output" "codeburn"
[ ! -e "$TMP/headroom-only/state/codeburn-calls" ] || fail "headroom-only run started codeburn"

# A later installer reuses healthy endpoints and never starts duplicates.
mkdir -p "$TMP/reuse/state"
touch "$TMP/reuse/state/codeburn-healthy" "$TMP/reuse/state/headroom-healthy"
run_helper reuse env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/reuse/output" "codeburn web: REUSED"
assert_contains "$TMP/reuse/output" "Headroom proxy: REUSED"
[ ! -e "$TMP/reuse/state/codeburn-calls" ] || fail "reuse started codeburn"
[ ! -e "$TMP/reuse/state/headroom-calls" ] || fail "reuse started Headroom"

# A healthy Codeburn listener can briefly miss the first identity request while
# its dashboard finishes loading. Recheck the exact title before classifying
# the occupied port as foreign; reuse it without spawning another process.
mkdir -p "$TMP/transient-codeburn/state"
touch "$TMP/transient-codeburn/state/codeburn-transient" \
  "$TMP/transient-codeburn/state/codeburn-listener"
run_selected_helper transient-codeburn codeburn
assert_contains "$TMP/transient-codeburn/output" "codeburn web: REUSED"
[ ! -e "$TMP/transient-codeburn/state/codeburn-calls" ] || fail "transient healthy listener started duplicate codeburn"

# A foreign HTTP owner is reported and left alone. The lsof shim models the
# listener independently from the response identity.
mkdir -p "$TMP/foreign/state"
touch "$TMP/foreign/state/codeburn-foreign" "$TMP/foreign/state/headroom-foreign" \
  "$TMP/foreign/state/codeburn-listener" "$TMP/foreign/state/headroom-listener"
run_helper foreign env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/foreign/output" "codeburn web: FAIL (port 4747 belongs to another service; left untouched"
assert_contains "$TMP/foreign/output" "Headroom proxy: FAIL (port 8787 belongs to another service; left untouched"
[ ! -e "$TMP/foreign/state/codeburn-calls" ] || fail "foreign port owner triggered codeburn"
[ ! -e "$TMP/foreign/state/headroom-calls" ] || fail "foreign port owner triggered Headroom"

# Non-HTTP listeners are also detected and never touched.
mkdir -p "$TMP/non-http/state"
touch "$TMP/non-http/state/codeburn-listener" "$TMP/non-http/state/headroom-listener"
run_helper non-http env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/non-http/output" "codeburn web: FAIL (port 4747 belongs to another service; left untouched"
assert_contains "$TMP/non-http/output" "Headroom proxy: FAIL (port 8787 belongs to another service; left untouched"
[ ! -e "$TMP/non-http/state/codeburn-calls" ] || fail "non-HTTP listener triggered codeburn"
[ ! -e "$TMP/non-http/state/headroom-calls" ] || fail "non-HTTP listener triggered Headroom"

# Headroom identity requires all three fields, including alive=true.
mkdir -p "$TMP/unhealthy-headroom/state"
touch "$TMP/unhealthy-headroom/state/codeburn-healthy" \
  "$TMP/unhealthy-headroom/state/headroom-alive-false" \
  "$TMP/unhealthy-headroom/state/headroom-listener"
run_helper unhealthy-headroom env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/unhealthy-headroom/output" "codeburn web: REUSED"
assert_contains "$TMP/unhealthy-headroom/output" "Headroom proxy: FAIL (port 8787 belongs to another service; left untouched"
[ ! -e "$TMP/unhealthy-headroom/state/headroom-calls" ] || fail "alive=false Headroom endpoint was reused"

# A failed codeburn child is cleaned. A failed native Headroom apply is reported
# without launching a direct fallback that could race a late native start.
run_helper failure env CODEBURN_SHIM_MODE=failure HEADROOM_SHIM_MODE=failure
assert_contains "$TMP/failure/output" "codeburn web: FAIL (fixed port 4747 did not become healthy; spawned process cleaned"
assert_contains "$TMP/failure/output" "Headroom proxy: FAIL (native profile agent-harness-shared did not become healthy"
[ ! -e "$TMP/failure/shared/codeburn.pid" ] || fail "failed codeburn PID file was retained"
[ ! -e "$TMP/failure/shared/headroom.pid" ] || fail "failed Headroom PID file was retained"
assert_not_contains "$TMP/failure/state/headroom-calls" "proxy"

# A persistent lock file carries no stale PID state and is immediately reusable.
mkdir -p "$TMP/stale-lock/state" "$TMP/stale-lock/shared"
touch "$TMP/stale-lock/shared/ensure.lock"
run_helper stale-lock env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/stale-lock/output" "codeburn web: STARTED"
assert_contains "$TMP/stale-lock/output" "Headroom proxy: STARTED"
[ -f "$TMP/stale-lock/shared/ensure.lock" ] || fail "kernel lock file was not preserved"
cleanup_pid "$TMP/stale-lock/shared/codeburn.pid"

# The kernel releases the advisory lock if its owner crashes.
mkdir -p "$TMP/crashed-lock/state" "$TMP/crashed-lock/shared"
python3 - "$TMP/crashed-lock/shared/ensure.lock" "$TMP/crashed-lock/locked" <<'PY' &
import fcntl, os, sys, time
fd = os.open(sys.argv[1], os.O_CREAT | os.O_RDWR, 0o600)
fcntl.flock(fd, fcntl.LOCK_EX)
open(sys.argv[2], "w").close()
time.sleep(30)
PY
lock_holder_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$TMP/crashed-lock/locked" ] && break
  sleep 0.1
done
[ -f "$TMP/crashed-lock/locked" ] || fail "crash test did not acquire kernel lock"
kill -KILL "$lock_holder_pid"
wait "$lock_holder_pid" 2>/dev/null || true
run_helper crashed-lock env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/crashed-lock/output" "codeburn web: STARTED"
assert_contains "$TMP/crashed-lock/output" "Headroom proxy: STARTED"
cleanup_pid "$TMP/crashed-lock/shared/codeburn.pid"

# Lock recovery never follows a pre-existing symlink.
mkdir -p "$TMP/unsafe-lock/state" "$TMP/unsafe-lock/shared"
printf 'keep-this-content\n' > "$TMP/unsafe-lock/victim"
ln -s "$TMP/unsafe-lock/victim" "$TMP/unsafe-lock/shared/ensure.lock"
run_helper unsafe-lock env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/unsafe-lock/output" "unsafe or unwritable startup lock"
[ "$(cat "$TMP/unsafe-lock/victim")" = "keep-this-content" ] || fail "symlinked lock target was modified"
[ ! -e "$TMP/unsafe-lock/state/codeburn-calls" ] || fail "unsafe lock started codeburn"
[ ! -e "$TMP/unsafe-lock/state/headroom-calls" ] || fail "unsafe lock started Headroom"

# Unsafe state paths fail closed without truncating a symlink target.
mkdir -p "$TMP/unsafe/state" "$TMP/unsafe/shared"
printf 'keep-this-content\n' > "$TMP/unsafe/sentinel"
ln -s "$TMP/unsafe/sentinel" "$TMP/unsafe/shared/logs"
run_helper unsafe env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/unsafe/output" "shared state directory is unsafe or unwritable"
[ "$(cat "$TMP/unsafe/sentinel")" = "keep-this-content" ] || fail "unsafe log symlink was modified"
[ ! -e "$TMP/unsafe/state/codeburn-calls" ] || fail "unsafe state started codeburn"
[ ! -e "$TMP/unsafe/state/headroom-calls" ] || fail "unsafe state started Headroom"

# Tests and callers can explicitly suppress service command startup.
run_helper skipped env AGENT_HARNESS_SERVICES_SKIP=1
assert_contains "$TMP/skipped/output" "Shared local services: SKIPPED"
[ ! -e "$TMP/skipped/state/codeburn-calls" ] || fail "skip contract started codeburn"
[ ! -e "$TMP/skipped/state/headroom-calls" ] || fail "skip contract started Headroom"

# Concurrent installers serialize through the shared lock; the second rechecks
# health and reuses both services instead of creating another pair.
case_root="$TMP/concurrent"
mkdir -p "$case_root/state" "$case_root/shared"
for n in 1 2; do
  env PATH="$SHIM:$PATH" SHIM_STATE="$case_root/state" \
    AGENT_HARNESS_STATE_DIR="$case_root/shared" \
    AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS=2 \
    CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native \
    bash "$REPO/scripts/ensure-shared-local-services.sh" > "$case_root/output-$n" 2>&1 &
  eval "helper_pid_$n=$!"
done
wait "$helper_pid_1"
wait "$helper_pid_2"
[ "$(wc -l < "$case_root/state/codeburn-calls" | tr -d ' ')" = "1" ] || fail "concurrent install started codeburn more than once"
[ "$(wc -l < "$case_root/state/headroom-calls" | tr -d ' ')" = "1" ] || fail "concurrent install started Headroom more than once"
cat "$case_root/output-1" "$case_root/output-2" > "$case_root/output-all"
assert_contains "$case_root/output-all" "codeburn web: STARTED"
assert_contains "$case_root/output-all" "codeburn web: REUSED"
assert_contains "$case_root/output-all" "Headroom proxy: STARTED"
assert_contains "$case_root/output-all" "Headroom proxy: REUSED"
cleanup_pid "$case_root/shared/codeburn.pid"

# Killing the real Python supervisor cannot release the lock while its worker
# shell is still waiting for a failed codeburn startup.
case_root="$TMP/supervisor-crash"
mkdir -p "$case_root/state" "$case_root/shared"
env PATH="$SHIM:$PATH" SHIM_STATE="$case_root/state" \
  AGENT_HARNESS_STATE_DIR="$case_root/shared" \
  AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS=5 \
  CODEBURN_SHIM_MODE=failure HEADROOM_SHIM_MODE=native \
  bash "$REPO/scripts/ensure-shared-local-services.sh" > "$case_root/output-first" 2>&1 &
supervisor_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$case_root/state/codeburn-parent.pid" ] && break
  sleep 0.1
done
[ -f "$case_root/state/codeburn-parent.pid" ] || fail "supervisor crash test did not start worker"
worker_pid=$(cat "$case_root/state/codeburn-parent.pid")
codeburn_pid=$(cat "$case_root/state/codeburn-shim.pid")
kill -KILL "$supervisor_pid"
wait "$supervisor_pid" 2>/dev/null || true
env PATH="$SHIM:$PATH" SHIM_STATE="$case_root/state" \
  AGENT_HARNESS_STATE_DIR="$case_root/shared" \
  AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS=1 \
  CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native \
  bash "$REPO/scripts/ensure-shared-local-services.sh" > "$case_root/output-second" 2>&1
assert_contains "$case_root/output-second" "shared startup lock timed out"
[ "$(wc -l < "$case_root/state/codeburn-calls" | tr -d ' ')" = "1" ] || fail "supervisor crash released startup lock"
kill -TERM "$worker_pid" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  kill -0 "$codeburn_pid" 2>/dev/null || break
  sleep 0.1
done
kill -0 "$codeburn_pid" 2>/dev/null && fail "crashed supervisor worker left codeburn running"

# A signal exits the lock owner and stops a codeburn process still in startup.
case_root="$TMP/signal"
mkdir -p "$case_root/state" "$case_root/shared"
env PATH="$SHIM:$PATH" SHIM_STATE="$case_root/state" \
  AGENT_HARNESS_STATE_DIR="$case_root/shared" \
  AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS=5 \
  CODEBURN_SHIM_MODE=failure HEADROOM_SHIM_MODE=native \
  bash "$REPO/scripts/ensure-shared-local-services.sh" > "$case_root/output" 2>&1 &
helper_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$case_root/state/codeburn-shim.pid" ] && break
  sleep 0.1
done
[ -f "$case_root/state/codeburn-shim.pid" ] || fail "signal test did not start codeburn"
codeburn_pid=$(cat "$case_root/state/codeburn-shim.pid")
kill -TERM "$helper_pid"
helper_rc=0
wait "$helper_pid" || helper_rc=$?
if [ "$helper_rc" != "143" ]; then
  cat "$case_root/output" >&2 || true
  fail "signaled helper exited with $helper_rc"
fi
kill -0 "$codeburn_pid" 2>/dev/null && fail "signaled helper left codeburn running"
[ -f "$case_root/shared/ensure.lock" ] || fail "signal test lost kernel lock file"
[ ! -e "$case_root/shared/codeburn.pid" ] || fail "signaled helper left PID file"
run_helper signal env CODEBURN_SHIM_MODE=success HEADROOM_SHIM_MODE=native
assert_contains "$TMP/signal/output" "codeburn web: STARTED"
cleanup_pid "$TMP/signal/shared/codeburn.pid"

echo "Shared local service tests passed"
