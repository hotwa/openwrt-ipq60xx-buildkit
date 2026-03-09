# IPQ60XX Buildkit Firmware Design

## Goal

Make `hotwa/openwrt-ipq60xx-buildkit` compile real IPQ60XX firmware on GitHub
Actions using the combined baseline lock, without depending on
`hotwa/OpenWRT-CI` as the execution repository.

## Recommended approach

Use `openwrt-ipq60xx-buildkit` as a thin orchestrator:

1. read the combined baseline lock
2. clone `davidtall/OpenWRT-CI` at the locked commit into a temporary workspace
3. clone `VIKINGYFY/immortalwrt` at the locked commit into `wrt/`
4. reuse the upstream `Scripts/`, `Config/`, `package/`, `patches/`, and `files/`
   from the locked CI base
5. run the existing source-build flow for `IPQ60XX-NOWIFI` and `IPQ60XX-WIFI`
6. upload artifacts from the resulting `bin/targets/` directories

This keeps the first implementation narrow. It validates that the combined
baseline is executable before layering ImageBuilder or custom package feeds on
top.

## Alternatives considered

### 1. Rebuild the full `OpenWRT-CI` workflow inside buildkit

This would duplicate too much logic and immediately create drift with
`davidtall/OpenWRT-CI`.

### 2. Jump directly to ImageBuilder

This is the eventual direction for `podman`, `tailscale`, and `nfs`, but it
adds another failure surface before we know the locked source baseline builds at
all.

## Architecture

- `locks/combined-baseline.lock` remains the single source of truth.
- A new `ci/build_firmware.sh` script creates a temporary per-profile workspace.
- That workspace is populated by the locked CI base repository and the locked
  WRT source tree.
- The script then runs the upstream shell pipeline with only minimal glue:
  environment variables, path wiring, and artifact export.
- A new GitHub Actions workflow runs a two-profile matrix and uploads the
  resulting firmware bundles.

## Constraints

- Keep using `VIKINGYFY/immortalwrt` because of Qualcomm NSS.
- Keep `davidtall/OpenWRT-CI` package/config overlays, excluding `zerotier`.
- First implementation prioritizes a real build over speed optimization.
- Caching and ImageBuilder layering can be added after the first successful run.

## Verification

- Shell syntax check for all buildkit scripts.
- YAML parse check for the new GitHub workflow.
- Local dry validation of the build script interface.
- Real GitHub Actions run on `hotwa/openwrt-ipq60xx-buildkit`.
