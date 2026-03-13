#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOCK_FILE="$TMP_DIR/lock"
WORK_ROOT="$TMP_DIR/work"
WORKSPACE="$WORK_ROOT/IPQ60XX-NOWIFI"
CONFIG_FILE="$WORKSPACE/wrt/.config"

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

mkdir -p "$WORKSPACE/wrt" "$WORKSPACE/Scripts" "$TMP_DIR/bin"

cat > "$WORKSPACE/Scripts/function.sh" <<'EOF'
generate_config() {
  cat > .config <<'CONFIG'
CONFIG_TARGET_qualcommax=y
CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG
}
EOF

cat > "$WORKSPACE/Scripts/Settings.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'CONFIG_PACKAGE_firewall4=y' >> "$PWD/.config"
EOF
chmod +x "$WORKSPACE/Scripts/Settings.sh"

cat > "$TMP_DIR/bin/make" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "defconfig" ]; then
  printf '%s\n' 'CONFIG_PACKAGE_kmod-gpio-button-hotplug=m' >> .config
  printf '%s\n' 'CONFIG_PACKAGE_dnsmasq-full=y' >> .config
  exit 0
fi
exit 0
EOF
chmod +x "$TMP_DIR/bin/make"

export PATH="$TMP_DIR/bin:$PATH"
export LOCK_FILE
export PROFILE="IPQ60XX-NOWIFI"
export WORK_ROOT
export BUILD_FIRMWARE_LIB_ONLY=true
export JOBS=5

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

generate_prebuild_package_stack_config

grep -qxF 'CONFIG_TARGET_qualcommax=y' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_luci-app-podman=m' "$CONFIG_FILE"
grep -qxF 'CONFIG_PACKAGE_tailscale=m' "$CONFIG_FILE"

if grep -q '^CONFIG_PACKAGE_kmod-gpio-button-hotplug=' "$CONFIG_FILE"; then
  printf 'unexpected target default kmod kept after final prebuild cleanup\n' >&2
  exit 1
fi

if grep -q '^CONFIG_PACKAGE_dnsmasq-full=' "$CONFIG_FILE"; then
  printf 'unexpected target default package kept after final prebuild cleanup\n' >&2
  exit 1
fi

if grep -q '^CONFIG_PACKAGE_firewall4=' "$CONFIG_FILE"; then
  printf 'unexpected settings package kept after final prebuild cleanup\n' >&2
  exit 1
fi

printf 'prebuild config final cleanup test passed\n'
