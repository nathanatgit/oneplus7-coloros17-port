# Fixes and patches in 17d

Status column: **V** = verified on the phone from a booted image, or live with the user's confirmation; **L** = verified live only (patch later baked, not re-tested from a clean flash); **U** = baked but untested on hardware. Paths are relative to the repository root. "Script" = `tools/build-port-b.sh` (with sha asserts) and `tools/preflight-b.sh` (checks the built images).

## A. Boot and platform (builds 1-9)

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| init fatal at boot (SELinux) | ColorOS init caps the policy to v29 on this kernel and strips only `allowx`; the remaining `auditallowx`/`dontauditx` rules fail `secilc -c 29` | Strip those logging-only rules (script, `tools/patch-vendor-sepolicy.py`); preflight emulates the v29 compile | V |
| Property-context trie build fails | Same prefix defined with different contexts by system and vendor | `tools/drop-propctx-conflicts.py` keeps the LOS vendor labels | V |
| `/data` never mounts / FBE fails | Old metadata key from LineageOS; LOS `fileencryption=ice` needs CAF patches the ColorOS vold lacks | `FBE_MODE=standard` (aes-256-xts:aes-256-cts:v2); reset keys with `tools/reset-data-keys.sh` on a first install | V |
| Boot hangs on SoundTrigger | LOS SoundTrigger 2.3 adapter vs native 1.0 device API | Stock H.40 SoundTrigger 2.1 adapter + manifest (`tools/patch-soundtrigger.sh`, `tools/soundtrigger-compat/`) | V |
| Screen stuck on the splash | ColorOS SurfaceFlinger sends QTI `SET_LAYER_TYPE` (0x800<<16) which the LOS composer rejects | Source-built composer HAL that accepts it (`tools/build-hwc.sh`, `tools/hwc-port/`); later also tolerates generic layer metadata (build 12 crash loop) | V |
| No WiFi | LOS vendor expects `/odm/vendor/etc/wifi/...` | `/odm/vendor` symlink | V |
| Camera provider crash | `libcamera_metadata.so` missing from the LLNDK list | Added to `system/etc/llndk.libraries.txt` | V |
| Software HEVC only | ColorOS `debug.stagefright.ccodec=1` hides all vendor C2 codecs except AVC | `debug.stagefright.ccodec=4` | V |
| ColorOS ignores `/my_*/etc/extension` features | `CUST_LEVEL_LIST` unset | Exported in `init.environ.rc` with the order decoded from the stock OTA | V |

## B. Input, buttons, fingerprint (builds 9-12)

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| Power key 5 s delay | `lib_inputflingerEx` blocks on an `IOplusProject` AIDL lookup for every key | Stub Binder registered under that name (`tools/oplus-stubs/`, `00-port-oplus-stubs.rc`) | V |
| Fingerprint enroll ANR | mediaserver waits 5 s for `IPerformance` per codec | The same stub dex answers `vendor.oplus.hardware.performance` | V |
| Fingerprint finger-down lost | LOS `fingerprint@2.3` wrapper hides the Goodix HAL; H.40 Goodix sends `vec<uint32>` but the ColorOS 17 callback reads `vec<int8>` | Retire the wrapper rc so Goodix `fps_hal` owns the names; patched `services.jar` reads int32 and narrows (`tools/live/fpcmd`) | V (unlock confirmed) |
| Fingerprint illumination / black lock screen | FOD "pressed" z-order bit and displaypanelfeature behaviour missing | Composer z-order handling + SystemUI dim patch (`tools/patch-systemui-dim.py`, original signing block re-attached with `tools/transplant-apk-sigblock.py`) | V |
| Screen-off gestures | `IOplusTouch` AIDL only; LOS has none | `port.TouchBinder` stub mapping node flags to `/proc/touchpanel/*` | V (double tap) |
| Alert slider | ColorOS 17 expects an action button | `port.SliderBridge` injects ACTION_BUTTON keys from `/proc/tristatekey/tri_state` | V |
| Volume panel on the wrong side | donor `persist.oplus.software.audio.right_volume_key=true` | set to false | V |
| About phone "2 mAh" / OnePlus 15 values | donor placeholders | power_profile.xml from H.40 (4065 mAh), market names, wireless-charging features removed | V |

## C. Camera (builds 12-16)

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| Donor camera crashes the HAL | OnePlus 15 camera vs the guacamole HAL | Stock H.40 OnePlus Camera shipped in my_stock, dex-patched (`tools/live/camera/OnePlusCamera-H40-v10.apk`; offset-preserving patch scripts in `tools/live/rea-analysis/`) | V |
| Video recording crashes the camera provider | EIS node (`libvidhance`) crashes on the ColorOS libEGL | `vendor.vidhance.enabled=0` | V |
| 4K30 session rejected | 4 streams including a YUV preview-frame reader | App patch disables the preview-frame callback | V |
| AAC encode failed | Codec2 audio path | `vendor.audio.hw.aac.encoder=false`, `ro.media.xml_variant.profiles=_vendor` | V |

Verified clips: 1080p30, 4K30, 1080p60 decode fully. Not tested: front camera video, clips longer than 10 s, 4K60, slow motion, HDR.

## D. Telephony (build 16)

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| Outgoing calls fell back to CS (cause 248) | ColorOS 17 `org.codeaurora.ims` only has the AIDL `IImsRadio` client; the LOS vendor serves HIDL | LOS24 `ims.apk` (HIDL ImsRadio) with `QtiImsExt.<init>` patched, the ColorOS signing block transplanted, LOS jni libs, `ims_ext_common.xml` dependency string | V (VoLTE registers, calls connect) |
| Incoming SMS never arrived | qcrild power optimisation buffers MT SMS and waits for an ACK ColorOS never sends | `persist.vendor.radio.poweron_opt=0` | V |
| IMS app missing after the first flash scan | not understood; it registered after live tests and persisted | none | open |

## E. Audio, brightness, sensors

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| Audio HAL killed on every sleep/wake | `ultrasound_extn_start` writes through a NULL pointer (`[adev+0xbc]`) | Guard patch of `audio.primary.msmnile.so`: start only when `[adev+0xbc] != 0` (`tools/live/audio-ultrasound/audio.primary.msmnile.guard.so`, sha `a76ab72b`). Build 16's "noultra" patch had disabled the main proximity sensor | L (proximity back live), baked in build 17 |
| Auto brightness too bright at low lux | The donor nit-to-level table is for the donor panel; this panel maps level/10 to raw; the H.40 lux-to-raw curve equals 2.55 x ColorOS's nit curve | `display_brightness_config_default.xml` nit column rescaled (`tools/live/brightness/`, sha `ae420be1`). The `lux_table`s in the common file are unused here: ColorOS's lux curve is built in | L |
| Light sensor ~0.45x and laggy | `vendor.lineage.oplus_als` over-display correction | none | open |

## F. Charger, Find My Device (build 17)

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| "Charging voltage too high" at plug-in and at boot, Battery Health "cannot obtain capacity", "third-party battery" | ColorOS 17 `OplusBatteryServiceFeature` only talks to the AIDL service `vendor.oplus.hardware.charger.ICharger/default` (V12); with it missing every status read -1 | Java AIDL stand-in (`tools/live/charger-aidl/`, 123 methods generated by `gen.py`; real sysfs values for SOH, FCC, RM, CC, level, voltage, temperature, current, authenticate, notify code and short-circuit status; `getPsyBatteryHmac` returns 1), started by init through `app_process`; the odm manifest declares AIDL v12 | V (user: capacity shown, no warning, none at boot with the cable) |
| Stock H.40 charger and cryptoeng binaries refused to start | (1) exec labels without a domain transition; (2) CANNOT LINK: `android::base::Trim(const std::string&)` and `Json::Value::operator=(Json::Value)` are missing from the LOS24 libraries | Labels `vendor_file` / `hal_*_exec` as needed; two forwarding shims (`libportcompat.so` in the build, live copies `libport_shim_{trim,json}.so`) loaded with `setenv LD_PRELOAD` in each rc | V |
| Find My Device "CryptoEng service is null" | RPMB access goes through HIDL `vendor.oplus.hardware.cryptoeng@1.0`, absent in the port | Stock H.40 `cryptoeng@1.0-service` + QSEE TA `cryptoeng.*` + libraries + vintf fragment | U for the full feature (service verified running; account/RPMB flow not re-tested) |
| `com.android.se` crash loop (about 5 per second) | The OMAPI app registers `android.se.omapi.ISecureElementService/default`, which was not declared in VINTF | Declared in `manifest_oplus_charger.xml` (odm manifest fragment) | V |

## G. eSE (kernel + HAL), `boot-ese-final.img`

| Piece | Detail |
| --- | --- |
| Kernel | LOS `0521dc29` + `CONFIG_NFC_P73_ESE=y`: reduced `p73.c` (misc device `/dev/p73`, DT `nxp,p61`, SPI read/write, P61 power and status ioctls) and `nqx_ese_pwr_ext()` exported from `drivers/nfc/nq-nci.c`. Patch `research/ese-p73/port/los-nfc-p73.patch`, build `tools/ese-build-kernel.sh`, repack `tools/bootimg_v2.py kernel` |
| Why the eSE was silent | The LOS `dtbo` still has the Qualcomm reference eSE power pin `<&tlmm 42>`; stock H.40 uses `<&tlmm 49>`. The kernel quirk drives TLMM 49 (no dtbo flash) |
| HAL | Stock `android.hardware.secure_elementnq330@1.1-service`, NXP libraries, `libese-nxp.conf`, `libport_shim_trim.so` (LD_PRELOAD), vintf fragment (eSE1 @1.1 plus the INxpEse / INxpEseEvtProcessor entries the HAL registers itself), oneshot rc, `vendor.nfc_se.config_ready` |
| OMAPI app | LineageOS 24 `SecureElement.apk` in `system_ext/app` (the H.40 one is Android 12 and binds by intent) |
| Verified | `/dev/p73`, `eSE1` registered, `dumpsys secure_element`: terminal eSE1 `mIsConnected:true`. The first open takes about 10 s because the SE HAL waits on the NXP NFC HAL's HIDL ioctl interface, which the LOS NFC HAL does not serve |
| Not verified on the 17d release | Wallet card provisioning (also needs the root checks to pass: see OPEN-ITEMS) |

## H. Voice wake-up (Breeno) on the H.40 DSP

| Problem | Root cause | Patch | Status |
| --- | --- | --- | --- |
| Breeno switch could not be enabled; every try rebooted the audio HAL | ColorOS 17 loads an "aispeech" model container for vendor uuid `68ac2d41-...`; the H.40 ADSP only has the QTI SVA engine (`68ab2d40-...`), so `gcs_enable` failed with -131 | ColorOS 17's own wake service patched to use the **H.40 SVA first stage**: `OVoiceManagerService.apk` smali (keyphrase `xiaobuxiaobu`, VOICE_TRIGGER only, raw model bytes, SVA 3.0 opaque config copied byte for byte from the working H.40 app, `captureRequested=true`, `b()` registers raised to 9), `OVMS_settings.xml` vendor uuid, `OVMS_1st_wakeup.bin` = H.40 `sm3_xiaobuxiaobu.uim` (`tools/live/breeno-sva/`) | V live (user: enroll works, 小布小布 wakes Breeno); baked in 17c/17d; clean-flash behaviour not re-tested |
| `01-port-audio-fix.rc` disabled the wake package at boot | earlier workaround | Removed in 17c; preflight fails if anything disables `com.oplus.ovoicemanager.wakeup` | |

The research path that led here (stock H.40 `com.oneplus.voicewakeup` patched for Android 17's `listModulesAsOriginator` / `attachModuleAsOriginator`) worked but is not shipped.

## I. Naming

`ro.build.display.id.show` = `GM1910_17.0.0.100(202610171200)` (display string only; `ro.build.version.ota` and the fingerprints keep the donor values). The About-phone device chip (`ro.product.model`, still PLK110 in 17d) is changed in the later 17e script: see OPEN-ITEMS.
