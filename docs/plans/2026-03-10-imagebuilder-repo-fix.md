# ImageBuilder Repository Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the buildkit ImageBuilder stage consume valid repositories so preload images can install `podman`, `tailscale`, and `nfs` packages.

**Architecture:** Keep firmware compilation unchanged. Change only the ImageBuilder repository assembly so it prefers same-build local package output, then appends valid external `packages.adb` sources for userland packages and the custom `luci-app-podman` feed.

**Tech Stack:** GitHub Actions, bash, ImmortalWrt buildroot, ImageBuilder, APK repositories

---

### Task 1: Update locked repository sources

**Files:**
- Modify: `locks/combined-baseline.lock`

**Step 1: Write the failing check**

Use the failing CI evidence from run `22852454548` showing external `APKINDEX.tar.gz` paths are invalid and package selection breaks in ImageBuilder.

**Step 2: Replace invalid external feed URLs**

Set official external repositories to valid `packages.adb` URLs:
- `targets/qualcommax/ipq60xx/packages/packages.adb`
- `packages/aarch64_cortex-a53/base/packages.adb`
- `packages/aarch64_cortex-a53/luci/packages.adb`
- `packages/aarch64_cortex-a53/packages/packages.adb`
- `packages/aarch64_cortex-a53/routing/packages.adb`
- `packages/aarch64_cortex-a53/telephony/packages.adb`
- `packages/aarch64_cortex-a53/video/packages.adb`

Set the custom feed policy to stop assuming an externally hosted `APKINDEX.tar.gz` path until a valid `packages.adb` endpoint exists.

**Step 3: Verify the lock file stays shell-compatible**

Run: `bash -n ci/export_env.sh ci/render_manifest.sh`

**Step 4: Commit**

```bash
git add locks/combined-baseline.lock
git commit -m "fix(buildkit): correct imagebuilder repository sources"
```

### Task 2: Rebuild ImageBuilder repository assembly

**Files:**
- Modify: `ci/build_firmware.sh`

**Step 1: Write the failing check**

Use the failing CI evidence from run `22852454548` showing ImageBuilder reaches `make image` and then fails selecting packages because repository inputs are wrong for same-baseline `kernel`, `base-files`, `kmod-*`, and `luci-app-podman`.

**Step 2: Add local repository preference**

Build the `repositories` file from same-build local outputs first:
- target packages directory under `wrt/bin/targets/.../packages`
- ImageBuilder bundled local repositories

Append external `packages.adb` sources only after local same-baseline repositories are present.

**Step 3: Keep package preload scope unchanged**

Do not change `IMAGEBUILDER_ALL_PACKAGES` in this task. Only change where ImageBuilder resolves them from.

**Step 4: Add minimal validation**

Fail early if the local target package repository is missing before `make image`.

**Step 5: Commit**

```bash
git add ci/build_firmware.sh
git commit -m "fix(buildkit): prefer same-build imagebuilder repos"
```

### Task 3: Verify and trigger CI

**Files:**
- Modify: `dist/current-baseline.md`
- Modify: `docs/buildkit-followup-checklist.md`

**Step 1: Run local verification**

Run:
- `bash -n ci/lib.sh ci/build_firmware.sh ci/export_env.sh ci/render_manifest.sh`
- `./ci/render_manifest.sh`
- `./ci/export_env.sh --format shell`

**Step 2: Update documentation**

Refresh the generated baseline manifest and note the new repository strategy in the follow-up checklist.

**Step 3: Push for GitHub Actions validation**

Push the branch to `main` to trigger `build-firmware`.

**Step 4: Inspect the next run**

Success criteria:
- log shows `prepare imagebuilder workspace`
- log shows `assemble imagebuilder image:`
- no `APKINDEX.tar.gz` fetches
- no `tar ... Cannot open`
- no external `kernel/base-files/kmod-*` mismatch from snapshot feeds

**Step 5: Commit**

```bash
git add docs/buildkit-followup-checklist.md dist/current-baseline.md
git commit -m "docs(buildkit): track imagebuilder repository strategy"
```
