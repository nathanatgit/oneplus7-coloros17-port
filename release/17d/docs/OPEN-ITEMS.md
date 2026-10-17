# Not in 17d: live-only patches, 17e, open issues, test list, rollback

## Live-only changes on the author's phone (not in the 17d images)

| Change | Where | Notes |
| --- | --- | --- |
| Screen color mode bridge | `/vendor/odm/bin/port-colormode.sh` + `/vendor/odm/etc/init/port-colormode.rc` (service `port_colormode`) | Follows `ColorDisplayService` log events and sets LiveDisplay modes: 301 standard -> Natural, 303 natural -> Brilliant, 307 vivid -> Vivid. Sources in `tools/live/colormode/`; added to `tools/live/odm-services/install.list` for the next build |
| In-place property overwrites | `/dev/__properties__` (reboot clears them) | Test only; nothing depends on them |

## Built but not flashed: 17e (`out-plk-build17e/`, preflight PASS)

17d + `ro.product.model=GM1910` in `my_manifest/build.prop` (About-phone chip; `Build.MODEL` changes only after boot; revert that one line if a ColorOS feature keyed on the model misbehaves) + the color mode bridge. Per the working rule it is not to be built or flashed without the user's approval.

## Known issues and unknowns

- Wallet card add on the 17d image has not been re-tested after the eSE work. Wallet, OPPO Health and Find My Device also check `ro.secure` / `ro.debuggable` and the bootloader state: the root checks fail on the development props (`PROD_PROPS=0`) and the unlocked bootloader cannot be hidden; the release ZIPs use production props.
- eSE opens take about 10 s (the SE HAL retries 5 x 2 s on the NXP NFC HAL's HIDL `omapi_status` ioctl that LineageOS does not serve). A small HIDL `INxpNfc` stand-in would remove the delay.
- Find My Device and the cryptoeng HAL: service runs; the account/RPMB flow was not re-tested end to end.
- IMS: the baked `ims.apk` was rejected once at the first scan after a flash (unexplained); `org.codeaurora.ims/.QtiImsExtService not found` was logged again later. Video calling, Wi-Fi calling and RCS were never tested.
- Light sensor reports about 0.45x of a reference and lags 2-4 s (`vendor.lineage.oplus_als` over-display correction not diagnosed).
- SystemUI GPU fault loop (`kgsl` page faults) seen once after a flash; not reproduced.
- Hardware self-check reports proximity and microphones as abnormal; microphones record fine, probably a self-check artefact.
- Front camera video, long clips, 4K60, slow motion, HDR: untested on the H.40 camera.
- Charger: the AIDL stand-in returns 0 / empty for 100+ methods that ColorOS may call for features not seen yet (fast-charge details, wireless).
- Breeno: only the keyword model is verified; activation after a reboot from a fresh data partition and the second-stage tuning are untested.
- Bluetooth, NFC card emulation, keyboard defaults and the Wi-Fi "connecting" item from the early lists were never worked through.

## Test list after a flash

1. `getprop sys.boot_completed`, `logcat -b crash -d`, no new tombstones, `pidof android.hardware.audio.service` stable for 30 s.
2. `/dev/p73`, `lshal | grep secure_element`, `dumpsys secure_element` shows `mIsConnected:true`; `service list | grep -E 'ICharger|secure_element'`.
3. Settings > Battery > Battery health shows a capacity; no "voltage too high" notice at USB plug-in or at boot with the cable.
4. Breeno: enable wake-up, finish the enroll screen, say 小布小布.
5. VoLTE call and an incoming SMS; GPS fix near a window; H.40 camera photo and a 1080p30 clip.
6. Auto brightness at low light is not brighter than manual 20 percent; proximity sensor wakes/blanks the screen in a call.

## Rollback

Flash the previous build's `system_b` and `vendor_b` (and `boot_b` if the kernel is suspect: `out-ese/boot_b.img` is the pre-eSE boot, sha `5fbf722d...`) from the kept build directories (`out-plk-build16/`, `out-plk-build15/` are the last two known-good). Slot A (stock H.40) is untouched by every install: `fastboot --set-active=a`, wipe only from stock recovery if data from another build blocks boot.
