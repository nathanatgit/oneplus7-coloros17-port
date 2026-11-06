# Development log — 17k

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
