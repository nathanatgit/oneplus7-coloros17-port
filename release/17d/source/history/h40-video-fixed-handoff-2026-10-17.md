# H.40 stock camera video — working live, 2026-10-17 (supersedes stock-camera-recording-handoff-2026-10-16.md)

Verified on the phone (build 15, slot B), each clip pulled to `logs/camera-video-b14/` and checked with ffprobe + full ffmpeg decode (rc 0):

| Mode | File | Result |
| --- | --- | --- |
| 1080p30 | `v9-1080p30.mp4` | HEVC 1920x1080 + AAC, 7.3 s |
| 4K30 | `v10-4k30.mp4`, `v10-4k30-final.mp4` | HEVC 3840x2160 + AAC, 220/221 frames in 7.3 s |
| 1080p60 | `v10-1080p60.mp4` | HEVC 1920x1080 + AAC, 443 frames in 7.4 s (~60 fps) |

Not tested: front camera video, clips longer than ~10 s, 4K60, slow motion, HDR, a clean boot with the new build.prop value.

## What fixed it (all three are needed; now baked into build 16, see `handoff-2026-10-17.md`)

1. `vendor.vidhance.enabled=0` — the EIS node (`com.oneplus.node.eis.so` -> `libvidhance.so`) crashed the camera provider the moment recording started (`EisNode ... enableEIS 1`, then a bad ANativeWindowBuffer `incRef` passed to `eglCreateImageKHR`; root cause inside libvidhance not resolved). Baked into `tools/build-port-b.sh` + `tools/preflight-b.sh`.
2. 4K30 only: the app configured 4 streams (1080p preview, 4K video, 4K JPEG snapshot, 960x540 YUV preview-frame reader) and the camera HAL answered `-38` (ENOSYS). 1080p uses 3 streams and works. `Camera2CoreImpl` (AbstractCameraCore) `isPreviewFrameCallbackDisabled()` was patched to return true, so the YUV reader is not created. Session type `OPNormalCamcorder.SessionType4k30fps` 0x8116 -> 0 is also in the APK; whether 0x8116 alone would have been accepted was not isolated.
3. `vendor.audio.hw.aac.encoder=false` (already baked earlier) for AAC through Codec2.

Camera APK: `tools/live/camera/OnePlusCamera-H40-v10.apk`, sha256 `3415078eebeb5c24cade0ae0ba6caa731c2719b5060f1d53a873879ba61fc5e1`. `tools/build-port-b.sh` now ships it (asserts the sha). It is built from V6 (`eis-bypass-v6-no-preview-callback`) + V8 (`patch_disable_preview_callback.py`, four-byte patch) + V9 (`patch_dex_const.py`) + V10 (`patch_dex_bytes.py`) in `tools/live/rea-analysis/`. V7 (`0ae28a20...`) is the malformed APK and must never be mounted; it was the top bind mount when this session started.

## Live state on the phone (lost on reboot)

- `/my_stock/priv-app/OnePlusCamera/OnePlusCamera.apk` top bind mount = `/data/local/tmp/OnePlusCamera-eis-bypass-v10.apk` (the stack underneath is still ~28 deep; not unwound).
- Props: `vendor.vidhance.enabled=0`, `vendor.vidhance.video.enabled=0`, `vendor.audio.hw.aac.encoder=false`.
- `com.oplus.ovoicemanager.wakeup` is `disabled-user` (`pm enable --user 0 com.oplus.ovoicemanager.wakeup` to undo).
- `/vendor/odm/lib/hw/audio.primary.msmnile.so` is bind-mounted from a patched copy (`tools/live/audio-ultrasound/audio.primary.msmnile.noultra.so`, sha256 `aeb84cc1ac406801...`): `ultra_sound_thread_loop` replaced by `mov r0,#0; bx lr`.
- Camera Video.xml = 3840x2160; screen timeout restored to 30000, stay-on off, logcat buffers set to 16M.

## Separate audio problem found while testing (NOT in the image yet)

Recording attempts failed with "app is already in use" because the audio HAL was dying:

- `audio.primary.msmnile.so` `receive_sensor_state` -> `ultrasound_apply_param_to_usecase` -> `ultrasound_extn_start` writes through a NULL pointer (`ldr r0,[fp,#0xbc]` is 0). Tombstones 17-25 (23:12 onward) are all this; every screen sleep->wake reproduced it. Cause of the NULL field not identified.
- A second loop: the Breeno wake-word service (`com.oplus.ovoicemanager.wakeup`) calls `loadPhraseSoundModel`, the LOS SoundTrigger HAL returns code 5, init handles `sys.audio.restart.hal=1` and SIGKILLs the audio HAL every ~6 s. Disabling the package stopped it (audio PID stable for 20+ min of testing).
- Neither was verified on a clean boot, and neither is baked. Both need a decision (disable the wake-word package by default? patch or replace the odm audio HAL?) and a build.

## REA

REA's native (Ghidra/objdump) and Android (JADX) providers are not usable on this Windows host (`ERR_REA_WINDOWS_NATIVE`, no `GHIDRA_INSTALL_DIR`, no `REA_JADX_MCP_JAR`). Disassembly was done with WSL aarch64 objdump, a capstone venv (ARM32), and Android SDK `dexdump`.

