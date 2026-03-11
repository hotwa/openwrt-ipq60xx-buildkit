#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

WORK_ROOT="$TMP_DIR/work"
WORKSPACE="$WORK_ROOT/IPQ60XX-NOWIFI"
IB_ROOT="$TMP_DIR/imagebuilder"
LOCK_FILE="$TMP_DIR/lock"

mkdir -p "$WORKSPACE/wrt/bin/targets/qualcommax/ipq60xx/packages"
mkdir -p "$WORKSPACE/wrt/bin/packages/aarch64_cortex-a53/base"
mkdir -p "$WORKSPACE/wrt/bin/packages/aarch64_cortex-a53/luci"
mkdir -p "$WORKSPACE/wrt/bin/packages/aarch64_cortex-a53/routing"
mkdir -p "$IB_ROOT/staging_dir/host/bin"

touch "$WORKSPACE/wrt/bin/targets/qualcommax/ipq60xx/packages/kernel-test.apk"
touch "$WORKSPACE/wrt/bin/packages/aarch64_cortex-a53/base/base-files-test.apk"
touch "$WORKSPACE/wrt/bin/packages/aarch64_cortex-a53/luci/luci-app-nikki-test.apk"

cat > "$LOCK_FILE" <<'EOF'
CI_BASE_REPO=test/base
CI_BASE_COMMIT=deadbeef
WRT_REPO=test/wrt
WRT_COMMIT=cafebabe
OFFICIAL_APK_FEEDS="https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/base/packages.adb"
CUSTOM_APK_FEEDS=""
PROFILES="IPQ60XX-NOWIFI"
EOF

cat > "$IB_ROOT/staging_dir/host/bin/apk" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      output="$2"
      shift 2
      ;;
    mkndx|--allow-untrusted)
      shift
      ;;
    *)
      shift
      ;;
  esac
done
[ -n "$output" ] || exit 1
printf 'stub-index\n' > "$output"
EOF
chmod +x "$IB_ROOT/staging_dir/host/bin/apk"

export LOCK_FILE
export PROFILE="IPQ60XX-NOWIFI"
export WORK_ROOT
export BUILD_FIRMWARE_LIB_ONLY=true

# shellcheck disable=SC1091
. "$ROOT_DIR/ci/build_firmware.sh"

repo_file="$TMP_DIR/repositories"
: > "$repo_file"

stage_local_imagebuilder_repos "$IB_ROOT"
write_imagebuilder_repositories "$repo_file" "$IB_ROOT"

grep -qxF "file://$IB_ROOT/local/target/packages.adb" "$repo_file"
grep -qxF "file://$IB_ROOT/local/base/packages.adb" "$repo_file"
grep -qxF "file://$IB_ROOT/local/luci/packages.adb" "$repo_file"

if grep -q 'file://.*/local/routing/packages.adb' "$repo_file"; then
  printf 'unexpected empty routing repo in repositories\n' >&2
  exit 1
fi

if grep -q 'downloads.immortalwrt.org' "$repo_file"; then
  printf 'unexpected remote feed in repositories\n' >&2
  exit 1
fi

if grep -q '^local/' "$repo_file"; then
  printf 'unexpected relative repo entry in repositories\n' >&2
  exit 1
fi

printf 'local imagebuilder repository test passed\n'
