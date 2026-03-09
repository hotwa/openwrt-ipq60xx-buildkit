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

## Package policy

The baseline uses three package sources:

- source-built inside the main firmware tree:
  - `nikki`
  - `dae`
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

## Local usage

```bash
bash -n ci/lib.sh ci/refresh_lock.sh ci/render_manifest.sh ci/export_env.sh
./ci/refresh_lock.sh --check
./ci/render_manifest.sh
./ci/export_env.sh --format shell
```
