# 17d no-root fastboot bundle

Target: OnePlus 7 Pro PLK110/GM1910 with matching H.40 firmware and an unlocked bootloader. This ZIP installs the 17d port directly; no base ROM flash is required.

1. Extract this ZIP completely on Windows.
2. Put exactly one supported phone in fastboot mode.
3. Run `powershell -ExecutionPolicy Bypass -File .\Install-17d.ps1`.
4. Confirm `PLK110` or `GM1910`, then type `WIPE` when prompted.

The installer selects the current active slot, flashes the included 17d bootstrap system/vendor/eSE boot, wipes userdata and metadata, boots the bootstrap, copies `my_stock.img` to `/data/port`, and flashes the final production-property 17d system and plain eSE boot. The opposite slot is left untouched.

The wipe deletes apps, accounts, keys, and personal files. Back up first. Do not interrupt the 5 GB `my_stock.img` transfer or the subsequent flash.
