# Camera build 13 handoff — 2026-10-16

Read `PORT_LOG_2026-10-16.md` for the chronological evidence and `FACTS_2026-10-16.md` for the current claims. Earlier project `handoff-2026-10-16.md` describes build 13 but predates this donor-camera work. Never flash the PLK110 donor firmware onto GM1910; the donor is an app source. Ask before flashing any prepared port image.

## Known working state

- Slot B build 13 booted, root ADB serial `<DEVICE_SERIAL>`. H.40 camera APK is intact. Open Camera Camera2 front preview and motor popup/retraction were verified live by frame count, motor state and user observation. Helper was allowed in the device-idle user whitelist and its UID owns only the two motor write nodes for this live session.
- New donor camera 7.006.125 is installed with shared-library registration. Rear ID 0 can open and HAL can emit preview buffers under a diagnostic no-APS setup, but the app displays black. The donor app has no validated capture/video output or final zoom row.

## Do next

1. Check current mounts/processes before any test. The three donor JNI/config overlays were removed for provider recovery. Remount only when testing donor app. Preserve original `fwk_config.json`, `vidhance_calibration`, existing product libraries, and old camera APK.
2. Diagnose black preview with corrected SDK trace helper. Inspect `Camera2Impl$6` `onCaptureCompleted`/`onCaptureProgressed`, metadata handoff, `NoneApsImpl.addPreviewFrameBuff`, and surface output. Do not infer missing metadata from the prior `NoSuchMethodError` tracing run. Restore a known-good SDK JAR if a diagnostic patch crashes.
3. Fix zoom by identifying actual preset construction and ultrawide capability. Target 0.6× → physical ID 3, 1× → ID 0, 3× → ID 2. Remove the 2× digital shortcut only when touch selection and preview routing both work. The donor config JSON list alone changed 3.5× to 3× but left 1× / 2× / 3×.
4. Keep popup verification separate from donor app preview. Build a persistent helper solution only after app privilege, narrow motor access, safe startup and clean boot are verified. Fall/drop protection has not been tested.

## Reversal and limits

- Live binds: `/product/framework`, `/system/etc/permissions`, `/product/app`. Staging: `/data/local/tmp/cos17-camera-build13`. No donor hardware HAL was flashed or replaced. The three removed overlays have staged copies. Confirm actual mount state before rollback; `rollback-sdk-live.sh` predates later mounts and is incomplete.
- Camera provider can disappear transiently and re-enumerate slowly (more than 30 s) on restart. Repeated provider deaths were seen during legacy Open Camera use; Camera2 produced 250 increasing frames in the successful front test.
- The D: drive holds only a copy of the donor APK. The exact OTA and all previous files remain where they were. The source port folder is outside this task's writable root; the authoritative new live log and facts reside in `<LOCAL_WINDOWS_PATH>`.

