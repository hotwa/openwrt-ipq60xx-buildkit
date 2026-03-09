#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

check_only=false
if [ "${1:-}" = "--check" ]; then
  check_only=true
elif [ -n "${1:-}" ]; then
  fail "unsupported argument: $1"
fi

require_cmd gh sed date
source_lock

ci_sha="$(resolve_branch_sha "$CI_BASE_REPO" "$CI_BASE_BRANCH")"
wrt_sha="$(resolve_branch_sha "$WRT_REPO" "$WRT_BRANCH")"
feed_sha="$(resolve_branch_sha "$CUSTOM_APK_FEED_REPO" "$CUSTOM_APK_FEED_BRANCH")"

printf '%s %s -> %s\n' "$CI_BASE_REPO" "$CI_BASE_COMMIT" "$ci_sha"
printf '%s %s -> %s\n' "$WRT_REPO" "$WRT_COMMIT" "$wrt_sha"
printf '%s %s -> %s\n' "$CUSTOM_APK_FEED_REPO" "$CUSTOM_APK_FEED_COMMIT" "$feed_sha"

if [ "$check_only" = true ]; then
  exit 0
fi

set_lock_value "BASELINE_UPDATED_AT" "$(date +%FT%T%:z)"
set_lock_value "CI_BASE_COMMIT" "$ci_sha"
set_lock_value "WRT_COMMIT" "$wrt_sha"
set_lock_value "CUSTOM_APK_FEED_COMMIT" "$feed_sha"

note "lock refreshed: $LOCK_FILE"

