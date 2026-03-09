# Buildkit Follow-up Checklist

Last updated: 2026-03-09 15:14 CST

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

- [ ] Watch run `22842495963`
  - Commit: `c68f424`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22842495963>
  - Goal: verify source build still succeeds with preload stage enabled on push
- [ ] Watch run `22842479700`
  - Commit: `1e2c5b3`
  - URL: <https://github.com/hotwa/openwrt-ipq60xx-buildkit/actions/runs/22842479700>
  - Goal: transitional run, lower priority than `22842495963`

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

## Next actions if run `22842495963` succeeds

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

## Next actions if run `22842495963` fails

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
