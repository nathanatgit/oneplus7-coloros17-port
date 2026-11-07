# Development log — 17k

## 2026-11-07: 17k-r2 rebuilt
1. User approved baking B24 (slider hold), B25b (release ends the capture) and B26 (audio policy maxOpenCount 1; verified live by the user: slider 随口记 recorded and saved a note). Same release name r2, folder 17k, replacing the never-flashed r2 artifacts.
2. Baked without rebuilding system.img: dex in the vendor (`/odm/bin`), init oneshot at `on boot` bind-mounts it (same technique as the live test), fallback to the stock dex. The two XMLs edited in the vendor image.
3. Preflight section "B24/B25b/B26", dev + prod PASS, vendor diff = the 5 expected files, dash stub test PASS. Not flashed, not booted, installers not run.

## 2026-11-06 (later): 17k-r2
1. After the first 17k upgrade the author's phone had Settings.Global `restricted_networking_mode` = 1: all normal apps without network (Wi-Fi and cellular), adb shell fine, `dumpsys netpolicy` "Restricted networking mode: true". `settings put global restricted_networking_mode 0` fixed it immediately; after one more reboot the key reads null. The row had defaultValue=1 defaultSysSet=true (made by a system component), was absent from the 2026-11-05 13:17 settings backup and survived a reboot while it was 1.
2. The writer is UNKNOWN (none of our scripts/docs/transcripts sets it; the investigation was cut short). The user approved a defensive fix: "update your release script in github to avoid this and make new 17k image to bake that".
3. Logged first as B22 / A04 in `tools/live/BAKE-LIST.md`, then built: `port-netguard.sh/.rc` (oneshot, 4 checks over ~5 min, no polling), preflight section "B22", installer step, vendor-only rebuild (`scripts/build-17k-r2-*.sh`), preflight dev + prod PASS, vendor diff = the two new files only, offline stub tests of the script, syntax checks of the installers.
4. Not done: no flash, no boot test, installers not run, idle drain not addressed, root cause not found.

## 2026-11-06
1. User approved baking the charge-cap (B20) and gauge (B21) fixes on top of 17j-r2, plus the wallpaper fix, and a release like 17d.
2. Wallpaper: a parallel session had already shipped the B18 saver fix in the 17j-r2 rebuild. A baked "default wallpaper" (B18b) was prototyped and live-tested, then dropped (wrong premise: the saver works; nothing is saved because the user had not picked a wallpaper after boot). `port-wp-keep.sh` is back at `a8e189f1...`, identical to the file inside the images.
3. B20/B21: confirmed `tools/live/odm-services/install.list` + `SHA256SUMS` carry the four files; added the preflight section "B20+B21". Because `stock-app-source/extracted/my_stock.img` is gone, the vendor was rebuilt alone from the 17j-r2 vendor; systems and my_stock reused byte-for-byte.
4. Preflight (development + production) and the vendor file diff: see `logs/`.
5. Not done: no flash, no boot test, installers not run end to end, idle drain not addressed.

## 2026-11-07 (17k-r3)
1. User approved: "rebake 17k as r3, update the release folder 17k and everything in GitHub" (build, release packaging, git commit + push; no flashing).
2. BAKE-LIST first: new entry A06, B27 marked baked. Route: vendor-only, one odm rc (`tools/live/odm-services/port/etc/init/port-offlinecam-stub.rc`, install.list + SHA256SUMS), no system.img change (the system rc declaring `port_oplus_stubs` stays as is).
3. `tools/build-17k-r3-vendor.sh` (rebuilt r2 vendor + 1 file), `tools/build-17k-r3-assemble.sh` (preflight dev + prod, vendor diff). New preflight section "B27".
4. Packaged like r2 (`scripts/package-release.py`, ZIP names `OnePlus7Pro-17k-r3-*.zip`); the r2 zips were removed (as r1's were at r2). The Quark upload of r3 is for the author to do.
5. Not done: no flash, no boot test, installers not run on a phone.
