# Current IPQ60XX Combined Baseline

- Updated at: `2026-03-09T15:14:09+08:00`
- Target: `qualcommax/ipq60xx`
- Profiles: `IPQ60XX-NOWIFI IPQ60XX-WIFI`

## Upstreams

- CI base: `davidtall/OpenWRT-CI@d793f2410350d1da80b7810f918828fe1c50d614`
- CI required commits: `ae52d1414db969fe6e08db7587bc3748e73a833b`
- CI required commit notes: `ae52d1414db969fe6e08db7587bc3748e73a833b=openwrt-fork/openwrt-gecoosac`
- WRT source: `VIKINGYFY/immortalwrt@9040dd58a7797933e6d9f68faca4da375a8ffb01`
- Custom APK feed: `hotwa/openwrt-ipq60xx-apk-feed@1ca0652615bc7440a2de4f50cd186bb4aa4864a2`
- Custom APK feed URL: `https://hotwa.github.io/openwrt-ipq60xx-apk-feed/all`
- Official APK feeds: `https://downloads.immortalwrt.org/snapshots/targets/qualcommax/ipq60xx/packages/packages.adb https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/base/packages.adb https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/luci/packages.adb https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/packages/packages.adb https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/routing/packages.adb https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/telephony/packages.adb https://downloads.immortalwrt.org/snapshots/packages/aarch64_cortex-a53/video/packages.adb`

## Package Policy

- Source packages: `dae nikki gecoosac luci-app-daed luci-app-pushbot luci-app-lucky`
- Official feed packages: `tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn podman conmon external-protocol netavark nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn`
- Custom feed packages: `luci-app-podman`

## Davidtall Overlay Policy

- Source overlay packages: `dae nikki gecoosac luci-app-daed luci-app-pushbot luci-app-lucky`
- Source overlay mappings: `gecoosac=openwrt-fork/openwrt-gecoosac@main luci-app-daed=QiuSimons/luci-app-daed@master luci-app-pushbot=zzsj0928/luci-app-pushbot@master luci-app-lucky=sirpdboy/luci-app-lucky@main`
- Config package delta: `autocore automount bash bind-dig bind-nslookup blkid block-mount btop cfdisk cgdisk coremark cpufreq curl default-settings default-settings-chn dmesg e2fsprogs f2fsck fdisk gdisk ip-full iperf3 kmod-bonding kmod-dsa kmod-fs-btrfs kmod-fs-ext4 kmod-fs-f2fs kmod-fuse kmod-inet-diag kmod-inet-mptcp-diag kmod-mtd-rw kmod-netlink-diag kmod-nft-arp kmod-nft-bridge kmod-nft-connlimit kmod-nft-core kmod-nft-dup-inet kmod-nft-fib kmod-nft-fullcone kmod-nft-nat kmod-nft-netdev kmod-nft-offload kmod-nft-queue kmod-nft-socket kmod-nft-tproxy kmod-nft-xfrm kmod-sound-core kmod-tcp-bbr kmod-tun kmod-usb-audio kmod-usb-core kmod-usb-dwc3 kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-cdc-eem kmod-usb-net-cdc-ether kmod-usb-net-cdc-mbim kmod-usb-net-cdc-ncm kmod-usb-net-cdc-subset kmod-usb-net-huawei-cdc-ncm kmod-usb-net-ipheth kmod-usb-net-qmi-wwan kmod-usb-net-qmi-wwan-fibocom kmod-usb-net-qmi-wwan-quectel kmod-usb-net-rndis kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-net-sierrawireless kmod-usb-ohci kmod-usb-storage kmod-usb-storage-extras kmod-usb-storage-uas kmod-usb-uhci kmod-usb-xhci kmod-usb3 kmod-veth kmod-wireguard libimobiledevice lsblk luci luci-app-autoreboot luci-app-cpufreq luci-app-dae luci-app-daed luci-app-ddns-go luci-app-gecoosac luci-app-nikki luci-app-ttyd luci-app-upnp luci-app-vlmcsd luci-app-wolplus luci-base luci-compat luci-lib-base luci-lib-ipkg luci-lua-runtime luci-proto-relay luci-proto-wireguard luci-theme-argon mkf2fs mmc-utils nand-utils openssh-keygen openssh-sftp-server openssl-util proto-bonding sfdisk sgdisk tcpdump usb-modeswitch usbmuxd usbutils v2ray-geodata-updater xz-utils`
- Excluded packages: `zerotier luci-app-zerotier`

## ImageBuilder Inputs

- Custom APK feeds: ``
- ImageBuilder official packages: `tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn podman conmon external-protocol netavark nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn`
- ImageBuilder custom packages: `luci-app-podman`
- Podman stack: `podman conmon external-protocol netavark luci-app-podman`
- Tailscale stack: `tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn`
- NFS stack: `nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn`
- NFS kmods: `kmod-fs-nfs kmod-fs-nfsd kmod-fs-nfs-v4`
- All preload packages: `podman conmon external-protocol netavark luci-app-podman tailscale luci-app-tailscale-community luci-i18n-tailscale-community-zh-cn nfs-kernel-server nfs-kernel-server-utils nfs-kernel-server-v4 nfs-utils nfs-utils-v4 rpcbind luci-app-nfs luci-i18n-nfs-zh-cn kmod-fs-nfs kmod-fs-nfsd kmod-fs-nfs-v4`
