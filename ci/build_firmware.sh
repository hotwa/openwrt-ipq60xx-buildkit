#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

require_cmd git bash find grep sed awk xargs tar sort

source_lock

PROFILE="${PROFILE:-}"
[ -n "$PROFILE" ] || fail "PROFILE is required"

WORK_ROOT="${WORK_ROOT:-$ROOT_DIR/.workspace}"
WORKSPACE="$WORK_ROOT/$PROFILE"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/dist/out/$PROFILE}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
TEST_ONLY="${TEST_ONLY:-false}"
ASSEMBLE_IMAGEBUILDER="${ASSEMBLE_IMAGEBUILDER:-false}"

WRT_THEME="${WRT_THEME:-argon}"
WRT_NAME="${WRT_NAME:-DAE-WRT}"
WRT_SSID="${WRT_SSID:-DAE-WRT}"
WRT_WORD="${WRT_WORD:-12345678}"
WRT_IP="${WRT_IP:-192.168.10.1}"
WRT_PW="${WRT_PW:-无}"
WRT_PACKAGE="${WRT_PACKAGE:-}"
CI_NAME="${CI_NAME:-buildkit-firmware}"
IMAGEBUILDER_DIR="$WORKSPACE/.imagebuilder"
IMAGEBUILDER_OUTPUT_DIR="$OUT_DIR/imagebuilder"
IMAGEBUILDER_ARCHIVE=""

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

prepare_overlay_packages() {
  local podman_makefile="$WORKSPACE/wrt/package/luci-app-podman/Makefile"

  if [ ! -f "$podman_makefile" ]; then
    note "fetch luci-app-podman source overlay: $SOURCE_LUCI_APP_PODMAN_REPO@$SOURCE_LUCI_APP_PODMAN_REF"
    fetch_repo_commit "$SOURCE_LUCI_APP_PODMAN_REPO" "$SOURCE_LUCI_APP_PODMAN_REF" "$WORKSPACE/wrt/package/luci-app-podman"
  fi

  [ -f "$podman_makefile" ] || fail "missing luci-app-podman source overlay"
  # Build only the lightweight LuCI frontend here; podman runtime comes from ImageBuilder.
  sed -i 's/+podman//g' "$podman_makefile"
}

disable_excluded_packages() {
  local config_file="$1"
  local pkg

  for pkg in $DAVIDTALL_EXCLUDED_PACKAGES; do
    sed -i \
      -e "/^CONFIG_PACKAGE_${pkg}=.*/d" \
      -e "/^# CONFIG_PACKAGE_${pkg} is not set$/d" \
      "$config_file"
    printf '# CONFIG_PACKAGE_%s is not set\n' "$pkg" >> "$config_file"
  done
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

  note "prepare overlay packages"
  prepare_overlay_packages

  note "generate config"
  (
    # shellcheck disable=SC1090
    . "$WORKSPACE/Scripts/function.sh"
    cd "$WORKSPACE/wrt"
    generate_config
    grep -qxF 'CONFIG_PACKAGE_luci-app-podman=y' .config || printf '%s\n' 'CONFIG_PACKAGE_luci-app-podman=y' >> .config
    disable_excluded_packages .config
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

build_imagebuilder() {
  local archive

  archive="$(find "$WORKSPACE/wrt/bin/targets" -type f -name '*imagebuilder*.tar.zst' | head -n 1 || true)"
  if [ -n "$archive" ]; then
    note "reuse existing imagebuilder archive: $archive"
    IMAGEBUILDER_ARCHIVE="$archive"
    return
  fi

  note "build imagebuilder archive"
  (
    cd "$WORKSPACE/wrt"
    make target/imagebuilder/compile -j"$JOBS" || make target/imagebuilder/compile -j1 V=s
  )

  archive="$(find "$WORKSPACE/wrt/bin/targets" -type f -name '*imagebuilder*.tar.zst' | head -n 1 || true)"
  [ -n "$archive" ] || fail "imagebuilder archive not found after build"
  IMAGEBUILDER_ARCHIVE="$archive"
}

append_unique_repo() {
  local repo_file="$1"
  local repo_url="$2"

  grep -qxF "$repo_url" "$repo_file" 2>/dev/null || printf '%s\n' "$repo_url" >> "$repo_file"
}

resolve_target_package_repo() {
  local repo_dir

  repo_dir="$(find "$WORKSPACE/wrt/bin/targets" -type f -path '*/packages/packages.adb' -print | head -n 1 || true)"
  [ -n "$repo_dir" ] || fail "same-build target package repository not found"
  dirname "$repo_dir"
}

stage_local_imagebuilder_repo() {
  local ib_root="$1"
  local local_repo="$2"

  [ -f "$local_repo/packages.adb" ] || fail "missing packages.adb in local repository: $local_repo"
  rm -rf "$ib_root/packages"
  ln -s "$local_repo" "$ib_root/packages"
}

write_imagebuilder_repositories() {
  local repo_file="$1"
  local repo_url

  : > "$repo_file"
  # ImageBuilder expects its same-build target repository under packages/packages.adb.
  printf '%s\n' "packages/packages.adb" >> "$repo_file"

  while read -r repo_url; do
    [ -n "$repo_url" ] || continue
    append_unique_repo "$repo_file" "$repo_url"
  done <<< "$(printf '%s\n%s\n' "$OFFICIAL_APK_FEEDS" "$CUSTOM_APK_FEEDS" | tr ' ' '\n')"
}

load_profile_devices() {
  sed -n 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_\(.*\)=y$/\1/p' "$WORKSPACE/Config/$PROFILE.txt" | sort -u
}

assemble_imagebuilder_images() {
  local archive ib_root repo_file device bin_dir local_repo
  local preload_packages="$IMAGEBUILDER_ALL_PACKAGES"

  build_imagebuilder
  archive="$IMAGEBUILDER_ARCHIVE"
  [ -n "$archive" ] || fail "imagebuilder archive path is empty"

  note "prepare imagebuilder workspace"
  rm -rf "$IMAGEBUILDER_DIR"
  mkdir -p "$IMAGEBUILDER_DIR"
  tar --zstd -xf "$archive" -C "$IMAGEBUILDER_DIR"
  ib_root="$(find "$IMAGEBUILDER_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
  [ -n "$ib_root" ] || fail "failed to unpack imagebuilder archive"

  local_repo="$(resolve_target_package_repo)"
  note "stage same-build local repository: $local_repo"
  stage_local_imagebuilder_repo "$ib_root" "$local_repo"

  repo_file="$ib_root/repositories"
  write_imagebuilder_repositories "$repo_file"

  mkdir -p "$IMAGEBUILDER_OUTPUT_DIR"
  while read -r device; do
    [ -n "$device" ] || continue
    bin_dir="$IMAGEBUILDER_OUTPUT_DIR/$device"
    mkdir -p "$bin_dir"
    note "assemble imagebuilder image: $device"
    (
      cd "$ib_root"
      make image \
        CONFIG_SIGNATURE_CHECK= \
        PROFILE="$device" \
        FILES="$WORKSPACE/files" \
        PACKAGES="$preload_packages" \
        EXTRA_IMAGE_NAME=preload \
        BIN_DIR="$bin_dir"
    )
  done < <(load_profile_devices)
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
  if [ "$ASSEMBLE_IMAGEBUILDER" = "true" ] && [ -d "$IMAGEBUILDER_OUTPUT_DIR" ]; then
    cp -Rf "$IMAGEBUILDER_OUTPUT_DIR" "$OUT_DIR/"
  fi
}

prepare_workspace
prepare_env_vars
init_host_environment
normalize_scripts
run_build_flow
[ "$TEST_ONLY" = "true" ] || [ "$ASSEMBLE_IMAGEBUILDER" != "true" ] || assemble_imagebuilder_images
export_artifacts

note "build completed for $PROFILE"
