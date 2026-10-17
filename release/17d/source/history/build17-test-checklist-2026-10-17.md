# Build 17 — test checklist (after flashing; nothing here has run on a phone yet)

Build: `out-plk-build17b/` (17 failed, see handoff §11; sections 1-2 now also require `service list | grep charger` to show the AIDL ICharger and `ps -A | grep -E "charger|cryptoeng"` running) (see `handoff-2026-10-17.md` §10 for shas and what changed). Phone on slot B, USB attached for anything telephony-related (wireless adb: `<LOCAL_IP>:5555`). Build 17 was built and preflighted only; **not flashed**.

## 0. Flash / rollback (needs the user's explicit OK first)

`my_stock.img` has the same size as build 16 and is built from the same inputs (the sha differs; content not diffed), so keep the file already on the phone (`/data/port/my_stock.img`) and flash only `system_b` and `vendor_b`:

```bash
adb reboot bootloader
fastboot getvar current-slot          # must say b
fastboot flash vendor_b out-plk-build17/vendor.img
fastboot flash system_b out-plk-build17/system.img
fastboot reboot
```

No wipe, no `boot_b`, nothing on slot A. Rollback = the same two commands with `out-plk-build16/`.

First look after boot (before any feature test): `getprop sys.boot_completed`, `adb logcat -b crash -d`, `ls /data/tombstones` (new files?), `pidof android.hardware.audio.service` stable for 30 s, `dmesg | grep -i 'avc.*denied' | head` is expected to be noisy (permissive).

## 1. Battery — charger HAL (A)

```bash
adb shell 'ps -A | grep -i charger; lshal list 2>/dev/null | grep -i oplus.hardware.charger'
adb shell 'logcat -b all -d | grep -ci getIChargerService'            # expect 0 new lines after boot
adb shell 'dumpsys battery'; adb shell 'cat /sys/class/power_supply/battery/uevent | grep -E "NOTIFY_CODE|CAPACITY|CHARGE_FULL"'
```

- `charger_hal_service` is running as `system` and `vendor.oplus.hardware.charger@1.0::ICharger/default` is listed. If it is missing: `logcat -b all -d | grep -iE 'charger_hal|hwservicemanager.*charger'` and `adb shell 'start charger_hal_service'`.
- Settings → Battery → **Battery health** shows a capacity instead of "cannot obtain capacity".
- Plug into the USB 3.0 PC port: no "charging voltage is too high" notice. If it still shows, capture `NOTIFY_CODE` and `logcat -b all` while it shows (handoff §9 item 1).
- The stock rc writes `/proc/ui_soc_decimal` and chmods `/sys/class/oplus_chg/*` nodes at boot_completed; missing nodes on the LOS kernel only log errors. Check `adb shell 'ls /proc/ui_soc_decimal /sys/class/oplus_chg 2>&1'` and note which exist.

## 2. Find My Device — cryptoeng HAL (B)

```bash
adb shell 'ps -A | grep -i cryptoeng; lshal list 2>/dev/null | grep -i cryptoeng; ls -ldZ /data/vendor_de/0/cryptoeng'
adb shell 'logcat -b all -d | grep -iE "cryptoeng|qseecom|QSEECom|keybox" | tail -40'
```

- Service running as `system`, `ICryptoeng/default` listed, `/data/vendor_de/0/cryptoeng` exists (`system:system 0770`).
- `/data/vendor_de` must still be `0551 root:root` (the port rc deliberately does not touch it): `adb shell 'ls -ldZ /data/vendor_de /data/vendor_de/0'`.
- The TA `cryptoeng` loads from `/odm/vendor/firmware` (same place as the Goodix TAs): look for `Loaded cryptoeng` or load errors in logcat/dmesg (`dmesg | grep -i cryptoeng`).
- Open Find My Device / the Settings entry. Before: `RPMB hardware channel: CryptoEng service is null`. App log lines (`FindMyPhone.Rpmb*`) are base64 of bytes XOR 2. Still failing → check the root checks (handoff §9 item 3: `ro.secure=0`/`ro.debuggable=1`; a `PROD_PROPS=1` build changes them and removes adb root, user decision).
- Risk to watch: the HAL calls `vendor.oplus.cryptoeng.need_init` at boot_completed and talks to qseecomd; a crash loop would show in `logcat -b crash` and `ps -A | grep cryptoeng` restarting.

## 3. Wallet — OMAPI app only (C) — the eSE HAL is NOT in 17b (no /dev/p73 on this kernel, see handoff §11); expect Wallet to change its error at best

```bash
adb shell 'ls -l /dev/p73; getprop vendor.nfc_se.config_ready; getprop init.svc.vendor.secure_element_hal_service_1_1'
adb shell 'lshal list 2>/dev/null | grep -i secure_element'          # expect SIM1, SIM2 (@1.2, from the LOS vendor) and eSE1 (@1.1)
adb shell 'service list | grep -i secure_element; pm path com.android.se; dumpsys package com.android.se | grep -E "userId|codePath|signatures"'
adb shell 'logcat -b all -d | grep -E "SecureElementService|nq330|ese_|SecureElement" | tail -60'
```

- The HAL needs the eSE SPI node `/dev/p73` from the kernel; if it does not exist the LOS kernel has no driver and this item cannot work without a kernel change (then everything else in this section is moot).
- `secure_element` appears in `service list` once `com.android.se` runs (persistent app, shared uid `android.uid.se`). `android.se.omapi.ISecureElementService/default` is only registered when the app's `secure_element_vintf_enabled` resource is true (not expected).
- Coexistence with the LOS NFC HAL (`android.hardware.nfc-service.nxp`, AIDL, user `nfc`): both should stay up; check `ps -A | grep -E 'nfc|secure_element'` and that tap-to-pay/NFC toggle still work. The stock SE HAL also expects a HIDL `vendor.nxp.nxpnfc@1.0` service that only the stock NFC HAL provides; the LOS HAL does not, so calls that go through it can fail (look for `INxpNfc` / `getService` errors in the SE HAL's log lines).
- Open Wallet → add card. Before: `ServiceConnectException: Se Service Connection Error`. If the error changes to a different one (reader not found, channel open error) note the exact text; `iwallet.finzfin.com` timeouts are a network/region matter (handoff §9b).
- Rollback of just this item (no reflash): `adb shell 'stop vendor.secure_element_hal_service_1_1'` and `pm disable-user --user 0 com.android.se`.

## 4. Voice wake-up — stock H.40 `com.oneplus.voicewakeup` (D)

```bash
adb shell 'pm list packages -d | grep ovoice'          # com.oplus.ovoicemanager.wakeup must be listed (disabled by port_disable_wakeup)
adb shell 'pm path com.oneplus.voicewakeup; dumpsys package com.oneplus.voicewakeup | grep -E "userId=|sharedUser|codePath|flags=|signatures|Package \["'
adb shell 'logcat -b all -d | grep -iE "voicewakeup|PackageManager.*voicewakeup|listenjni|UnsatisfiedLink" | tail -40'
adb shell 'logcat -b all -d | grep -iE "sound_trigger|soundtrigger" | tail -40'
```

- Package scanned: `userId=1000` (shared `android.uid.system`), no "Signature mismatch for shared user" or scan error, no `UnsatisfiedLinkError`. First boot compiles it (no oat), a short CPU burst is normal.
- `SoundTrigger.listModules` should now return the QTI module (earlier live test failed with no module only because the phone was in a degraded state). Check: `dumpsys soundtrigger_middleware` (or `cmd` equivalent) lists a module.
- Wake-up on/off is `Settings.Global wakeup_word` (non-empty = on; the app restores its session itself at boot): `adb shell settings get global wakeup_word`. To switch on without the training UI try `adb shell settings put global wakeup_word xiaobuxiaobu`, then `logcat | grep -i voicewakeup` for `loadSoundModel`/`startRecognition` results; the DSP model is `assets/sm3_xiaobuxiaobu.uim` (GM1910). The app's own UI is the Qualcomm SVA demo (Sound Model Settings: LOAD / START / STOP / UNLOAD). Say the phrase and look for the detection event.
- **Risk:** a failed start used to make `SoundTriggerHalEnforcer` restart the audio HAL repeatedly (recording stops). While testing keep `pidof android.hardware.audio.service` in view. Emergency off: `adb shell settings put global wakeup_word ""; adb shell pm disable-user --user 0 com.oneplus.voicewakeup`.
- ColorOS 17's Breeno package must stay disabled (`pm list packages -d`), it is what crash-looped the HAL.

## 5. Proximity (audio HAL guard patch) and other folded-in items

- `adb shell dumpsys sensorservice | grep -iA3 proximity` / a call with the screen off: the type-8 `proximity` sensor reports; 4× sleep/wake with no new `audio.service` tombstones (`ls -la /data/tombstones`). Known limit: after some wakes the ultrasound start is skipped, so proximity may be quiet until the next restart; test a real call (face-to-ear screen off) and `Hw stype 8` helper (`tools/live/hwtest/Hw.java`).
- Hardware self-check (`com.oplus.postmanservice`): proximity should pass now; the three mic items are still unexplained (handoff §7 item 3).
- Auto-brightness: at ~100 lux the panel raw level is about 221-223 (`cat /sys/class/backlight/panel0-backlight/brightness`); try lamp and dark room too (high-lux/HBM never measured).
- About phone → Version shows `GM1910_17.0.0.100(202610171200)`.
- Regression pass from handoff §4: incoming SMS, VoLTE call both ways (IMS app scan: `dumpsys package org.codeaurora.ims`), camera 1080p30/4K30/1080p60, GPS fix, SystemUI stable (no `kgsl-3d0` page faults in `dmesg`).

## 6. What to send back if something fails

`adb logcat -b all -d > logs/plk-build17/boot-logcat.txt`, `adb shell dmesg > logs/plk-build17/dmesg.txt`, `adb shell getprop > logs/plk-build17/getprop.txt`, `adb shell 'ls -laZ /data/tombstones'`, plus the exact app error text for the feature under test.

