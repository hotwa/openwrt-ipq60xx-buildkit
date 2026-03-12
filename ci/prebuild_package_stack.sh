#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

require_cmd git bash find grep sed awk xargs tar sort cp
source_lock

PROFILE="${PROFILE:-IPQ60XX-NOWIFI}"
PREBUILT_DIST_DIR="${PREBUILT_DIST_DIR:-$ROOT_DIR/dist/prebuilt}"

export PROFILE
export BUILD_FIRMWARE_LIB_ONLY=true
export TEST_ONLY=false
export ASSEMBLE_IMAGEBUILDER=false
export USE_PREBUILT_STACK=false

# shellcheck disable=SC1091
. "$SCRIPT_DIR/build_firmware.sh"

prepare_workspace
prepare_env_vars
init_host_environment
normalize_scripts
run_prebuild_package_stack_flow

artifact_name="$(baseline_artifact_name "$PACKAGE_ARCH")"
artifact_dir="$PREBUILT_DIST_DIR/$artifact_name"
apk_bin="$WORKSPACE/wrt/staging_dir/host/bin/apk"

note "stage prebuilt package-stack repositories"
stage_source_build_repos_to_root "$artifact_dir" "$apk_bin"

[ -x "$apk_bin" ] || fail "host apk tool missing after package-stack build: $apk_bin"

cat > "$artifact_dir/prebuilt-stack.env" <<EOF
BASELINE_KEY=$(compute_baseline_key "$PACKAGE_ARCH")
BASELINE_ARTIFACT_NAME=$artifact_name
BASELINE_RELEASE_TAG=$(baseline_release_tag "$PACKAGE_ARCH")
BASELINE_RELEASE_ASSET=$(baseline_release_asset_name "$PACKAGE_ARCH")
PROFILE=$PROFILE
TARGET=$TARGET
WRT_ARCH=$PACKAGE_ARCH
UPSTREAM_WRT_ARCH=$WRT_ARCH
CI_BASE_COMMIT=$CI_BASE_COMMIT
WRT_COMMIT=$WRT_COMMIT
SOURCE_LUCI_APP_PODMAN_REF=$SOURCE_LUCI_APP_PODMAN_REF
EOF

note "prebuilt stack artifact exported: $artifact_dir"
