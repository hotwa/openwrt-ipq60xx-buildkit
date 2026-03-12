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

[ -n "${WRT_ARCH:-}" ] || fail "WRT_ARCH is required in $LOCK_FILE"

BASELINE_KEY="$(compute_baseline_key "$WRT_ARCH")"
BASELINE_ARTIFACT_NAME="$(baseline_artifact_name "$WRT_ARCH")"
BASELINE_RELEASE_TAG="$(baseline_release_tag "$WRT_ARCH")"
BASELINE_RELEASE_ASSET_NAME="$(baseline_release_asset_name "$WRT_ARCH")"

emit TARGET "$TARGET"
emit WRT_ARCH "$WRT_ARCH"
emit BASELINE_KEY "$BASELINE_KEY"
emit BASELINE_ARTIFACT_NAME "$BASELINE_ARTIFACT_NAME"
emit BASELINE_RELEASE_TAG "$BASELINE_RELEASE_TAG"
emit BASELINE_RELEASE_ASSET_NAME "$BASELINE_RELEASE_ASSET_NAME"
