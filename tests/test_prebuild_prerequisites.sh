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
export JOBS=7

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/build_firmware.sh"

prepare_package_stack_build_prerequisites

grep -qxF 'tools/install -j7' "$MAKE_LOG"
grep -qxF 'toolchain/install -j7' "$MAKE_LOG"
grep -qxF 'target/linux/prepare -j7' "$MAKE_LOG"
grep -qxF 'target/linux/oldconfig -j7' "$MAKE_LOG"

if [ "$(sed -n '1p' "$MAKE_LOG")" != 'tools/install -j7' ]; then
  printf 'expected tools/install to run first\n' >&2
  exit 1
fi

if [ "$(sed -n '2p' "$MAKE_LOG")" != 'toolchain/install -j7' ]; then
  printf 'expected toolchain/install to run second\n' >&2
  exit 1
fi

if [ "$(sed -n '3p' "$MAKE_LOG")" != 'target/linux/prepare -j7' ]; then
  printf 'expected target/linux/prepare to run third\n' >&2
  exit 1
fi

if [ "$(sed -n '4p' "$MAKE_LOG")" != 'target/linux/oldconfig -j7' ]; then
  printf 'expected target/linux/oldconfig to run fourth\n' >&2
  exit 1
fi

if grep -q '^package/compile' "$MAKE_LOG"; then
  printf 'unexpected package compile before prerequisites\n' >&2
  exit 1
fi

if grep -q '^target/linux/compile' "$MAKE_LOG"; then
  printf 'unexpected target/linux/compile in package-stack prerequisites\n' >&2
  exit 1
fi

printf 'prebuild prerequisite test passed\n'
