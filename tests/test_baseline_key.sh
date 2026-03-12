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
SOURCE_LUCI_APP_PODMAN_REPO=test/podman
SOURCE_LUCI_APP_PODMAN_REF=feedface
TARGET=qualcommax/ipq60xx
PROFILES="IPQ60XX-NOWIFI IPQ60XX-WIFI"
EOF

export LOCK_FILE

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/lib.sh"

key_one="$(compute_baseline_key "aarch64_cortex-a53")"
key_two="$(compute_baseline_key "aarch64_cortex-a53")"

[ -n "$key_one" ]
[ "$key_one" = "$key_two" ]

artifact_name="$(baseline_artifact_name "aarch64_cortex-a53")"
[ "$artifact_name" = "prebuilt-stack-$key_one" ]

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=feedf00d
SOURCE_LUCI_APP_PODMAN_REPO=test/podman
SOURCE_LUCI_APP_PODMAN_REF=feedface
TARGET=qualcommax/ipq60xx
PROFILES="IPQ60XX-NOWIFI IPQ60XX-WIFI"
EOF

key_changed_commit="$(compute_baseline_key "aarch64_cortex-a53")"
[ "$key_changed_commit" != "$key_one" ]

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=cafebabe
SOURCE_LUCI_APP_PODMAN_REPO=test/podman
SOURCE_LUCI_APP_PODMAN_REF=feedface
TARGET=qualcommax/ipq60xx
PROFILES="IPQ60XX-NOWIFI IPQ60XX-WIFI"
EOF

key_changed_arch="$(compute_baseline_key "aarch64_cortex-a72")"
[ "$key_changed_arch" != "$key_one" ]

printf 'baseline key test passed\n'
