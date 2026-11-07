# 17k no-root upgrade bundle

Target: a OnePlus 7 Pro (GM1910 / PLK110, fastboot product `msmnile`) with an unlocked bootloader; for an upgrade it already runs this ColorOS 17 port (17d or later) on its
active slot, for a clean install any state, with an unlocked bootloader and matching H.40 firmware.

**Default = upgrade, your data is kept.** The installer first flashes the active slot's `vendor`, `system` and `boot` and replaces
`/data/port/my_stock.img` (the previous one stays as `/data/port/my_stock-prev.img`). The other slot is not touched. **After the
images are flashed, before the final reboot, it asks:** `Wipe user data? Default is No: upgrade keeps your data. Type WIPE to erase
/data.` Only the exact word `WIPE` (case sensitive) erases `/data` (clean install, `fastboot -w`); Enter, any other text, or no
input (piped / non-interactive) keeps your data. Scripted runs: `--wipe` / `--no-wipe` (`-Wipe` / `-NoWipe` in PowerShell).
Back up anyway: a failed flash can still leave the phone unbootable.

1. Extract the ZIP completely. Install Android platform-tools (`adb`, `fastboot`) and put them on `PATH`.
2. Connect exactly ONE phone, either booted into the port with USB debugging authorized (preferred; the installer reboots it to the
   bootloader itself), or already in the bootloader (fastboot) mode.
3. Optional: `Install-17k.bat -DryRun` (Windows) or `bash ./Install-17k.sh --dry-run` (Linux/macOS) checks the images, the phone,
   the slot, root and free space and changes nothing.
4. Run `Install-17k.bat` (or `powershell -ExecutionPolicy Bypass -File .\Install-17k.ps1`), or `bash ./Install-17k.sh`. There is no
   typed model prompt any more. In Android mode the installer checks `guacamole`, the installed port, the active slot, free space
   and root. In bootloader mode it reads `fastboot getvar product`: `msmnile` continues; anything else prints a warning and you must
   confirm it is a OnePlus 7 Pro (GM1910 / guacamole) by typing `yes` (otherwise it aborts with nothing written; `--confirm-device`
   / `-ConfirmDevice` accepts it in scripts).

How `my_stock.img` (about 6.9 GB, it lives in userdata) is placed:
- If the running port gives the installer root (a development build with `adb root`, or Magisk), the image is copied to
  `/data/port/my_stock.img.new`, verified on the phone and swapped in before the reboot; then one fastboot pass flashes vendor, the
  production 17k system and the eSE boot.
- Otherwise (a 17d no-root install): the installer flashes vendor, the temporary 17k **bootstrap** system (development build with
  adb root) and the eSE boot, boots it once without wiping, copies and verifies `my_stock.img`, returns to fastboot and flashes the
  final production-property 17k system.

**Started in the bootloader (fastboot) mode, or answered WIPE:** nothing can be copied through adb in that state, so `my_stock.img` is
copied after the first boot, and the installer waits for it:
- NoRoot: the installer flashes the temporary 17k **bootstrap** system (adb root) instead of the final one, boots it, copies and
  verifies `my_stock.img` (on a wiped phone it first creates `/data/port`), returns to fastboot and flashes the final system. This is
  the 17d clean-install flow.
- WIPE after an Android-mode run that already copied `my_stock.img`: the copy is erased with `/data`, so the bootstrap system is
  flashed and the image is copied again after the wipe.
- If a step fails after a wipe, the installer prints the exact manual commands; **a wiped phone without `my_stock.img` may not start
  the port properly**, so do not stop there. The wipe path is tested with stub adb/fastboot scripts only, never on a phone.

The final system has production properties (`ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`) and no builder ADB key. Your
computer's existing ADB authorization is kept (it is in userdata; after a wipe you authorize again).

After the first boot, see "After flashing" in `README.md` of the release (camera update removal, wallpaper keeper, charging limit checks).

17k-r2 has NOT been flashed or boot-tested; the installers have not been run end to end. **The new connection-mode detection, product check, WIPE question and wipe path were tested only with stub adb/fastboot scripts (logs/installer-stub-test.txt), never on a phone.** r2 = the first 17k (installed once on the author's phone) + a defensive guard for `restricted_networking_mode` = 1 (all apps without network after the first 17k upgrade; the component that writes it is unknown): a boot-time service in the vendor image and a non-fatal step at the end of the installer that sets it to 0 through adb. The rebuilt r2 also bakes the alert-slider hold (B24/B25b: down = press-and-hold, release ends the 一键闪记 capture; a boot-time bind mount of a dex from /odm, stock dex kept on any problem) and audio policy `primary input` maxOpenCount 1 (B26). Slider hold and audio sharing were verified only live on the author's phone (bind mounts); the baked image, the boot-time services and the installers have not been run on a phone; the note/ASR step depends on the cloud server; other audio paths (calls, video audio) after the B26 change are unverified. Idle battery drain is not fixed.
