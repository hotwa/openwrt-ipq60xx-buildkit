# Current IPQ60XX Combined Baseline

- Updated at: `2026-03-09T11:09:00+08:00`
- Target: `qualcommax/ipq60xx`
- Profiles: `IPQ60XX-NOWIFI IPQ60XX-WIFI`

## Upstreams

- CI base: `davidtall/OpenWRT-CI@d793f2410350d1da80b7810f918828fe1c50d614`
- WRT source: `VIKINGYFY/immortalwrt@9040dd58a7797933e6d9f68faca4da375a8ffb01`
- Custom APK feed: `hotwa/openwrt-ipq60xx-apk-feed@1ca0652615bc7440a2de4f50cd186bb4aa4864a2`
- Custom APK feed URL: `https://hotwa.github.io/openwrt-ipq60xx-apk-feed/all`

## Package Policy

- Source packages: `nikki dae`
- Official feed packages: `tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn podman conmon external-protocol netavark nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn`
- Custom feed packages: `luci-app-podman`

## ImageBuilder Inputs

- Custom APK feeds: `https://hotwa.github.io/openwrt-ipq60xx-apk-feed/all`
- ImageBuilder official packages: `tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn podman conmon external-protocol netavark nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn`
- ImageBuilder custom packages: `luci-app-podman`
- Podman stack: `podman conmon external-protocol netavark luci-app-podman`
- Tailscale stack: `tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn`
- NFS stack: `nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn`
