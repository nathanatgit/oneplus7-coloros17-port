# Verified camera facts, 2026-10-16

| Claim | Evidence | Limit |
|---|---|---|
| Target is GM1910 guacamole, currently slot B build 13 with root ADB | `adb` ID and `ro.boot.slot_suffix=_b`; build display `CP2A.260605.016` | Properties include donor spoofing; hardware identity came from prior port audit. |
| HAL IDs 0 main, 1 front, 2 tele, 3 ultrawide, 4 portrait logical, 5 rear SAT logical | `baseline-camera.txt` static metadata and focal lengths; SDK mapping patch | Six HAL IDs are not six distinct physical sensors. |
| Open Camera Camera2 front popup and preview worked live | User confirmation, active ID 1, position 0 while open, 24→250 produced frames, position 1 after Home | No clean boot or fall detection test. |
| Popup helper was idle-stopped and then ColorOS FastClear-killed before whitelist | `am_stop_idle_service` events 14:44:28, `am_kill o-kill(2006)` 14:45:08 | Whitelist and UID ownership are live workarounds, not baked port repair. |
| Donor camera 7.006.125 can open rear ID 0 with diagnostic APS mode0 and operation mode0; preview on phone is black | HAL session/frame logs and user's physical observation | Opening + frames is not functional preview/capture. |
| Donor native APS6 mode1 crashes | `aps-native-tombstone.txt`, `APSClient_createClient+60` | Replacing with mode0 is not the final APS integration. |
| Zoom row remains incorrect | User observation and `hardware-config.png`; `r2.smali` explicit 2.0f shortcut | Desired 0.6× / 1× / 3× sensor routing unvalidated. |
| Exact donor APK copied, not moved; no donor firmware flashed | APK SHA-256 and OTA extraction log; current mounts | Live framework/app binds and user app install still exist. |
| On build 13 the popup did not retract after closing the camera | User report; `/sys/class/motor/position` = 0 (up) at 15:07; retracted by adb → 1 | Root cause below; not fixed in the image. |
| Helper is a user app and is killed by ColorOS | `pm path` → `/data/app/…`, `flags=0x0`; `am_kill … o-kill(2006) FastClear` 14:45:08 and 14:52:21 | `persistent` is ignored for non-system apps; whitelisting did not prevent the 14:52 kill. |
| Stock H.40 moves the motor from system_server, not an app | H.40 oplus-services.jar `MotorManagerService` + services.jar HIDL `vendor.oplus.hardware.motorcontrol@1.0::IMotorControl`; odm `motorcontrol@1.0-service` | Read from images only, not run on this port. |
| ColorOS 17 has only the motor client API | C17 oplus-framework.jar `IMotorManager`/`MotorManager`; no `MotorManagerService` class, no `IMotorControl` client | String search of dex; a stub server is needed for clients to work. |

Do not revise these into stronger claims without a new live test. Current mount/process state must be re-read because it changes between sessions.

