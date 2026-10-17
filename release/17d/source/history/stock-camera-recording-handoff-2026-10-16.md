# H.40 stock camera recording crash handoff — 2026-10-16

> **Superseded 2026-10-17:** H.40 stock camera records 1080p30 / 4K30 / 1080p60 with `vendor.vidhance.enabled=0` and the v10 APK; see `h40-video-fixed-handoff-2026-10-17.md`. The V6/V7 state described below is obsolete (V7 is malformed; never mount it).

## Objective

Fix the OnePlus 7 Pro PLK110 H.40 stock Camera app crashing when entering video preview or starting video recording, especially 1080p60 and 4K30. Validate 1080p30 first. A successful activity launch or preview is not proof of a successful recording: final validation must produce an MP4 and inspect its streams, dimensions, frame rate, duration, and audio.

Use REA 6.5.0 for live inspection/control and root ADB for device diagnostics. The REA CLI used previously is `<LOCAL_WINDOWS_PATH>`.

## Device and live state at handoff

- Device: PLK110 / OnePlus 7 Pro, ADB serial `<DEVICE_SERIAL>`; root ADB was available.
- The top camera APK bind mount is V6, staged as `/data/local/tmp/OnePlusCamera-eis-bypass-v6.apk`, SHA-256 `388d28ca33f87c33eff432e975f7dfa77762c81a0846664673c4c1c8bc76996e`. The mounted path hash matched the staged V6 APK.
- The camera process was force-stopped after the last failed test.
- `screen_off_timeout` was restored to `30000`; `stay_on_while_plugged_in` was restored to `0`.
- Several camera APK bind mounts are stacked. V6 is the top mount. Do not casually unmount or reboot; inspect the mount table and understand the stack first.
- Camera's per-mode `Video.xml` was set to 3840x2160@30 during earlier testing. Inspect current values before changing them.
- Do not flash or reboot as part of this investigation without an explicit user request. The user has emphasized waking the phone before taking screenshots.

## Confirmed Video shortcut

The launcher shortcut was inspected with Android ShortcutManager:

```text
adb shell cmd shortcut get-shortcuts --user 0 --flags 31 com.oneplus.camera
```

The registered shortcut ID is `video`, label `Video`, package `com.oneplus.camera`. Its action and component are:

```text
com.oneplus.camera.action.LAUNCH_IN_VIDEO
com.oneplus.camera/.CameraEntry
```

The exact direct launch that worked was:

```text
rea start-adb-activity <DEVICE_SERIAL> com.oneplus.camera.action.LAUNCH_IN_VIDEO --component com.oneplus.camera/.CameraEntry
```

REA reported `com.oneplus.camera/.CameraActivity`; logs showed `StartMode NORMAL -> NORMAL_VIDEO`. This proves the Video shortcut intent directly enters Video mode. A prior generic `android.media.action.VIDEO_CAMERA` launch aimed at `.OPCameraActivity` was wrong and should not be reused.

## Failure evidence with V6

Log: `tools/live/rea-analysis/v6-direct-shortcut.log`.

The HAL tried to configure these streams, including the 960x540 preview-frame callback reader:

```text
1920x1080
3840x2160
3840x2160
960x540
```

Then it failed:

```text
Error configuring streams: Function not implemented (-38)
```

`OPCamera2CoreImpl/0` reported a camera session failure (`CameraAccessException: CAMERA_ERROR (3)`). The app then finished `CameraActivity` from its preview/error callback and returned to Launcher. Thus, the observed UI disappearance follows camera preview/HAL configuration failure; it is not evidence that the shortcut intent failed or that Voice Assistant caused the original crash.

V6 did **not** remove the 960x540 callback reader. Logs include `Preview frame call-back size selected: 960x540` and `Create preview frame reader with size 960x540`. Inspection of its DEX showed `OPNormalCamcorderImpl.onSelectPreviewFrameCallbackSize` was still original.

## V7 patch experiment — invalid candidate

- Helper: `tools/live/rea-analysis/patch_disable_preview_callback.py`.
- Intended method entry in the inspected DEX: offset `0x88fac0`, original first instruction bytes `1a00 33a5` (two code units).
- Intended patch replaces both code units with `28 42 00 00` (little-endian): `goto +0x42`, followed by `nop`, reaching the existing `OperationResult.NONE` return path.
- The first attempt changed only two bytes (`28 42`) and left the second old code unit behind. Android rejected that APK with `VerifyError`; see `tools/live/rea-analysis/v7-direct-shortcut.log`.
- The helper was corrected to write all four bytes, but the corrected result has **not** been rebuilt or tested. Existing `OnePlusCamera-eis-bypass-v7-disable-callback.apk` is the malformed APK and must not be installed or treated as valid.
- Build the next experiment from V6 to a new filename and a unique device path (for example V8), so the malformed V7 file and remote path are not reused.

## Next steps

1. Reconfirm device/build, root ADB, mount stack, camera process, settings, and `Video.xml` before testing. Keep the phone awake for screenshots and restore any temporary settings afterward.
2. Rebuild a fresh candidate from V6 using the corrected four-byte DEX patch. Verify the patch bytes and disassembly before pushing. Expected entry: `goto 0042`, then `nop`; target: `sget-object OperationResult.NONE; return-object`. Verify DEX/APK integrity/checksum.
3. Push the candidate with REA to a new remote path, bind-mount it only after recording the current mount state, and verify the live mounted APK hash.
4. Launch the exact Video shortcut action above. Inspect whether the 960x540 callback reader is gone and whether the HAL accepts the resulting stream set. Capture fresh logcat around configuration.
5. If preview remains stable, test and validate 1080p30 first. Then test 1080p60 and 4K30 individually, capturing the actual MP4 and checking it with `ffprobe` or equivalent. If HAL still rejects streams, use the exact rejected stream combination to guide the next narrow patch rather than claiming a fix.
6. Preserve V6 and all prior APK/log artifacts. Never treat UI launch alone as a successful recording.

## Historical results and evidence files

Earlier tests (before the current V6 state) recorded:

- Open Camera 4K: verified MP4, about 10.01 seconds, H.264 3840x2160 at about 29.7 fps, AAC audio.
- Stock H.40 Camera 1080p30: a historical 82.85-second HEVC 1920x1080 recording was reported verified.

These are historical baselines, not validation of V6 or of the current 1080p60/4K30 fixes. No successful video recording with V6 has been established.

Relevant REA artifacts include `tools/live/rea-analysis/v6-direct-shortcut.log`, `v6-shortcut-video.log`, `v7-direct-shortcut.log`, and the APK/DEX files in the same directory.

