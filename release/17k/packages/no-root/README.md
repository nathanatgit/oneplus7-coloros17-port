# 17k no-root upgrade bundle

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
5. Type `GM1910` or `PLK110` when asked.

How `my_stock.img` (about 6.9 GB, it lives in userdata) is placed:
- If the running port gives the installer root (a development build with `adb root`, or Magisk), the image is copied to
  `/data/port/my_stock.img.new`, verified on the phone and swapped in before the reboot; then one fastboot pass flashes vendor, the
  production 17k system and the eSE boot.
- Otherwise (a 17d no-root install): the installer flashes vendor, the temporary 17k **bootstrap** system (development build with
  adb root) and the eSE boot, boots it once without wiping, copies and verifies `my_stock.img`, returns to fastboot and flashes the
  final production-property 17k system.

The final system has production properties (`ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`) and no builder ADB key. Your
computer's existing ADB authorization is kept (it is in userdata).

After the first boot, see "After flashing" in `README.md` of the release (camera update removal, wallpaper keeper, charging limit checks).

17k-r2 has NOT been flashed or boot-tested; the installers have not been run end to end. r2 = the first 17k (installed once on the author's phone) + a defensive guard for `restricted_networking_mode` = 1 (all apps without network after the first 17k upgrade; the component that writes it is unknown): a boot-time service in the vendor image and a non-fatal step at the end of the installer that sets it to 0 through adb. The rebuilt r2 also bakes the alert-slider hold (B24/B25b: down = press-and-hold, release ends the 一键闪记 capture; a boot-time bind mount of a dex from /odm, stock dex kept on any problem) and audio policy `primary input` maxOpenCount 1 (B26). Slider hold and audio sharing were verified only live on the author's phone (bind mounts); the baked image, the boot-time services and the installers have not been run on a phone; the note/ASR step depends on the cloud server; other audio paths (calls, video audio) after the B26 change are unverified. Idle battery drain is not fixed.
