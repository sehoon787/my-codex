#!/usr/bin/env bash
set -euo pipefail

my_codex_git_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

my_codex_state_dir() {
  git rev-parse --git-path my-codex-attribution 2>/dev/null || true
}

my_codex_state_file() {
  local state_dir
  state_dir="$(my_codex_state_dir)"
  [ -n "$state_dir" ] || return 0
  printf '%s/state.env\n' "$state_dir"
}

my_codex_changed_files_file() {
  local state_dir
  state_dir="$(my_codex_state_dir)"
  [ -n "$state_dir" ] || return 0
  printf '%s/changed-files.txt\n' "$state_dir"
}

my_codex_is_enabled() {
  local enabled
  enabled="$(git config --bool --get my-codex.codexAttribution 2>/dev/null || printf 'true')"
  [ "$enabled" != "false" ]
}

my_codex_previous_hooks_path() {
  git config --global --get my-codex.previousHooksPath 2>/dev/null || true
}

my_codex_run_previous_hook() {
  local hook_name="$1"
  local current_hook="$2"
  shift 2

  local previous_path previous_hook
  previous_path="$(my_codex_previous_hooks_path)"
  [ -n "$previous_path" ] || return 0

  previous_hook="${previous_path%/}/$hook_name"
  [ -x "$previous_hook" ] || return 0
  [ "$previous_hook" = "$current_hook" ] && return 0

  "$previous_hook" "$@"
}

my_codex_mark_session() {
  local repo_root="$1"
  local timestamp="$2"
  local state_dir state_file
  state_dir="$(my_codex_state_dir)"
  [ -n "$state_dir" ] || return 0
  mkdir -p "$state_dir"
  state_file="$(my_codex_state_file)"
  printf 'MY_CODEX_TOOL=%q\n' "codex" > "$state_file"
  printf 'MY_CODEX_TIMESTAMP=%q\n' "$timestamp" >> "$state_file"
  printf 'MY_CODEX_REPO_ROOT=%q\n' "$repo_root" >> "$state_file"
}

my_codex_append_paths() {
  local files_file="$1"
  shift || true

  local tmp_file
  tmp_file="$(mktemp)"
  {
    if [ -f "$files_file" ]; then
      cat "$files_file"
    fi
    if [ "$#" -gt 0 ]; then
      printf '%s\n' "$@"
    fi
  } | awk 'NF && !seen[$0]++' > "$tmp_file"
  mv "$tmp_file" "$files_file"
}

my_codex_reset_state() {
  local state_dir
  state_dir="$(my_codex_state_dir)"
  [ -n "$state_dir" ] || return 0
  rm -rf "$state_dir"
}
