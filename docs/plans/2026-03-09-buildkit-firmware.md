# Buildkit Firmware Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `hotwa/openwrt-ipq60xx-buildkit` run a real two-profile IPQ60XX firmware build on GitHub Actions using the combined baseline lock.

**Architecture:** Add a build script that materializes a temporary workspace from the locked CI base and locked WRT source, then reuse the upstream shell build flow. Add a GitHub Actions matrix workflow that invokes the script for `IPQ60XX-NOWIFI` and `IPQ60XX-WIFI` and uploads the resulting artifacts.

**Tech Stack:** Bash, GitHub Actions, git, OpenWrt build system

---

### Task 1: Add the firmware build script

**Files:**
- Create: `ci/build_firmware.sh`
- Modify: `README.md`

**Step 1: Define the script interface**

Implement environment-driven inputs:
- `PROFILE` required
- `WORK_ROOT` optional
- `OUT_DIR` optional
- `JOBS` optional
- `TEST_ONLY` optional

**Step 2: Materialize the locked workspace**

Clone:
- `davidtall/OpenWRT-CI@$CI_BASE_COMMIT` into the temporary workspace root
- `VIKINGYFY/immortalwrt@$WRT_COMMIT` into `wrt/`

**Step 3: Reuse the upstream shell pipeline**

Run:
- `scripts/feeds update -a`
- `scripts/feeds install -a`
- `Scripts/Packages.sh`
- `Scripts/Handles.sh`
- `generate_config`
- `Scripts/Settings.sh`
- `make defconfig`
- `make download`
- `make`

**Step 4: Export artifacts**

Copy `.config` and the final `bin/targets/` outputs into `dist/out/<PROFILE>/`.

**Step 5: Verify**

Run:
```bash
bash -n ci/build_firmware.sh
```

Expected: exit 0

### Task 2: Add the GitHub Actions firmware workflow

**Files:**
- Create: `.github/workflows/build-firmware.yml`

**Step 1: Add workflow triggers**

Support:
- `push` to `main`
- manual `workflow_dispatch`

**Step 2: Add two-profile matrix**

Profiles:
- `IPQ60XX-NOWIFI`
- `IPQ60XX-WIFI`

**Step 3: Add build steps**

Steps:
- checkout buildkit repo
- free disk
- install minimal host packages
- run `ci/build_firmware.sh`
- upload `dist/out/<PROFILE>/`

**Step 4: Verify**

Run:
```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/build-firmware.yml")'
```

Expected: exit 0

### Task 3: Document the execution model

**Files:**
- Modify: `README.md`

**Step 1: Describe the new workflow**

Document:
- what the firmware workflow does
- why it clones the locked CI base into a temporary workspace
- what it does not do yet: ImageBuilder layering

**Step 2: Verify**

Run:
```bash
sed -n '1,260p' README.md
```

Expected: the workflow description matches the implementation

### Task 4: Trigger and inspect a real build

**Files:**
- None

**Step 1: Commit**

```bash
git add .
git commit -m "feat(buildkit): add firmware build workflow"
```

**Step 2: Push**

```bash
git push origin codex/build-firmware:main
```

**Step 3: Verify remote run**

Use `gh` to inspect the newly triggered GitHub Actions run and confirm whether
both profile jobs start and reach the build phase.
