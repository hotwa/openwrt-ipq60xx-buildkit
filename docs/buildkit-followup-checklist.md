# Buildkit Follow-up Checklist

Last updated: 2026-03-12 18:40 CST

## Two-stage CI architecture

- [x] Shared prebuild workflow added: `.github/workflows/prebuild-package-stack.yml`
  - Scope: one `qualcommax/ipq60xx + aarch64_cortex-a53` package-stack-only APK
    repository per baseline key
  - Output: local repo artifact with `.apk` files and `packages.adb`
  - Output mirror: baseline-keyed GitHub Release asset with the same repo
    snapshot
  - Build order: `make download` -> `make tools/install` ->
    `make toolchain/install` -> `make target/linux/prepare` ->
    `make package/compile`
- [x] Profile firmware workflow kept as matrix:
  - `IPQ60XX-NOWIFI`
  - `IPQ60XX-WIFI`
- [x] Baseline key contract is shared between workflows:
  - `locks/combined-baseline.lock` content hash
  - `CI_BASE_COMMIT`
  - `WRT_COMMIT`
  - `SOURCE_LUCI_APP_PODMAN_REF`
  - `TARGET`
  - `WRT_ARCH`
- [x] `build-firmware` now depends on `prebuild-package-stack` for the shared
  `tailscale + luci-app-podman + nfs*` repo.
- [x] `build-firmware` is chained from successful prebuild runs via
  `workflow_run`.
- [x] Missing prebuilt artifacts are an intentional fail-fast condition.
- [x] Artifact-first rule is now explicit:
  - downstream firmware builds use the Actions artifact
  - Release is archival only, not the normal downstream input

## Manual operator steps

- [x] Change the lock or package-stack build logic.
- [x] Run `prebuild-package-stack` first, or push a matching change to `main`.
- [x] Wait for artifact `prebuilt-stack-<baseline-key>` to upload.
- [x] Wait for `build-firmware` to start automatically from `workflow_run`.
- [x] If needed, manually dispatch `build-firmware` after prebuild finishes.
- [x] If `build-firmware` fails before bootstrap with a missing prebuilt
  artifact message, re-run `prebuild-package-stack` for the same baseline.
- [x] If Release upload fails but the artifact exists, fix repository
  `GITHUB_TOKEN` write permissions before retrying prebuild.

## Fail-fast rule

- [x] `build-firmware` resolves the shared baseline key before freeing disk or
  installing bootstrap packages.
- [x] If no matching artifact exists, the workflow stops immediately and tells
  operators to run `prebuild-package-stack` first.
- [x] `TEST_ONLY=true` skips the artifact dependency because that mode does not
  compile or assemble the preload image path.

## Permissions rule

- [x] Same-repo Release publishing uses `GITHUB_TOKEN`; no PAT is required by
  default.
- [x] Prebuild workflow must keep `contents: write`.
- [x] Firmware workflow must keep `actions: read`.
- [x] If a future agent changes token model or moves assets cross-repo, update
  this checklist and `README.md` in the same change.

## Variable rule

- [x] Lock `WRT_ARCH` means package arch for baseline identity.
- [x] Upstream `davidtall/OpenWRT-CI` scripts use `WRT_ARCH` as the
  target/subtarget token such as `qualcommax_ipq60xx`.
- [x] Keep those two meanings separate in local scripts, or prebuild will read
  the wrong `target/linux/...` path during `generate_config`.

## Current state

- [x] Combined baseline lock created and pushed.
- [x] `openwrt-ipq60xx-apk-feed` integrated into buildkit lock.
- [x] Source firmware build workflow added to `openwrt-ipq60xx-buildkit`.
- [x] Source firmware build verified successful once.
  - Successful run: `22837240102`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22837240102>
- [x] Second-stage preload implementation added.
  - Commit: `1e2c5b3`
  - Purpose: add same-baseline ImageBuilder preload stage for `podman`, `tailscale`, `nfs`
- [x] Push-triggered preload validation enabled.
  - Commit: `c68f424`
  - Purpose: force the second stage to run on push because local `gh workflow run` is blocked by token scope

## Runs to watch now

- [x] Run `22842479700` completed successfully.
  - Commit: `1e2c5b3`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22842479700>
  - Note: `ASSEMBLE_IMAGEBUILDER=false`, so this only proves source firmware build success.
- [x] Run `22842495963` failed.
  - Commit: `c68f424`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22842495963>
  - Root cause: ImageBuilder archive path was polluted by stdout output from `build_imagebuilder()`.
- [x] Run `22844206819` failed with the same root cause as `22842495963`.
  - Commit: `cacc714`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22844206819>
- [x] Run `22852454548` failed after the archive-path fix.
  - Commit: `6ce9726`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22852454548>
  - Root cause: ImageBuilder reached package selection but lacked the same-build local `packages/packages.adb`, used invalid external `APKINDEX.tar.gz` paths, and could not resolve `luci-app-podman` because the custom feed is not published.
- [x] Run `22880478254` failed quickly before compile.
  - Commit: `0615a96`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22880478254>
  - Root cause: buildkit assumed the CI base already included the `luci-app-podman` source overlay, but `CI_BASE_COMMIT=d793f241...` from `davidtall/OpenWRT-CI` does not.
- [x] Run `22891002718` failed after the repository-format fix.
  - Commit: `991cbb7`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22891002718>
  - Root cause: ImageBuilder reached package selection with a syntactically valid `repositories` file, but the staged same-build local repo was effectively empty (`OK: 0 B in 0 packages`).
  - First missing packages: `luci-app-podman`, `nss-firmware-ipq60xx`, `nss-firmware`, `nss-eip-firmware`, `kmod-fs-nfs*`, `kmod-dm`, `libubox20260213`.

## Important debugging notes

- [x] The warnings below are confirmed non-blocking by comparison with successful run `22837240102`:
  - `luci-app-cd8021x -> wpad`
  - `mac80211 -> hostapd-common`
  - `onionshare-cli -> python3-pysocks`
  - `onionshare-cli -> python3-unidecode`
  - `prometheus-node-exporter-lua -> hostapd-utils`
  - `qmodem -> kmod-mhi-wwan`
  - `qmodem -> quectel-CM-5G`
- [ ] Do not “fix” the warnings above unless a completed failed run proves they are the real root cause.
- [x] Local `gh` token cannot dispatch or cancel workflows.
  - Observed error: `HTTP 403 Resource not accessible by personal access token`
- [x] `openwrt-ipq60xx-apk-feed` currently has no GitHub Pages site.
  - `gh api repos/hotwa/openwrt-ipq60xx-apk-feed/pages` returns `404`.
  - Current `luci-app-podman` failures are therefore not caused by missing kernel modules.
- [x] The current preload strategy must do two things together:
  - stage the same-build local target package repository into ImageBuilder as `packages/packages.adb`
  - compile only the lightweight `luci-app-podman` LuCI package in the source build while keeping `podman` runtime installation in ImageBuilder
- [x] Buildkit must fetch `luci-app-podman` directly by pinned repo/ref when the CI base does not provide it.
- [x] Latest logs confirm the current hard failure is no longer repository syntax.
  - Evidence: `assemble imagebuilder image` runs, then package selection fails.
- [x] Latest logs show `zerotier` is still collected during feed installation but was not the first hard failure in run `22891002718`.
- [ ] Current focused fix under test:
  - aggregate all same-build `.apk` outputs from `wrt/bin/targets/.../packages` and `wrt/bin/packages/*/*` into ImageBuilder `packages/`
  - explicitly enable source-built same-baseline packages required by preload image assembly: `kmod-fs-nfs`, `kmod-fs-nfsd`, `kmod-fs-nfs-v4`, `kmod-dm`, `nss-firmware-ipq60xx`, `nss-firmware`, `nss-eip-firmware`
- [x] Run `22897972655` proved the same-build `.apk` aggregation works.
  - Commit: `12a596c`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22897972655>
  - Evidence: ImageBuilder staged `499` local `.apk` files.
  - New root cause: local `packages/packages.adb` was not generated before `make image`, so `apk` ignored the same-build package set and fell back to external feeds.
- [x] Run `22905819677` narrowed the bootstrap failure further.
  - Commit: `97afbf5`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22905819677>
  - Evidence: `make package_index` still failed to produce `packages/packages.adb`.
  - Root cause: ImageBuilder `make package_index` itself uses an `apk` wrapper that already points at `packages/packages.adb`, so it cannot bootstrap a missing local repo index.
- [x] Local repo-only preload staging implemented in the worktree.
  - Strategy: stage `wrt/bin/targets/.../packages` and `wrt/bin/packages/<arch>/*` as separate local repos under ImageBuilder `local/`.
  - Strategy: generate missing `packages.adb` files locally with the bundled ImageBuilder `apk mkndx`.
  - Strategy: write ImageBuilder `repositories` using only local relative `packages.adb` paths during preload assembly.
  - Expected effect: stop mixing pinned source-build packages with mutable snapshot feed versions during package selection.

## Next actions if the next preload run succeeds

- [ ] Confirm both jobs uploaded artifacts successfully.
- [ ] Inspect artifacts for:
  - source-built firmware output
  - preload image output under `imagebuilder/`
- [ ] Verify the preload artifacts contain:
  - `podman`
  - `luci-app-podman`
  - `tailscale`
  - `luci-app-tailscale-community`
  - `nfs-kernel-server`
  - `nfs-kernel-server-v4`
  - `rpcbind`
  - `luci-app-nfs`
- [ ] If preload images are correct, update `hotwa/OpenWRT-CI` to consume buildkit outputs instead of rebuilding these package stacks in the main firmware workflow.

## Next actions if the next preload run fails

- [ ] Fetch the failed job log tail first.
- [ ] Record the first hard failure line, not just nearby warnings.
- [ ] Classify the failure into one of these buckets:
  - source build regression
  - imagebuilder archive missing
  - repository/signature problem
  - package resolution problem
  - per-device preload image assembly problem
- [ ] Only then make one focused fix and trigger a new run.

## Files to update for future fixes

- [ ] Build logic: `ci/build_firmware.sh`
- [ ] Workflow behavior: `.github/workflows/build-firmware.yml`
- [ ] Lock variables: `locks/combined-baseline.lock`
- [ ] Exported envs: `ci/export_env.sh`
- [ ] Human-readable status: `dist/current-baseline.md`

## Stop conditions

- [ ] Stop when:
  - preload run succeeds
  - artifacts are verified
  - main firmware repo integration plan is ready
