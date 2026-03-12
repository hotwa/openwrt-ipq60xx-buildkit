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
DAVIDTALL_EXCLUDED_PACKAGES="zerotier"
SOURCE_OVERLAY_PACKAGES="kmod-fs-nfs kmod-fs-nfsd kmod-fs-nfs-v4 kmod-dm nss-firmware-ipq60xx nss-firmware nss-eip-firmware"
IMAGEBUILDER_ALL_PACKAGES="podman conmon external-protocol netavark luci-app-podman tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn kmod-fs-nfs kmod-fs-nfsd kmod-fs-nfs-v4"
PROFILES="IPQ60XX-NOWIFI"
EOF

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_zerotier=y
# CONFIG_PACKAGE_luci-app-podman is not set
# CONFIG_PACKAGE_podman is not set
# CONFIG_PACKAGE_tailscale is not set
# CONFIG_PACKAGE_nfs-kernel-server is not set
EOF

PREBUILT_CONFIG_FILE="$TMP_DIR/.config.prebuilt"
cat > "$PREBUILT_CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=m
CONFIG_PACKAGE_tailscale=m
CONFIG_PACKAGE_nfs-kernel-server=m
CONFIG_PACKAGE_kmod-fs-nfs=y
CONFIG_PACKAGE_nss-firmware-ipq60xx=y
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

grep -qxF 'CONFIG_PACKAGE_luci-app-podman=y' "$CONFIG_FILE" || \
  printf '%s\n' 'CONFIG_PACKAGE_luci-app-podman=y' >> "$CONFIG_FILE"
disable_excluded_packages "$CONFIG_FILE"
enable_source_overlay_packages "$CONFIG_FILE"
enable_imagebuilder_source_build_packages "$CONFIG_FILE"

grep -qxF '# CONFIG_PACKAGE_zerotier is not set' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_luci-app-podman=y' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_kmod-fs-nfs=y' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_nss-firmware-ipq60xx=y' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_podman=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_tailscale=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_nfs-kernel-server=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_rpcbind=m' "$CONFIG_FILE"

if grep -q '^CONFIG_PACKAGE_kmod-fs-nfs=m$' "$CONFIG_FILE"; then
  printf 'kernel overlay package should stay built-in, not module-only\n' >&2
  exit 1
fi

export USE_PREBUILT_STACK=true
enable_source_overlay_packages "$PREBUILT_CONFIG_FILE"
enable_imagebuilder_source_build_packages "$PREBUILT_CONFIG_FILE"
disable_prebuilt_stack_packages "$PREBUILT_CONFIG_FILE"

grep -qxF '# CONFIG_PACKAGE_luci-app-podman is not set' "$PREBUILT_CONFIG_FILE"
grep -qxF '# CONFIG_PACKAGE_podman is not set' "$PREBUILT_CONFIG_FILE"
grep -qxF '# CONFIG_PACKAGE_tailscale is not set' "$PREBUILT_CONFIG_FILE"
grep -qxF '# CONFIG_PACKAGE_nfs-kernel-server is not set' "$PREBUILT_CONFIG_FILE"
grep -qxF '# CONFIG_PACKAGE_kmod-fs-nfs is not set' "$PREBUILT_CONFIG_FILE"
grep -qxF '# CONFIG_PACKAGE_nss-firmware-ipq60xx is not set' "$PREBUILT_CONFIG_FILE"

printf 'source build package selection test passed\n'
