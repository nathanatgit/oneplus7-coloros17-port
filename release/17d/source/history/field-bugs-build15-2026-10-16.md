# Build 15 field bugs reported 2026-10-16

> **Update 2026-10-17:** outgoing calls and incoming SMS are fixed live (and baked into build 16, not yet flashed): see `ims-volte-findings-2026-10-17.md` and `handoff-2026-10-17.md`. Incoming call / outgoing SMS already worked.

Device under test: OnePlus 7 Pro, ColorOS 17 port build 15, slot B. The following are the user's direct live observations; the exact error messages and radio logs have not yet been captured.

| Function | User-reported result |
| --- | --- |
| Outgoing cellular call (dial a number) | Fails |
| Incoming cellular call | Works |
| Incoming SMS | Does not arrive |
| Outgoing SMS | Works |

Keep the two failing directions distinct in triage. This is not evidence that cellular voice or SMS is entirely unavailable. Next diagnosis: capture a timestamped outgoing-call attempt and an incoming-SMS attempt, then compare telephony framework, RIL, IMS, and carrier registration logs. Do not write a fix into the image until reproduced and live-validated.

Camera issue remains separate: H.40 Camera enters video mode but does not save video. With the staged 1080p profile loaded at framework startup, it passed the earlier `No profile` failure, then the camera provider crashed in AWB (`CamX::CSFMLCZV1::OnFrameStart`). A temporary H.40 `camera.qcom.so` swap made OnePlusCamera show “The camera may be damaged” before recording could start. The original build 15 core was restored (SHA-256 `4d4a2556...`) and a rear preview was confirmed in Open Camera. Details: `h40-video-build15-2026-10-16.md`.

Open Camera also fails to record with audio enabled: ColorOS Stagefright requests unavailable `OMX.qcom.audio.encoder.aac` and `MediaRecorder.prepare()` fails. With audio disabled temporarily, Open Camera saved a verified 11.84-second, 1920x1080 H.264 MP4. The app preference was restored afterward. This isolates its immediate failure to the audio-encoder path; a silent recording is not the completed camera fix.

