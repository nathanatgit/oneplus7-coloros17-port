# Architecture

## Layers and who owns what

| Layer | Source | Role | Rule of thumb |
| --- | --- | --- | --- |
| Kernel + boot ramdisk | LineageOS 24 `android_kernel_oneplus_sm8150` (`lineage-24.0`, commit `0521dc29`, 4.14.357) + our p73 eSE driver | Hardware truth, Android 17 needs this newer 4.14 (eBPF backports) | Keep vermagic; flash separately (`boot_b`) |
| `vendor_b` | LineageOS 24 vendor (HALs, firmware links) + H.40 odm HALs we port | Talks to the hardware | Everything here is rw-remountable on a running phone (`mount -o remount,rw /vendor`) but lost on re-flash |
| `system_b` | ColorOS 17 PLK110 donor (Axis GSI, EROFS) with our patches | Framework, SystemUI, Settings, my_* partitions content | Read-only on the phone; fix by rebuilding |
| `my_stock` | EROFS image kept at `/data/port/my_stock.img`, loop-mounted at boot by `00-port-mystock.rc` | Stock ColorOS apps, H.40 OnePlus camera (patched), keyboards | Same size as earlier builds; swap only with a matching file |
| Slot A | Stock H.40 | Recovery path, reference | **Never touch.** No `fastboot -w` / format on slot A |

## Why this layout

- The donor GSI (PLK110, Qualcomm) boots on a legacy-SAR OnePlus 7 Pro only on top of the **LineageOS boot model** (2SI, system EROFS line added to the first-stage fstab, `vbmeta_b` with verity disabled). The stock H.40 kernel cannot run Android 17 (eBPF), so the LineageOS 4.14 kernel and vendor are the base.
- ColorOS expects many OnePlus HALs that LineageOS does not have. They come from stock H.40 `odm.img` (also the nested `system/euclid/odm.img` and `euclid/my_product.img`) and are either copied as binaries or replaced by small stand-ins when the interface changed (AIDL vs HIDL).

## Boot chain (slot B)

`bootloader -> boot_b (LOS kernel + patched ramdisk) -> first-stage mount: system (EROFS), vendor -> init (ColorOS) -> SELinux (permissive, policy capped to v29) -> vendor/odm rc services, port rc files in /system/etc/init (00-port-*, 01-port-audio-fix) -> /data (FBE standard) -> my_stock loop mount -> framework`.

## Partitions touched by an install

`vendor_b`, `system_b`, `boot_b` (eSE kernel), `/data/port/my_stock.img`. Not touched: slot A, `vbmeta_b`, `dtbo_b` (the eSE power pin is fixed in the kernel, not in the dtbo), modem, firmware.
