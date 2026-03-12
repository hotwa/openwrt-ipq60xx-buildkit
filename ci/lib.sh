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

sha256_file() {
  local file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi

  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
    return
  fi

  fail "missing sha256 tool"
}

sha256_string() {
  local value="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha256sum | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
    return
  fi

  if command -v openssl >/dev/null 2>&1; then
    printf '%s' "$value" | openssl dgst -sha256 | awk '{print $NF}'
    return
  fi

  fail "missing sha256 tool"
}

compute_baseline_key() {
  local wrt_arch="$1"
  local lock_hash payload

  [ -n "$wrt_arch" ] || fail "WRT_ARCH is required for baseline key"
  source_lock

  lock_hash="$(sha256_file "$LOCK_FILE")"
  payload="$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$lock_hash" \
    "$CI_BASE_COMMIT" \
    "$WRT_COMMIT" \
    "$SOURCE_LUCI_APP_PODMAN_REF" \
    "$TARGET" \
    "$wrt_arch")"
  sha256_string "$payload"
}

baseline_artifact_name() {
  local wrt_arch="$1"

  printf 'prebuilt-stack-%s\n' "$(compute_baseline_key "$wrt_arch")"
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
