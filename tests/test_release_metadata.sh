#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/combined-baseline.lock"

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=cafebabe
SOURCE_LUCI_APP_PODMAN_REF=feedface
TARGET=qualcommax/ipq60xx
WRT_ARCH=aarch64_cortex-a53
PROFILES="IPQ60XX-NOWIFI"
EOF

export LOCK_FILE

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/lib.sh"

artifact_name="$(baseline_artifact_name "aarch64_cortex-a53")"
release_tag="$(baseline_release_tag "aarch64_cortex-a53")"
release_asset="$(baseline_release_asset_name "aarch64_cortex-a53")"

[ "$release_tag" = "$artifact_name" ]
[ "$release_asset" = "$artifact_name.tar.zst" ]

printf 'release metadata test passed\n'
