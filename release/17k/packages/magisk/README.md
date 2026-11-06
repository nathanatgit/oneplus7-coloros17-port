# 17k Magisk 31 upgrade bundle

Target: a OnePlus 7 Pro (GM1910 / PLK110, fastboot product `guacamole` or `msmnile`) that already runs this ColorOS 17 port (17d or later) on its
active slot, with an unlocked bootloader and matching H.40 firmware.

**This is an upgrade. It keeps your data:** apps, accounts, settings and files stay. The installer never runs `fastboot -w`, never
formats or erases userdata/metadata, and has no wipe step. It writes only the active slot's `vendor`, `system` and `boot`
partitions and replaces `/data/port/my_stock.img` (the previous one stays as `/data/port/my_stock-prev.img`). The other slot is not
touched. Back up anyway: a failed flash can still leave the phone unbootable.

1. Extract the ZIP completely. Install Android platform-tools (`adb`, `fastboot`) and put them on `PATH`.
2. Boot the phone into the port, enable USB debugging and authorize this computer (preferred), or put it in fastboot mode.
3. Optional: `Install-17k.bat -DryRun` (Windows) or `bash ./Install-17k.sh --dry-run` (Linux/macOS) checks the images, the phone,
   the slot, root and free space and changes nothing.
4. Run `Install-17k.bat` (or `powershell -ExecutionPolicy Bypass -File .\Install-17k.ps1`), or `bash ./Install-17k.sh`.
5. Type `GM1910` or `PLK110` when asked. Approve Magisk's root request for the ADB shell on the phone if it appears.

How `my_stock.img` (about 6.9 GB, it lives in userdata) is placed:
- If the running port gives the installer root (Magisk, or a development build with `adb root`), the image is copied to
  `/data/port/my_stock.img.new`, verified on the phone and swapped in before the reboot; then one fastboot pass flashes vendor, the
  production 17k system and the Magisk-patched eSE boot. The installer then installs the Magisk app if it is missing.
- Otherwise (a 17d no-root install): it flashes the three partitions, boots the new system (the old `my_stock.img` is used for that
  one boot), installs Magisk v31.0 if missing, asks MagiskSU for root, copies and verifies `my_stock.img` and reboots.

If MagiskSU is denied, grant root to the shell in Magisk and run the installer again (it detects the root and only stages the image
before flashing the same partitions again), or stage it by hand:

```
adb push images/my_stock.img /data/local/tmp/my_stock.img.new
adb shell "su -c 'mv -f /data/local/tmp/my_stock.img.new /data/port/my_stock.img.new && sha256sum /data/port/my_stock.img.new'"
# compare with SHA256SUMS, then:
adb shell "su -c 'cd /data/port && rm -f my_stock-prev.img && mv my_stock.img my_stock-prev.img && mv my_stock.img.new my_stock.img && chown 0:0 my_stock.img && chmod 0644 my_stock.img && chcon u:object_r:system_file:s0 my_stock.img && sync'"
adb reboot
```

The system has production properties (`ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`); root is through MagiskSU, not `adb root`.
Magisk v31.0 is an official pre-release (Android 17 / API 37 support). The boot image is 17d's Magisk patch of the eSE boot; 17k
did not change the boot ramdisk or kernel.

After the first boot, see "After flashing" in `README.md` of the release (camera update removal, wallpaper keeper, charging limit checks).

17k has NOT been flashed or boot-tested; the installers have not been run end to end. Idle battery drain is not fixed.
