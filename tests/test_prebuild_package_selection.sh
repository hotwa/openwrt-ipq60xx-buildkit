#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/lock"
CONFIG_FILE="$TMP_DIR/.config"

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=cafebabe
SOURCE_LUCI_APP_PODMAN_REF=feedface
TARGET=qualcommax/ipq60xx
WRT_ARCH=aarch64_cortex-a53
DAVIDTALL_EXCLUDED_PACKAGES="zerotier"
SOURCE_OVERLAY_PACKAGES="kmod-fs-nfs kmod-fs-nfsd kmod-fs-nfs-v4 kmod-dm nss-firmware-ipq60xx nss-firmware nss-eip-firmware"
IMAGEBUILDER_ALL_PACKAGES="podman conmon external-protocol netavark luci-app-podman tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn kmod-fs-nfs kmod-fs-nfsd kmod-fs-nfs-v4"
PROFILES="IPQ60XX-NOWIFI"
EOF

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_zerotier=y
# CONFIG_PACKAGE_luci-app-podman is not set
# CONFIG_PACKAGE_podman is not set
CONFIG_PACKAGE_luci=y
EOF

export LOCK_FILE
export PROFILE="IPQ60XX-NOWIFI"
export WORK_ROOT="$TMP_DIR/work"
export BUILD_FIRMWARE_LIB_ONLY=true

sed() {
  if [ "${1:-}" = "-i" ]; then
    shift
    local exprs=()
    while [ "${1:-}" = "-e" ]; do
      exprs+=("-e" "$2")
      shift 2
    done
    local file="$1"
    command sed "${exprs[@]}" "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    return
  fi
  command sed "$@"
}

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/build_firmware.sh"

prepare_prebuild_package_only_config "$CONFIG_FILE"

grep -qxF 'CONFIG_TARGET_qualcommax=y' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_luci-app-podman=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_podman=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_tailscale=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_nfs-kernel-server=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_kmod-fs-nfs=m' "$CONFIG_FILE"
grep -qxF '# CONFIG_PACKAGE_zerotier is not set' "$CONFIG_FILE"

if grep -q '^CONFIG_PACKAGE_dnsmasq-full=' "$CONFIG_FILE"; then
  printf 'unexpected unrelated package kept in prebuild config\n' >&2
  exit 1
fi

if grep -q '^CONFIG_PACKAGE_luci=' "$CONFIG_FILE"; then
  printf 'unexpected full firmware package kept in prebuild config\n' >&2
  exit 1
fi

printf 'prebuild package selection test passed\n'
