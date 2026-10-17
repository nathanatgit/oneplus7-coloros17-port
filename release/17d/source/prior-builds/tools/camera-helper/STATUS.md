# ColorOS camera-motor helper adaptation

2026-10-15: user confirmed the front camera rises and retracts automatically when switching OpenCamera to front camera and returning Home.

Artifact: OnePlusCameraHelper-port.apk, repackaged from the saved LineageOS24 helper. Original dex/resources remain byte-identical. Manifest changes: remove android.uid.system shared UID, add CAMERA permission, target SDK 28, export the two services behind android.permission.DUMP for privileged test startup. Signed with a local test certificate (not the ColorOS platform key).

Current live app UID: 10190. Only direction and enable motor nodes changed from system:system 0644 to system:10190 0664 for this test. Calibration untouched. SYSTEM_ALERT_WINDOW app-op enabled for Lineage fall-protection dialog. Ten-minute temporary background allowance used to start the services. Both CameraMotorService and FallSensorService run; camera_protect sensor registered. Physical free-fall handling has not been tested and must not be claimed certified.

Not permanent yet: kernel node ownership resets on reboot; test background allowance expires. Image integration must provide narrow stable permissions and reliable service startup without hard-coding this install UID. Prefer a dedicated signature permission mapped to system GID for the trusted helper, appropriate SELinux policy, and privileged app/background-service treatment. Do not carry temporary world-writable permissions into the image.

Original permissions rollback: stop both helper services, restore direction/enable owner system:system and mode 0644, disable its overlay app-op, uninstall the test app if requested. Close/retract the camera before stopping its controller.

Camera circle animation: ColorOS SystemUI contains FrontCameraPinholeAnimView and FrontCameraDoublePinholeAnimView. It is separate from motor operation; its feature trigger and selective suppression are still unvalidated.

Stock-app restoration requested: ColorOS 17 donor camera, keyboard, app market and other stock apps. Build 9 already provides my_stock apps. my_heytap/my_bigball are empty in the GSI, so additional verified app extraction material is required. No app restoration has yet been claimed complete.

2026-10-16 build 13 follow-up: see ../../camera-facts-2026-10-16.md and ../../camera-port-2026-10-16.md. The prior temporary service allowance was insufficient: ColorOS idle-stopped and FastClear-killed the helper. Exact device-idle user whitelist + active bucket kept the live helper running. Motor direction/enable ownership is now UID 10190:system, mode 0644 (live only). Open Camera Camera2 front popup and preview were user-confirmed with 24->250 HAL frames; Home retracted. Clean-boot startup, stable UID policy, and drop protection are unverified.
