# Core principles for merging and patching into this build

These came out of failures. Follow them when adding a fix to 17d or merging another donor or stock component.

## 1. Respect the layers

- Hardware truth lives in the LineageOS kernel and vendor. Framework behaviour lives in the ColorOS 17 donor. Missing OEM services come from stock H.40 (`odm.img`, `system/euclid/*`, `reserve.img` nested images). Decide which layer a symptom belongs to before patching.
- Prefer **stock H.40 binaries** for OnePlus hardware HALs. Write a stand-in only when the donor asks for a different interface (AIDL instead of HIDL) and implement the real reply shape.
- Never register a generic stub for an interface whose getters return arrays: a stub for `IDisplayPanelFeature` crash-looped system_server (`bad array lengths`). Mirror the real shapes or use the stock HAL.
- Check LineageOS guacamole first: if LOS already solves it for this phone, reuse that.

## 2. Live first, then bake, then prove

1. Reproduce and capture logs. Find the root cause (the cause is often one level below the visible error: the SE HAL silence was a GPIO number in a dtbo).
2. Fix live over root adb (bind mount, `remount,rw /vendor`, `setprop`), with the USB cable attached for anything touching telephony or the framework.
3. Get user confirmation or a measurable result.
4. Bake into `tools/build-port-b.sh` with a **sha256 assert** on every donor file you replace and on every artifact you add; add a matching check to `tools/preflight-b.sh`.
5. Test again from a clean flashed boot. A live fix that depends on leftover state (hidden package, bind mount, spoofed property) is not a fix.

## 3. Be explicit about persistence

- `system_b` is read-only EROFS; the rebuild is the only way to change it.
- `/vendor/odm` can be edited live and survives reboots but not a vendor flash. Everything you edit there must also be added to `tools/live/odm-services/install.list` + `SHA256SUMS` or it is lost on the next flash.
- Bind mounts and in-place property edits vanish at reboot. Zygote-cached values (`Build.*`) change only after a reboot of a new image.
- Record every live-only change in the handoff before it is forgotten.

## 4. Signing, props, linking: the three silent traps

- System APKs you modify must keep the donor's signing block (`transplant-apk-sigblock.py`); shared-uid system apps fail otherwise. Remove stale `oat` directories of patched APKs. The block is only honoured on system partitions, never for `/data` installs.
- `ro.*` is write-once; check which file defines a prop first (`grep` every `build.prop`) and whether a duplicate exists. Do not change `ro.product.name/device` or the fingerprints; features key on them. Change display-only values.
- A stock binary that "won't start" is usually (a) an SELinux exec label with no domain transition, (b) a missing symbol in the LOS libs (`CANNOT LINK`; run it by hand), (c) a missing VINTF entry. Check all three before assuming the HAL is broken.

## 5. Evidence over assumption

- Read the actual consumer: decompile or disassemble the app that complains (jadx, dexdump, smali) to see which property, service or file it reads. Examples: Battery Health reads `ICharger.getUIsohValue`; the About chip reads `Build.MODEL`; the wake service wraps the model in a container.
- Use ablation to prove a patch is needed (remove it, watch the failure return).
- Compare stock H.40 and the port on the same artefact (panel XML hashes, props, manifests) before inventing a theory.
- Say what was not tested. Do not call something fixed from a log line; use the user-visible result (screen, call, audio).

## 6. Safety rules (user-set)

- Slot A is stock H.40 and the rollback path: never flash it, never `fastboot -w` or format it; wipes for slot A go through stock recovery.
- Ask before any flash, wipe or slot change; use `fastboot boot` for temporary tests.
- **Do not build a new image until the user approves or requests it; record the fixes first** (handoff §14).
- Keep the previous builds and their hashes for rollback; never accept an OTA inside the port.
- Do not hide state that makes a test pass (for example a hidden package or a spoofed model name left behind).

## 7. Merging checklist for a new component

1. Where does it run (namespace, partition, uid)? 2. Which interface does the consumer ask for (HIDL / AIDL / version)? 3. Needed libraries resolve in that namespace? (`tools/odm-deps-check.py`) 4. VINTF entry + rc + exec label + mode/owner. 5. Missing symbols: shim. 6. sha asserts + preflight check. 7. Clean-boot test list entry. 8. Handoff entry.
