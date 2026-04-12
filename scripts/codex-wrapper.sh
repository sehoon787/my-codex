#!/usr/bin/env bash
set -euo pipefail

LIB_PATH="${HOME}/.codex/lib/codex-attribution.sh"
[ -f "$LIB_PATH" ] && . "$LIB_PATH"

find_real_codex() {
  local self_dir dir normalized_dir old_ifs
  self_dir="$(cd "$(dirname "$0")" && pwd)"
  old_ifs="$IFS"
  IFS=':'
  for dir in $PATH; do
    [ -n "$dir" ] || continue
    if normalized_dir="$(cd "$dir" 2>/dev/null && pwd)"; then
      :
    else
      normalized_dir="$dir"
    fi
    if [ "$normalized_dir" = "$self_dir" ]; then
      continue
    fi
    if [ -x "$normalized_dir/codex" ]; then
      printf '%s/codex\n' "$normalized_dir"
      IFS="$old_ifs"
      return 0
    fi
  done
  IFS="$old_ifs"
  return 1
}

snapshot_changed_files() {
  local repo_root="$1"
  local output_file="$2"
  : > "$output_file"

  git -C "$repo_root" status --porcelain=v1 --untracked-files=all | while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="${line:3}"
    case "$path" in
      *" -> "*)
        path="${path##* -> }"
        ;;
    esac

    if [ -e "$repo_root/$path" ]; then
      hash="$(git -C "$repo_root" hash-object -- "$repo_root/$path" 2>/dev/null || printf '__HASH_ERROR__')"
    else
      hash="__MISSING__"
    fi
    printf '%s\t%s\n' "$path" "$hash"
  done | LC_ALL=C sort -u > "$output_file"
}

record_session_changes() {
  local repo_root="$1"
  local before_file="$2"
  local after_file="$3"
  local timestamp="$4"

  local files_file changed_delta
  local changed_paths=()
  files_file="$(my_codex_changed_files_file)"
  mkdir -p "$(dirname "$files_file")"
  changed_delta="$(comm -13 "$before_file" "$after_file" | cut -f1)"

  if [ -n "$changed_delta" ]; then
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      changed_paths+=("$path")
    done <<EOF
$changed_delta
EOF
    my_codex_mark_session "$repo_root" "$timestamp"
    my_codex_append_paths "$files_file" "${changed_paths[@]}"
  fi
}

REAL_CODEX="$(find_real_codex || true)"
if [ -z "$REAL_CODEX" ]; then
  echo "my-codex wrapper could not find the real codex binary in PATH." >&2
  exit 127
fi

# Run my-codex SessionStart hook (side effects only; Codex CLI has no native hook support)
# Output discarded because nothing in Codex consumes hookSpecificOutput. Failures non-blocking.
_hook_installed="no"
[ -x "$HOME/.codex/hooks/session-start.sh" ] && _hook_installed="yes"
if [ -x "$HOME/.codex/hooks/session-start.sh" ]; then
  bash "$HOME/.codex/hooks/session-start.sh" >/dev/null 2>&1 || true
fi

# Diagnostic log
{
  printf '%s\twrapper=codex.sh\tcwd=%s\thook_installed=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" \
    "$(pwd 2>/dev/null || echo unknown)" \
    "$_hook_installed"
} >> "$HOME/.codex/last-invocation.log" 2>/dev/null || true

if ! command -v git >/dev/null 2>&1 || ! command -v date >/dev/null 2>&1 || ! command -v mktemp >/dev/null 2>&1; then
  "$REAL_CODEX" "$@"; _cs=$?
  echo '{"agent_id":"codex-wrapper-stop","agent_type":"wrapper"}' | node "$HOME/.codex/hooks/stop-profile-update.js" 2>/dev/null || true
  exit $_cs
fi

repo_root=""
if [ -f "$LIB_PATH" ]; then
  repo_root="$(my_codex_git_root)"
fi

if [ -z "$repo_root" ] || ! my_codex_is_enabled; then
  "$REAL_CODEX" "$@"; _cs=$?
  echo '{"agent_id":"codex-wrapper-stop","agent_type":"wrapper"}' | node "$HOME/.codex/hooks/stop-profile-update.js" 2>/dev/null || true
  exit $_cs
fi

before_file="$(mktemp)"
after_file="$(mktemp)"
timestamp="$(date +%s)"

cleanup() {
  rm -f "$before_file" "$after_file"
}
trap cleanup EXIT

snapshot_changed_files "$repo_root" "$before_file"
set +e
"$REAL_CODEX" "$@"
codex_status=$?
set -e
snapshot_changed_files "$repo_root" "$after_file"
record_session_changes "$repo_root" "$before_file" "$after_file" "$timestamp"
# Run my-codex Stop hook (profile + session + decisions + learnings auto-gen)
if [ -f "$HOME/.codex/hooks/stop-profile-update.js" ]; then
  echo '{"agent_id":"codex-wrapper-stop","agent_type":"wrapper"}' | node "$HOME/.codex/hooks/stop-profile-update.js" 2>/dev/null || true
fi
exit "$codex_status"
