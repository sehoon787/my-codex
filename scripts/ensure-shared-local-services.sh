#!/usr/bin/env bash
# Ensure the dashboards shared by my-claude and my-codex are available once.
# Both harnesses use the same state directory, ports, health checks, and lock.
set -u
umask 077

STATE_DIR="${AGENT_HARNESS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness-services}"
TIMEOUT_SECONDS="${AGENT_HARNESS_SERVICE_TIMEOUT_SECONDS:-12}"
LOCK_FILE="$STATE_DIR/ensure.lock"
LOG_DIR="$STATE_DIR/logs"
CODEBURN_URL="http://127.0.0.1:4747/"
HEADROOM_URL="http://127.0.0.1:8787/stats"
HEADROOM_HEALTH_URL="http://127.0.0.1:8787/livez"
SPAWNED_CODEBURN_PID=""
ENABLE_CODEBURN=0
ENABLE_HEADROOM=0

if [ "$#" -eq 0 ]; then
  ENABLE_CODEBURN=1
  ENABLE_HEADROOM=1
else
  for service_name in "$@"; do
    case "$service_name" in
      codeburn) ENABLE_CODEBURN=1 ;;
      headroom) ENABLE_HEADROOM=1 ;;
      *) echo "ERROR: unknown shared local service: $service_name" >&2; exit 2 ;;
    esac
  done
fi

case "$TIMEOUT_SECONDS" in
  ''|*[!0-9]*) TIMEOUT_SECONDS=12 ;;
  0) TIMEOUT_SECONDS=1 ;;
esac

path_owner_uid() {
  case "$(uname -s)" in
    Darwin) stat -f '%u' "$1" 2>/dev/null ;;
    *) stat -c '%u' "$1" 2>/dev/null ;;
  esac
}

prepare_private_dir() {
  _dir="$1"
  [ ! -L "$_dir" ] || return 1
  mkdir -p "$_dir" 2>/dev/null || return 1
  [ -d "$_dir" ] && [ ! -L "$_dir" ] || return 1
  [ "$(path_owner_uid "$_dir")" = "$(id -u)" ] || return 1
  chmod 700 "$_dir" 2>/dev/null || return 1
}

prepare_log_file() {
  _file="$1"
  [ ! -L "$_file" ] || return 1
  : >> "$_file" 2>/dev/null || return 1
  chmod 600 "$_file" 2>/dev/null || return 1
}

print_locations() {
  [ "$ENABLE_CODEBURN" = "1" ] && echo "  codeburn dashboard: $CODEBURN_URL"
  [ "$ENABLE_HEADROOM" = "1" ] && echo "  Headroom stats:     $HEADROOM_URL"
  echo "  Shared service logs: $LOG_DIR"
  if [ "$ENABLE_HEADROOM" = "1" ]; then
    echo "  Headroom does not route Claude or Codex traffic until you explicitly configure a client."
  fi
}

if [ "${AGENT_HARNESS_SERVICES_SKIP:-0}" = "1" ]; then
  echo "Shared local services: SKIPPED (AGENT_HARNESS_SERVICES_SKIP=1)"
  print_locations
  exit 0
fi

fetch_url() {
  curl --silent --show-error --max-time 1 "$1" 2>/dev/null
}

codeburn_healthy() {
  _body=$(fetch_url "$CODEBURN_URL") || return 1
  printf '%s' "$_body" | grep -Fq '<title>CodeBurn - Local Dashboard</title>'
}

headroom_healthy() {
  _body=$(fetch_url "$HEADROOM_HEALTH_URL") || return 1
  printf '%s' "$_body" | grep -Eq '"service"[[:space:]]*:[[:space:]]*"headroom-proxy"' || return 1
  printf '%s' "$_body" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"healthy"' || return 1
  printf '%s' "$_body" | grep -Eq '"alive"[[:space:]]*:[[:space:]]*true'
}

# Return 0 when a listener owns the port, 1 when it is clear, and 2 when this
# host has neither supported listener probe. Health identity is checked first,
# so an occupied port here is always left untouched.
port_is_occupied() {
  _port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$_port" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk -v suffix=":$_port" '$4 ~ suffix "$" { found = 1 } END { exit(found ? 0 : 1) }'
    return $?
  fi
  return 2
}

wait_for_health() {
  _health_fn="$1"
  _ticks=$((TIMEOUT_SECONDS * 10))
  while [ "$_ticks" -gt 0 ]; do
    "$_health_fn" && return 0
    sleep 0.1
    _ticks=$((_ticks - 1))
  done
  return 1
}

stop_our_process() {
  _pid="$1"
  case "$_pid" in ''|*[!0-9]*) return 0 ;; esac
  kill "$_pid" 2>/dev/null || true
  _ticks=10
  while kill -0 "$_pid" 2>/dev/null && [ "$_ticks" -gt 0 ]; do
    sleep 0.1
    _ticks=$((_ticks - 1))
  done
  kill -KILL "$_pid" 2>/dev/null || true
  wait "$_pid" 2>/dev/null || true
}

handle_signal() {
  trap - HUP INT TERM
  if [ -n "$SPAWNED_CODEBURN_PID" ]; then
    stop_our_process "$SPAWNED_CODEBURN_PID"
    rm -f "$STATE_DIR/codeburn.pid" 2>/dev/null || true
    SPAWNED_CODEBURN_PID=""
  fi
  exit 130
}

trap handle_signal HUP INT TERM

close_inherited_lock_fd() {
  _lock_fd="${AGENT_HARNESS_LOCK_FD:-}"
  case "$_lock_fd" in
    ''|*[!0-9]*) return 0 ;;
  esac
  eval "exec ${_lock_fd}>&-"
  unset AGENT_HARNESS_LOCK_FD
}

ensure_codeburn() {
  _log="$LOG_DIR/codeburn.log"
  _pid_file="$STATE_DIR/codeburn.pid"

  if codeburn_healthy; then
    echo "codeburn web: REUSED ($CODEBURN_URL)"
    return 0
  fi
  port_is_occupied 4747
  _port_status=$?
  if [ "$_port_status" = "0" ]; then
    echo "codeburn web: FAIL (port 4747 belongs to another service; left untouched; log: $_log)"
    return 0
  fi
  if ! command -v codeburn >/dev/null 2>&1; then
    echo "codeburn web: FAIL (codeburn is not installed; log: $_log)"
    return 0
  fi

  if ! prepare_log_file "$_log"; then
    echo "codeburn web: FAIL (unsafe or unwritable log path; left untouched: $_log)"
    return 0
  fi
  # The worker shell keeps the startup lock, but this long-lived server must
  # not inherit it after installation completes.
  (
    close_inherited_lock_fd
    exec env BROWSER=none NO_BROWSER=1 \
      codeburn web --provider all --port 4747 --no-open
  ) </dev/null >>"$_log" 2>&1 &
  _pid=$!
  SPAWNED_CODEBURN_PID="$_pid"
  _pid_tmp=$(mktemp "$STATE_DIR/.codeburn.pid.XXXXXX" 2>/dev/null || true)
  if [ -n "$_pid_tmp" ] && printf '%s\n' "$_pid" > "$_pid_tmp" 2>/dev/null; then
    mv -f "$_pid_tmp" "$_pid_file" 2>/dev/null || true
  fi
  if wait_for_health codeburn_healthy; then
    SPAWNED_CODEBURN_PID=""
    echo "codeburn web: STARTED ($CODEBURN_URL; log: $_log)"
    return 0
  fi

  # codeburn falls back to a free port when 4747 becomes busy. Do not leave
  # that unexpected process behind; only stop the PID this invocation spawned.
  stop_our_process "$_pid"
  SPAWNED_CODEBURN_PID=""
  rm -f "$_pid_file" 2>/dev/null || true
  echo "codeburn web: FAIL (fixed port 4747 did not become healthy; spawned process cleaned; log: $_log)"
}

ensure_headroom() {
  _log="$LOG_DIR/headroom.log"

  if headroom_healthy; then
    echo "Headroom proxy: REUSED ($HEADROOM_URL)"
    return 0
  fi
  port_is_occupied 8787
  _port_status=$?
  if [ "$_port_status" = "0" ]; then
    echo "Headroom proxy: FAIL (port 8787 belongs to another service; left untouched; log: $_log)"
    return 0
  fi
  if ! command -v headroom >/dev/null 2>&1; then
    echo "Headroom proxy: FAIL (headroom is not installed; log: $_log)"
    return 0
  fi

  if ! prepare_log_file "$_log"; then
    echo "Headroom proxy: FAIL (unsafe or unwritable log path; left untouched: $_log)"
    return 0
  fi
  # `--providers manual` with no `--target` produces an empty mutation list.
  # Unset routing variables as an extra guard because Headroom otherwise copies
  # them into the persistent profile's supervised environment.
  # Headroom owns the apply lifecycle and its 45-second readiness bound. Run it
  # synchronously so killing a wrapper cannot orphan a newly installed native
  # service. Its failure path removes the deployment before it returns.
  if env -u ANTHROPIC_BASE_URL -u OPENAI_BASE_URL \
      -u ANTHROPIC_TARGET_API_URL -u ANTHROPIC_FOUNDRY_BASE_URL \
      -u OPENAI_TARGET_API_URL -u GEMINI_TARGET_API_URL \
      -u CLOUDCODE_TARGET_API_URL -u VERTEX_TARGET_API_URL \
      -u BEDROCK_TARGET_API_URL \
      headroom install apply --profile agent-harness-shared \
      --preset persistent-service --runtime python --providers manual \
      --port 8787 --no-telemetry --env HEADROOM_NO_SUBSCRIPTION_TRACKING=1 \
      >>"$_log" 2>&1; then
    if wait_for_health headroom_healthy; then
      echo "Headroom proxy: STARTED ($HEADROOM_URL; profile: agent-harness-shared; log: $_log)"
      return 0
    fi
  fi

  # Recheck after failure in case another installer completed while apply was
  # unwinding. No direct proxy fallback is launched: it could race a native
  # service that becomes healthy after its installer process returns.
  if headroom_healthy; then
    echo "Headroom proxy: REUSED ($HEADROOM_URL)"
  else
    echo "Headroom proxy: FAIL (native profile agent-harness-shared did not become healthy; log: $_log)"
  fi
}

if ! prepare_private_dir "$STATE_DIR" || ! prepare_private_dir "$LOG_DIR"; then
  [ "$ENABLE_CODEBURN" = "1" ] && echo "codeburn web: FAIL (shared state directory is unsafe or unwritable: $STATE_DIR)"
  [ "$ENABLE_HEADROOM" = "1" ] && echo "Headroom proxy: FAIL (shared state directory is unsafe or unwritable: $STATE_DIR)"
  print_locations
  exit 0
fi

run_without_starting() {
  _reason="${AGENT_HARNESS_LOCK_ERROR:-shared startup lock timed out}"
  if [ "$ENABLE_CODEBURN" = "1" ]; then
    codeburn_healthy \
      && echo "codeburn web: REUSED ($CODEBURN_URL)" \
      || echo "codeburn web: FAIL ($_reason; log: $LOG_DIR/codeburn.log)"
  fi
  if [ "$ENABLE_HEADROOM" = "1" ]; then
    headroom_healthy \
      && echo "Headroom proxy: REUSED ($HEADROOM_URL)" \
      || echo "Headroom proxy: FAIL ($_reason; log: $LOG_DIR/headroom.log)"
  fi
  print_locations
}

case "${AGENT_HARNESS_LOCK_MODE:-}" in
  acquired)
    [ "$ENABLE_CODEBURN" = "1" ] && ensure_codeburn
    [ "$ENABLE_HEADROOM" = "1" ] && ensure_headroom
    print_locations
    exit 0
    ;;
  no-start)
    run_without_starting
    exit 0
    ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  AGENT_HARNESS_LOCK_ERROR="python3 is required for the shared startup lock" \
    AGENT_HARNESS_LOCK_MODE=no-start bash "$0" "$@"
  exit 0
fi

# A kernel-managed advisory lock is released automatically when the supervisor
# exits, including after a crash. O_NOFOLLOW plus fstat prevents a pre-created
# symlink or foreign-owned file from redirecting the lock outside STATE_DIR.
exec python3 - "$LOCK_FILE" "$TIMEOUT_SECONDS" "$0" "$@" <<'PY'
import errno
import os
import signal
import stat
import subprocess
import sys
import time

lock_path, timeout_text, script, *service_args = sys.argv[1:]
timeout = max(1, int(timeout_text))
child = None


def run_helper(mode: str, error: str = "") -> int:
    global child
    env = os.environ.copy()
    env["AGENT_HARNESS_LOCK_MODE"] = mode
    if error:
        env["AGENT_HARNESS_LOCK_ERROR"] = error
    popen_options = {"env": env, "start_new_session": True}
    if mode == "acquired" and os.name != "nt":
        # Keep the same open file description in the worker so SIGKILL of this
        # supervisor cannot release the lock while startup is still running.
        env["AGENT_HARNESS_LOCK_FD"] = str(fd)
        popen_options["pass_fds"] = (fd,)
    child = subprocess.Popen(["bash", script, *service_args], **popen_options)
    return child.wait()


def forward_signal(signum, _frame):
    if child is not None and child.poll() is None:
        try:
            if hasattr(os, "killpg"):
                os.killpg(child.pid, signum)
            else:
                child.send_signal(signum)
        except OSError:
            pass
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            try:
                if hasattr(os, "killpg"):
                    os.killpg(child.pid, signal.SIGKILL)
                else:
                    child.kill()
            except OSError:
                pass
    raise SystemExit(128 + signum)


for signal_name in ("SIGHUP", "SIGINT", "SIGTERM"):
    sig = getattr(signal, signal_name, None)
    if sig is not None:
        signal.signal(sig, forward_signal)

flags = os.O_CREAT | os.O_RDWR
if hasattr(os, "O_NOFOLLOW"):
    flags |= os.O_NOFOLLOW

try:
    fd = os.open(lock_path, flags, 0o600)
    info = os.fstat(fd)
    current_uid = os.getuid() if hasattr(os, "getuid") else info.st_uid
    if not stat.S_ISREG(info.st_mode) or info.st_uid != current_uid:
        raise PermissionError("lock file is not a user-owned regular file")
    if hasattr(os, "fchmod"):
        os.fchmod(fd, 0o600)
except (OSError, PermissionError) as exc:
    sys.exit(run_helper("no-start", f"unsafe or unwritable startup lock: {exc}"))

deadline = time.monotonic() + timeout
try:
    import fcntl

    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() >= deadline:
                sys.exit(run_helper("no-start"))
            time.sleep(0.1)
except ImportError:
    # Windows Python lacks fcntl. msvcrt locks one byte and releases it when the
    # descriptor closes, providing the same crash-safe ownership property.
    import msvcrt

    if info.st_size == 0:
        os.write(fd, b"\0")
    while True:
        try:
            os.lseek(fd, 0, os.SEEK_SET)
            msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
            break
        except OSError as exc:
            if exc.errno not in (errno.EACCES, errno.EDEADLK, errno.EAGAIN):
                raise
            if time.monotonic() >= deadline:
                sys.exit(run_helper("no-start"))
            time.sleep(0.1)

sys.exit(run_helper("acquired"))
PY
