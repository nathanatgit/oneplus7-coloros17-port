# 17k test status (written after the first flash, 2026-11-06)

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
- **Idle battery drain (about 150 mA with the screen off) is not fixed.** 17k does not change it. See `docs/battery-handoff-2026-11-05.md`.
- An `init second_stage` child process aborts once per boot (tombstone, `SIGABRT`). It also happens on the previous build and was not
  investigated.
- The README and FACTS files inside the release ZIPs were written before this first flash and still say the build was never flashed;
  this file and the loose copies in the repository are the current state.
