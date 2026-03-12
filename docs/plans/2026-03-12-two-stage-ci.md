# Two-Stage CI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the shared preload package stack into a baseline-keyed prebuild workflow and make the profile firmware workflow consume it with fail-fast behavior.

**Architecture:** Keep the existing source firmware matrix per profile, but externalize the expensive `tailscale + luci-app-podman + nfs*` build into one target/arch-scoped APK repository artifact. Add a shared baseline-key function so prebuild and firmware workflows agree on artifact identity and so the shell build can switch between source-built local repos and downloaded prebuilt repos.

**Tech Stack:** GitHub Actions, Bash, OpenWrt build system, ImageBuilder, shell regression tests

---

### Task 1: Add failing tests for baseline key and prebuilt stack flow

**Files:**
- Create: `tests/test_baseline_key.sh`
- Modify: `tests/test_source_build_package_selection.sh`
- Modify: `tests/test_imagebuilder_local_repos.sh`

**Step 1: Write the failing tests**

- Add a test for a deterministic baseline key that changes with lock content,
  commits, podman ref, target, or arch.
- Extend package-selection coverage so `USE_PREBUILT_STACK=true` keeps the stack
  out of source compilation while preserving required source overlays.
- Extend local-repo coverage so ImageBuilder accepts a downloaded prebuilt repo.

**Step 2: Run tests to verify they fail**

Run:

```bash
tests/test_baseline_key.sh
tests/test_source_build_package_selection.sh
tests/test_imagebuilder_local_repos.sh
```

Expected:

- missing baseline-key helper failure
- source-package-selection expectations fail for prebuilt mode
- local repo staging expectations fail for downloaded prebuilt repo mode

**Step 3: Write minimal implementation**

- Add shared Bash helpers for baseline-key generation and artifact naming.
- Teach `ci/build_firmware.sh` to treat the prebuilt stack as external repos.

**Step 4: Run tests to verify they pass**

Run:

```bash
tests/test_baseline_key.sh
tests/test_source_build_package_selection.sh
tests/test_imagebuilder_local_repos.sh
```

Expected: all pass.

**Step 5: Commit**

```bash
git add tests/test_baseline_key.sh tests/test_source_build_package_selection.sh tests/test_imagebuilder_local_repos.sh ci/lib.sh ci/build_firmware.sh
git commit -m "test(ci): cover shared prebuilt baseline flow"
```

### Task 2: Add the prebuild workflow and artifact lookup

**Files:**
- Create: `.github/workflows/prebuild-package-stack.yml`
- Modify: `.github/workflows/build-firmware.yml`
- Create: `ci/prebuild_package_stack.sh`

**Step 1: Write the failing workflow validation**

- Validate both workflow YAML files parse.
- Validate the new workflow exports a baseline-keyed artifact name.
- Validate `build-firmware` contains a fail-fast artifact lookup path.

**Step 2: Run validation to verify it fails**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/prebuild-package-stack.yml")'
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/build-firmware.yml")'
```

Expected: parse errors or missing referenced scripts before implementation.

**Step 3: Write minimal implementation**

- Add the new workflow with push + dispatch triggers and one target/arch job.
- Add artifact discovery/download to `build-firmware.yml`.
- Add a shell entrypoint that builds and exports the local APK repository.

**Step 4: Run validation to verify it passes**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/prebuild-package-stack.yml")'
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/build-firmware.yml")'
bash -n ci/prebuild_package_stack.sh
```

Expected: both YAML files parse and the new shell script is syntactically valid.

**Step 5: Commit**

```bash
git add .github/workflows/prebuild-package-stack.yml .github/workflows/build-firmware.yml ci/prebuild_package_stack.sh
git commit -m "ci(workflows): add shared prebuild package stage"
```

### Task 3: Update documentation and verify end-to-end behavior

**Files:**
- Modify: `docs/buildkit-followup-checklist.md`
- Modify: `README.md`

**Step 1: Update docs**

- Record the two-stage architecture and the dependency between the workflows.
- Document the fail-fast behavior and operator steps for a missing prebuild.

**Step 2: Run full verification**

Run:

```bash
bash -n ci/lib.sh ci/build_firmware.sh ci/prebuild_package_stack.sh ci/export_env.sh
tests/test_baseline_key.sh
tests/test_source_build_package_selection.sh
tests/test_imagebuilder_local_repos.sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/prebuild-package-stack.yml")'
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/build-firmware.yml")'
```

Expected: all commands exit 0.

**Step 3: Commit**

```bash
git add README.md docs/buildkit-followup-checklist.md
git commit -m "docs(buildkit): record two-stage ci flow"
```
