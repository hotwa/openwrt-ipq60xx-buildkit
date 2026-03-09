#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

format="github"
if [ "${1:-}" = "--format" ]; then
  format="${2:-}"
elif [ -n "${1:-}" ]; then
  fail "unsupported argument: $1"
fi

source_lock

emit() {
  local key="$1"
  local value="$2"
  case "$format" in
    github|gha)
      printf '%s=%s\n' "$key" "$value"
      ;;
    shell)
      printf 'export %s=%q\n' "$key" "$value"
      ;;
    *)
      fail "unsupported format: $format"
      ;;
  esac
}

emit CI_BASE_REPO "$CI_BASE_REPO"
emit CI_BASE_COMMIT "$CI_BASE_COMMIT"
emit WRT_REPO "$WRT_REPO"
emit WRT_REF "$WRT_COMMIT"
emit CUSTOM_APK_FEED_REPO "$CUSTOM_APK_FEED_REPO"
emit CUSTOM_APK_FEED_COMMIT "$CUSTOM_APK_FEED_COMMIT"
emit CUSTOM_APK_FEED_URL "$CUSTOM_APK_FEED_URL"
emit TARGET "$TARGET"
emit PROFILES "$PROFILES"
emit SOURCE_PACKAGE_POLICY "$SOURCE_PACKAGE_POLICY"
emit OFFICIAL_PACKAGE_POLICY "$OFFICIAL_PACKAGE_POLICY"
emit CUSTOM_PACKAGE_POLICY "$CUSTOM_PACKAGE_POLICY"

