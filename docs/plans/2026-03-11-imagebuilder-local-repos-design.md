# ImageBuilder Local Repositories Design

## Goal

Make the preload ImageBuilder stage consume only repositories produced by the
same pinned source build, so package selection stays aligned with
`WRT_COMMIT` and stops drifting against mutable snapshot feeds.

## Recommended approach

Use the source build outputs as the only ImageBuilder package sources:

1. keep the source firmware build unchanged
2. collect every local APK repository produced by the build:
   - `wrt/bin/targets/.../packages`
   - `wrt/bin/packages/<arch>/*`
3. copy each repository into the ImageBuilder workspace as its own directory
4. generate `packages.adb` for any copied directory that has APK files but no
   index yet
5. rewrite ImageBuilder `repositories` to list only those local `packages.adb`
   files
6. keep the preload package list unchanged so `nikki`, `dae`, `podman`,
   `tailscale`, and `nfs` continue to resolve through the same-build package
   graph

## Alternatives considered

### 1. Keep remote snapshot feeds and pin a subset of packages

This is the current failure mode. `base-files`, `kernel`, and `kmod-*` drift
even when a few packages are pinned locally.

### 2. Publish a separate frozen APK feed and consume that in ImageBuilder

This can work later for device-side online installation, but it adds another
release pipeline. It does not solve preload reproducibility faster than using
the existing same-build outputs directly.

## Architecture

- `ci/build_firmware.sh` becomes responsible for staging local repositories
  under the unpacked ImageBuilder directory.
- The script keeps repository boundaries instead of flattening all `.apk`
  files into a single `packages/` directory.
- The generated `repositories` file contains only local relative paths such as
  `local/base/packages.adb` and `local/target/packages.adb`.
- `OFFICIAL_APK_FEEDS` is no longer consumed by the preload ImageBuilder
  assembly path.

## Nikki impact

- `nikki` remains installable in preload images if it is built during the same
  source build and its APK lands in one of the staged local repositories.
- This design improves `nikki` reproducibility because it stops mixing its
  dependency graph with newer remote snapshot packages.
- This design does not by itself provide an online post-flash feed for later
  `opkg` or `apk` installs on the device.

## Constraints

- Keep the source build package policy unchanged.
- Do not change the preload package set in this iteration.
- Preserve shell compatibility and keep the fix contained to buildkit scripts
  and generated docs.

## Verification

- Add a bash regression test that stages fake local repositories and asserts
  the generated ImageBuilder `repositories` file references only local
  `packages.adb` paths.
- Run `bash -n` over modified scripts.
- Run the regression test locally before committing.
