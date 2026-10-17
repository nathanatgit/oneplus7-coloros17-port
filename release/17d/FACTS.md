# 17d release facts

## Target and behavior

- Target: OnePlus 7 Pro PLK110 / GM1910, fastboot product `guacamole`; `msmnile` is the Snapdragon platform family.
- Android build: ColorOS 17 port build 17d, Android 17/API 37.
- Firmware prerequisite: matching H.40 firmware. The installer writes the full 17d system, vendor, and boot images and does not flash a separate base ROM or firmware set.
- Slot behavior: both installers read `current-slot` at runtime and flash only that slot; the no-root installer rechecks the slot after its bootstrap staging step. The opposite slot is left alone.
- Host installers: PowerShell plus a `.bat` launcher for Windows, and Bash for Linux/macOS. Each ZIP contains all images used by its installer; the release root also carries the full image set for the named top-level installer copies.
- Data behavior: a clean data wipe is required on every target device. Both installers require typing `WIPE` and run `fastboot -w` before first boot; this erases userdata and metadata, including apps, accounts, keys, and personal files. The installer then stages the required EROFS image at `/data/port/my_stock.img`.
- No-root variant: production properties (`ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`); no builder ADB key is baked into the release image. The final boot is the plain 17d eSE boot image.
- Magisk variant: same production-property system image, with the 17d eSE boot image patched by official Magisk v31.0. Magisk v31.0 is a pre-release.

## Image hashes

| Image | SHA-256 | Source / role |
|---|---|---|
| `bootstrap-system.img` | `2d2b4c07ceebcda8b61100467f768fa0dba4baf0440c53c82777e0ea094f18c8` | Original build 17d system; temporary ADB-root staging image in the no-root ZIP |
| `system.img` | `d56f80b4ea9d39338e954127bdefb1e56d4eab77ff8b4498f79ac0124db390d2` | 17d rebuild with production root and ADB properties; used by both final variants |
| `vendor.img` | `b55bc1810bd49aebae3c34f56e8e098e440f98ce4f5c6a215a16f1f3bfa729f6` | Original build 17d vendor image |
| `my_stock.img` | `fac842d6d7ca732c1d5dd7f356cfae1991ee9433f88e89b6e3370a1336811760` | Original build 17d EROFS image installed in userdata |
| `boot-ese-final.img` | `a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91` | Plain eSE-enabled boot image |
| `boot-magisk31-17d.img` | `b073b02da7c29f00f54e510fb4e6a7304d49c5c5df89f684f81d69fa90d4e155` | Magisk v31.0 patch of the plain eSE boot image |
| `Magisk-v31.0.apk` | `2c8a488b9a5293e578e95ae4f07e3c57aba4feec4a52ca4dd852a2692d6dd4e8` | Official Magisk manager APK |

The production-property rebuild must pass `tools/preflight-b.sh` with `PROD_PROPS=1` before packaging. A read-only filesystem comparison found only `system/build.prop` differing from the original 17d system; vendor and `my_stock` file trees had no differences. The ZIPs include the original 17d vendor and `my_stock` images.

## Live test evidence

- Connected device: PLK110, fastboot product `msmnile`, active slot B.
- Magisk v31.0 app launched on Android 17/API 37.
- `fastboot boot boot-magisk31-17d.img` returned success; device booted on slot B and `sys.boot_completed=1`.
- `magisk -v` returned `31.0:MAGISK:R`; `magiskd` was running; `su -c id` returned `uid=0(root)` with context `u:r:magisk:s0`.
- The test image was temporary. A normal reboot returned to the installed 17d boot. No partition was flashed for the Magisk test.
- The no-root image has not been flashed or live-tested. The two ZIP installers have not been run through a full data wipe on a second device.
