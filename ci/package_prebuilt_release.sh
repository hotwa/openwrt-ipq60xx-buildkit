#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

require_cmd gh tar mktemp
source_lock

[ -n "${WRT_ARCH:-}" ] || fail "WRT_ARCH is required in $LOCK_FILE"

PREBUILT_DIST_DIR="${PREBUILT_DIST_DIR:-$ROOT_DIR/dist/prebuilt}"
artifact_name="$(baseline_artifact_name "$WRT_ARCH")"
release_tag="$(baseline_release_tag "$WRT_ARCH")"
release_asset_name="$(baseline_release_asset_name "$WRT_ARCH")"
artifact_dir="$PREBUILT_DIST_DIR/$artifact_name"
release_asset_path="$PREBUILT_DIST_DIR/$release_asset_name"
metadata_file="$artifact_dir/prebuilt-stack.env"
notes_file="$(mktemp)"
trap 'rm -f "$notes_file"' EXIT

[ -d "$artifact_dir" ] || fail "prebuilt artifact directory not found: $artifact_dir"
[ -f "$metadata_file" ] || fail "prebuilt metadata file not found: $metadata_file"
[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ] || fail "GITHUB_TOKEN or GH_TOKEN is required for release publishing"

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
export GH_REPO="${GITHUB_REPOSITORY:-${GH_REPO:-}}"
[ -n "$GH_REPO" ] || fail "GITHUB_REPOSITORY or GH_REPO is required for release publishing"

note "package release asset: $release_asset_path"
rm -f "$release_asset_path"
tar --zstd -cf "$release_asset_path" -C "$PREBUILT_DIST_DIR" "$artifact_name"

cat > "$notes_file" <<EOF
Artifact-first chain:
- Downstream firmware builds consume the Actions artifact from the matching prebuild workflow run.
- This release mirrors the same prebuilt APK repository for archival and manual rollback only.

Baseline metadata:
$(sed 's/^/- /' "$metadata_file")
EOF

if gh release view "$release_tag" >/dev/null 2>&1; then
  note "update release: $release_tag"
  gh release edit "$release_tag" --title "$release_tag" --notes-file "$notes_file"
  gh release upload "$release_tag" "$release_asset_path" --clobber
else
  note "create release: $release_tag"
  gh release create "$release_tag" "$release_asset_path" --title "$release_tag" --notes-file "$notes_file"
fi
