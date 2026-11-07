# OnePlus 7 Pro ColorOS 17 port — 17k-r2 upgrade release

**17k-r2 (rebuilt 2026-11-07, replaces the r2 of 2026-11-06 that was never flashed) = 17k + B22 network guard + B24/B25b slider hold + B26 audio sharing.** Only `vendor.img` differs from the first 17k. New in this rebuild: (B24/B25b) the alert slider DOWN is a real press-and-HOLD of the action button, and releasing it ends the 一键闪记 / 随口记 capture (boot-time `port_sliderdex` bind-mounts `/odm/bin/port-slider-hold.dex` over `/system/framework/oplus-port-stubs.dex` before the slider bridge starts; if the file is missing or its sha differs the stock dex stays); (B26) the two audio policy XMLs set `primary input` `maxOpenCount` 2 -> 1 so two concurrent capture clients share one HAL stream (without it the second stream landed on the starved `audio-record-compress2` path and the slider memo recorded nothing). **Verified only LIVE on the author's phone (via bind mounts, 2026-11-07): holding the slider DOWN recorded a 随口记 and saved a note.** The baked image, the installers and the boot-time services (`port_sliderdex`, `port_netguard`) have NOT been booted or run on any phone. The note/ASR step depends on the cloud server. NOT verified: other audio paths (calls, video audio, other recorders) with `maxOpenCount` 1; behaviour across a reboot of the baked layout.

**Earlier text of this r2 (B22): it adds a defensive guard for one problem seen on the author's phone after the first 17k upgrade:** Settings.Global `restricted_networking_mode` was `1`, so every normal app had NO network (Wi-Fi and cellular) while the adb shell still worked (`dumpsys netpolicy`: "Restricted networking mode: true"). `settings put global restricted_networking_mode 0` fixed it at once. **The component that writes the 1 is UNKNOWN** (nothing in our scripts, docs or logs sets it; the investigation was cut short), so r2 is a guard, not a root-cause fix: the vendor image gains an init oneshot (`port_netguard`) that, at boot and again at +30 s, +120 s and +300 s, sets the value to 0 if it is exactly 1, then exits (no polling), and the installers do the same once through adb after the final flash. **17k-r2 itself has NOT been flashed or boot-tested on a phone.**

**STATUS (honest, first 17k): 17k was installed and booted once on the author's phone (2026-11-06, see [TEST-STATUS.md](TEST-STATUS.md) for what was and was not verified); it is otherwise untested.** It is the 17j-r2 system/my_stock (with the B18 wallpaper-saver fix, which was also not boot-tested) plus a vendor image that adds the B20 charging-limit enforcer and the B21 real-fuel-gauge level (both were verified live on a running 17j-r2 phone on 2026-11-04, but never from a boot-time start). Only the Magisk `.sh` installer has been run end to end (once, on one phone); the NoRoot, `.bat` and `.ps1` installers have not. The idle battery drain (~150 mA screen-off) is NOT fixed; the B19 experiments (Wi-Fi scan, appops, package disabling) are not included; no mem_sleep changes. See docs/battery-handoff-2026-11-05.md.

Local test release for the OnePlus 7 Pro GM1910 / PLK110 (`guacamole`, Snapdragon 855 / `msmnile`), ColorOS 17 (PLK110 donor) on
the LineageOS 24 vendor and kernel. It contains two standalone fastboot bundles:

- `OnePlus7Pro-17k-r2-NoRoot.zip`
- `OnePlus7Pro-17k-r2-Magisk31.zip`

(The folder and the `Install-17k-*` file names stay `17k`; the first 17k zips were `OnePlus7Pro-17k-NoRoot.zip` / `-Magisk31.zip` and are replaced by these. To apply r2 on a phone that already runs 17k, re-run `Install-17k-Magisk.sh` (upgrade, no wipe).)

What changed: [docs/CHANGELOG-17k.md](docs/CHANGELOG-17k.md) (17k = 17j-r2 + B20 charge-limit enforcer + B21 real fuel-gauge level; 17k-r2 = 17k + B22 network-restriction guard + B24/B25b slider hold + B26 audio sharing); everything since 17d is in [docs/CHANGELOG-17j-history.md](docs/CHANGELOG-17j-history.md) (builds 17e–17i plus the 17j bake: ColorOS 17 donor camera, battery-drain fixes, H.40 props, OnePlus 7 Pro identity, live-wallpaper keeper).

## Install = upgrade, user data is kept

The 17k installers are **upgrade installers for a phone that already runs this port (17d or later)**. They do not wipe: no
`fastboot -w`, no format or erase of userdata/metadata, no "type WIPE" step. They write only the active slot's `vendor`, `system` and
`boot` partitions and replace `/data/port/my_stock.img` (about 6.9 GB, it lives in userdata); the previous image stays as
`/data/port/my_stock-prev.img`. The other slot is never touched. Back up anyway.

1. Extract the ZIP for your variant completely; install platform-tools (`adb`, `fastboot`) on `PATH`.
2. Boot the phone into the port with USB debugging on and this computer authorized (preferred), or put it in fastboot mode.
3. Dry run (changes nothing): `Install-17k.bat -DryRun` on Windows, `bash ./Install-17k.sh --dry-run` on Linux/macOS. It checks the
   image hashes, the phone (`guacamole`, port installed), the slot, whether root is available for staging, and free space on /data.
4. Run `Install-17k.bat` (or the `.ps1`), or `bash ./Install-17k.sh`, and type `GM1910` or `PLK110` when asked.

How `my_stock.img` gets into userdata without a wipe:
- **Root available on the running port** (development build with `adb root`, or MagiskSU): the image is pushed to
  `/data/port/my_stock.img.new`, its SHA-256 checked on the phone, and swapped in (`my_stock.img` → `my_stock-prev.img`,
  `.new` → `my_stock.img`, owner 0:0, mode 0644, label `system_file`) while the old system still runs from the old inode. Then one
  fastboot pass: `vendor_X`, `system_X`, `boot_X`, reboot. This is the procedure used for every build flashed on the author's phone
  (17f–17i).
- **No root** (a 17d no-root install): NoRoot flashes vendor + the temporary 17k **bootstrap** system (development build, adb root) +
  the eSE boot, boots it once, stages as above, goes back to fastboot and flashes the final production system. Magisk flashes the
  final partitions, boots once on the old my_stock, installs Magisk v31.0 if missing, stages with MagiskSU and reboots.

The final system in both bundles has production properties (`ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`) and no builder ADB
key, like 17d. NoRoot boots the plain eSE boot image, Magisk the Magisk v31.0 patch of it (both from 17d: 17k did not change the
boot ramdisk or cmdline, see `logs/boot-compare.txt`).

## After flashing (once, on the first boot)

1. **Camera** — only on a phone that had the ColorOS camera installed live in `/data` (the author's phone; `restore-live.sh` era):
   ```
   adb shell pm path com.oplus.camera                       # /data/app/... = the old update is still active
   adb shell pm uninstall-system-updates com.oplus.camera   # keeps app data and the uid
   adb shell pm path com.oplus.camera                       # want /my_product/app/OplusCamera/OplusCamera.apk
   ```
   Checks: `pm list libraries | grep -c camera.unit` = 3; `grep -cE ' /vendor/odm/etc/camera | /vendor/odm/lib64 ' /proc/mounts` = 2;
   `getprop persist.camera.override_preview_hdr_support` = false. If the app's uid changed (reinstall), as root:
   `U=$(stat -c %u /data/data/com.oplus.camera); chown -R $U:$U /data/vendor/camera_process /data/vendor/cam_alog`.
2. **Do not run `tools/live/camera-donor17/restore-live.sh` any more.** Everything it set up is in the image; it would bind old
   copies over newer image files and restart zygote. Keep `/data/local/tmp/cos17-cam` only as a revert source.
3. **Wallpaper keeper (B18, saver fix)** — pick your live wallpaper once, at least 150 s after boot; the watcher saves it and re-applies it 20 s after every later boot. A static image wallpaper removes the saved component on purpose (a static image persists by itself). With nothing saved nothing is changed (no default wallpaper is applied). Optional seed, as root: `echo com.heytap.colorfulengine/.wallpaper.service.ColorfulWallpaperService > /data/port/wp/wallpaper-component`. Logs: `logcat -s port_wp_keep port_wp_save`.
4. **Charging limit / gauge (B20+B21)** — after boot: `logcat -d | grep -E "chglimit|bmslevel"` should show `bound battery/capacity -> bms/capacity`; `grep battery/capacity /proc/mounts` shows the bind mount; set the Settings > Battery charging limit and watch `hold (cap=.. L=..)` in the log at the limit.
5. Run the first-boot checks in [docs/OPEN-ITEMS.md](docs/OPEN-ITEMS.md).

## Clean install (manual only, not scripted)

Only for a phone that does not run the port yet, or to start over. It **erases all user data**. From fastboot on the active slot X:
flash `vendor_X` = `images/vendor.img`, `system_X` = `images/bootstrap-system.img`, `boot_X` = `images/boot-ese-final.img`, then
`fastboot -w` (wipes userdata and metadata), reboot, `adb root`, wait for `/data/port`, `adb push images/my_stock.img
/data/port/my_stock.img`, `adb shell 'chown 0:0 /data/port/my_stock.img; chmod 0644 /data/port/my_stock.img; chcon
u:object_r:system_file:s0 /data/port/my_stock.img; sync'`, `adb reboot bootloader`, flash `system_X` = `images/system.img` (and
`boot_X` = `images/boot-magisk31-17d.img` for root), reboot. This is the 17d installer's flow; the 17k scripts do not do it.

## Requirements

Unlocked bootloader, matching H.40 firmware, current platform-tools, a OnePlus 7 Pro (fastboot product `guacamole` or `msmnile`). The bundles do
not flash firmware, modem, dtbo or vbmeta.

## Documentation and evidence

[docs/](docs/README.md), [FACTS.md](FACTS.md) (image hashes, what was verified), [BUILD_SOURCES.md](BUILD_SOURCES.md) (how the
images were built), [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md), `logs/` (build and preflight output), `scripts/` (build, finalize,
compare and packaging scripts). Image download details: [images/README.md](images/README.md).

**Rebuilt r2 (2026-11-07): `vendor.img` sha256 `e61b3b199ae48f3518119d489aced6425fec0f8bb086f8537f50e382be731f3c`**; `tools/preflight-b.sh` development and production pairs PASS (new section "B24/B25b/B26"); vendor diff against the previous r2 vendor (`3a70f811...`): only `odm/bin/port-slider-hold.dex`, `odm/bin/port-sliderdex.sh`, `odm/etc/init/port-sliderdex.rc` and the two `audio_policy_configuration*.xml` (`logs/vendor-r2-prev-vs-r2-rebuilt-diff.txt`); stub test of `port-sliderdex.sh` under dash (`logs/sliderdex-stub-test.txt`). Nothing was flashed. Text for the previous r2 build follows. The 17k-r2 images passed `tools/preflight-b.sh` (`PREFLIGHT PASS`, development and production pairs; `logs/preflight-17k-r2-*.txt`, new section "B22"); the r2 vendor differs from the first 17k vendor only by `odm/bin/port-netguard.sh` and `odm/etc/init/port-netguard.rc` (`logs/vendor-17k-vs-17k-r2-diff.txt`). The guard script was tested offline only (stub `settings`/`log`/`sleep`, `logs/netguard-stub-test.txt`); the installers were only syntax-checked (`logs/installer-syntax-check.txt`). r2 was never flashed. About the first 17k:

The first 17k images passed `tools/preflight-b.sh` (`PREFLIGHT PASS`, development and production pairs; logs/). 17k was flashed once and booted on the author's phone (see TEST-STATUS.md). Only the Magisk `.sh` installer has been run; the NoRoot, `.bat` and `.ps1` installers have not. Dev/prod system images and my_stock are byte-identical to the 17j-r2 rebuild in `release/17j/images`; the vendor image differs from 17j-r2's only by the four B20/B21 odm files (`logs/vendor-17j-vs-17k-diff.txt`).
