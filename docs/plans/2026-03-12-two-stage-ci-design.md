# Two-Stage CI Design

Last updated: 2026-03-12

## Goal

Move the long-running `tailscale + luci-app-podman + nfs*` package compilation
out of the profile firmware workflow so `IPQ60XX-NOWIFI` and `IPQ60XX-WIFI`
reuse one same-baseline prebuilt APK repository for
`qualcommax/ipq60xx + aarch64_cortex-a53`.

## Current constraints

- The build matrix must stay profile-based because final firmware artifacts are
  still profile-specific.
- The prebuilt package artifact must be keyed by baseline, not by profile.
- Missing prebuilt artifacts must fail quickly with a clear operator action.
- The existing NFS v4 install guard hotfix in `ci/build_firmware.sh` must stay.
- Existing `TEST_ONLY` and `ASSEMBLE_IMAGEBUILDER` flows must continue to work.

## Options considered

### 1. One workflow per profile

Rejected. This duplicates the slow package-stack build across
`IPQ60XX-NOWIFI` and `IPQ60XX-WIFI`, which is exactly the timeout problem we
need to remove.

### 2. Single prebuild keyed by baseline and target/arch

Chosen. Build the shared APK repository once, upload it as an artifact named by
baseline key, then let both firmware profile jobs consume that same artifact.
This preserves profile-specific final assembly while deduplicating the expensive
package compilation.

### 3. Build-firmware silently falls back to source compilation

Rejected. Silent fallback hides cache misses and pushes the workflow back toward
the 6 hour hosted-runner limit. The main workflow must fail fast and instruct
operators to run the prebuild workflow first.

## Approved design

### Baseline identity

Both workflows derive the same baseline key from:

- `locks/combined-baseline.lock` content hash
- `CI_BASE_COMMIT`
- `WRT_COMMIT`
- `SOURCE_LUCI_APP_PODMAN_REF`
- `TARGET`
- `WRT_ARCH`

This key becomes the artifact naming and matching contract.

### Prebuild workflow

Add `.github/workflows/prebuild-package-stack.yml` to:

- trigger on `workflow_dispatch`
- trigger on `push` for lock and package-stack related paths
- build the shared package stack once for
  `qualcommax/ipq60xx + aarch64_cortex-a53`
- upload a local APK repository artifact containing `.apk` files and
  `packages.adb`

### Firmware workflow

Keep the profile matrix in `.github/workflows/build-firmware.yml`, but:

- export the same baseline key before the matrix build
- discover and download the matching prebuild artifact
- fail fast if no artifact exists
- pass `USE_PREBUILT_STACK=true` and the downloaded repo directory into
  `ci/build_firmware.sh`

### Shell build changes

`ci/build_firmware.sh` gains a prebuilt branch that:

- does not source-build the `tailscale`, `luci-app-podman`, or `nfs*` stack
- stages the downloaded local repo into ImageBuilder repositories
- keeps building the rest of the source firmware and ImageBuilder outputs
- preserves the current NFS v4 hotfix logic

### Documentation

Update follow-up docs so operators know:

- `prebuild-package-stack` must succeed before `build-firmware`
- the artifact is shared across both IPQ60XX profiles
- the main workflow intentionally fails early on a cache miss
