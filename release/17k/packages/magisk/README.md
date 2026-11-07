# 17k Magisk 31 upgrade bundle

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
5. Approve Magisk's root request for the ADB shell on the phone if it appears.

How `my_stock.img` (about 6.9 GB, it lives in userdata) is placed:
- If the running port gives the installer root (Magisk, or a development build with `adb root`), the image is copied to
  `/data/port/my_stock.img.new`, verified on the phone and swapped in before the reboot; then one fastboot pass flashes vendor, the
  production 17k system and the Magisk-patched eSE boot. The installer then installs the Magisk app if it is missing.
- Otherwise (a 17d no-root install): it flashes the three partitions, boots the new system (the old `my_stock.img` is used for that
  one boot), installs Magisk v31.0 if missing, asks MagiskSU for root, copies and verifies `my_stock.img` and reboots.

**Started in the bootloader (fastboot) mode, or answered WIPE:** nothing can be copied through adb in that state, so `my_stock.img` is
copied after the first boot, and the installer waits for it:
- Magisk: the installer flashes the final system and the Magisk boot, wipes if asked, boots, installs the Magisk app, asks MagiskSU for
  root, creates `/data/port` on a wiped phone, copies and verifies `my_stock.img`, and reboots (the 17d Magisk clean-install flow). On
  a wiped phone you must finish the setup wizard far enough to enable USB debugging, authorize this computer, and approve Magisk's
  root request; the installer waits up to 15 minutes for each step.
- If a step fails after a wipe, the installer prints the exact manual commands; **a wiped phone without `my_stock.img` may not start
  the port properly**, so do not stop there. The wipe path is tested with stub adb/fastboot scripts only, never on a phone.

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

17k-r3 has NOT been flashed or boot-tested; the installers have not been run end to end. **The new connection-mode detection, product check, WIPE question and wipe path were tested only with stub adb/fastboot scripts (logs/installer-stub-test.txt), never on a phone.** r2 = the first 17k (installed once on the author's phone) + a defensive guard for `restricted_networking_mode` = 1 (all apps without network after the first 17k upgrade; the component that writes it is unknown): a boot-time service in the vendor image and a non-fatal step at the end of the installer that sets it to 0 through adb. The rebuilt r2 also bakes the alert-slider hold (B24/B25b: down = press-and-hold, release ends the 一键闪记 capture; a boot-time bind mount of a dex from /odm, stock dex kept on any problem) and audio policy `primary input` maxOpenCount 1 (B26). Slider hold and audio sharing were verified only live on the author's phone (bind mounts); the baked image, the boot-time services and the installers have not been run on a phone; the note/ASR step depends on the cloud server; other audio paths (calls, video audio) after the B26 change are unverified. Idle battery drain is not fixed.
