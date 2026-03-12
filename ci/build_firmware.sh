#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

require_cmd git bash find grep sed awk xargs tar sort

source_lock
LOCK_PACKAGE_ARCH="${WRT_ARCH:-}"

PROFILE="${PROFILE:-}"
BUILD_FIRMWARE_LIB_ONLY="${BUILD_FIRMWARE_LIB_ONLY:-false}"

if [ "$BUILD_FIRMWARE_LIB_ONLY" != "true" ]; then
  [ -n "$PROFILE" ] || fail "PROFILE is required"
fi

WORK_ROOT="${WORK_ROOT:-$ROOT_DIR/.workspace}"
WORKSPACE="$WORK_ROOT/$PROFILE"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/dist/out/$PROFILE}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
TEST_ONLY="${TEST_ONLY:-false}"
ASSEMBLE_IMAGEBUILDER="${ASSEMBLE_IMAGEBUILDER:-false}"
USE_PREBUILT_STACK="${USE_PREBUILT_STACK:-false}"
PREBUILT_STACK_DIR="${PREBUILT_STACK_DIR:-}"
PACKAGE_ARCH="${PACKAGE_ARCH:-$LOCK_PACKAGE_ARCH}"

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
IMAGEBUILDER_ROOT=""

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

detect_profile_wrt_arch() {
  local config_file="$1"

  sed -n 's/.*_DEVICE_\(.*\)_DEVICE_.*/\1/p' "$config_file" | head -n 1
}

prepare_env_vars() {
  local detected_wrt_arch

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
  export PACKAGE_ARCH

  WRT_DATE="$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")"
  WRT_TARGET="$(grep -m 1 -oP '^CONFIG_TARGET_\K[\w]+(?=\=y)' "$WORKSPACE/Config/$PROFILE.txt" | tr '[:lower:]' '[:upper:]')"
  detected_wrt_arch="$(detect_profile_wrt_arch "$WORKSPACE/Config/$PROFILE.txt")"
  # Upstream scripts use WRT_ARCH as the target/subtarget token such as
  # "qualcommax_ipq60xx", while this repository uses the lock's WRT_ARCH as the
  # package architecture for baseline identity. Keep them separate.
  WRT_ARCH="$detected_wrt_arch"

  [ -n "$WRT_TARGET" ] || fail "failed to resolve WRT_TARGET from $PROFILE"
  [ -n "$WRT_ARCH" ] || fail "failed to resolve WRT_ARCH from $PROFILE"
  [ -n "$PACKAGE_ARCH" ] || fail "failed to resolve PACKAGE_ARCH from lock"
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

set_package_config_state() {
  local config_file="$1"
  local pkg="$2"
  local state="$3"

  sed -i \
    -e "/^CONFIG_PACKAGE_${pkg}=.*/d" \
    -e "/^# CONFIG_PACKAGE_${pkg} is not set$/d" \
    "$config_file"

  case "$state" in
    unset)
      printf '# CONFIG_PACKAGE_%s is not set\n' "$pkg" >> "$config_file"
      ;;
    y|m)
      printf 'CONFIG_PACKAGE_%s=%s\n' "$pkg" "$state" >> "$config_file"
      ;;
    *)
      fail "unsupported package state: $state"
      ;;
  esac
}

clear_package_config_states() {
  local config_file="$1"

  sed -i \
    -e '/^CONFIG_PACKAGE_[^=]*=.*/d' \
    -e '/^# CONFIG_PACKAGE_.* is not set$/d' \
    "$config_file"
}

package_in_list() {
  local pkg="$1"
  local package_list="$2"

  printf '%s\n' "$package_list" | tr ' ' '\n' | awk 'NF' | grep -qxF "$pkg"
}

prebuilt_stack_package_list() {
  printf '%s\n%s\n' "$IMAGEBUILDER_ALL_PACKAGES" "$SOURCE_OVERLAY_PACKAGES" | \
    tr ' ' '\n' | awk 'NF && !seen[$0]++'
}

package_built_from_prebuilt_stack() {
  local pkg="$1"

  prebuilt_stack_package_list | grep -qxF "$pkg"
}

disable_prebuilt_stack_packages() {
  local config_file="$1"
  local pkg

  while read -r pkg; do
    [ -n "$pkg" ] || continue
    set_package_config_state "$config_file" "$pkg" unset
  done < <(prebuilt_stack_package_list)
}

enable_package_list_as_modules() {
  local config_file="$1"
  local package_list="$2"
  local pkg

  while read -r pkg; do
    [ -n "$pkg" ] || continue
    set_package_config_state "$config_file" "$pkg" m
  done < <(printf '%s\n' "$package_list" | tr ' ' '\n' | awk 'NF && !seen[$0]++')
}

prepare_prebuild_package_only_config() {
  local config_file="$1"

  clear_package_config_states "$config_file"
  enable_package_list_as_modules "$config_file" "$(prebuilt_stack_package_list)"
  disable_excluded_packages "$config_file"
}

validate_prebuilt_stack_dir() {
  local expected_artifact

  [ "$USE_PREBUILT_STACK" = "true" ] || return 0
  [ "$TEST_ONLY" = "true" ] && return 0

  expected_artifact="$(baseline_artifact_name "$PACKAGE_ARCH")"
  [ -n "$PREBUILT_STACK_DIR" ] || \
    fail "PREBUILT_STACK_DIR is required when USE_PREBUILT_STACK=true (expected artifact: $expected_artifact)"
  [ -d "$PREBUILT_STACK_DIR" ] || \
    fail "prebuilt stack directory not found: $PREBUILT_STACK_DIR (expected artifact: $expected_artifact)"
}

apply_nfs_kernel_server_v4_hotfix() {
  local nfs_makefile="$WORKSPACE/wrt/feeds/packages/net/nfs-kernel-server/Makefile"

  [ -f "$nfs_makefile" ] || return 0
  grep -q '/utils/nfsdcld/nfsdcld' "$nfs_makefile" || return 0
  grep -q '/ipkg-install/usr/sbin/rpc.idmapd' "$nfs_makefile" || return 0
  grep -q '\[ -x .*/utils/nfsdcld/nfsdcld' "$nfs_makefile" && \
    grep -q '\[ -x .*/ipkg-install/usr/sbin/rpc.idmapd' "$nfs_makefile" && return 0

  note "apply nfs-kernel-server-v4 install guards"
  awk '
    /^[[:space:]]*\$\(INSTALL_BIN\) \$\(PKG_BUILD_DIR\)\/utils\/nfsdcld\/nfsdcld \$\(1\)\/usr\/sbin\// {
      sub(/\$\(INSTALL_BIN\) \$\(PKG_BUILD_DIR\)\/utils\/nfsdcld\/nfsdcld \$\(1\)\/usr\/sbin\//,
          "[ -x $(PKG_BUILD_DIR)/utils/nfsdcld/nfsdcld ] \\&\\& $(INSTALL_BIN) $(PKG_BUILD_DIR)/utils/nfsdcld/nfsdcld $(1)/usr/sbin/ || true")
    }
    /^[[:space:]]*\$\(INSTALL_BIN\) \$\(PKG_INSTALL_DIR\)\/usr\/sbin\/rpc\.idmapd \$\(1\)\/usr\/sbin\// {
      sub(/\$\(INSTALL_BIN\) \$\(PKG_INSTALL_DIR\)\/usr\/sbin\/rpc\.idmapd \$\(1\)\/usr\/sbin\//,
          "[ -x $(PKG_INSTALL_DIR)/usr/sbin/rpc.idmapd ] \\&\\& $(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/sbin/rpc.idmapd $(1)/usr/sbin/ || true")
    }
    { print }
  ' "$nfs_makefile" > "$nfs_makefile.tmp"
  mv "$nfs_makefile.tmp" "$nfs_makefile"
}

disable_excluded_packages() {
  local config_file="$1"
  local pkg

  for pkg in $DAVIDTALL_EXCLUDED_PACKAGES; do
    set_package_config_state "$config_file" "$pkg" unset
  done
}

enable_source_overlay_packages() {
  local config_file="$1"
  local pkg

  for pkg in $SOURCE_OVERLAY_PACKAGES; do
    [ -n "$pkg" ] || continue
    if [ "$USE_PREBUILT_STACK" = "true" ] && package_built_from_prebuilt_stack "$pkg"; then
      continue
    fi
    set_package_config_state "$config_file" "$pkg" y
  done
}

package_selected_in_config() {
  local config_file="$1"
  local pkg="$2"
  local state="$3"

  grep -qxF "CONFIG_PACKAGE_${pkg}=${state}" "$config_file"
}

enable_imagebuilder_source_build_packages() {
  local config_file="$1"
  local pkg

  for pkg in $IMAGEBUILDER_ALL_PACKAGES; do
    [ -n "$pkg" ] || continue
    if package_selected_in_config "$config_file" "$pkg" "y"; then
      continue
    fi
    if [ "$USE_PREBUILT_STACK" = "true" ] && package_built_from_prebuilt_stack "$pkg"; then
      continue
    fi
    if printf '%s\n' "$SOURCE_OVERLAY_PACKAGES" | tr ' ' '\n' | grep -qxF "$pkg"; then
      continue
    fi
    set_package_config_state "$config_file" "$pkg" m
  done
}

run_build_flow() {
  note "update feeds"
  (
    cd "$WORKSPACE/wrt"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    apply_nfs_kernel_server_v4_hotfix
  )

  note "apply custom packages"
  (
    cd "$WORKSPACE/wrt/package"
    "$WORKSPACE/Scripts/Packages.sh"
    "$WORKSPACE/Scripts/Handles.sh"
  )

  if [ "$USE_PREBUILT_STACK" != "true" ]; then
    note "prepare overlay packages"
    prepare_overlay_packages
  fi

  note "generate config"
  (
    # shellcheck disable=SC1090
    . "$WORKSPACE/Scripts/function.sh"
    cd "$WORKSPACE/wrt"
    generate_config
    if [ "$USE_PREBUILT_STACK" != "true" ]; then
      grep -qxF 'CONFIG_PACKAGE_luci-app-podman=y' .config || printf '%s\n' 'CONFIG_PACKAGE_luci-app-podman=y' >> .config
    else
      disable_prebuilt_stack_packages .config
    fi
    disable_excluded_packages .config
    enable_source_overlay_packages .config
    enable_imagebuilder_source_build_packages .config
    "$WORKSPACE/Scripts/Settings.sh"
    if [ "$USE_PREBUILT_STACK" = "true" ]; then
      disable_prebuilt_stack_packages .config
    fi
    disable_excluded_packages .config
    enable_source_overlay_packages .config
    enable_imagebuilder_source_build_packages .config
    if [ "$USE_PREBUILT_STACK" = "true" ]; then
      disable_prebuilt_stack_packages .config
    fi
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

prepare_package_stack_build_prerequisites() {
  note "prepare package-stack build prerequisites"
  (
    cd "$WORKSPACE/wrt"
    make tools/install -j"$JOBS" || make tools/install -j1 V=s
    make toolchain/install -j"$JOBS" || make toolchain/install -j1 V=s
    make target/linux/prepare -j"$JOBS" || make target/linux/prepare -j1 V=s
  )
}

prebuild_compile_targets() {
  cat <<'EOF'
package/feeds/packages/tailscale/compile
package/feeds/luci/luci-app-tailscale-community/compile
package/feeds/packages/podman/compile
package/feeds/packages/conmon/compile
package/feeds/packages/external-protocol/compile
package/feeds/packages/netavark/compile
package/feeds/packages/rpcbind/compile
package/feeds/packages/nfs-kernel-server/compile
package/feeds/luci/luci-app-nfs/compile
package/feeds/nss_packages/nss-firmware/compile
package/feeds/nss_packages/nss-eip-firmware/compile
package/kernel/linux/compile
package/luci-app-podman/compile
EOF
}

compile_prebuild_stack_packages() {
  local targets=()
  local target

  while read -r target; do
    [ -n "$target" ] || continue
    targets+=("$target")
  done < <(prebuild_compile_targets)

  [ "${#targets[@]}" -gt 0 ] || fail "prebuild compile target list is empty"
  note "compile package-stack targets: ${targets[*]}"
  (
    cd "$WORKSPACE/wrt"
    make "${targets[@]}" -j"$JOBS" || make "${targets[@]}" -j1 V=s
  )
}

run_prebuild_package_stack_flow() {
  note "update feeds"
  (
    cd "$WORKSPACE/wrt"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    apply_nfs_kernel_server_v4_hotfix
  )

  note "apply custom packages"
  (
    cd "$WORKSPACE/wrt/package"
    "$WORKSPACE/Scripts/Packages.sh"
    "$WORKSPACE/Scripts/Handles.sh"
  )

  note "prepare overlay packages"
  prepare_overlay_packages

  note "generate package-stack config"
  (
    # shellcheck disable=SC1090
    . "$WORKSPACE/Scripts/function.sh"
    cd "$WORKSPACE/wrt"
    generate_config
    prepare_prebuild_package_only_config .config
    "$WORKSPACE/Scripts/Settings.sh"
    prepare_prebuild_package_only_config .config
    make defconfig -j"$JOBS"
  )

  note "download package-stack sources"
  (
    cd "$WORKSPACE/wrt"
    make download -j"$JOBS"
  )

  prepare_package_stack_build_prerequisites

  compile_prebuild_stack_packages
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

  repo_dir="$(find "$WORKSPACE/wrt/bin/targets" -type f -path '*/packages/*.apk' -print | head -n 1 || true)"
  [ -n "$repo_dir" ] || fail "same-build target package repository not found"
  dirname "$repo_dir"
}

collect_local_package_dirs() {
  local target_repo="$1"
  local arch_root="$WORKSPACE/wrt/bin/packages"

  [ -d "$target_repo" ] && printf '%s\n' "$target_repo"
  if [ -d "$arch_root" ]; then
    find "$arch_root" -mindepth 2 -maxdepth 2 -type d | sort
  fi
}

repo_alias_for_dir() {
  local repo_dir="$1"
  local target_repo="$2"

  if [ "$repo_dir" = "$target_repo" ]; then
    printf 'target\n'
    return
  fi

  basename "$repo_dir"
}

prepare_local_imagebuilder_index_dir() {
  local repo_dir="$1"
  local apk_bin="$2"

  [ -x "$apk_bin" ] || fail "imagebuilder apk tool is missing: $apk_bin"
  [ -d "$repo_dir" ] || fail "imagebuilder repo directory is missing: $repo_dir"
  find "$repo_dir" -maxdepth 1 -type f -name '*.apk' | grep -q . || \
    fail "imagebuilder repo has no apk files: $repo_dir"
  (
    cd "$repo_dir"
    "$apk_bin" mkndx --allow-untrusted --output packages.adb ./*.apk >/dev/null
  )
  [ -f "$repo_dir/packages.adb" ] || fail "imagebuilder local packages.adb was not generated: $repo_dir"
}

stage_prebuilt_imagebuilder_repos() {
  local ib_root="$1"
  local repo_root repo_dir repo_name dest apk_bin copied_count repo_apk_count

  [ -d "$PREBUILT_STACK_DIR" ] || fail "prebuilt stack directory is missing: $PREBUILT_STACK_DIR"
  repo_root="$ib_root/local"
  apk_bin="$ib_root/staging_dir/host/bin/apk"

  rm -rf "$repo_root"
  mkdir -p "$repo_root"

  copied_count=0
  while read -r repo_dir; do
    [ -n "$repo_dir" ] || continue
    repo_apk_count="$(find "$repo_dir" -maxdepth 1 -type f -name '*.apk' | wc -l | tr -d ' ')"
    if [ "${repo_apk_count:-0}" -eq 0 ]; then
      note "skip empty prebuilt repo: $repo_dir"
      continue
    fi
    repo_name="$(basename "$repo_dir")"
    dest="$repo_root/$repo_name"
    mkdir -p "$dest"
    note "stage prebuilt packages from: $repo_dir -> $dest"
    find "$repo_dir" -maxdepth 1 -type f \( -name '*.apk' -o -name 'packages.adb' \) -exec cp -f {} "$dest/" \;
    if ! [ -f "$dest/packages.adb" ]; then
      note "build prebuilt local package index: $dest"
      prepare_local_imagebuilder_index_dir "$dest" "$apk_bin"
    fi
    copied_count="$((copied_count + repo_apk_count))"
  done < <(find "$PREBUILT_STACK_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  [ "$copied_count" -gt 0 ] || fail "no prebuilt apk packages staged into imagebuilder local repos"
  note "staged prebuilt apk count: $copied_count"
}

stage_source_build_repos_to_root() {
  local repo_root="$1"
  local apk_bin="$2"
  local target_repo
  local repo_dir repo_name dest copied_count repo_apk_count

  target_repo="$(resolve_target_package_repo)"
  rm -rf "$repo_root"
  mkdir -p "$repo_root"

  copied_count=0
  while read -r repo_dir; do
    [ -n "$repo_dir" ] || continue
    repo_apk_count="$(find "$repo_dir" -maxdepth 1 -type f -name '*.apk' | wc -l | tr -d ' ')"
    if [ "${repo_apk_count:-0}" -eq 0 ]; then
      note "skip empty same-build repo: $repo_dir"
      continue
    fi
    repo_name="$(repo_alias_for_dir "$repo_dir" "$target_repo")"
    dest="$repo_root/$repo_name"
    mkdir -p "$dest"
    note "collect same-build packages from: $repo_dir -> $dest"
    find "$repo_dir" -maxdepth 1 -type f \( -name '*.apk' -o -name 'packages.adb' \) -exec cp -f {} "$dest/" \;
    if ! [ -f "$dest/packages.adb" ]; then
      note "build same-build local package index: $dest"
      prepare_local_imagebuilder_index_dir "$dest" "$apk_bin"
    fi
    copied_count="$((copied_count + repo_apk_count))"
  done < <(collect_local_package_dirs "$target_repo")

  [ "$copied_count" -gt 0 ] || fail "no same-build apk packages staged into $repo_root"
  note "staged same-build apk count: $copied_count"
}

stage_local_imagebuilder_repos() {
  local ib_root="$1"

  stage_source_build_repos_to_root "$ib_root/local" "$ib_root/staging_dir/host/bin/apk"
}

write_imagebuilder_repositories() {
  local repo_file="$1"
  local ib_root="$2"
  local repo_path

  : > "$repo_file"

  while read -r repo_path; do
    [ -n "$repo_path" ] || continue
    repo_path="file://$repo_path"
    append_unique_repo "$repo_file" "$repo_path"
  done < <(find "$ib_root/local" -type f -name 'packages.adb' | sort)

  [ -s "$repo_file" ] || fail "imagebuilder repositories file is empty"
}

load_profile_devices() {
  sed -n 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_\(.*\)=y$/\1/p' "$WORKSPACE/Config/$PROFILE.txt" | sort -u
}

prepare_imagebuilder_workspace() {
  local archive="$1"
  local dest_root="$2"

  rm -rf "$dest_root"
  mkdir -p "$dest_root"
  tar --zstd -xf "$archive" -C "$dest_root"
  IMAGEBUILDER_ROOT="$(find "$dest_root" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
  [ -n "$IMAGEBUILDER_ROOT" ] || fail "failed to unpack imagebuilder archive"
}

assemble_imagebuilder_images() {
  local archive ib_root repo_file device bin_dir local_repo
  local preload_packages="$IMAGEBUILDER_ALL_PACKAGES"

  build_imagebuilder
  archive="$IMAGEBUILDER_ARCHIVE"
  [ -n "$archive" ] || fail "imagebuilder archive path is empty"

  note "prepare imagebuilder workspace"
  prepare_imagebuilder_workspace "$archive" "$IMAGEBUILDER_DIR"
  ib_root="$IMAGEBUILDER_ROOT"

  if [ "$USE_PREBUILT_STACK" = "true" ]; then
    note "stage downloaded prebuilt repositories"
    stage_prebuilt_imagebuilder_repos "$ib_root"
  else
    note "stage same-build local repositories"
    stage_local_imagebuilder_repos "$ib_root"
  fi

  repo_file="$ib_root/repositories"
  write_imagebuilder_repositories "$repo_file" "$ib_root"

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

main() {
  prepare_workspace
  prepare_env_vars
  validate_prebuilt_stack_dir
  init_host_environment
  normalize_scripts
  run_build_flow
  [ "$TEST_ONLY" = "true" ] || [ "$ASSEMBLE_IMAGEBUILDER" != "true" ] || assemble_imagebuilder_images
  export_artifacts

  note "build completed for $PROFILE"
}

if [ "$BUILD_FIRMWARE_LIB_ONLY" != "true" ]; then
  main "$@"
fi
