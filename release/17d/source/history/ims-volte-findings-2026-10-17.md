# Outgoing calls / incoming SMS: IMS (VoLTE) never comes up — findings 2026-10-17

Symptoms (user, build 15): outgoing call fails, incoming call works, outgoing SMS works, incoming SMS never arrives. SIM 1 China Mobile (46000), LTE in service, data connected.

## Verified (logs in `logs/calls-sms-2026-10-17/`)
- Outgoing call 00:43:05: `GsmCdmaPhone: isImsUseEnabled=true, isOutgoingImsVoiceAllowed=false` -> "Trying (non-IMS) CS call" on LTE; modem accepted the DIAL, call stayed DIALING 44 s, then `LAST_CALL_FAIL_CAUSE causeCode 248 "Radio is out of service"` (`CallAnalytics ... ERROR_UNSPECIFIED, LTE`).
- `getImsRegistrationTechnology = -1`; `dumpsys phone`: MMTEL feature state `UNAVAILABLE`, reason `IMS_SERVICE_DISCONNECTED` for both slots since boot (18:50). No IMS registration at all.
- Root cause chain: ColorOS 17 `org.codeaurora.ims` (`/system_ext/priv-app/ims/ims.apk`, sha 93c199d7...) contains only the AIDL `vendor.qti.hardware.radio.ims.IImsRadio` client (`ImsRadioAidl`), no HIDL one. The LOS24 vendor only provides the HIDL `vendor.qti.hardware.radio.ims@1.x::IImsRadio/imsradio0,1` (lshal: up to 1.6 available). Log: `ImsRadioHalFactory: Initialize default HAL as either AIDL or ril target support is not available`, `ImsSenderRxr: ImsRadio HAL is not available`, `QtiRadioConfigAidl: initQtiRadioConfig failed`.
- Second defect: `OplusImsHalFactory: NoClassDefFoundError android/hidl/manager/V1_0/IServiceNotification$Stub` because ims.apk does not `uses-library` `android.hidl.manager-V1.0-java` (jar exists, declared in platform.xml). Live fix: `dependency="android.hidl.base-V1.0-java:android.hidl.manager-V1.0-java"` on the `ims-ext-common` `<library>` in `/product/etc/permissions/ims_ext_common.xml` (`tools/live/ims/ims_ext_common.xml`, bind mount + framework restart). Result: `OplusImsHalHidl` connected to `oplusimsradio0/1`. That alone did not make IMS ready (the QTI HAL path is still missing).

## Experiment: LineageOS24's ims.apk (reverted)
- LOS24 `system_ext/priv-app/ims/ims.apk` (sha 5b2cddb0..., HIDL `ImsRadioHidl` + AIDL, targetSdk 31) with ColorOS's signing block transplanted (`tools/transplant-apk-sigblock.py`; scan accepted, same signer) and LOS `libimsmedia_jni.so`/`libimscamera_jni.so` bind-mounted over `lib/arm64` (the ColorOS libs crash with `JNI_ERR from JNI_OnLoad`). Files: `tools/live/ims/los/`.
- The LOS app did find the HAL (`ImsRadioHidl: imsRadioV15/V16 available`, `onServiceUp: HAL Service available`) but the MMTEL feature stayed UNAVAILABLE and telephony degraded within ~1 min: `com.android.phone` FATAL NullPointerException in `IQtiImsExt$Stub$Proxy.getImsFeatureState` <- `QtiImsExtManager` <- ColorOS `com.oplus.internal.telephony.ScbmHandler.onConnectionAvailable` (NPE thrown by the LOS QtiImsExtService, `Context` null: log "QtiImsExtService: ImsService is not yet started retry ... onBind returned null"); `phone` service went missing and the radio reported OFF. All three mounts were removed and the framework restarted; telephony recovered (SIM loaded, LTE in service).
- Not determined: whether IMS would register if that NPE were avoided; whether ColorOS framework needs more Oplus IMS pieces that only the ColorOS ims.apk has.

## Not tried / options
1. Fix the LOS-app route (the NPE in QtiImsExtService before ImsService is up; coherent set of LOS IMS jars/libs; check `vendor.qti.ims.*` jars).
2. AIDL-to-HIDL `IImsRadio` shim service for the ColorOS app (large).
3. Make circuit-switched fallback work for outgoing calls instead (cause 248 on a CS dial from LTE; not investigated: preferred network mode, SGs/combined attach, CSFB RATs of the modem).
4. Incoming SMS may also depend on IMS (SMS-over-IMS on China Mobile); unverified.

State now: no IMS mounts; earlier workarounds (camera v10 mount, vidhance off, AAC false, ultrasound HAL mount, wake-word package disabled) still active. Nothing baked, no image built.

## UPDATE 01:10-01:30: outgoing calls FIXED live; incoming SMS still not working

Working live set (all bind mounts + framework restart, USB attached; revert script `/data/local/tmp/ims_revert.sh`; not in any image):
1. `/product/etc/permissions/ims_ext_common.xml` <- `tools/live/ims/ims_ext_common.xml` (`dependency=` on the two HIDL java libs; the LOS app needs `android.hidl.manager-V1.0-java` too).
2. `/system_ext/priv-app/ims/ims.apk` <- `tools/live/ims/los/ims-los24-ctx-cossig.apk` (sha 470b8c126db66886...): LOS24 ims.apk with `QtiImsExt.<init>` changed to call ColorOS's `QtiImsExtBase.<init>(Executor, Context)` (ColorOS' base class stores mContext; the LOS app called the no-arg ctor, so `mContext` stayed null -> NPE in `onGetImsFeatureState` -> `com.android.phone` crash via `ScbmHandler`). Built with `tools/camera-helper/apktool_3.0.3.jar` (decode -r, smali edit, build), then `tools/transplant-apk-sigblock.py` with the ColorOS ims.apk block. Smali source: `tools/live/ims/los/smali-out/`.
3. `/system_ext/priv-app/ims/lib/arm64` <- dir with LOS `libimsmedia_jni.so` + `libimscamera_jni.so` (copied from LOS24 `system_ext/lib64`); the ColorOS ones fail `JNI_OnLoad`.

Result (user-verified): outgoing call connects; log: `ImsPhoneCallTracker dialInternal`, `getImsRegistrationTechnology =0` (LTE), MMTEL `READY`, IMS registration `{1,1}`, outgoing SMS goes `REQUEST_SEND_IMS_SMS` result 1. com.qti.phone stable, no fatal exceptions.

Incoming SMS (user sent from a third-party phone known to send fine, 01:17 and earlier): no inbound-SMS event at any layer (no `UNSOL_INCOMING_IMS_SMS`, no `UNSOL_RESPONSE_NEW_SMS`, no InboundSmsHandler, nothing from qcrild/RILQ). Facts for the next step:
- LOS app advertises MmTel `SMS: true` (from the modem's IMS service status). Stock H.40 (`logs/h40-sim-ref/radio.txt`) had IMS registered with `SMS: false`, i.e. texts used the CS route; here the CS domain shows no SMS service (`availableServices=[VOICE, VIDEO]`), so texts must come over IMS.
- The app never sets IMS SMS config items (`setConfig` items seen: 26, 27, 66, 1006).
- LOS app does contain the incoming path (`ImsRadioUtils.incomingSmsfromHidl`, V1_2 `IncomingImsSms`); it is not being called, so the modem/HAL is not forwarding an incoming SIP MESSAGE, or the network is not delivering it.
- The shell cannot read `content://sms` (always "No result found"); use logs.
- Vendor IMS daemons (`imsqmidaemon`, etc.) write nothing to logcat; no files under /data/vendor/ims*.
Not tried: toggling airplane mode / re-registering; verbose qcrild logging (`persist.vendor.radio.adb_log_on=1` + restart qcrild); forcing SMS-over-IMS off to get stock-like CS SMS; a CXLL-to-10086 reply test (needs user to send); checking the HAL indication version registered by the app (HIDL 1.6 HAL vs app's `onCallStateChanged_1_8` handlers).

## UPDATE 01:24-01:40: SMS-over-IMS switched off; incoming SMS still does not arrive

- Helper `tools/live/ims/prov/Prov.java` (+ built `classes.dex`; run as root `CLASSPATH=/data/local/tmp/prov.dex app_process /system/bin Prov <subId> <key> [value]`) reads/writes IMS provisioning ints via the phone service (`ITelephony.get/setImsProvisioningInt`). ImsConfig item 14 (SMS_OVER_IP) was 1; set to 0 for sub 1 (reversible: set back to 1). It reached the modem (`REQUEST_SET_IMS_CONFIG`). After an airplane-mode toggle the log shows `ImsSmsDispatcher: isAvailable: up=true, reg=true, cap=false` (was cap=true), and outgoing SMS use the CS path; the user's outgoing texts (01:31:51 etc.) are stored in `bugle_db`.
- `persist.vendor.radio.adb_log_on=1` + restart of `vendor.qcrild`/`qcrild2` gives full QCRIL logs (tags `QCRIL_SMS`, `RILQ`). At 01:30:48 qcril: `WMS_SERVICE_READY_STATUS_3GPP`, `qcril_qmi_sms_retrieve_ims_sms_registration_state: Transport NW Reg Status: 0` (not registered for SMS over IMS), GSM broadcast config OK.
- CS domain: `availableServices=[VOICE,SMS,VIDEO]`, registered HOME on LTE (earlier "VOICE VIDEO" reading was my line-wrap error).
- Result: with CS route, WMS ready, fresh registrations, and a fresh test text from a known-good third-party phone (01:35-01:40), no QMI WMS MT indication, no `UNSOL_RESPONSE_NEW_SMS`, no inbound event anywhere. Earlier note that this also failed with IMS fully down (before the IMS fix) means it is probably independent of IMS.
- Messages DB: shell cannot read `content://sms`; the Messages app (`com.android.mms`) stores in `/data/data/com.android.mms/databases/bugle_db` (pull and read with python sqlite3); `mmssms.db` is empty.
- Untested: a carrier-originated text (user sends `CXLL` to 10086 from this phone; the reply is a carrier-originated MT SMS); testing the SIM in another phone; SIM/operator-side SMS settings (blocking, forwarding); comparing with stock H.40 receiving a text on this SIM.

## RESOLVED 01:43: incoming SMS fixed by `persist.vendor.radio.poweron_opt=0` (+ qcrild restart)

Root cause: the ColorOS donor's `/system_ext/etc/build.prop` sets `persist.vendor.radio.poweron_opt=1`. With it, qcrild's "power optimization" buffers incoming (MT) SMS (`qcril_qmi_sms_update_mt_sms_with_ack_needed_power_opt_buffer`, `qcril_qmi_nas_notify_mt_sms_ind_hdlr`) and waits for a handshake/ACK that the ColorOS AP never gives; after ~20 s `qcril_qmi_nas_mt_sms_power_opt_transaction_expired: Reset MT SMS buffer`, nothing is passed up (no `UNSOL_RESPONSE_NEW_SMS` / `onIncomingImsSms`), the network redelivers every ~22 s. This is the likely cause of "incoming SMS never arrives" before the IMS work too (the earlier handoff listed poweron_opt as a suspect), but the fix was only verified with the IMS fix mounted; poweron_opt=0 alone on the unpatched ColorOS IMS app was not tested.

Fix: `setprop persist.vendor.radio.poweron_opt 0` then `setprop ctl.restart vendor.qcrild; setprop ctl.restart vendor.qcrild2` (the property is read at qcrild start). Result (user-confirmed + logs): at 01:43:47-01:44:16 all queued messages arrived over IMS (`UNSOL_INCOMING_IMS_SMS`, `ImsSmsImpl onSmsReceived`, `GsmInboundSmsHandler`); `bugle_db` now has 16 messages, incoming ones including the 18:40 (previous evening) and 01:17-01:38 texts. State at the time: SMS_OVER_IP provisioning = 1 (restored), IMS registered, the LOS IMS app set mounted.

Not baked (all live): `poweron_opt` is a persist prop, so the live value persists across reboot in /data but the image still ships `=1` in `/system_ext/etc/build.prop`; the three IMS bind mounts do not persist; SMS_OVER_IP value is held by telephony provisioning. `persist.vendor.radio.adb_log_on` was set to 1 for diagnosis and set back to 0 (effective at the next qcrild restart).

