# Package-Only Prebuild Release Chain Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Change prebuild into a package-stack-only build, chain firmware builds from it with `workflow_run`, and publish the same prebuilt repo as a Release asset.

**Architecture:** Keep one baseline-keyed prebuild per `TARGET/WRT_ARCH`, but make that workflow compile only the shared package stack plus required dependencies instead of a full firmware image. Use `workflow_run` to trigger `build-firmware` from successful prebuild runs, consume the triggering run’s artifact as the real input, and upload the same repo snapshot to a GitHub Release for durable archival and manual rollback.

**Tech Stack:** GitHub Actions, Bash, OpenWrt build system, GitHub CLI, shell regression tests

---

### Task 1: Lock package-only prebuild behavior with tests

**Files:**
- Modify: `tests/test_source_build_package_selection.sh`
- Create: `tests/test_prebuild_package_selection.sh`
- Create: `tests/test_release_metadata.sh`

**Step 1: Write the failing tests**

- Add a test proving prebuild config strips unrelated package selections and keeps only the shared stack.
- Add a test proving release tag and asset names are derived from the same baseline key.
- Extend package-selection coverage so firmware builds in prebuilt mode do not source-build the shared stack.

**Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test_prebuild_package_selection.sh
bash tests/test_release_metadata.sh
bash tests/test_source_build_package_selection.sh
```

Expected:

- missing package-only config helper failure
- missing release naming helper failure
- existing prebuilt-mode package-selection regression failure if behavior drifted

**Step 3: Write minimal implementation**

- Add config helpers for package-only prebuild mode.
- Add baseline-derived release tag/asset helpers.

**Step 4: Run tests to verify they pass**

Run:

```bash
bash tests/test_prebuild_package_selection.sh
bash tests/test_release_metadata.sh
bash tests/test_source_build_package_selection.sh
```

Expected: all pass.

**Step 5: Commit**

```bash
git add tests/test_prebuild_package_selection.sh tests/test_release_metadata.sh tests/test_source_build_package_selection.sh ci/lib.sh ci/build_firmware.sh
git commit -m "test(ci): cover package-only prebuild flow"
```

### Task 2: Convert prebuild to package-stack-only output

**Files:**
- Modify: `ci/prebuild_package_stack.sh`
- Modify: `ci/build_firmware.sh`
- Modify: `ci/compute_baseline_key.sh`

**Step 1: Implement package-only prebuild**

- Reuse workspace/bootstrap/feed preparation.
- Generate a minimal package-only `.config`.
- Compile packages only, not full firmware images.
- Stage the produced local APK repositories directly from the source tree.

**Step 2: Verify shell syntax**

Run:

```bash
bash -n ci/prebuild_package_stack.sh ci/build_firmware.sh ci/compute_baseline_key.sh
```

Expected: exit 0.

**Step 3: Run package-flow tests**

Run:

```bash
bash tests/test_prebuild_package_selection.sh
bash tests/test_imagebuilder_local_repos.sh
```

Expected: pass.

**Step 4: Commit**

```bash
git add ci/prebuild_package_stack.sh ci/build_firmware.sh ci/compute_baseline_key.sh
git commit -m "ci(prebuild): compile shared package stack only"
```

### Task 3: Add workflow chaining and Release archival

**Files:**
- Modify: `.github/workflows/prebuild-package-stack.yml`
- Modify: `.github/workflows/build-firmware.yml`
- Create: `ci/package_prebuilt_release.sh`

**Step 1: Write workflow changes**

- Make `build-firmware` trigger from `workflow_run` of successful prebuild runs.
- Keep manual dispatch for recovery.
- Publish a baseline-keyed Release tag and asset from prebuild.
- Make firmware builds download artifacts from the triggering prebuild run when available.

**Step 2: Verify workflow syntax**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/prebuild-package-stack.yml")'
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/build-firmware.yml")'
bash -n ci/package_prebuilt_release.sh
```

Expected: exit 0.

**Step 3: Commit**

```bash
git add .github/workflows/prebuild-package-stack.yml .github/workflows/build-firmware.yml ci/package_prebuilt_release.sh
git commit -m "ci(release): chain firmware build from prebuild"
```

### Task 4: Record the architecture for future agents

**Files:**
- Modify: `README.md`
- Modify: `docs/buildkit-followup-checklist.md`

**Step 1: Update docs**

- State that artifact is the downstream source of truth.
- State that Release mirrors the same prebuilt repo for archival only.
- Document `workflow_run` chaining and manual recovery steps.
- Document permissions: `contents: write` for Release publishing, no extra PAT for same-repo use.

**Step 2: Run full verification**

Run:

```bash
bash -n ci/lib.sh ci/build_firmware.sh ci/prebuild_package_stack.sh ci/package_prebuilt_release.sh ci/compute_baseline_key.sh
bash tests/test_baseline_key.sh
bash tests/test_prebuild_package_selection.sh
bash tests/test_release_metadata.sh
bash tests/test_source_build_package_selection.sh
bash tests/test_imagebuilder_local_repos.sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/prebuild-package-stack.yml"); YAML.load_file(".github/workflows/build-firmware.yml")'
```

Expected: all commands exit 0.

**Step 3: Commit**

```bash
git add README.md docs/buildkit-followup-checklist.md
git commit -m "docs(buildkit): describe artifact-first chain"
```
