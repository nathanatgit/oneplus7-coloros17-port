# 17k / 17k-r2 test status

## 17k-r2 rebuilt (2026-11-07): NOT flashed, NOT boot-tested
- Adds B24/B25b slider hold and B26 audio sharing (vendor image only, vendor sha256 `e61b3b199ae48f3518119d489aced6425fec0f8bb086f8537f50e382be731f3c`) to the r2 below.
- **Verified LIVE on the author's phone (bind mounts, not the baked image), 2026-11-07:** holding the alert slider DOWN started 随口记, recorded audio and saved a note (B26 `primary input` maxOpenCount 1 + B24/B25b dex).
- Offline only: development and production preflight PASS (section "B24/B25b/B26"); vendor diff vs the previous r2 = only the slider files and the two policy XMLs; `port-sliderdex.sh` stub-tested under dash; `bash -n` of the `.sh` installers and the PowerShell parser on the `.ps1`. The installers were not run.
- NOT verified: the baked image booting; `port_sliderdex` and `port_netguard` starting from /odm at boot and the bind mount holding after a reboot; the slider hold with the baked layout; other audio after `maxOpenCount` 1 (calls, video audio, other recorders); the ASR/note result depends on the cloud server.
- To apply (after a separate decision to flash): re-run `Install-17k-Magisk.sh` (upgrade, no wipe).

---

## 17k-r2 (2026-11-06): NOT flashed, NOT boot-tested
- Built and checked offline only: development and production preflight PASS (new section "B22"), vendor diff against the first 17k vendor = only `port-netguard.sh` / `.rc`, stub test of the guard script under dash (value 1 then 0; null; 0; 1 that survives the put and is retried at every check; value that turns 1 only at +120 s; the script exits after the +300 s check), `bash -n` of the `.sh` installers and the PowerShell parser on the `.ps1` installers. The installers were NOT run (not even `--dry-run`), nothing was flashed, no phone was touched.
- Why r2 exists: the first 17k (below) exposed `restricted_networking_mode` = 1 on the author's phone: all normal apps had no network (Wi-Fi and cellular), adb shell worked, `dumpsys netpolicy` said "Restricted networking mode: true". Fixed live with `settings put global restricted_networking_mode 0`; it reads null after one more reboot. r2 adds the guard (boot service + installer step).
- **The writer of that 1 is unknown** (the settings row had defaultSysSet=true, so a system component made it; it was not in the 2026-11-05 settings backup). The guard is defensive, not a root-cause fix, and cannot catch a write later than ~5 minutes after boot.
- Untested on a phone: `port_netguard` starting from /odm at boot; the installer step; whether r2 actually prevents the problem. Idle drain (~150 mA screen-off) is still not fixed.
- OPPO Health "risk notice" (root detected, app closes): on the author's phone with the first 17k, Magisk's `su` was visible to the app (`/product/bin/su`, 9 Magisk mounts). Live: `magisk --denylist enable` + `add com.heytap.health` made the app's mount view clean (0 Magisk mounts, no `su`, `which su` empty) and the dialog did not appear in a uiautomator check right after launch. NOT verified: longer use of the app, other apps with root checks, persistence across a reboot (the setting is stored in Magisk's database), and the new installer step itself (not run).
- To apply (after a separate decision to flash): re-run `Install-17k-Magisk.sh` (upgrade, no wipe).

---

# First 17k (the images before r2): test status written after the first flash, 2026-11-06

17k has been installed on **one** phone: the author's OnePlus 7 Pro GM1910, which was running 17j-r2 with Magisk. Nothing here is a
claim about other phones, other firmware, or long-term behaviour.

## Verified on that phone
- `bash ./Install-17k-Magisk.sh` (from Git Bash on Windows) completed: no wipe, `/data` and its apps kept, `my_stock.img` replaced
  (previous one kept as `my_stock-prev.img`), slot B `vendor`, `system` and the Magisk boot flashed. A dry run (`--dry-run`) before it
  also passed.
- The phone booted to Android (`sys.boot_completed=1` about 80 s after power-up), on slot B, with the production properties
  (`ro.secure=1`, `ro.debuggable=0`) and MagiskSU root.
- The baked B20/B21 files are on the phone (`/vendor/odm/bin/port-chglimit.sh`, `port-bmslevel.sh` and the two `.rc` files;
  `port-chglimit.sh` has sha256 starting `ac6aa905`) and the init services `port_chglimit`, `port_bmslevel`, `port_wp_save` and
  `port_health_poke` were running after boot, started by init and not by hand.
- Battery level: right after boot Android showed the charger driver's inflated value (79 %) for a short time, then the real fuel-gauge
  value; the bind mount over `battery/capacity` was present and `dumpsys battery` level equalled `bms/capacity` (71 %).
- The charging-limit settings (`regular_charge_protection_switch_state=1`, level 85) were present, and the phone kept charging at 71 %,
  which is correct below the limit.

## NOT verified
- The real 85 % crossing: that charging actually stops at the limit with the baked service, and resumes when the level falls.
- The B18 wallpaper saver across reboots. After this first boot the wallpaper was the framework default (`Infiniti1VideoWallpaper`) and
  `/data/port/wp/` was empty. By design the saver only records a live wallpaper that is picked at least 150 s after boot, and removes the
  saved entry when a static wallpaper is chosen.
- The `oplus_chg` node-path fallback in `port-chglimit.sh` (the port's kernel does not have that path).
- `Install-17k-NoRoot` (any variant), and the `.bat` / `.ps1` installers. Only the `.sh` Magisk installer was run.
- A first install on a phone that does not already run the port. 17k is an upgrade only.

## Known issues
- **Found after this first flash:** `restricted_networking_mode` = 1 (no app network); see the 17k-r2 section above. The "Verified" list above did not catch it.
- **Idle battery drain (about 150 mA with the screen off) is not fixed.** 17k does not change it. See `docs/battery-handoff-2026-11-05.md`.
- An `init second_stage` child process aborts once per boot (tombstone, `SIGABRT`). It also happens on the previous build and was not
  investigated.
- The README and FACTS files inside the release ZIPs were written before this first flash and still say the build was never flashed;
  this file and the loose copies in the repository are the current state.
