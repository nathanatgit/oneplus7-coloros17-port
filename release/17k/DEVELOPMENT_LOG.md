# Development log — 17k

## 2026-11-06
1. User approved baking the charge-cap (B20) and gauge (B21) fixes on top of 17j-r2, plus the wallpaper fix, and a release like 17d.
2. Wallpaper: a parallel session had already shipped the B18 saver fix in the 17j-r2 rebuild. A baked "default wallpaper" (B18b) was prototyped and live-tested, then dropped (wrong premise: the saver works; nothing is saved because the user had not picked a wallpaper after boot). `port-wp-keep.sh` is back at `a8e189f1...`, identical to the file inside the images.
3. B20/B21: confirmed `tools/live/odm-services/install.list` + `SHA256SUMS` carry the four files; added the preflight section "B20+B21". Because `stock-app-source/extracted/my_stock.img` is gone, the vendor was rebuilt alone from the 17j-r2 vendor; systems and my_stock reused byte-for-byte.
4. Preflight (development + production) and the vendor file diff: see `logs/`.
5. Not done: no flash, no boot test, installers not run end to end, idle drain not addressed.
