# Not in 17j, open issues, first-boot checks, rollback

## Not in the 17j images

- B6 H.40 camera Vidhance EIS: partial live fix only; `vendor.vidhance.enabled=0` stays (Super Steady records without Vidhance).
- B15 proposals not implemented: wake-word vs suspend measurement, DcBridge's 30 s settings fallback poll, small vendor retry loops
  (AEC effect, DmtpClient, GPU minidump, Obrain), the overnight unplugged drain test.
- Donor-camera items still open (BAKE-LIST C1): tele in video/master/portrait modes, preset grain/glow/vignette, strength slider
  other than 100, donor-only LUTs (`ccd_promist_neutral.bin`), the unpatched Fold/Lut video-wallpaper engines.
- Offline-charging at a truly dead battery was fixed live (B5) but the baked boot was not repeated at 0 %.

## Verified only live (baked in 17j, the baked boot path is untested)

C1 donor camera (now from the image instead of `restore-live.sh`), B15 (wallpaper decoder release, ImsRilService rc, schedtune
mount from `cgroups_28.json`, event-driven feeder, inotify colour mode), B17 test keys (were live through vendor build.prop),
B18 wallpaper keeper. Checks for the first boot are below.

## First boot after flashing 17j

```
adb shell getprop sys.boot_completed                                    # 1
adb shell "logcat -b crash -d | tail -n 20"; adb shell ls /data/tombstones
adb shell pm path com.oplus.camera                                      # want /my_product/app/OplusCamera/OplusCamera.apk
adb shell "pm list libraries | grep -c camera.unit"                     # 3
adb shell "grep -cE ' /vendor/odm/etc/camera | /vendor/odm/lib64 ' /proc/mounts"   # 2
adb shell getprop persist.camera.override_preview_hdr_support           # false
adb shell "mount | grep stune; ls /dev/stune"                           # schedtune mounted, 5 groups (B15)
adb shell "getprop ro.product.device; getprop ro.product.name; getprop ro.build.product"   # OnePlus7Pro OnePlus7Pro_CH GM1910
adb shell "logcat -d -s port_wp_keep port_wp_save"                      # B18 messages
adb shell "dumpsys package org.codeaurora.ims | grep -A3 disabledComponents"   # lists org.codeaurora.ims.ImsRilService (B15)
```

Then by hand: camera photo / video / front / 3x, master-mode preset, Breeno wake word, VoLTE call + incoming SMS (with a SIM),
GPS fix near a window, DC dimming at low brightness, screen off for a few minutes with the video wallpaper (no hwcodec CPU).

## Known issues and unknowns (carried from 17d, still open)

- Wallet / OPPO Health / Find My Device: root and bootloader checks; production props help, the unlocked bootloader cannot be hidden.
- eSE opens take about 10 s (NXP NFC HAL `omapi_status` retries).
- IMS: video calling, Wi-Fi calling and RCS never tested; VoLTE + SMS not re-tested since B15's ImsRilService change.
- Light sensor reads about 0.45x of a reference and lags 2-4 s.
- Charger AIDL stand-in answers 0 / empty for methods not seen yet.

## Rollback

- Keep the previous build's images. Flash its `vendor_X`, `system_X` (and `boot_X` if it differs) of the active slot, then put the
  previous my_stock back before booting it, as root on the phone:
  `cd /data/port && mv my_stock.img my_stock-17j.img && mv my_stock-prev.img my_stock.img && chcon u:object_r:system_file:s0 my_stock.img && sync`
  (the 17j installer keeps the previous image as `my_stock-prev.img`). 17j's system works with an older my_stock for a boot (no donor
  camera then), an older system ignores 17j's extra `/my_stock/port-camera`.
- The installers write only `vendor`, `system` and `boot` of the slot they flash (the port runs from slot B), and `userdata` only when you type WIPE.
