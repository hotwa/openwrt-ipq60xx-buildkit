# ImageBuilder Local Repositories Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the preload ImageBuilder stage use only same-build local APK repositories.

**Architecture:** Keep firmware compilation unchanged. Replace the ImageBuilder repository staging path so it copies each local source-build repo into the ImageBuilder workspace, generates missing `packages.adb` indexes locally, and rewrites `repositories` to contain only local relative paths.

**Tech Stack:** GitHub Actions, bash, ImmortalWrt buildroot, ImageBuilder, APK repositories

---

### Task 1: Add a regression test harness

**Files:**
- Create: `tests/test_imagebuilder_local_repos.sh`
- Modify: `ci/build_firmware.sh`

**Step 1: Write the failing test**

Create a shell test that:
- creates a temporary fake workspace with:
  - `wrt/bin/targets/.../packages/*.apk`
  - `wrt/bin/packages/aarch64_cortex-a53/{base,luci,packages}/*.apk`
  - a fake ImageBuilder root with a stub `apk mkndx`
- sources `ci/build_firmware.sh` without running its main flow
- runs the repository staging helpers
- asserts `repositories` contains only local relative `packages.adb` entries
- asserts remote snapshot URLs are absent

**Step 2: Run test to verify it fails**

Run: `bash tests/test_imagebuilder_local_repos.sh`
Expected: failure because current script flattens packages and still writes remote feeds.

**Step 3: Commit**

```bash
git add tests/test_imagebuilder_local_repos.sh ci/build_firmware.sh
git commit -m "test(buildkit): cover local imagebuilder repos"
```

### Task 2: Replace ImageBuilder repo staging

**Files:**
- Modify: `ci/build_firmware.sh`

**Step 1: Write minimal implementation**

Change the script to:
- discover all same-build local repo directories
- copy each repo into a stable local subtree inside the ImageBuilder root
- preserve repository boundaries instead of merging all `.apk` files
- generate `packages.adb` inside copied repos when missing
- write ImageBuilder `repositories` using only those local relative paths

**Step 2: Keep preload package scope unchanged**

Do not change `IMAGEBUILDER_ALL_PACKAGES`. Only change repository resolution.

**Step 3: Run test to verify it passes**

Run: `bash tests/test_imagebuilder_local_repos.sh`
Expected: pass and show only local repository references.

**Step 4: Commit**

```bash
git add ci/build_firmware.sh tests/test_imagebuilder_local_repos.sh
git commit -m "fix(buildkit): use same-build local repos"
```

### Task 3: Refresh generated docs and verify scripts

**Files:**
- Modify: `dist/current-baseline.md`
- Modify: `docs/buildkit-followup-checklist.md`

**Step 1: Run verification**

Run:
- `bash -n ci/lib.sh ci/build_firmware.sh ci/export_env.sh ci/render_manifest.sh tests/test_imagebuilder_local_repos.sh`
- `bash tests/test_imagebuilder_local_repos.sh`
- `./ci/render_manifest.sh`

**Step 2: Update docs**

Record that preload ImageBuilder now uses same-build local repositories and no
longer consumes remote snapshot feeds during package selection.

**Step 3: Commit**

```bash
git add dist/current-baseline.md docs/buildkit-followup-checklist.md
git commit -m "docs(buildkit): record local repo strategy"
```
