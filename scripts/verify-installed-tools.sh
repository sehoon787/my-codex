#!/usr/bin/env bash

# Bounded runtime checks used by install.sh. This file is sourced so tests can
# exercise the real probe logic without running the full installer.

tool_probe_detail() {
  local output_file="$1" detail
  detail="$(head -n 1 "$output_file" 2>/dev/null | tr '\r\n' '  ' | sed 's/[[:space:]]*$//' | cut -c 1-160)"
  if [ -n "$detail" ]; then
    printf '%s' "$detail"
  else
    printf 'no output'
  fi
}

run_bounded_tool_probe() {
  local output_file="$1" timeout_seconds="$2"
  shift 2

  local timeout_marker="${output_file}.timeout" probe_pid watchdog_pid status restore_monitor=0
  : > "$output_file"
  rm -f "$timeout_marker"

  # Non-interactive Bash normally puts background commands in the installer's
  # process group. Temporarily enabling job control gives this probe its own
  # group, so a timeout can stop wrappers and every renderer/helper they spawn.
  case "$-" in
    *m*) ;;
    *) set -m; restore_monitor=1 ;;
  esac
  "$@" >"$output_file" 2>&1 &
  probe_pid=$!
  (
    sleep "$timeout_seconds"
    if kill -0 "$probe_pid" 2>/dev/null; then
      : > "$timeout_marker"
      kill -KILL -- "-$probe_pid" 2>/dev/null || kill -KILL "$probe_pid" 2>/dev/null || true
    fi
  ) &
  watchdog_pid=$!
  if [ "$restore_monitor" -eq 1 ]; then
    set +m
  fi

  if wait "$probe_pid" 2>/dev/null; then
    status=0
  else
    status=$?
  fi
  kill -KILL -- "-$watchdog_pid" 2>/dev/null || kill -KILL "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  # Also remove descendants left behind by a wrapper that exited before them.
  kill -KILL -- "-$probe_pid" 2>/dev/null || true

  if [ -f "$timeout_marker" ]; then
    return 124
  fi
  return "$status"
}

run_archify_commands() {
  local renderer="$1" example="$2" rendered_file="$3"
  local render_output_file="$4" check_output_file="$5" phase_file="$6"

  printf 'render\n' > "$phase_file"
  if node "$renderer" render workflow "$example" "$rendered_file" >"$render_output_file" 2>&1; then
    :
  else
    return $?
  fi
  if [ ! -s "$rendered_file" ] || ! grep -Eiq '<!doctype html|<html' "$rendered_file"; then
    printf 'validate\n' > "$phase_file"
    return 90
  fi

  printf 'check\n' > "$phase_file"
  if node "$renderer" check "$rendered_file" >"$check_output_file" 2>&1; then
    return 0
  else
    return $?
  fi
}

verify_version_probe() {
  local label="$1" command_name="$2" expected="$3" output_file="$4" timeout_seconds="$5"
  local status detail

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '  %-14s FAIL (command not found)\n' "${label}:"
    return 1
  fi

  if run_bounded_tool_probe "$output_file" "$timeout_seconds" "$command_name" --version; then
    status=0
  else
    status=$?
  fi

  if [ "$status" -eq 124 ]; then
    printf '  %-14s FAIL (timeout after %ss)\n' "${label}:" "$timeout_seconds"
    return 1
  fi

  detail="$(tool_probe_detail "$output_file")"
  if [ "$status" -ne 0 ]; then
    printf '  %-14s FAIL (exit %s: %s)\n' "${label}:" "$status" "$detail"
    return 1
  fi
  if ! grep -Fq "$expected" "$output_file"; then
    printf '  %-14s FAIL (unexpected version: %s)\n' "${label}:" "$detail"
    return 1
  fi

  printf '  %-14s OK (%s)\n' "${label}:" "$detail"
  return 0
}

verify_archify_probe() {
  local codex_root="$1" work_dir="$2" timeout_seconds="$3"
  local skill_dir="$codex_root/skills/archify"
  local renderer="$skill_dir/bin/archify.mjs"
  local example="$skill_dir/examples/agent-tool-call.workflow.json"
  local output_file="$work_dir/archify-probe.out"
  local combined_output_file="$work_dir/archify-combined.out"
  local check_output_file="$work_dir/archify-check.out"
  local phase_file="$work_dir/archify-phase"
  local rendered_file="$work_dir/archify-probe.html"
  local status detail

  if ! command -v node >/dev/null 2>&1; then
    printf '  %-14s FAIL (node command not found)\n' 'archify:'
    return 1
  fi
  if [ ! -f "$renderer" ] || [ ! -f "$example" ]; then
    printf '  %-14s FAIL (bundled renderer or example missing)\n' 'archify:'
    return 1
  fi

  if run_bounded_tool_probe "$combined_output_file" "$timeout_seconds" \
    run_archify_commands "$renderer" "$example" "$rendered_file" \
      "$output_file" "$check_output_file" "$phase_file"; then
    status=0
  else
    status=$?
  fi

  if [ "$status" -eq 124 ]; then
    if grep -q '^check$' "$phase_file" 2>/dev/null; then
      printf '  %-14s FAIL (check timeout after %ss)\n' 'archify:' "$timeout_seconds"
    else
      printf '  %-14s FAIL (timeout after %ss)\n' 'archify:' "$timeout_seconds"
    fi
    return 1
  fi
  if [ "$status" -eq 90 ]; then
    printf '  %-14s FAIL (renderer produced no valid HTML)\n' 'archify:'
    return 1
  fi
  if [ "$status" -ne 0 ]; then
    if grep -q '^check$' "$phase_file" 2>/dev/null; then
      detail="$(tool_probe_detail "$check_output_file")"
      printf '  %-14s FAIL (check exit %s: %s)\n' 'archify:' "$status" "$detail"
    else
      detail="$(tool_probe_detail "$output_file")"
      printf '  %-14s FAIL (exit %s: %s)\n' 'archify:' "$status" "$detail"
    fi
    return 1
  fi

  printf '  %-14s OK (rendered and checked bundled workflow example)\n' 'archify:'
  return 0
}

verify_installed_tools() (
  local codex_root="$1"
  local timeout_seconds="${MY_CODEX_VERIFY_TIMEOUT_SECONDS:-2}"
  local temp_parent="${MY_CODEX_VERIFY_TMP_PARENT:-${TMPDIR:-/tmp}}"
  local work_dir ok_count=0 fail_count=0

  cleanup_tool_verification() {
    if [ -n "${work_dir:-}" ] && [ -d "$work_dir" ]; then
      rm -rf "$work_dir"
    fi
  }
  trap cleanup_tool_verification EXIT

  if ! mkdir -p "$temp_parent" 2>/dev/null || \
    ! work_dir="$(mktemp -d "$temp_parent/my-codex-tool-verification.XXXXXX" 2>/dev/null)"; then
    echo "  Tool probes:   0 OK, 4 FAIL (could not create temporary directory)"
  else
    if verify_version_probe codeburn codeburn 0.9.23 "$work_dir/codeburn.out" "$timeout_seconds"; then
      ok_count=$((ok_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
    if verify_version_probe serena serena 'Serena 1.7.0' "$work_dir/serena.out" "$timeout_seconds"; then
      ok_count=$((ok_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
    if verify_version_probe headroom headroom 'headroom, version 0.37.0' "$work_dir/headroom.out" "$timeout_seconds"; then
      ok_count=$((ok_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
    if verify_archify_probe "$codex_root" "$work_dir" "$timeout_seconds"; then
      ok_count=$((ok_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi

    printf '  Tool probes:   %s OK, %s FAIL\n' "$ok_count" "$fail_count"
  fi
  echo ""
  echo "Tool access:"
  echo "  Serena dashboard: http://localhost:24282/dashboard/index.html"
  echo '  codeburn: `codeburn web` serves http://127.0.0.1:4747 (not started by this installer)'
  echo "  Serena/Headroom MCP: auto-start each Codex session"

  # Runtime verification is diagnostic. A missing or unhealthy optional tool
  # must not abort installation under set -euo pipefail.
  return 0
)
