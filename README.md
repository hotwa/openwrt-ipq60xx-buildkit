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
- `.github/workflows/prebuild-package-stack.yml`
  - shared package-stack prebuild keyed by target/arch baseline
- `.github/workflows/build-firmware.yml`
  - firmware build workflow for the two IPQ60XX profiles that consumes the
    shared prebuilt stack
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
- NFS kernel modules
- full preload package set

Downstream workflows can consume these groups directly instead of rebuilding the
same package selection logic.

## Two-stage CI

The firmware flow now runs in two stages:

1. `prebuild-package-stack.yml`
   - builds only the shared `tailscale + luci-app-podman + nfs*` package stack
     once per baseline key
   - does not build full firmware images
   - still prepares OpenWrt host tools and toolchain explicitly before
     `make package/compile`, because package-only prebuilds do not get those
     prerequisites for free
   - also prepares `target/linux` before package compile, because the shared
     stack includes kernel-facing packages such as NFS kmods
   - compiles an explicit source package target list instead of global
     `package/compile`, so unrelated target defaults do not leak into prebuild
   - uploads a local repo artifact containing `.apk` files and `packages.adb`
   - mirrors the same repo snapshot to a baseline-keyed GitHub Release asset
   - targets `qualcommax/ipq60xx + aarch64_cortex-a53`, not individual profiles
2. `build-firmware.yml`
   - keeps the profile matrix for `IPQ60XX-NOWIFI` and `IPQ60XX-WIFI`
   - is chained from successful prebuild runs via `workflow_run`
   - resolves the same baseline key from the prebuild commit that triggered it
   - downloads the matching prebuilt repo artifact from that triggering run
   - fails fast if the artifact is missing
   - reuses that repo during ImageBuilder assembly instead of recompiling the
     stack from source in each profile job

`TEST_ONLY=true` remains available for manual validation runs and skips the
artifact lookup because it does not compile firmware or assemble ImageBuilder
outputs.

## Artifact-First Rule

For this repository, the source of truth between CI stages is the GitHub
Actions artifact produced by `prebuild-package-stack`.

- `build-firmware` consumes the artifact from the triggering prebuild run
- the GitHub Release asset is a mirror of the same repo snapshot
- the Release exists for archival, inspection, and manual rollback
- the Release is not the default input for downstream firmware builds

If a future agent changes this behavior, they must update the workflows and
docs together. Do not silently switch downstream consumption from artifact to
Release.

## Variable Semantics

Do not conflate the repository lock's package architecture with the upstream CI
base script variable of the same name.

- `locks/combined-baseline.lock` `WRT_ARCH`
  - package architecture for baseline identity
  - current value: `aarch64_cortex-a53`
- upstream `davidtall/OpenWRT-CI` shell flow `WRT_ARCH`
  - target/subtarget token consumed by `Scripts/function.sh`
  - current IPQ60XX shape: `qualcommax_ipq60xx`

This repository keeps those semantics separate internally. Future agents should
not reuse the lock's package arch directly as the upstream shell variable.

## Permissions

Same-repo automation does not require a separate PAT today.

- prebuild release publishing uses the built-in `GITHUB_TOKEN`
- `.github/workflows/prebuild-package-stack.yml` requires `contents: write`
- `.github/workflows/build-firmware.yml` requires `actions: read`
- repository Actions settings must allow write permissions for `GITHUB_TOKEN`

If the repository policy forces `GITHUB_TOKEN` to read-only, Release publishing
will fail until that repository setting is changed or a stronger token is wired
in explicitly.

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
