#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${MY_CODEX_REPO_URL:-https://github.com/sehoon787/my-codex.git}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/my-codex-XXXXXX")"
REPO_DIR="$TMP_ROOT/repo"

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

echo "==> my-codex bootstrap"
require_cmd git
require_cmd bash
require_cmd node
require_cmd npm

echo "==> Cloning repository"
git clone --depth 1 "$REPO_URL" "$REPO_DIR"

if [ ! -f "$REPO_DIR/install.sh" ]; then
  echo "ERROR: install.sh not found in cloned repository: $REPO_DIR" >&2
  exit 1
fi

echo "==> Running installer"
bash "$REPO_DIR/install.sh"
