#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/lock"
WORK_ROOT="$TMP_DIR/work"
WORKSPACE="$WORK_ROOT/IPQ60XX-NOWIFI"

mkdir -p "$WORKSPACE/Config"

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=cafebabe
TARGET=qualcommax/ipq60xx
WRT_ARCH=aarch64_cortex-a53
PROFILES="IPQ60XX-NOWIFI"
EOF

cat > "$WORKSPACE/Config/IPQ60XX-NOWIFI.txt" <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y
EOF

export LOCK_FILE
export PROFILE="IPQ60XX-NOWIFI"
export WORK_ROOT
export BUILD_FIRMWARE_LIB_ONLY=true

grep() {
  if [ "${1:-}" = "-m" ] && [ "${2:-}" = "1" ] && [ "${3:-}" = "-oP" ]; then
    local file="$5"
    perl -ne 'print "$1\n" if /^CONFIG_TARGET_(\w+)=y$/' "$file" | head -n 1
    return
  fi
  command grep "$@"
}

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/build_firmware.sh"

prepare_env_vars

[ "$WRT_TARGET" = "QUALCOMMAX" ]
[ "$WRT_ARCH" = "qualcommax_ipq60xx" ]
[ "$PACKAGE_ARCH" = "aarch64_cortex-a53" ]

printf 'locked wrt arch test passed\n'
