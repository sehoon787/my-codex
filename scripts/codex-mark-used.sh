#!/usr/bin/env bash
set -euo pipefail

LIB_PATH="${HOME}/.codex/lib/codex-attribution.sh"
[ -f "$LIB_PATH" ] || exit 0
. "$LIB_PATH"

repo_root="$(my_codex_git_root)"
[ -n "$repo_root" ] || exit 0
my_codex_is_enabled || exit 0

timestamp="$(date +%s)"
my_codex_mark_session "$repo_root" "$timestamp"

files_file="$(my_codex_changed_files_file)"
mkdir -p "$(dirname "$files_file")"

normalized_paths=()
for path in "$@"; do
  [ -n "$path" ] || continue
  case "$path" in
    "$repo_root"/*)
      normalized_paths+=("${path#$repo_root/}")
      ;;
    *)
      normalized_paths+=("$path")
      ;;
  esac
done

if [ "${#normalized_paths[@]}" -gt 0 ]; then
  my_codex_append_paths "$files_file" "${normalized_paths[@]}"
fi
