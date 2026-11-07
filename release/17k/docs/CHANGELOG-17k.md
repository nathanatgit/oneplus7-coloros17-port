# 17k changelog vs 17j-r2

## Installer revision (2026-11-07, still named 17k-r2): connection-mode detection, product check, optional WIPE

Images are unchanged (vendor `e61b3b199ae48f3518119d489aced6425fec0f8bb086f8537f50e382be731f3c`, same system / my_stock / boot / Magisk hashes). Only the installers (`.sh`, `.ps1`, `.bat` wrappers; both variants), the package READMEs, these docs, the packager guard and the two ZIPs (new hashes) changed.

- The installer detects the mode first: exactly one device in `adb devices` (Android) or `fastboot devices` (bootloader), else an error as before.
- The typed `GM1910 / PLK110` prompt is gone. Android mode keeps the adb-side checks (project_codename guacamole, the port installed, active slot, free space, root) and stages `my_stock.img` before rebooting to the bootloader.
- Bootloader mode: `fastboot getvar product`; `msmnile` continues; any other value prints a warning (reported vs expected) and asks to confirm a OnePlus 7 Pro (GM1910 / guacamole) by typing `yes`; anything else aborts with nothing written. `--confirm-device` / `-ConfirmDevice` accepts it in scripts. (After an Android-mode run, where guacamole was already verified over adb, a fastboot product of `guacamole` is also accepted.)
- After the images are flashed and before the final reboot: `Wipe user data? Default is No: upgrade keeps your data. Type WIPE to erase /data.` Only the exact word `WIPE` runs `fastboot -w`; Enter / other text / no input = keep. `--wipe` / `--no-wipe` (`-Wipe` / `-NoWipe`) for scripts; `--dry-run` prints what would happen and changes nothing.
- my_stock after a wipe or from the bootloader: no adb exists then, so it is copied after the first boot, using the mechanisms the 17d clean install used. NoRoot: bootstrap system (adb root) flashed first, `/data/port` waited for / created, image pushed and SHA-256 verified, back to fastboot, final system flashed. Magisk: final system + Magisk boot, wait for authorized adb (up to 15 min after a wipe), install the Magisk app, MagiskSU, create `/data/port`, push, verify, reboot. If an Android-mode run already staged the image and the user then answers WIPE, the staged copy is erased with `/data`; the NoRoot bootstrap system is reflashed and the copy is redone. On failure after a wipe the installer prints the manual commands.
- Kept: image hash checks, Magisk app install, restricted_networking_mode step, Magisk DenyList for com.heytap.health, hints, the no-wipe default path (same sequence as before except the dropped prompt and the WIPE question).
- Tested ONLY with stub adb/fastboot (`logs/installer-stub-test.txt`) plus bash / PowerShell syntax parsing. Never run on a phone. Not verified: the real bootloader's `getvar product` output on the author's device, `fastboot -w` on this device with these images, the first boot after a wipe, ADB authorization and Magisk root grant on a fresh phone, the Windows `.ps1`/`.bat` paths on a phone.

## 17k-r2 rebuilt (2026-11-07) = 17k + B22 + B24/B25b slider hold + B26 audio sharing

| Item | Change | Status |
| --- | --- | --- |
| B24 alert slider hold | Slider DOWN = ACTION_BUTTON (780) DOWN kept until the slider leaves DOWN (ColorOS turns it into LONG_PRESS 782 after ~0.5 s); watchdog releases on screen off / state lost; stale key released after a killed bridge. UP = click unchanged, MIDDLE = nothing. | verified live on the author's phone; the baked image was never booted |
| B25b release ends 一键闪记 | On release (after 3 s grace) `am force-stop com.oplus.aimemory` if it still holds a mic / shows FlashMemoryAnimation; the record animation stays. | same |
| baking | `odm/bin/port-slider-hold.dex` (`5ac5b643...`) + `port-sliderdex.sh` + `port-sliderdex.rc`: oneshot at `on boot` bind-mounts the dex over `/system/framework/oplus-port-stubs.dex` (system.img unchanged); stock dex stays if the file is missing / sha differs / mount fails. | stub-tested under dash; not booted |
| B26 audio sharing | `audio_policy_configuration.xml` and `..._a2dp_offload_disabled.xml`: mixPort `primary input` maxOpenCount 2 -> 1 (two capture clients share one HAL stream; the second stream used to hit the starved `audio-record-compress2` HAL path and recorded nothing). | live OK for 随口记 (user); calls / video audio unverified |

Files that differ from the previous r2 vendor (`logs/vendor-r2-prev-vs-r2-rebuilt-diff.txt`): those three odm files and the two policy XMLs. All other images are byte-identical. Installers/templates unchanged. ASR/note depends on the cloud server.

## 17k-r2 (2026-11-06, first build, replaced) = 17k + B22 network-restriction guard

| Item | Change | Status |
| --- | --- | --- |
| B22 restricted_networking_mode guard | After the first 17k upgrade the author's phone had Settings.Global `restricted_networking_mode` = 1: every normal app had no network (Wi-Fi and cellular), the adb shell did. Live fix: `settings put global restricted_networking_mode 0`. r2 ships `/vendor/odm/bin/port-netguard.sh` + `/vendor/odm/etc/init/port-netguard.rc` (init oneshot `port_netguard`, user root, seclabel su, at `sys.boot_completed=1`): if the value is exactly 1 it writes 0 and logs `netguard`; checks at start, +30 s, +120 s, +300 s, then exits (no polling). The four installers also clear it once through adb (as the shell user) after the final flash; non-fatal. | script: offline stub tests only (dash); installers: syntax check only; boot-time start from /odm U; **never flashed** |

**Root cause NOT found.** The writer of the 1 is unknown (defaultSysSet=true: some system component, not us). The guard only clears the value within ~5 minutes of boot; a later write, or a different cause of lost network, is not covered. It is a defensive workaround, not a fix of the cause. The idle drain is still not fixed.

Also in r2 (installer only, Magisk variant): the installer enforces Magisk's DenyList for `com.heytap.health` (`magisk --denylist enable` + `add`) so OPPO Health no longer reports a rooted device. Found live on the author's phone: the DenyList entry alone does nothing until enforcement is switched on, and `enable` persists the setting. Not part of the images.

Files that differ from the first 17k (`logs/vendor-17k-vs-17k-r2-diff.txt`): `vendor.img` gains `odm/bin/port-netguard.sh` and `odm/etc/init/port-netguard.rc`. All other images are byte-identical. The installers differ by the post-flash step. Zip names: `OnePlus7Pro-17k-r2-NoRoot.zip` / `OnePlus7Pro-17k-r2-Magisk31.zip`.

## 17k vs 17j-r2

17k = the 17j-r2 rebuild (2026-11-05, with the B18 wallpaper-saver fix) + two battery-related fixes in the vendor image.
Everything older is in [CHANGELOG-17j-history.md](CHANGELOG-17j-history.md). Item numbers are those of `tools/live/BAKE-LIST.md` (A03).
**L** = verified live on a running phone, baked and not booted from a flashed image, **U** = untested.

| Item | Change | Status |
| --- | --- | --- |
| B20 charging limit | Settings > Battery charging limit (85 %) never stopped charging: ColorOS only sends the limit to the absent vendor charger HAL. `/vendor/odm/bin/port-chglimit.sh` (init service `port_chglimit`, user system, seclabel su, started at `sys.boot_completed=1`) reads the settings and the fuel gauge (`bms/capacity`) and drives `battery/mmi_charging_enable` (hold at the limit, release 2 % below / switch off / unplugged / limit raised). | L (2026-11-04, started by hand); boot-time start U; real 85 % crossing U |
| B21 real gauge | The charger driver's ui_soc (`battery/capacity`) snaps to ~97-100 when charging is held, so Android showed ~97 % while the coulomb counter said ~84 %. `/vendor/odm/bin/port-bmslevel.sh` (service `port_bmslevel`, user root, seclabel su) bind-mounts a small file in `/dev` that it rewrites every 5 s from `bms/capacity` over `battery/capacity`. No health-service restart needed in the live test. | L; boot-time start U |
| B18 wallpaper saver (already in 17j-r2 images) | inotifyd mask `wmny`; a static wallpaper removes the saved component on purpose; first `<wp>` tag only. system.img / bootstrap-system.img are unchanged from the 17j-r2 rebuild. | L; not booted from a flashed image |

Files that differ from 17j-r2 (the only differences, `logs/vendor-17j-vs-17k-diff.txt`): `vendor.img` gains `odm/bin/port-chglimit.sh`, `odm/bin/port-bmslevel.sh`, `odm/etc/init/port-chglimit.rc`, `odm/etc/init/port-bmslevel.rc`. `system.img`, `bootstrap-system.img`, `my_stock.img` and the boot images are byte-identical to 17j-r2.

Not included: B19 (Wi-Fi scan / appops / package-disable experiments: no measured drain gain), mem_sleep changes. The idle drain (~150 mA screen-off)
is NOT fixed: see [battery-handoff-2026-11-05.md](battery-handoff-2026-11-05.md).
