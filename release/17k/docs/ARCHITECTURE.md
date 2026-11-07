# Architecture

## Layers and who owns what

| Layer | Source | Role | Rule of thumb |
| --- | --- | --- | --- |
| Kernel + boot ramdisk | LineageOS 24 `android_kernel_oneplus_sm8150` (`lineage-24.0`, commit `0521dc29`, 4.14.357) + our p73 eSE driver | Hardware truth, Android 17 needs this newer 4.14 (eBPF backports) | Keep vermagic; flash separately (`boot_b`) |
| `vendor_b` | LineageOS 24 vendor (HALs, firmware links) + H.40 odm HALs we port | Talks to the hardware | Everything here is rw-remountable on a running phone (`mount -o remount,rw /vendor`) but lost on re-flash |
| `system_b` | ColorOS 17 PLK110 donor (Axis GSI, EROFS) with our patches | Framework, SystemUI, Settings, my_* partitions content | Read-only on the phone; fix by rebuilding |
| `my_stock` | EROFS image kept at `/data/port/my_stock.img`, loop-mounted at boot by `00-port-mystock.rc` | Stock ColorOS apps, H.40 OnePlus camera (patched), keyboards | Same size as earlier builds; swap only with a matching file |

## Why this layout

- The donor GSI (PLK110, Qualcomm) boots on a legacy-SAR OnePlus 7 Pro only on top of the **LineageOS boot model** (2SI, system EROFS line added to the first-stage fstab, `vbmeta_b` with verity disabled). The stock H.40 kernel cannot run Android 17 (eBPF), so the LineageOS 4.14 kernel and vendor are the base.
- ColorOS expects many OnePlus HALs that LineageOS does not have. They come from stock H.40 `odm.img` (also the nested `system/euclid/odm.img` and `euclid/my_product.img`) and are either copied as binaries or replaced by small stand-ins when the interface changed (AIDL vs HIDL).

## Boot chain (slot B)

`bootloader -> boot_b (LOS kernel + patched ramdisk) -> first-stage mount: system (EROFS), vendor -> init (ColorOS) -> SELinux (permissive, policy capped to v29) -> vendor/odm rc services, port rc files in /system/etc/init (00-port-*, 01-port-audio-fix) -> /data (FBE standard) -> my_stock loop mount -> framework`.

## Partitions touched by an install

`vendor_b`, `system_b`, `boot_b` (eSE kernel), `/data/port/my_stock.img`. Not touched: `vbmeta_b`, `dtbo_b` (the eSE power pin is fixed in the kernel, not in the dtbo), modem, firmware.

## Changes in 17j

- `my_stock.img` (in userdata, `/data/port/my_stock.img`) grew from 5.0 GB to about 6.9 GB: it also carries the donor camera's odm
  data and libraries (`/my_stock/port-camera/{odm-camera,odm-lib64}`, they do not fit `vendor_b`). `01-port-camera.rc` (post-fs-data,
  right after `00-port-mystock.rc` mounts `/my_stock`) bind-mounts `odm-camera` over `/vendor/odm/etc/camera` and overlays
  `odm-lib64` on `/vendor/odm/lib64` (read-only). A 17j system booted with an older my_stock simply has no donor camera data.
- The ColorOS 17 camera app is a system app in `/my_product/app/OplusCamera` (system_b); its SDK/adapter jars are in
  `/product/framework`. The H.40 OnePlus camera in my_stock stays.
- New port services in `/system/etc/init`: `00-port-stune.rc` (early-init schedtune groups), `00-port-ims-rilsvc.rc`,
  `00-port-wpkeep.rc` (`port_wp_keep`, `port_wp_save`), `01-port-camera.rc`. Port state in userdata: `/data/port/wp/` (wallpaper keeper).
- Install: the 17j installers are upgrades (no wipe); they replace `my_stock.img` in place and keep the previous one as
  `my_stock-prev.img`.
