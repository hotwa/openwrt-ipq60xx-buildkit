# IPQ60XX Buildkit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bootstrap a dedicated repository that locks the combined baseline for the IPQ60XX firmware flow.

**Architecture:** A small shell-based repository maintains one lock file with resolved upstream SHAs, a generated markdown manifest, and exported environment values for downstream workflows. No long-running build jobs are added in the bootstrap phase.

**Tech Stack:** Bash, GitHub CLI, GitHub Actions

---

### Task 1: Add repository skeleton

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `docs/plans/2026-03-09-ipq60xx-buildkit-design.md`
- Create: `docs/plans/2026-03-09-ipq60xx-buildkit.md`

**Step 1: Write the repository purpose and scope**

Document the combined-baseline problem and the bootstrap-only scope.

**Step 2: Add ignore rules for generated state**

Ignore `.worktrees/`, `.cache/`, `.tmp/`, and `dist/`.

**Step 3: Verify files exist**

Run: `find . -maxdepth 3 -type f | sort`

Expected: the new docs and root files appear in the repository.

### Task 2: Add the combined baseline lock

**Files:**
- Create: `locks/combined-baseline.lock`

**Step 1: Define the lock schema**

Store repository names, tracked branches, resolved commits, target, profiles,
and package policy using shell-compatible `KEY=value` lines.

**Step 2: Seed the current resolved SHAs**

Write the current commit SHAs for:
- `davidtall/OpenWRT-CI`
- `VIKINGYFY/immortalwrt`
- `hotwa/openwrt-ipq60xx-apk-feed`

**Step 3: Verify readability**

Run: `sed -n '1,240p' locks/combined-baseline.lock`

Expected: all baseline values are present and easy to audit.

### Task 3: Add lock refresh and export scripts

**Files:**
- Create: `ci/lib.sh`
- Create: `ci/refresh_lock.sh`
- Create: `ci/render_manifest.sh`
- Create: `ci/export_env.sh`

**Step 1: Implement shared helpers**

Add helper functions for loading the lock file, resolving branch SHAs with
`gh api`, and updating `KEY=value` lines safely.

**Step 2: Implement lock refresh**

Support:
- `./ci/refresh_lock.sh`
- `./ci/refresh_lock.sh --check`

**Step 3: Implement manifest rendering**

Generate `dist/current-baseline.md` from the lock file.

**Step 4: Implement environment export**

Support shell output and GitHub Actions style output.

**Step 5: Verify script syntax**

Run: `bash -n ci/lib.sh ci/refresh_lock.sh ci/render_manifest.sh ci/export_env.sh`

Expected: no output and exit code `0`.

### Task 4: Add the GitHub workflow

**Files:**
- Create: `.github/workflows/refresh-lock.yml`

**Step 1: Add manual and scheduled triggers**

Use `workflow_dispatch` and a daily schedule.

**Step 2: Run refresh and manifest generation**

Execute `./ci/refresh_lock.sh` and `./ci/render_manifest.sh`.

**Step 3: Auto-commit lock changes**

Only commit if `locks/combined-baseline.lock` or `dist/current-baseline.md`
changed.

**Step 4: Verify the workflow file**

Run: `ruby -e 'require \"yaml\"; YAML.load_file(\".github/workflows/refresh-lock.yml\")'`

Expected: no error output.

### Task 5: Verify and save the bootstrap

**Files:**
- Modify: all new files above

**Step 1: Run local checks**

Run:
- `./ci/refresh_lock.sh --check`
- `./ci/render_manifest.sh`
- `./ci/export_env.sh --format shell`

Expected:
- check mode prints the resolved SHAs
- manifest is written under `dist/current-baseline.md`
- exported variables match the lock file

**Step 2: Review git status**

Run: `git status --short`

Expected: only intended bootstrap files are staged or modified.

**Step 3: Commit**

```bash
git add .
git commit -m "feat(buildkit): bootstrap combined baseline lock"
```

