#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

require_cmd mkdir
source_lock

mkdir -p "$DIST_DIR"
OUT_FILE="${OUT_FILE:-$DIST_DIR/current-baseline.md}"

cat > "$OUT_FILE" <<EOF
# Current IPQ60XX Combined Baseline

- Updated at: \`$BASELINE_UPDATED_AT\`
- Target: \`$TARGET\`
- Profiles: \`$PROFILES\`

## Upstreams

- CI base: \`$CI_BASE_REPO@$CI_BASE_COMMIT\`
- CI required commits: \`$CI_BASE_REQUIRED_COMMITS\`
- CI required commit notes: \`$CI_BASE_REQUIRED_COMMIT_NOTES\`
- WRT source: \`$WRT_REPO@$WRT_COMMIT\`
- Custom APK feed: \`$CUSTOM_APK_FEED_REPO@$CUSTOM_APK_FEED_COMMIT\`
- Custom APK feed URL: \`$CUSTOM_APK_FEED_URL\`
- Official APK feeds: \`$OFFICIAL_APK_FEEDS\`

## Package Policy

- Source packages: \`$SOURCE_PACKAGE_POLICY\`
- Official feed packages: \`$OFFICIAL_PACKAGE_POLICY\`
- Custom feed packages: \`$CUSTOM_PACKAGE_POLICY\`

## Davidtall Overlay Policy

- Source overlay packages: \`$DAVIDTALL_SOURCE_PACKAGE_POLICY\`
- Source overlay mappings: \`$DAVIDTALL_SOURCE_OVERLAYS\`
- Config package delta: \`$DAVIDTALL_CONFIG_PACKAGE_POLICY\`
- Excluded packages: \`$DAVIDTALL_EXCLUDED_PACKAGES\`

## ImageBuilder Inputs

- Custom APK feeds: \`$CUSTOM_APK_FEEDS\`
- ImageBuilder official packages: \`$IMAGEBUILDER_OFFICIAL_PACKAGES\`
- ImageBuilder custom packages: \`$IMAGEBUILDER_CUSTOM_PACKAGES\`
- Podman stack: \`$IMAGEBUILDER_PODMAN_STACK\`
- Tailscale stack: \`$IMAGEBUILDER_TAILSCALE_STACK\`
- NFS stack: \`$IMAGEBUILDER_NFS_STACK\`
- NFS kmods: \`$IMAGEBUILDER_NFS_KMODS\`
- All preload packages: \`$IMAGEBUILDER_ALL_PACKAGES\`
EOF

note "manifest written: $OUT_FILE"
