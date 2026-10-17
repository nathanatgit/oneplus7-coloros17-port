# 17d Magisk 31 test fastboot bundle

Target: OnePlus 7 Pro PLK110/GM1910 with matching H.40 firmware and an unlocked bootloader. This ZIP installs the 17d port directly; no base ROM flash is required.

1. Extract this ZIP completely on your computer.
2. Put exactly one supported phone in fastboot mode.
3. Windows: run `Install-17d.bat` (or `powershell -ExecutionPolicy Bypass -File .\Install-17d.ps1`). Linux/macOS: run `bash ./Install-17d.sh` from the extracted folder. Install Android platform-tools (`adb`, `fastboot`) first.
4. Confirm `PLK110` or `GM1910`, then type `WIPE` when prompted.
5. If Magisk requests root for the ADB shell, approve it on the phone so the installer can place `my_stock.img` in userdata.

The installer selects the current active slot, flashes the included production-property 17d system, vendor, and Magisk-patched eSE boot, wipes userdata and metadata, installs the official Magisk v31.0 app, and stages `my_stock.img` with MagiskSU. The opposite slot is left untouched. This clean data wipe is required on every device.

The wipe deletes apps, accounts, keys, and personal files. Back up first. After first boot, unlock the phone and approve the computer's ADB authorization prompt if shown, then approve Magisk's shell root request. Do not interrupt the 5 GB `my_stock.img` transfer or the subsequent reboot.

If the Magisk shell request is denied, open Magisk and grant root to the installer shell, then run:

```powershell
adb shell su -c id
adb push .\images\my_stock.img /data/local/tmp/my_stock.img
adb shell su -c "mkdir -p /data/port; chown 0:0 /data/port; chmod 0750 /data/port; cp /data/local/tmp/my_stock.img /data/port/my_stock.img; chown 0:0 /data/port/my_stock.img; chmod 0644 /data/port/my_stock.img; chcon u:object_r:system_file:s0 /data/port/my_stock.img; sync; rm -f /data/local/tmp/my_stock.img"
adb reboot
```

This is a Magisk v31.0 pre-release compatibility test. Confirm Magisk reports installed after reboot; root access is through MagiskSU, not `adb root`.
