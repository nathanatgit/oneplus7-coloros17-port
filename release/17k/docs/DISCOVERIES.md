# Discoveries made while porting

Facts that are not obvious from the code, with where they were measured. Useful when something looks like it should work and does not.

## Hardware and firmware

- The OnePlus 7 Pro (guacamole, SM8150) has an NXP PN553 NFC chip (`/dev/nq-nci` kernel driver) and, on eSE-equipped variants, an external NXP eSE on SPI (`spi1.0`, modalias `spi:p61`, node `/dev/p73` with the OnePlus driver). Stock H.40 also ships "noeSE" NFC configs for project 18821 (`libnfc-nxp_noeSE.conf_18821`), so some regional units have no eSE; the user's phone has one (stock ran `secure_elementnq330`).
- The OnePlus 8T (SM8250) uses a different eSE design (Qualcomm GPQeSE inside the secure world through a QSEE app `eseservice`, `vendor.qti.secure_element@1.2` + `esepowermanager`), so it is not a reference for this phone's eSE. Its sound-trigger platform info lists the same four vendor uuids as the H.40 one (QTI SVA `68ab2d40-...`).
- Panel color: the panel calibration file `qdcm_calib_data_samsung_dsc_cmd_mode_oneplus_dsi_panel.xml` is byte-identical in stock H.40 and the LOS vendor (modes SRGB, DCI_P3, advance_*, zhal_native, fod_native, hal_hdr, CTS). Stock props `ro.oplus.display.colormode.colorful=0` and `.cinema=3` match LineageOS LiveDisplay ids 0 (Vivid) and 3 (Brilliant); LiveDisplay ids are 0 Vivid, 1 Natural, 2 Cinematic, 3 Brilliant.
- Brightness: the panel node maps framework level L to raw L/10 (222 -> 23, 8191 -> 818, 10239 -> 1023); `batt_fcc`/`batt_soh` sysfs nodes exist on the LOS kernel; `/sys/class/oplus_chg` does not.
- Touch node table, alert slider (`/proc/tristatekey/tri_state`), motor (`/sys/class/motor`) and the display `oplus_display` sysfs nodes are present on the LOS kernel.

## ColorOS 17 internals

- `Build.MODEL` and other `Build` fields are static values cached by zygote; app processes inherit them, so a property change shows only after zygote restarts (a reboot). Property values can be overwritten in place in `/dev/__properties__/<context>` for same-length strings, but app processes already forked keep the old static.
- `ro.*` properties are write-once: when a name appears twice in `build.prop` files the first definition wins at load time (the donor my_manifest defines some names twice).
- The About-phone chip is `OplusDeviceInfoUtils.getDeviceModel()` = `Build.MODEL`.
- ColorOS 17 `OplusBatteryServiceFeature` and many other OnePlus services only use the **AIDL** form of their HAL (charger V12, touch V2, project, misc fall back to HIDL). The stock H.40 HAL is HIDL; a matching AIDL stand-in is needed.
- ColorOS 17 Settings feeds `display_color_mode` (301 standard, 303 natural, 307 vivid) to `ColorDisplayService.setColorModeExt` and its SurfaceFlinger extension; on this composer SF logs "map unknown (DCI-P3 sRGB Full range)/(Unknown RenderIntent) to default color mode" and nothing changes. The color temperature wheel works through color matrices (a direct SF color matrix turned the screen red).
- ColorOS's wake service (`com.oplus.ovoicemanager.wakeup`) wraps its first-stage model in a 204,800-byte "aispeech" container (name, sha1, env, res sections). Passing a raw QTI SVA `.uim` as the model with vendor uuid `68ab2d40` and the SVA 3.0 opaque config (8,916 bytes: confidence 60/80/80, history buffer 2,000 ms / pre-roll 500 ms) makes the H.40 DSP load and start it.
- Android 17 `SoundTrigger.listModules(ArrayList)` returns 0 without filling the list; attaching needs `attachModuleAsOriginator(..., Identity)`. `startForegroundService` on an app service that does not call `startForeground` is killed by the activity manager after 5 s.
- The Breeno enroll screen binds `com.oplus.ovoicemanager.wakeup` OVoiceTrainService; if that package is disabled the screen hangs on "正在加载" and error `[20]` appears if the service crashes.
- Persistent system apps (for example `com.android.se`) are restarted by the activity manager even when hidden or disabled; `pm uninstall` fails. The fix must remove the crash cause.
- The platform signature of ColorOS 17 differs from H.40's; shared-uid system APKs need the donor's own signing block. `tools/transplant-apk-sigblock.py` re-attaches an original block to a patched APK; PackageManager skips digest checks only for APKs on system partitions.

## Linux, linker and VINTF

- Services started from `/odm/bin/hw` run in the vendor linker namespace: libraries must be found in `/odm/lib64` or `/vendor/lib64`; `/system/lib64` is not visible (stock `libevent` had to be copied into odm).
- `LD_PRELOAD` through `setenv` in an rc is the cheapest way to add a missing symbol to a stock binary: a tiny assembly forwarder (`tools/live/odm-shim/`). Preloads are eagerly resolved on Android, so a shim must not reference symbols the target process does not load (hence separate `trim` and `json` shims).
- init refuses to start a service whose binary has no SELinux exec type with a domain transition ("incorrect label or no domain transition") even though SELinux is permissive, and reports it as a generic "unable to start service".
- Every HIDL/AIDL service needs a VINTF manifest entry (odm fragment); the servicemanagers read manifests at start, so a manifest edit needs a reboot.
- SELinux is permissive on this port; the policy is capped to v29 by the donor init.

## Tooling and environment

- Git Bash rewrites `/...` arguments to adb: set `MSYS_NO_PATHCONV=1`. WSL drops loop mounts between calls: mount and use them in one script. `adb exec-out` of large partitions stalls: copy to `/data/local/tmp` and pull.
- `fastboot flash` of the 3.6 GB system image over a flaky USB cable can drop mid-transfer; a dropped flash leaves the partition half written (re-flash the whole partition).
- `/vendor` can be remounted read-write on the running phone (`mount -o remount,rw /vendor`); changes persist until the next vendor flash.
- jadx (WSL), baksmali/smali (WSL), Android SDK `dexdump`, `aapt2` and `zipalign` cover Android analysis; REA's native and Android providers were not usable on this Windows host.
- `ro.boot.rpmb_enable=true`, `ro.boot.prjname=18821` (OnePlus 7 Pro project) on this phone.
