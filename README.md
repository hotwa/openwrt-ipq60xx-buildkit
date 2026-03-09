# IPQ60XX Buildkit

Combined baseline lock repository for the `hotwa/OpenWRT-CI` firmware flow.

This repository exists because the firmware project depends on two different
upstreams at the same time:

- `davidtall/OpenWRT-CI`
  - workflow and profile customizations for IPQ60XX, `nikki`, and `dae`
- `VIKINGYFY/immortalwrt`
  - source tree with Qualcomm NSS support

Those inputs cannot be treated as a single upstream. This repository locks the
exact commits used by the firmware workflow and exports a reproducible manifest
for later build stages.

## Scope

The bootstrap version of this repository only does three things:

1. lock the current upstream commits into one manifest
2. document package policy for IPQ60XX builds
3. export machine-readable values for later GitHub Actions and Gitea/Woodpecker

The long-running build stages can be added on top of this lock later, but the
first requirement is to make the floating inputs explicit and auditable.

The lock also records `davidtall/OpenWRT-CI` overlays that must survive future
syncs from `VIKINGYFY/OpenWRT-CI`, including required commits and package delta
policy.

The repository now also contains a first-pass firmware workflow. It uses the
combined lock to materialize a temporary build workspace and run a real source
build for `IPQ60XX-NOWIFI` and `IPQ60XX-WIFI`.

## Repository layout

- `locks/combined-baseline.lock`
  - combined lock for CI upstream, WRT source upstream, and custom APK feed
- `ci/refresh_lock.sh`
  - resolves floating branches to concrete commit SHAs
- `ci/render_manifest.sh`
  - generates a markdown summary in `dist/current-baseline.md`
- `ci/export_env.sh`
  - emits shell or GitHub Actions style environment variables for consumers
- `.github/workflows/refresh-lock.yml`
  - scheduled and manual lock refresh workflow
- `.github/workflows/build-firmware.yml`
  - first-pass firmware build workflow for the two IPQ60XX profiles
- `ci/build_firmware.sh`
  - clones the locked CI base and locked WRT source into a temporary workspace
    and runs the upstream shell build flow

## Package policy

The baseline uses three package sources:

- source-built inside the main firmware tree:
  - `nikki`
  - `dae`
  - `gecoosac`
  - `luci-app-daed`
  - `luci-app-pushbot`
  - `luci-app-lucky`
  - Qualcomm NSS related code from `VIKINGYFY/immortalwrt`
- official feed / later ImageBuilder install:
  - `tailscale`
  - `luci-app-tailscale-community`
  - `luci-i18n-tailscale-community-zh-cn`
  - `podman`
  - `conmon`
  - `external-protocol`
  - `netavark`
  - `nfs-kernel-server`
  - `nfs-kernel-server-utils`
  - `nfs-kernel-server-v4`
  - `nfs-utils`
  - `nfs-utils-v4`
  - `rpcbind`
  - `luci-app-nfs`
  - `luci-i18n-nfs-zh-cn`
- custom APK feed:
  - `luci-app-podman`

`luci-app-podman` is intentionally separated from the rest of the Podman stack:

- custom feed:
  - `luci-app-podman`
- official or same-baseline feed / later ImageBuilder install:
  - `podman`
  - `conmon`
  - `external-protocol`
  - `netavark`

The lock file exports explicit ImageBuilder package groups for:

- Podman
- Tailscale
- NFS

Downstream workflows can consume these groups directly instead of rebuilding the
same package selection logic.

## Firmware workflow

`build-firmware.yml` is intentionally narrower than the long-term target:

- it validates that the combined baseline can perform a real source build
- it reuses `davidtall/OpenWRT-CI` shell scripts and config from the locked
  commit
- it compiles `IPQ60XX-NOWIFI` and `IPQ60XX-WIFI`
- it uploads `dist/out/<PROFILE>/` as artifacts

What it does not do yet:

- no ImageBuilder second stage
- no custom feed package installation into the final image
- no build cache tuning yet

That layering comes after the first successful source-build run proves the
baseline is executable.

## Davidtall-specific overlays

The current baseline preserves `davidtall/OpenWRT-CI` additions beyond
`VIKINGYFY/OpenWRT-CI` in two forms:

- required commits
  - currently includes `ae52d1414db969fe6e08db7587bc3748e73a833b`
  - this keeps the `gecoosac` source switch to `openwrt-fork/openwrt-gecoosac`
- source overlay mappings
  - `gecoosac=openwrt-fork/openwrt-gecoosac@main`
  - `luci-app-daed=QiuSimons/luci-app-daed@master`
  - `luci-app-pushbot=zzsj0928/luci-app-pushbot@master`
  - `luci-app-lucky=sirpdboy/luci-app-lucky@main`
- config package delta
  - the lock tracks the extra package set enabled by `davidtall/OpenWRT-CI`
  - `zerotier` and `luci-app-zerotier` are intentionally excluded

Consumers should prefer the exported variables in `ci/export_env.sh` instead of
hard-coding these overlays in downstream workflows.

## Local usage

```bash
bash -n ci/lib.sh ci/refresh_lock.sh ci/render_manifest.sh ci/export_env.sh
./ci/refresh_lock.sh --check
./ci/render_manifest.sh
./ci/export_env.sh --format shell
```
