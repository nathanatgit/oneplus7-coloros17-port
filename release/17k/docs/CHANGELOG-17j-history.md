# 17j changelog vs the 17d release

17d was the first release. The builds after it (17e, 17f, 17g, 17g-r2, 17h, 17i) were only flashed on the author's phone; 17j is the
next release and contains all of them. Item numbers are those of `tools/live/BAKE-LIST.md` (repository), where each one has its
evidence, live test and revert. **V** = verified on the phone (booted image or live with the user's confirmation), **L** = verified
live only, baked for 17j and not yet booted from a flashed image, **U** = baked, untested.

## 17e (built 2026-10-17)

| Item | Change | Status |
| --- | --- | --- |
| About chip | `ro.product.model` PLK110 → GM1910 (my_manifest) | V |
| Screen colour mode | ColorOS 鲜明/标准/自然 → LineageOS LiveDisplay modes (`/vendor/odm/bin/port-colormode.sh`, service `port_colormode`) | V |

## 17f

| Item | Change | Status |
| --- | --- | --- |
| A1 proximity | Type 8 proximity through IR only while the display is off: patched `sensors.ssc.so` reads its "audio state" from the FIFO `/data/vendor/aus`; `port_prox_fifo` + `port_prox_feeder` (ScreenStateFeeder) drive it. No IR emitter blink with the screen on / AOD | V |
| A2 panel feature 217 | `persist.vendor.port.dpf.217=3` (ColorOS "smooth transition" bits) | V |

## 17g / 17g-r2

| Item | Change | Status |
| --- | --- | --- |
| B1 DC dimming | Low-flicker option 2 drives the panel's DC backlight (`dimlayer_bl_en`) through DcBridge; option texts rewritten (OplusEyeProtect.apk string patch) | V |
| B2 memory extension | 内存扩展 works on the LineageOS kernel: swap file on /data (`port-nandswap.sh`, service `port_nandswap`) | V |
| B3 Play Store | Genuine Google Play Store placeholder as a my_product priv-app, so the market's Play Store is a privileged update (MANAGE_USERS; it used to crash at start) | V |
| B4 battery level | Battery level/voltage now update while unplugged: `IHealth::update()` every 20 s (`port_health_poke`) | V |

## 17h

| Item | Change | Status |
| --- | --- | --- |
| Incoming SMS / IMS | Aligned, factory-fixed `ims.apk` (`296bc757…`); PackageManager skipped the 17g APK (resources.arsc not 4-aligned), so no incoming SMS | V (user: pending SMS arrived) |
| B5 offline charging | `ro.qboot.res.path=/system_ext/etc/media/quickboot/`: charging with the phone off no longer loops (quickboot crashed on a missing image folder and powered off); ICharger stand-in returns real online states | V |

## 17i

| Item | Change | Status |
| --- | --- | --- |
| B7 com.android.se | No crash loop without a SIM (`SecureElement-iau.apk`, INTERACT_ACROSS_USERS) | V |
| B8 / B11 stubs | No-op AIDL perf2 IPerf and virtual face HAL stubs (`port-stubs.dex`): ends ~1000 log lines/min of failed HAL lookups; face service finishes registering | V |
| B9 GNSS | `loc_sys_service` not started (ILocAidlGnss retry loop) | V (GPS fix re-test pending) |
| B10 DC flicker | No bright frame at refresh-rate switches with DC dimming: `vendor.display.enable_optimize_refresh=0`, `persist.oplus.display.vrr=0`, DcBridge pins min refresh while DC is on | V |
| B12 keep-on-looking | Settings 注视时不息屏 hidden (pop-up front camera; AON overlay + aon features removed) | V |
| B13 app root checks | `/product/bin/getprop` shim shows apps ro.debuggable=0 / ro.secure=1 (OPPO Health "rooted" dialog) | V |
| B14 camera provider | Provider starts with SIGPIPE ignored (was killed mid-capture) | V |

## 17j (new in this release)

| Item | Change | Status |
| --- | --- | --- |
| C1 / C1b-fix donor camera | ColorOS 17 camera `com.oplus.camera` 7.006.125 baked in: `/my_product/app/OplusCamera/OplusCamera.apk` (p9: front shutter, 3x tele switch, master-mode filters), SDK v11 + adapter v18 in `/product/framework` (LUT fallback, two-LUT blend), unit library XML, `persist.camera.override_*` defaults (no HDR preview); donor odm camera data (1.5 GB) and 113 donor odm libs in `my_stock.img` `/my_stock/port-camera`, bind/overlay-mounted by `01-port-camera.rc`; master preview no longer overexposed (SimTool_Master.ini ODT=0, CWCM=0). Replaces `restore-live.sh`. The H.40 OnePlus camera stays | L (live set verified; baked boot path untested) |
| B15 video wallpaper | Patched WallpaperChooser releases the paused HEVC decoder 1.5 s after screen off (3.6 → 0 CPU-s per minute screen off) | L |
| B15 IMS rebind loop | `00-port-ims-rilsvc.rc` keeps `org.codeaurora.ims/.ImsRilService` disabled (bind loop every 0.5 s). Revert: `setprop persist.sys.port.imsrilsvc on` | L (VoLTE / SMS with a SIM not re-tested) |
| B15 schedtune | `/dev/stune` mounted from `/system/etc/task_profiles/cgroups_28.json` + 5 LOS groups (`00-port-stune.rc`): the power HAL stops retrying every 0.5 s | L (boot path untested) |
| B15 proximity feeder | Event-driven ScreenStateFeeder (DisplayListener instead of a 150 ms poll) | L |
| B15 colour mode | `port-colormode.sh` watches the settings file with inotifyd instead of reading the whole logcat | L |
| B16 props | H.40 / ColorOS values in vendor build.prop: density 600 + screen-zoom steps, dalvik heap, confidential=false / allnet, mag_filter, OnePlus default sounds, keystore_desede + cuptsm, LTE RSRP thresholds, no data roaming, media volume 15, rc.size | V (live on vendor_b, verified after reboot) |
| B17 identity | my_manifest `ro.product.bootimage.{model,name,device}`, my_product `ro.product.authentication`, and (test keys, live-tested) `ro.product.device=OnePlus7Pro`, `ro.product.name=OnePlus7Pro_CH`, `ro.build.product=GM1910` | L (test keys were live through vendor build.prop; camera photo OK, apps open) |
| B18 wallpaper keep | The chosen live wallpaper survives reboots: `port_wp_keep` re-applies `/data/port/wp/wallpaper-component` 20 s after boot; `port_wp_save` (inotifyd) saves the user's later changes | L (helper verified live; baked boot path untested) |

## Not in 17j

- B6 H.40 Vidhance EIS (partial live fix only; `vendor.vidhance.enabled=0` stays).
- B15 proposals not done: Breeno wake word vs suspend, DcBridge's 30 s settings poll, small vendor retry loops, the unplugged overnight drain measurement.
- Test-only rc files from live sessions (they disappear with the vendor flash).

## Install change

17d installers were clean installs (`fastboot -w`). The 17j installers are **upgrade** installers: no wipe, user data kept. A clean
install is only described as a manual procedure in `README.md`.

## 17j-r2 (2026-11-03)

| Item | Change | Status |
| --- | --- | --- |
| Camera libs | 41 donor JNI libs also in `/product/lib64` (the camera app cannot see `/my_product/lib64`; `libCombineLutJni.so not found` crash) | L (overlay of the same files verified on the phone), image U |
| Production boot | `oplus-services.jar` `OplusEngineerFwService.getEngineerService()` no longer calls `waitForService` on the absent IEngineer HAL when `ro.adb.secure=1` (watchdog bootloop of the 17j production image); `ro.adb.secure=1` unchanged | U (offline checks only) |

### r2 (rebuilt 2026-11-05 with the B18 wallpaper saver fix)

| Item | Change | Status |
| --- | --- | --- |
| Wallpaper saver (B18) | `port-wp-save.sh` removes `/data/port/wp/wallpaper-component` when the system wallpaper is static (no component on the `<wp>` tag, ImageWallpaper, or bindSource SET_STATIC), so a reboot no longer replaces a static image with the last live wallpaper; the inotifyd mask is now `wmny` (WMS writes `wallpaper_info.xml.tmp` and renames it: event `y`, `wmn` never fired). Lock `<kwp>` entry ignored on purpose. | L (live-tested on the phone, see DEVELOPMENT_LOG), image U |

The previous r2 production system (sha 1e47ce79…) was boot-tested by running on the phone for 1 day 4 h with no tombstones; props, identity, the camera system app and `/product/lib64` libs, stune, the IMS rule, the odm camera mounts and Magisk su were all verified. Only the system images changed in this rebuild (development `e64a10ca…`, production `0b24fcb2…`); a file-by-file comparison with the system the phone was running shows only `port-wp-save.sh` and `00-port-wpkeep.rc` changed (`oplus-services.jar` differs only in dex byte layout: baksmali output identical). **vendor and my_stock are unchanged from r2** (`d8f45456…`, dumped from the phone's vendor_b; `135022d0…`, copied from the phone's /data/port), because a fresh build of them would have dropped 504 stock app files (the full-stock my_stock source no longer exists) and added two odm services (port-chglimit, port-bmslevel) that are not part of this release.
