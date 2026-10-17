# Read-only connected-device audit — 2026-10-15

All commands targeted ADB serial 6f3e7112. No settings changed, no services restarted, no image flashed, no data wiped. Physical NFC/A2DP/USB audio/slider/fingerprint interactions were not simulated; these are state/registration/configuration tests, not full functional certification.

## Verified current state

- Android 17, SDK 37, build CP2A.260605.016; active slot B.
- sys.boot_completed=1; uptime 4333.99 seconds at first capture; system_server PID 17181.
- SELinux permissive; ro.port.sf_first_api_level=36.
- Audio, power and camera-provider init services report running.
- Real SoundTrigger HIDL 2.0/2.1 service is registered at PID 17001; audio HAL is HIDL 6.0.
- Power service rc already includes group system readproc (upstream 503532 equivalent present).
- Bluetooth audio AIDL manifest exposes version 6.

Evidence: live/state.txt, live/hal-audio-codec.txt.

## Confirmed repair targets

1. **Hardware video codec enumeration/selection.** Registered Qualcomm C2 default store exists at PID 3852. Vendor media_codecs_c2.xml declares c2.qti.hevc.decoder. dumpsys media.player exposes only c2.android.hevc.decoder under video/hevc; c2.qti.avc.decoder and encoder show rank 4294967295. debug.stagefright.ccodec=1. This establishes a concrete configuration/enumeration mismatch. It does not yet establish whether the controlling cause is ccodec policy, cached list, rejected component traits, XML discovery, or an ABI error. Dolby WorkBundle patch 507507 is not proven relevant. Next: inspect generator/Codec2Client logs and runtime traits, compare LOS XML selection and property behavior, then test a real HEVC decode without disabling enrollment.

2. **Missing OEM integration services.** service check reports OplusProject, IPerformance and IOplusMisc/default not found. This corroborates earlier recorded caller waits and slider integration gap. Matrix bump 505310 alone cannot fix missing implementations. Current brief test did not reproduce a new timed physical power-key press, so the historical 5-second delay remains supported by the earlier trace rather than newly measured.

Evidence: live/targeted-checks.txt, live/codec-selection.txt, live/services.txt, live/hal-audio-codec.txt, logs/plk-live2/rec-power-nfc.txt.

## Not established as needing an upstream patch

- libperfmgr session-state/null-dereference changes 507525/507152: service present, but no ADPF transition test or matching crash reproduced.
- Bluetooth V3/V4 adapters: V6 service exists; that alone does not prove old-client ABI corruption. Actual streaming/consumer-symbol checks remain necessary.
- NFC timer revert 506215: NXP HAL present; NFC dump reports screen OFF_LOCKED. No new physical tag discovery or timer shutdown test performed; do not claim this revert explains reader inactivity.
- Fingerprint HAL reports running; motor position=1 (down), tri_state=3. Reading these nodes does not validate motor automation, slider transition delivery, or enrollment video.
- SELinux fixes remain an enforcing-policy audit; permissive state cannot certify them.

## Collection limitations

dumpsys media.codec is not a registered service on this build; media.player supplied the codec list. SurfaceFlinger/head pipeline produced a broken-pipe message, so its truncated HDR output is not authoritative. Some standard system/ODM codec XML paths are absent; their absence is recorded, not assumed causal. Current state includes prior live-only repairs; it is not a clean reboot of the newly prepared system image.
