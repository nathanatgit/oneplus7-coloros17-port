# LineageOS guacamole compatibility audit — 2026-10-15

State reference: handoff-2026-10-15.md. Its live fixes supersede the earlier boot-loop state. They have not all been built and clean-boot tested. The handoff explicitly requires asking before flashing. No flash was performed in this audit. ADB currently reports no connected device.

The supplied download changelog returned HTTP 403 through web retrieval. Evidence below was retrieved from official LineageOS GitHub APIs and raw source. Saved JSON includes full commit IDs, dates, messages, URLs, and diffs; this is current branch history, not a claim that every change is new or absent from the downloaded nightly.

## Direct browser follow-up

The actual changelog successfully loaded in the Codex browser on 2026-10-15. The earlier HTTP 403 was specific to the web retrieval tool, not a general browser-access limitation.

The page currently shows changes to be included in the next 24.0 build and mixes platform/shared-hardware entries with device-specific entries. A device-specific label does not prove that a change targets SM8150.

The new [legacy Codec2 WorkBundle shim, change 507507](https://review.lineageos.org/c/LineageOS/android_hardware_lineage_compat/+/507507) is merged on lineage-24.0, submitted October 13. Its stated scope is forwarding an old HIDL BufferPoolSender symbol for Dolby Codec2 clients; its topic is dolby-vision-sm8550. It postdates our October 11 nightly, but is not yet evidence of a fix for guacamole's fingerprint guide video. Check for the corresponding missing symbol/Dolby client before using it. Ordinary HEVC decoder enumeration remains the stronger immediate lead.

## Android base

The project's earlier image/ADB inspection recorded Android 17, SDK 37 and CP2A.260605.016 for both the LineageOS 24 base and ColorOS donor (PORTING.md, Phase A and donor sections). The official device repositories currently default to lineage-24.0. No new on-device version verification was possible today. Shared Android version does not imply identical HIDL adapters, linker namespaces, CAF display extensions, codec configuration, or OEM services.

## Fix-to-failure mapping

| Evidence | Implication for this port | Next verification |
|---|---|---|
| [guacamole audio relocation](https://github.com/LineageOS/android_device_oneplus_guacamole/commit/6403422c79), [extract path correction](https://github.com/LineageOS/android_device_oneplus_guacamole/commit/25832a97b5) | The real primary audio HAL intentionally lives in ODM. Our SoundTrigger loader's vendor/system-only search missed it. Preserve the matching real HAL and the tested path link. | Confirm path and genuine 2.1 service after a clean boot. |
| [SoundTrigger 2.3 device change](https://github.com/LineageOS/android_device_oneplus_sm8150-common/commit/83477862b1), [adapter source](https://github.com/LineageOS/android_hardware_interfaces/blob/lineage-24.0/soundtrigger/2.3/default/SoundTriggerHw.cpp) | The newer adapter explicitly requires native API 1.3. Our native blob reported 1.0; forcing a version value would expose newer function pointers that the old implementation may not supply. The genuine stock 2.1 adapter is a compatibility repair, not feature suppression. | Real properties/recognition and ordinary audio still need functional testing. |
| [audio ABI adjustment](https://github.com/LineageOS/android_device_oneplus_sm8150-common/commit/798c07e146) | LineageOS builds audio interfaces without the new speaker-layout field for old HAL ABI compatibility. Equal Android versions alone do not ensure compatible audio structs. | Compare ColorOS callers and existing LOS-built vendor interfaces before replacing more audio libraries. |
| [motor calibration change](https://github.com/LineageOS/android_device_oneplus_sm8150-common/commit/ec6945cce3) | Calibration moved to vendor init; 11-value OEM data gains the missing sensitivity field. Use current helper behavior and init order rather than blindly repackaging an older APK. | Inspect whether the installed vendor already contains this script. Preserve per-device persist calibration. |
| [codec configuration](https://github.com/LineageOS/android_device_oneplus_sm8150-common/blob/lineage-24.0/media/media_codecs_c2.xml), [OMX disable](https://github.com/LineageOS/android_device_oneplus_guacamole/commit/9b3081cb2d) | Hardware C2 HEVC decoder is configured in the device tree; disabling OMX is intentional. Fingerprint guide video failure should be investigated through C2 enumeration, includes, ranks, and profiles, not by disabling enrollment or assuming a broken sensor. | Compare runtime media codec list and vendor XML against ColorOS selection; reproduce guide video decode. |
| [slider integration](https://github.com/LineageOS/android_hardware_oneplus/blob/lineage-24.0/packages/KeyHandler/src/org/lineageos/settings/device/KeyHandler.kt) | Current implementation observes tri_state_key kernel uevents and uses Lineage-specific framework/SystemUI integration. Copying the APK alone will not recreate that integration on ColorOS. | Capture actual slider events and implement a compatible real position/ringer bridge. |
| [BPF override](https://github.com/LineageOS/android_device_oneplus_sm8150-common/commit/89aa7329eb) | Confirms 5.10.239 override paired with backported kernel support, already used by our tethering component repair. | Keep kernel and loader paired; no reason to redo this solved boot stage. |
| [blob extraction fixups](https://github.com/LineageOS/android_device_oneplus_sm8150-common/blob/lineage-24.0/extract-files.py) | Camera uses a metadata shim; fingerprint uses its own shim; NFC config changes device node to /dev/nq-nci. These may already be present in the extracted vendor. | Inventory before applying duplicate patches. LLNDK visibility is separate from camera metadata ABI. |

## Work order

1. Build and preflight the already prepared persistent display/WiFi/LLNDK/my_stock repairs. Review exact image changes before requesting flash approval. Do not confuse earlier live success with clean-boot validation.
2. Audit blocking missing Oplus AIDL service calls for power-key delay. None of the above device commits proves a fix for ColorOS Theia; use the recorded caller stack and actual framework code.
3. Restore hardware video decode selection for fingerprint enrollment, then integrate current motor helper/calibration and slider behavior with ColorOS permissions and services.
4. Analyze recorded NFC session and charging interfaces; no verified upstream fix has yet been identified for those symptoms. Do not clear charging warnings or alter calibration to hide a mismatch.

Downloaded source and commit JSON in this directory provide a reproducible starting point. No new hardware functionality is claimed fixed by this audit.
