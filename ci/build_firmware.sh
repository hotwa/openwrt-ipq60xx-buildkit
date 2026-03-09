#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

require_cmd git bash find grep sed awk xargs

source_lock

PROFILE="${PROFILE:-}"
[ -n "$PROFILE" ] || fail "PROFILE is required"

WORK_ROOT="${WORK_ROOT:-$ROOT_DIR/.workspace}"
WORKSPACE="$WORK_ROOT/$PROFILE"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/dist/out/$PROFILE}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
TEST_ONLY="${TEST_ONLY:-false}"

WRT_THEME="${WRT_THEME:-argon}"
WRT_NAME="${WRT_NAME:-DAE-WRT}"
WRT_SSID="${WRT_SSID:-DAE-WRT}"
WRT_WORD="${WRT_WORD:-12345678}"
WRT_IP="${WRT_IP:-192.168.10.1}"
WRT_PW="${WRT_PW:-无}"
WRT_PACKAGE="${WRT_PACKAGE:-}"
CI_NAME="${CI_NAME:-buildkit-firmware}"

fetch_repo_commit() {
  local repo="$1"
  local commit="$2"
  local dest="$3"

  rm -rf "$dest"
  mkdir -p "$dest"
  git -C "$dest" init -q
  git -C "$dest" remote add origin "https://github.com/$repo.git"
  git -C "$dest" fetch --depth 1 origin "$commit"
  git -C "$dest" checkout -q FETCH_HEAD
}

prepare_workspace() {
  note "prepare workspace: $WORKSPACE"
  rm -rf "$WORKSPACE"
  mkdir -p "$WORKSPACE"

  note "clone CI base: $CI_BASE_REPO@$CI_BASE_COMMIT"
  fetch_repo_commit "$CI_BASE_REPO" "$CI_BASE_COMMIT" "$WORKSPACE"

  note "clone WRT source: $WRT_REPO@$WRT_COMMIT"
  fetch_repo_commit "$WRT_REPO" "$WRT_COMMIT" "$WORKSPACE/wrt"
}

init_host_environment() {
  note "initialize host build environment"
  sudo bash "$WORKSPACE/Scripts/init_build_environment.sh"
}

prepare_env_vars() {
  export GITHUB_WORKSPACE="$WORKSPACE"
  export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-hotwa/openwrt-ipq60xx-buildkit}"
  export WRT_DIR="wrt"
  export WRT_CONFIG="$PROFILE"
  export WRT_THEME
  export WRT_NAME
  export WRT_SSID
  export WRT_WORD
  export WRT_IP
  export WRT_PW
  export WRT_PACKAGE
  export CI_NAME
  export WRT_REPO="https://github.com/$WRT_REPO.git"
  export WRT_BRANCH="$WRT_COMMIT"
  export WRT_SOURCE="$WRT_REPO"
  export WRT_TEST="$TEST_ONLY"
  export WRT_DATE
  export WRT_TARGET
  export WRT_ARCH

  WRT_DATE="$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")"
  WRT_TARGET="$(grep -m 1 -oP '^CONFIG_TARGET_\K[\w]+(?=\=y)' "$WORKSPACE/Config/$PROFILE.txt" | tr '[:lower:]' '[:upper:]')"
  WRT_ARCH="$(sed -n 's/.*_DEVICE_\(.*\)_DEVICE_.*/\1/p' "$WORKSPACE/Config/$PROFILE.txt" | head -n 1)"

  [ -n "$WRT_TARGET" ] || fail "failed to resolve WRT_TARGET from $PROFILE"
  [ -n "$WRT_ARCH" ] || fail "failed to resolve WRT_ARCH from $PROFILE"
}

normalize_scripts() {
  note "normalize scripts"
  find "$WORKSPACE" -maxdepth 3 -type f \( -iname "*.txt" -o -iname "*.sh" \) -print0 | \
    xargs -0 dos2unix >/dev/null 2>&1 || true
  find "$WORKSPACE" -maxdepth 3 -type f -iname "*.sh" -exec chmod +x {} +
}

run_build_flow() {
  note "update feeds"
  (
    cd "$WORKSPACE/wrt"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
  )

  note "apply custom packages"
  (
    cd "$WORKSPACE/wrt/package"
    "$WORKSPACE/Scripts/Packages.sh"
    "$WORKSPACE/Scripts/Handles.sh"
  )

  note "generate config"
  (
    # shellcheck disable=SC1090
    . "$WORKSPACE/Scripts/function.sh"
    cd "$WORKSPACE/wrt"
    generate_config
    "$WORKSPACE/Scripts/Settings.sh"
    make defconfig -j"$JOBS"
  )

  if [ "$TEST_ONLY" = "true" ]; then
    note "test-only mode enabled, skip download and compile"
    return
  fi

  note "download packages"
  (
    cd "$WORKSPACE/wrt"
    make download -j"$JOBS"
  )

  note "compile firmware"
  (
    cd "$WORKSPACE/wrt"
    make -j"$JOBS" || make -j1 V=s
  )
}

export_artifacts() {
  note "export artifacts: $OUT_DIR"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  cp -f "$WORKSPACE/wrt/.config" "$OUT_DIR/Config-$PROFILE.txt"

  if [ "$TEST_ONLY" = "true" ]; then
    return
  fi

  find "$WORKSPACE/wrt/bin/targets" -type d -name packages -prune -exec rm -rf {} +
  cp -Rf "$WORKSPACE/wrt/bin/targets" "$OUT_DIR/"
}

prepare_workspace
prepare_env_vars
init_host_environment
normalize_scripts
run_build_flow
export_artifacts

note "build completed for $PROFILE"
