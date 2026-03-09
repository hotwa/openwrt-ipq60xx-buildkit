#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${LOCK_FILE:-$ROOT_DIR/locks/combined-baseline.lock}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"

note() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"
  done
}

source_lock() {
  [ -f "$LOCK_FILE" ] || fail "lock file not found: $LOCK_FILE"
  # shellcheck disable=SC1090
  . "$LOCK_FILE"
}

resolve_branch_sha() {
  local repo="$1"
  local branch="$2"

  gh api "repos/$repo/branches/$branch" --jq .commit.sha
}

set_lock_value() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$LOCK_FILE"; then
    sed -i.bak -E "s|^${key}=.*$|${key}=${value}|" "$LOCK_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$LOCK_FILE"
  fi
  rm -f "${LOCK_FILE}.bak"
}

