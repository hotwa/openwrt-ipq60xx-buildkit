# Buildkit Follow-up Checklist

Last updated: 2026-03-10 16:55 CST

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
