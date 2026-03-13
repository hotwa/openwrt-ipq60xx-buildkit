#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/lock"
WORK_ROOT="$TMP_DIR/work"
WORKSPACE="$WORK_ROOT/IPQ60XX-NOWIFI"
MAKE_LOG="$TMP_DIR/make.log"

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=cafebabe
TARGET=qualcommax/ipq60xx
WRT_ARCH=aarch64_cortex-a53
PROFILES="IPQ60XX-NOWIFI"
EOF

mkdir -p "$WORKSPACE/wrt" "$TMP_DIR/bin"

cat > "$TMP_DIR/bin/make" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >> "$MAKE_LOG"
EOF
chmod +x "$TMP_DIR/bin/make"

export PATH="$TMP_DIR/bin:$PATH"
export LOCK_FILE
export PROFILE="IPQ60XX-NOWIFI"
export WORK_ROOT
export BUILD_FIRMWARE_LIB_ONLY=true
export JOBS=5

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/build_firmware.sh"

compile_prebuild_stack_packages

grep -q 'package/feeds/packages/tailscale/compile' "$MAKE_LOG"
grep -q 'package/feeds/luci/luci-app-tailscale-community/compile' "$MAKE_LOG"
grep -q 'package/feeds/packages/podman/compile' "$MAKE_LOG"
grep -q 'package/feeds/packages/conmon/compile' "$MAKE_LOG"
grep -q 'package/feeds/packages/external-protocol/compile' "$MAKE_LOG"
grep -q 'package/feeds/packages/netavark/compile' "$MAKE_LOG"
grep -q 'package/feeds/packages/rpcbind/compile' "$MAKE_LOG"
grep -q 'package/feeds/packages/nfs-kernel-server/compile' "$MAKE_LOG"
grep -q 'package/feeds/luci/luci-app-nfs/compile' "$MAKE_LOG"
grep -q 'package/feeds/nss_packages/nss-firmware/compile' "$MAKE_LOG"
grep -q 'package/feeds/nss_packages/nss-eip-firmware/compile' "$MAKE_LOG"
grep -q 'package/luci-app-podman/compile' "$MAKE_LOG"

if grep -q 'package/compile' "$MAKE_LOG"; then
  printf 'unexpected global package/compile target in prebuild\n' >&2
  exit 1
fi

if ! grep -q -- '-j5' "$MAKE_LOG"; then
  printf 'expected prebuild compile targets to use requested parallelism\n' >&2
  exit 1
fi

printf 'prebuild compile target test passed\n'
