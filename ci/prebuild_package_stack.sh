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
run_build_flow
build_imagebuilder

artifact_name="$(baseline_artifact_name "$WRT_ARCH")"
artifact_dir="$PREBUILT_DIST_DIR/$artifact_name"

note "prepare prebuilt imagebuilder repository workspace"
prepare_imagebuilder_workspace "$IMAGEBUILDER_ARCHIVE" "$IMAGEBUILDER_DIR"
stage_local_imagebuilder_repos "$IMAGEBUILDER_ROOT"

rm -rf "$artifact_dir"
mkdir -p "$artifact_dir"
cp -Rf "$IMAGEBUILDER_ROOT/local/." "$artifact_dir/"

cat > "$artifact_dir/prebuilt-stack.env" <<EOF
BASELINE_KEY=$(compute_baseline_key "$WRT_ARCH")
BASELINE_ARTIFACT_NAME=$artifact_name
PROFILE=$PROFILE
TARGET=$TARGET
WRT_ARCH=$WRT_ARCH
CI_BASE_COMMIT=$CI_BASE_COMMIT
WRT_COMMIT=$WRT_COMMIT
SOURCE_LUCI_APP_PODMAN_REF=$SOURCE_LUCI_APP_PODMAN_REF
EOF

note "prebuilt stack artifact exported: $artifact_dir"
