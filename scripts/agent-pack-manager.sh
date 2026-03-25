#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_DIR="${HOME}/.codex"
AGENTS_DIR="${CODEX_DIR}/agents"
PACKS_DIR="${CODEX_DIR}/agent-packs"
STATE_FILE="${CODEX_DIR}/enabled-agent-packs.txt"
DEFAULT_PACKS=(
  engineering
  language-specialists
  research-analysis
  testing
)

usage() {
  cat <<'EOF'
Usage:
  agent-pack-manager.sh ensure-state
  agent-pack-manager.sh activate
  agent-pack-manager.sh list
  agent-pack-manager.sh status
  agent-pack-manager.sh enable <pack...>
  agent-pack-manager.sh disable <pack...>
  agent-pack-manager.sh set-profile <minimal|dev|full>
EOF
}

is_known_pack() {
  local pack_name=$1
  [ -d "${PACKS_DIR}/${pack_name}" ]
}

print_pack_lines() {
  for pack_name in "$@"; do
    [ -n "${pack_name}" ] || continue
    printf '%s\n' "${pack_name}"
  done
}

read_state_packs() {
  if [ ! -f "${STATE_FILE}" ]; then
    return 0
  fi

  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print $0 }
  ' "${STATE_FILE}"
}

detect_previously_linked_packs() {
  if [ ! -d "${AGENTS_DIR}" ]; then
    return 0
  fi

  find "${AGENTS_DIR}" -maxdepth 1 -type l -name '*.toml' -print 2>/dev/null |
    while IFS= read -r symlink_path; do
      target_path=$(readlink "${symlink_path}" 2>/dev/null || true)
      case "${target_path}" in
        "${PACKS_DIR}/"*)
          pack_name=${target_path#${PACKS_DIR}/}
          pack_name=${pack_name%%/*}
          [ -n "${pack_name}" ] && printf '%s\n' "${pack_name}"
          ;;
      esac
    done
}

write_state_file() {
  mkdir -p "${CODEX_DIR}"
  {
    echo "# One pack name per line."
    echo "# This file is managed by my-codex and preserved across reinstalls."
    print_pack_lines "$@"
  } > "${STATE_FILE}"
}

list_available_packs() {
  if [ ! -d "${PACKS_DIR}" ]; then
    return 0
  fi

  find "${PACKS_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

collect_lines_into_array() {
  local target_name=$1
  local line

  eval "${target_name}=()"
  while IFS= read -r line; do
    [ -n "${line}" ] || continue
    eval "${target_name}+=(\"\${line}\")"
  done
}

ensure_state_file() {
  local migrated_packs=()
  local pack_name

  if [ -f "${STATE_FILE}" ]; then
    return 0
  fi

  while IFS= read -r pack_name; do
    [ -n "${pack_name}" ] || continue
    migrated_packs+=("${pack_name}")
  done < <(detect_previously_linked_packs | sort -u)

  if [ ${#migrated_packs[@]} -gt 0 ]; then
    write_state_file "${migrated_packs[@]}"
    return 0
  fi

  write_state_file "${DEFAULT_PACKS[@]}"
}

activate_configured_packs() {
  local activated_count=0
  local pack_name
  local pack_file
  local destination_path
  local symlink_path
  local target_path

  mkdir -p "${AGENTS_DIR}"
  while IFS= read -r symlink_path; do
    [ -n "${symlink_path}" ] || continue
    target_path=$(readlink "${symlink_path}" 2>/dev/null || true)
    case "${target_path}" in
      "${PACKS_DIR}/"*)
        rm -f "${symlink_path}"
        ;;
    esac
  done < <(find "${AGENTS_DIR}" -maxdepth 1 -type l -name '*.toml' 2>/dev/null)

  while IFS= read -r pack_name; do
    [ -n "${pack_name}" ] || continue
    if ! is_known_pack "${pack_name}"; then
      echo "WARNING: unknown agent pack '${pack_name}' in ${STATE_FILE}" >&2
      continue
    fi

    while IFS= read -r pack_file; do
      [ -n "${pack_file}" ] || continue
      destination_path="${AGENTS_DIR}/$(basename "${pack_file}")"
      if [ -e "${destination_path}" ]; then
        continue
      fi

      ln -sf "${pack_file}" "${destination_path}"
      activated_count=$((activated_count + 1))
    done < <(find "${PACKS_DIR}/${pack_name}" -maxdepth 1 -type f -name '*.toml' | sort)
  done < <(read_state_packs)

echo "${activated_count}"
}

list_configured_packs() {
  read_state_packs
}

status() {
  echo "Configured packs:"
  read_state_packs || true
  echo "Installed packs: $(list_available_packs | wc -l | tr -d ' ')"
  echo "Active linked agents: $(find "${AGENTS_DIR}" -maxdepth 1 -type l -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')"
}

set_profile() {
  local profile=${1:-}
  local all_packs=()

  case "${profile}" in
    minimal)
      write_state_file
      ;;
    dev)
      write_state_file "${DEFAULT_PACKS[@]}"
      ;;
    full)
      collect_lines_into_array all_packs < <(list_available_packs)
      write_state_file "${all_packs[@]}"
      ;;
    *)
      echo "unsupported profile: ${profile}" >&2
      exit 1
      ;;
  esac
}

enable_packs() {
  local existing=()
  local merged=()
  local pack_name
  local line

  [ "$#" -gt 0 ] || {
    echo "enable requires at least one pack name" >&2
    exit 1
  }

  for pack_name in "$@"; do
    if ! is_known_pack "${pack_name}"; then
      echo "unknown agent pack: ${pack_name}" >&2
      exit 1
    fi
  done

  collect_lines_into_array existing < <(read_state_packs || true)
  for pack_name in "$@"; do
    existing+=("${pack_name}")
  done

  while IFS= read -r line; do
    [ -n "${line}" ] || continue
    merged+=("${line}")
  done < <(printf '%s\n' "${existing[@]}" | awk 'NF { seen[$0] = 1 } END { for (pack in seen) print pack }' | sort)

  write_state_file "${merged[@]}"
}

disable_packs() {
  local existing=()
  local filtered=()
  local line

  [ "$#" -gt 0 ] || {
    echo "disable requires at least one pack name" >&2
    exit 1
  }

  collect_lines_into_array existing < <(read_state_packs || true)
  while IFS= read -r line; do
    [ -n "${line}" ] || continue
    filtered+=("${line}")
  done < <(printf '%s\n' "${existing[@]}" | grep -vxF -f <(printf '%s\n' "$@") || true)

  write_state_file "${filtered[@]}"
}

main() {
  local command=${1:-}

  case "${command}" in
    ensure-state)
      ensure_state_file
      ;;
    activate)
      activate_configured_packs
      ;;
    list)
      list_available_packs
      ;;
    status)
      status
      ;;
    enable)
      shift
      enable_packs "$@"
      activate_configured_packs >/dev/null
      ;;
    disable)
      shift
      disable_packs "$@"
      activate_configured_packs >/dev/null
      ;;
    set-profile)
      shift
      set_profile "${1:-}"
      activate_configured_packs >/dev/null
      ;;
    configured)
      list_configured_packs
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
