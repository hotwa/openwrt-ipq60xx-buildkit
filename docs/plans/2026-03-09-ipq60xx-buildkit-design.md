# IPQ60XX Buildkit Design

**Goal:** Create a dedicated repository that freezes the combined build baseline
for the IPQ60XX firmware flow built from `davidtall/OpenWRT-CI` workflow logic
and `VIKINGYFY/immortalwrt` source commits.

## Problem

The firmware project uses two different moving upstreams:

- `davidtall/OpenWRT-CI` for workflow, config, and package overlay behavior
- `VIKINGYFY/immortalwrt` for the actual source tree and Qualcomm NSS support

That means there is no single upstream version to pin. If the firmware workflow
continues to consume these inputs directly from floating branches, package feed
compatibility and future ImageBuilder stages become difficult to audit.

## Design

Create a separate `openwrt-ipq60xx-buildkit` repository that records one
combined baseline manifest. The repository does not replace the firmware repo.
Instead, it provides locked inputs that the firmware repo can consume later.

Bootstrap scope:

1. Record the exact commit of `davidtall/OpenWRT-CI`
2. Record the exact commit of `VIKINGYFY/immortalwrt`
3. Record the exact commit of `hotwa/openwrt-ipq60xx-apk-feed`
4. Record the target, profiles, and package sourcing policy
5. Export these values for later GitHub Actions and Gitea/Woodpecker workflows

## Package policy

- `nikki` and `dae` remain source-built in the main firmware tree
- `tailscale`, `podman`, and NFS userland packages are intended for later
  feed/ImageBuilder installation against the locked source commit
- `luci-app-podman` remains on the custom APK feed

## Why a new repository

This baseline should not live in `hotwa/OpenWRT-CI` because that repository is
still a functional fork of `davidtall/OpenWRT-CI`. A dedicated repository keeps
baseline data separate from firmware workflow changes and makes later migration
to Woodpecker simpler.

## Next stage

Once the lock repository is in place, later work can add:

- build stages that derive feed or ImageBuilder artifacts from `WRT_COMMIT`
- firmware workflow changes that consume the exported lock values
- Woodpecker jobs for longer package or image builds

