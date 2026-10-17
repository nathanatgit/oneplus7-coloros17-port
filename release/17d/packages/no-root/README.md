# 17d no-root fastboot bundle

Target: OnePlus 7 Pro PLK110/GM1910 with matching H.40 firmware and an unlocked bootloader. This ZIP installs the 17d port directly; no base ROM flash is required.

1. Extract this ZIP completely on your computer.
2. Put exactly one supported phone in fastboot mode.
3. Windows: run `Install-17d.bat` (or `powershell -ExecutionPolicy Bypass -File .\Install-17d.ps1`). Linux/macOS: run `bash ./Install-17d.sh` from the extracted folder. Install Android platform-tools (`adb`, `fastboot`) first.
4. Confirm `PLK110` or `GM1910`, then type `WIPE` when prompted.

The installer selects the current active slot, flashes the included 17d bootstrap system/vendor/eSE boot, wipes userdata and metadata, boots the bootstrap, copies `my_stock.img` to `/data/port`, and flashes the final production-property 17d system and plain eSE boot. The bootstrap is a temporary debug image that provides ADB root only for staging; it is replaced before the installer finishes. The final no-root system has secure ADB settings and no builder key. The opposite slot is left untouched.

The clean data wipe is required on every device. It deletes apps, accounts, keys, and personal files. Back up first. Do not interrupt the 5 GB `my_stock.img` transfer or the subsequent flash.

The final system uses secure ADB settings and contains no builder ADB key. On first setup, unlock the phone and approve your computer's ADB authorization prompt before running later ADB commands.
