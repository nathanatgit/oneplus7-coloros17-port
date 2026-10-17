# Development log — first 17d test release

## 2026-10-17

1. Started from the latest build 17d artifacts only. The original 17d system, vendor, and `my_stock` images were preflighted; the eSE-enabled final boot image is `out-ese/boot-ese-final.img`.
2. Rebuilt the 17d system with `PROD_PROPS=1` for the no-root and Magisk variants. The final image has `ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`, no builder ADB key, and `preflight-b.sh` reported `PREFLIGHT PASS`.
3. Mounted the original and rebuilt images read-only and compared file trees. Only `/system/build.prop` differed in system; vendor and `my_stock` had no file-tree differences. The release therefore uses the original 17d vendor and `my_stock` images.
4. Downloaded official Magisk v31.0 and verified its SHA-256 against the official release asset digest. Magisk v31.0 is a pre-release; it was selected because its release notes list Android 17/API 37 support.
5. Used Magisk's “Select and patch a file” workflow on the exact `boot-ese-final.img`. Patched image size is 100,663,296 bytes; SHA-256 is recorded in `FACTS.md`.
6. Temporarily booted the patched image with `fastboot boot`. Android reached `sys.boot_completed=1` on slot B; Magisk 31.0 and `magiskd` were present; `su -c id` returned UID 0. The image was not flashed. A normal reboot returned the phone to its installed 17d boot.
7. Prepared two standalone fastboot bundles. Each installer auto-detects the active slot and directly writes the 17d port images. Both require a full userdata/metadata wipe; the no-root installer uses the bundled debug 17d bootstrap image to copy `my_stock.img`, while the rooted installer uses MagiskSU.
8. The installers are host-assisted workflows, not `fastboot update` ZIPs. They include the complete 17d images they flash and do not require a separately flashed base ROM.
9. Added Bash installers for Linux/macOS and Windows `.bat` launchers beside the PowerShell installers. Corrected the fastboot product guard to `guacamole` (the device codename; `msmnile` is the platform family), while retaining the typed PLK110/GM1910 model confirmation.
10. Parsed both Bash variants with `bash -n`, parsed all PowerShell installers, checked the release image hashes, and completed full CRC scans plus SHA-256 hashing for both updated ZIPs. The ZIPs have distinct entries for all three platform launchers and their updated README.

## Validation boundary

- Verified: image hashes, no-root image preflight, read-only file-tree comparison, Magisk boot patch, temporary Magisk boot, root identity, package entry lists, and ZIP integrity checks.
- Not verified: a clean-wipe install on another phone, clean boot of the no-root system, acoustic Breeno wake on a fresh data partition, and Wallet card provisioning on the exact release ZIP.
- Target is limited to OnePlus 7 Pro PLK110/GM1910 with matching H.40 firmware. No firmware/base ROM is flashed by the installer.

11. Expanded the first-release source snapshot to include 3,115 cumulative source/config/patch files from earlier build tools and research, plus 15 sanitized historical notes. The source archive SHA-256 manifest verifies with zero mismatches. Generated binaries, donor ROMs, decompiled app trees, external tool executables, and signing keys are excluded.


