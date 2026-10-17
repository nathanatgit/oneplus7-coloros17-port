#!/usr/bin/env bash
# Phase B: ColorOS 17 (Axis GSI) system on the LineageOS 24 base (slot B). Run as root inside WSL.
#   out-b/system.img  EROFS ColorOS system (my_stock emptied) + LineageOS tethering APEX + bpf kver override
#   out-b/boot.img    LineageOS boot with an erofs /system line added to the first-stage fstab
#   out-b/vendor.img  LineageOS vendor with an erofs /system line added to /etc/fstab.qcom
#
# Donor-independent: override GSI / W / OUT / GSI_MNT to build from another donor, e.g. (PLK110, Qualcomm):
#   GSI=$P/ColorOS17-PLK110/system.img W=/root/plk OUT=$P/out-plk GSI_MNT=/mnt/plk FBE_MODE=... build-port-b.sh
# FBE_MODE: "standard" (aes-256-xts:aes-256-cts:v2; needed for an AOSP vold) or "ice" (keep LineageOS's Qualcomm
# legacy option; only works if the donor's vold carries the CAF wrapped-key/ICE patches).
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
L=$P/LineageOS24
GSI=${GSI:-$P/ColorOS17-GSI/system.img}
W=${W:-/root/cos17b}
OUT=${OUT:-$P/out-b}
GM=${GSI_MNT:-/mnt/gsi}
FBE_MODE=${FBE_MODE:-standard}
SYSTEM_PART=3640655872
AVB="python3 -I $P/tools/avb/avbtool.py"
KEY=$P/tools/avb/port_key.pem
EROFS_LINE='/dev/block/by-name/system                               /system                erofs   ro                                                   wait,slotselect,avb,first_stage_mount'

mkdir -p "$GM" /mnt/los /mnt/losv "$W" "$OUT"
mountpoint -q "$GM" || mount -o ro,loop "$GSI" "$GM"
mountpoint -q /mnt/los || mount -o ro,loop "$L/payload/system.img" /mnt/los
mountpoint -q /mnt/losv || mount -o ro,loop "$L/payload/vendor.img" /mnt/losv

add_erofs_line() {  # insert the erofs /system entry before the ext4 one (fs_mgr tries same-mount entries in order)
  local f=$1
  grep -q '^/dev/block/by-name/system .* ext4 ' "$f" || { echo "no ext4 /system line in $f"; exit 1; }
  grep -q ' erofs ' "$f" && { echo "already patched: $f"; return; }
  awk -v l="$EROFS_LINE" '/^\/dev\/block\/by-name\/system .* ext4 / { print l } { print }' "$f" > "$f.new"
  cat "$f.new" > "$f" && rm "$f.new"     # rewrite in place: keeps inode, owner, mode and SELinux xattr
}

echo "== system tree"
rm -rf "$W/tree" && cp -a "$GM" "$W/tree"
T=$W/tree
# my_stock (Contacts/dialer, InCallUI, Mms, Gallery... 1.5 GB) doesn't fit the 3.4 GB system partition: ship it as
# its own EROFS image ($OUT/my_stock.img -> push to /data/port/my_stock.img) and loop-mount it before zygote.
# With the verified full ColorOS 17 my_stock extracted (stock-app-source/, see tools/make-mystock-merged.sh), ship the
# merged 153-app image instead (donor's 40 apps kept as-is, nothing downgraded).
FULL_STOCK=$P/stock-app-source/extracted/my_stock.img
# Camera: the donor's OnePlus Camera (OnePlus 15/8T) crashes the guacamole camera HAL; ship the stock H.40 one (built for
# this camera stack) from StockRom/H40-images system.img -> system/euclid/my_product.img, with its haptics path patched
# (tools/patch-h40-camera.sh, live-tested: no linearmotor service on ColorOS 17). Its v2 signature is stripped, so it
# can only live on a system partition: the my_stock image. Photo, lens switching and video (see below) work.
CAMX=$W/camextra; rm -rf "$CAMX"; mkdir -p "$CAMX/priv-app" "$CAMX/etc/permissions" /mnt/h40s /mnt/h40myp
mountpoint -q /mnt/h40s || mount -o ro,loop $P/StockRom/H40-images/system.img /mnt/h40s
mountpoint -q /mnt/h40myp || mount -o ro,loop /mnt/h40s/system/euclid/my_product.img /mnt/h40myp
cp -a /mnt/h40myp/priv-app/OnePlusCamera /mnt/h40myp/priv-app/OnePlusCameraService "$CAMX/priv-app/"
cp -a /mnt/h40myp/etc/permissions/com.oneplus.camera.xml /mnt/h40myp/etc/permissions/com.oneplus.camera.service.xml "$CAMX/etc/permissions/"
# v10 = novib + the live-validated video patches (tools/live/rea-analysis/*, all offset-preserving dex edits): EIS bypass,
# 4K30 session type 0x8116 -> 0, no 960x540 preview-frame reader (4th stream makes the HAL return -38 at 4K).
# Live test (build 15 + vendor.vidhance.enabled=0 + vendor.audio.hw.aac.encoder=false): 1080p30, 4K30 and 1080p60 recordings
# are valid HEVC+AAC (logs/camera-video-b14/v10-*.mp4).
[ "$(sha256sum < $P/tools/live/camera/OnePlusCamera-H40-v10.apk | cut -d' ' -f1)" = 3415078eebeb5c24cade0ae0ba6caa731c2719b5060f1d53a873879ba61fc5e1 ]
cat $P/tools/live/camera/OnePlusCamera-H40-v10.apk > "$CAMX/priv-app/OnePlusCamera/OnePlusCamera.apk"   # keep label
umount /mnt/h40myp /mnt/h40s
# Its 2019 runtime-permission request loops on Android 17 (dialog never shows): pre-grant like a stock system camera.
install -D -m 0644 -o root -g root /dev/null "$T/system/etc/default-permissions/oneplus7port-camera.xml"
printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>' '<exceptions>' '    <exception package="com.oneplus.camera">' \
  '        <permission name="android.permission.CAMERA" fixed="false"/>' \
  '        <permission name="android.permission.RECORD_AUDIO" fixed="false"/>' \
  '        <permission name="android.permission.ACCESS_FINE_LOCATION" fixed="false"/>' \
  '        <permission name="android.permission.ACCESS_COARSE_LOCATION" fixed="false"/>' \
  '        <permission name="android.permission.READ_MEDIA_IMAGES" fixed="false"/>' \
  '        <permission name="android.permission.READ_MEDIA_VIDEO" fixed="false"/>' \
  '        <permission name="android.permission.POST_NOTIFICATIONS" fixed="false"/>' \
  '    </exception>' '</exceptions>' > "$T/system/etc/default-permissions/oneplus7port-camera.xml"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/default-permissions/oneplus7port-camera.xml"
mkfs.erofs -zlz4hc,12 -E legacy-compress -b4096 --mount-point=/my_stock "$W/my_stock-donor.img" "$T/my_stock" > "$W/mystock-mkfs.log"
if [ -f "$FULL_STOCK" ]; then bash $P/tools/make-mystock-merged.sh "$FULL_STOCK" "$W/my_stock-donor.img" "$W/my_stock.img" "$CAMX"
else mv "$W/my_stock-donor.img" "$W/my_stock.img"; fi
find "$T/my_stock" -mindepth 1 -delete
printf '%s\n' "# OnePlus7Port: my_stock lives on /data (see build-port-b.sh)" \
  "on post-fs-data" \
  "    mkdir /data/port 0750 root root encryption=None" \
  "    mount erofs loop@/data/port/my_stock.img /my_stock ro" > "$T/system/etc/init/00-port-mystock.rc"
setfattr -n security.selinux -v "u:object_r:system_file:s0" "$T/system/etc/init/00-port-mystock.rc"
# Development builds accept the local builder key. Production-property releases remove that key and require normal
# Android ADB authorization, so a release ZIP cannot silently trust the build PC on a different device.
if [ "${PROD_PROPS:-0}" = 1 ]; then
  rm -f "$T/product/etc/security/adb_keys"
else
  install -m 0644 -o root -g root /mnt/c/Users/Han/.android/adbkey.pub "$T/product/etc/security/adb_keys"
  setfattr -n security.selinux -v "u:object_r:adb_keys_file:s0" "$T/product/etc/security/adb_keys"
fi
printf '\n# --- OnePlus7Port Phase B ---\npersist.sys.usb.config=adb\n# LineageOS sm8150 kernel has eBPF backported to 5.10 level (same value as LineageOS product.prop)\nro.bpf.kver_override=5.10.239\n' >> "$T/system/build.prop"
# Display: ColorOS SF keeps its QTI composer extension (SET_LAYER_TYPE); the vendor composer is the source-built one
# that parses it and marks the fingerprint pressed layer (vendor block below). Replaces tools/patch-sf-qti-ext.py.
# Live-tested artifacts below (handoff-2026-10-15 §0d/§0e) replace donor files; each is tied to the donor it came from.
need_sha() { [ "$(sha256sum < "$1" | cut -d' ' -f1)" = "$2" ] || { echo "unexpected donor file $1 (artifact made for another donor)"; exit 1; }; }
replace_file() {  # rewrite in place: keeps inode, owner, mode and SELinux xattr
  cat "$2" > "$1"
}
# Oplus AIDL stubs (tools/oplus-stubs, app_process): ColorOS 17 waits 5 s for HALs the LOS vendor lacks.
# IOplusProject: Theia power-key hook on the input thread (5 s power-key delay). IPerformance: mediaserver/system_server
# (fingerprint enroll ANR). IDisplayPanelFeature: fpType (211) = 2 and 22/12/28 → /sys/kernel/oplus_display
# dimlayer_hbm/hbm/notify_fppress (stock H.40 SetDisplayPanelDimlayHBM/HBM/FPPress); the LOS kernel only runs its FOD
# path (HBM + UI ready to gf_spi) while dimlayer_hbm=1. Starts before zygote. su domain = debug build only.
# IOplusTouch: ColorOS 17's only route to /proc/touchpanel (screen-off gestures write the double_tap_enable_indep
# mask); nodeFlag = index into the stock H.40 touch@1.0-service path table.
# MotorBridge: pop-up front camera (handoff-2026-10-16 §0). The repackaged LOS helper was a user app and ColorOS
# FastClear killed it; this runs from init as root, so it is not an app process. Live-verified 2026-10-16 17:12.
install -m 0644 -o root -g root $P/tools/oplus-stubs/oplus-stubs.dex "$T/system/framework/oplus-port-stubs.dex"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/framework/oplus-port-stubs.dex"
# Screen-off gestures: the LOS touch driver reports gestures as scancode 246 + type (O 252, V 248, single tap 262);
# ColorOS OplusScreenOffGestureManager only acts on KEYCODE_F4 + /proc/touchpanel/coordinate. Map them to F4
# (live-verified: single tap -> AOD, O and V actions, double tap wakes). The stub keeps double tap in the mask.
install -m 0644 -o root -g root $P/tools/live/keylayout/touchpanel.kl "$T/system/usr/keylayout/touchpanel.kl"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/usr/keylayout/touchpanel.kl"
printf '%s\n' "# OnePlus7Port: Oplus AIDL stub services (tools/oplus-stubs, see build-port-b.sh)" \
  "service port_oplus_stubs /system/bin/app_process /system/bin port.OplusStubs vendor.oplus.hardware.stability.oplus_project.IOplusProject/default vendor.oplus.hardware.performance.IPerformance/default vendor.oplus.hardware.displaypanelfeature.IDisplayPanelFeature/default vendor.oplus.hardware.touch.IOplusTouch/default" \
  "    user root" \
  "    group root system" \
  "    setenv CLASSPATH /system/framework/oplus-port-stubs.dex" \
  "    seclabel u:r:su:s0" \
  "    disabled" \
  "" \
  "on post-fs-data" \
  "    start port_oplus_stubs"   ""   "# Alert slider -> ColorOS action button (port.SliderBridge): up = press, middle = nothing, down = long press."   "service port_slider_bridge /system/bin/app_process /system/bin port.SliderBridge"   "    user root"   "    group root input"   "    setenv CLASSPATH /system/framework/oplus-port-stubs.dex"   "    seclabel u:r:su:s0"   "    disabled"   ""   "on property:sys.boot_completed=1"   "    start port_slider_bridge"   "    start port_motor_bridge"   ""   "# Pop-up front camera motor (port.MotorBridge, LOS CameraMotorService logic): front cam opened = up, released = down."   "service port_motor_bridge /system/bin/app_process /system/bin port.MotorBridge"   "    user root"   "    group root camera"   "    setenv CLASSPATH /system/framework/oplus-port-stubs.dex"   "    seclabel u:r:su:s0"   "    disabled" > "$T/system/etc/init/00-port-oplus-stubs.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-oplus-stubs.rc"
# Light sensor: the OP7 Pro ALS (stk_stk2232) sits under the OLED. LOS's sensors HAL (vendor) subtracts the screen's own
# light using the pixels above the sensor, fetched from the system-side AIDL service vendor.lineage.oplus_als
# IAreaCapture/default (LOS sm8150-common als/default, system_ext). AlsCorrection::init() only connects if that
# instance is VINTF-declared; otherwise service=nullptr and every reading needing correction is dropped ("Could not
# get area above sensor") -> no lux at all (seen 2026-10-16). Ship LOS's 4 files unchanged except that the rc gets a
# seclabel (ColorOS policy has no hal_lineage_oplus_als domain; su like the other port services).
A=$P/tools/live/als
sha256sum -c --quiet <<SUMS || exit 1
23da00307930cb130bcb2d96391647fddd4056f7f0845817008b9b6880f701da  $A/vendor.lineage.oplus_als-V1-ndk.so
6654a74d56e85c038c64706fcf9646f3c9d87d8a10fbaf5a74b9e9d38da4979b  $A/vendor.lineage.oplus_als.service
b1aab70a497dd2725afe29ff7110f42c1a36997aa49a5e0d8e75bbc5d2b31c2f  $A/vendor.lineage.oplus_als.service.rc
8936b22f4757b3c9620cc3e3ba14fff2645ea0c949c29528e00df3f98465184c  $A/vendor.lineage.oplus_als.service.xml
SUMS
for f in "$T/system/lib64/vendor.lineage.oplus_als-V1-ndk.so" "$T/system_ext/bin/hw/vendor.lineage.oplus_als.service" \
         "$T/system_ext/etc/init/vendor.lineage.oplus_als.service.rc" "$T/system_ext/etc/vintf/manifest/vendor.lineage.oplus_als.service.xml"; do
  [ ! -e "$f" ] || { echo "donor already has $f"; exit 1; }
done
install -m 0644 -o root -g root $A/vendor.lineage.oplus_als-V1-ndk.so "$T/system/lib64/"
setfattr -n security.selinux -v u:object_r:system_lib_file:s0 "$T/system/lib64/vendor.lineage.oplus_als-V1-ndk.so"
install -D -m 0755 -o root -g 2000 $A/vendor.lineage.oplus_als.service "$T/system_ext/bin/hw/vendor.lineage.oplus_als.service"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system_ext/bin/hw/vendor.lineage.oplus_als.service"
{ cat $A/vendor.lineage.oplus_als.service.rc; echo "    seclabel u:r:su:s0"; } > "$T/system_ext/etc/init/vendor.lineage.oplus_als.service.rc"
chmod 0644 "$T/system_ext/etc/init/vendor.lineage.oplus_als.service.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system_ext/etc/init/vendor.lineage.oplus_als.service.rc"
install -m 0644 -o root -g root $A/vendor.lineage.oplus_als.service.xml "$T/system_ext/etc/vintf/manifest/"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system_ext/etc/vintf/manifest/vendor.lineage.oplus_als.service.xml"
# Fingerprint: the stock H.40 Goodix HAL sends IBiometricsFingerprintClientCallbackEx.onFingerprintCmd as vec<uint32>;
# ColorOS 17 reads vec<int8> → TOUCH_DOWN lost. Patched services.jar (classes4.dex, tools/live/fpcmd) reads int32s.
# Its odex/vdex/art were built from the old dex: drop them (system_server then runs the jar's dex).
need_sha "$T/system/framework/services.jar" 8fd8f8321817e75c87f019b8e24a0d69431742c1c0c17b00f2b952c4674ebfdc
replace_file "$T/system/framework/services.jar" $P/tools/live/fpcmd/services.jar
rm -f "$T"/system/framework/oat/*/services.{odex,vdex,art}{,.fsv_meta}
# SystemUI: kernel and SystemUI both dimmed the lock screen for the fingerprint (black lock screen). The kernel's dim
# layer compensates HBM by itself, so SystemUI's is switched off: tools/patch-systemui-dim.py
# (KeyguardFeatureOption.isDisableAppDimLayer only) + tools/transplant-apk-sigblock.py (original platform signing
# block; system-partition APKs are scanned without digest checks — verified live with the package cache wiped).
need_sha "$T/system_ext/priv-app/SystemUI/SystemUI.apk" 5677dadb2eae2e898aafe286b842b3885cbbb69b572099f52a984f6cfa01ee8e
replace_file "$T/system_ext/priv-app/SystemUI/SystemUI.apk" $P/tools/live/SystemUI-kernel-dim-signed.apk
rm -rf "$T/system_ext/priv-app/SystemUI/oat"
# ColorOS config search path: OplusCfgFilePolicy splits env CUST_LEVEL_LIST (":"-list of partition roots, last = top
# priority) and both feature loaders (OplusFeatureConfigManagerService oplus-features, AppFeature provider app-features)
# scan <root>/etc/extension through it. The GSI's init.environ.rc doesn't export it (stock devices get it from the boot
# ramdisk's init.environ.rc), so every my_* feature was ignored: "AppFeature_ParserUtils: no pathList found for
# /etc/extension", 0 app features -> Settings isExpVersion (no com.android.settings.cn_version) -> Special access closes
# itself; oplus.software.* features of my_product unread.
# Order = what stock PLK110 init (Oplus-modified system/core/init, ColorOS 17.0.0.105 CN01 full OTA) builds before
# setenv("CUST_LEVEL_LIST", Join(list, ':')) in SecondStageMain, minus its property-dependent entries (hardware SKU,
# brand region, pipeline region, ro.oplus.cust.ver). The GSI's init has no such code.
printf '%s\n' "on early-init" \
  "    # OnePlus7Port: ColorOS config partition order (low -> high priority), as stock init sets it" \
  "    export CUST_LEVEL_LIST /system:/system_ext:/vendor:/odm:/odm/cust:/my_preload:/my_stock:/my_region/global:/my_product:/my_region:/my_bigball:/my_carrier:/my_carrier/cust:/my_company:/my_engineering:/my_product/special" \
  >> "$T/init.environ.rc"
# OnePlus 7 Pro hardware vs the PLK110 (OnePlus 15) my_product. With CUST_LEVEL_LIST set, ColorOS reads my_product's
# features too, so OnePlus 15-only hardware must not be declared:
#  - display: no punch hole (pop-up camera), 1440x3120 / 1080x2340 panel, 60/90 Hz without LTPO (no ADFR/PDFR, no
#    144/165 Hz exclusive modes; the OnePlus 11 also keeps adfr=2 for its LTPO panel);
#  - always-on sensor hub (aon_*), wired reverse charging, camera-hole brighten/curve: hardware/HALs not present;
#  - radio: GM1910 is LTE-only (no 5G / dual NR).
python3 -I - "$T/my_product/build.prop" "$T/my_product/etc/extension/com.oplus.oplus-feature.xml" <<'PY'
import sys, re
bp, feat = sys.argv[1], sys.argv[2]
s = open(bp).read()
def setp(k, v):
    global s
    assert re.search(r'^%s=' % re.escape(k), s, re.M), k
    s = re.sub(r'^%s=.*$' % re.escape(k), '%s=%s' % (k, v), s, flags=re.M)
def dropp(k):
    global s
    assert re.search(r'^%s=' % re.escape(k), s, re.M), k
    s = re.sub(r'^%s=.*\n' % re.escape(k), '', s, flags=re.M)
dropp('ro.oplus.display.screenhole.positon')
setp('ro.oplus.resolution.low', '1080,2340')
setp('ro.oplus.resolution.high', '1440,3120')
setp('persist.oplus.display.vrr.adfr', '0')
setp('persist.oplus.display.vrr.pdfr', '0')
dropp('persist.oplus.display.ogfr.exclusive')
# Auto brightness: the OnePlus 7 Pro also has an under-screen light sensor, but at H.40's region (stock
# my_product build.prop, 1440-wide panel), not the OnePlus 15's 732,100,770,137 on 1272x2772.
setp('ro.lcd.display.screen.underlightsensor.region', '988,251,1042,305')
setp('ro.oplus.lcd.display.screen.underlightsensor.region', '988,251,1042,305')
setp('ro.oplus.lcd.display.screen.underlightsensor.screensize', '1440,3120')
setp('ro.oplus.radio.dual_nr_enabled', 'false')
setp('ro.oplus.radio.dual_nr_toggle_enabled', 'false')
open(bp, 'w').write(s)
f = open(feat).read()
for name in ('oplus.software.aon_sensorhub_enable', 'oplus.software.aon_phone_camera_gesture_recognition',
             'oplus.software.aon_aod_enable', 'oplus.software.display.adfr_v32_lp', 'oplus.hardware.wired_reverse_charging',
             'oplus.software.display.camera.brighten', 'oplus.software.display.camera.curve',
             'oplus.software.radio.support_5g', 'oplus.software.radio.support_dual_nr'):
    pat = r'[ \t]*<oplus-feature name="%s"\s*/>[ \t]*\n' % re.escape(name)
    assert len(re.findall(pat, f)) == 1, name
    f = re.sub(pat, '', f)
open(feat, 'w').write(f)
print('my_product: OnePlus 7 Pro adjustments applied')
PY
# OnePlus 15 panel overlays (static, always enabled): framework one sets a 78x141 punch-hole cutout, 176 px rounded
# corners, stable display 1272x2772 and a dual (rear) light sensor; the oplus one holds its cutout/rounded-corner
# drawables -> hole mask drawn on a notchless panel. Stock H.40 my_product has no display overlay (framework
# defaults).
# Neither can simply be dropped. The android one also defines config_availableColorModes (0,1,3,256-265,301-308);
# without it ColorOS's saved display_color_mode=301 is invalid -> system_server crash loop "Invalid colorMode: 301"
# (ColorDisplayService:1333), seen live 2026-10-16 15:11-15:12 -> keep it, blank its cutout (below).
# The oplus one holds only the rc/cutout drawables (oplus_rc_cutout.png = the visible hole), but dropping it is wrong too: ColorOS 17's default oplus_rc_top_left.png has a punch hole baked in (a
# hole then showed top-left, live 2026-10-16). Use what stock H.40 ships for this panel instead: H.40 odm
# oplus_framework_res_overlay.display.product.18821.apk (18821 = OP7 Pro project; same package name, static, target
# "oplus") = only the 4 OP7 Pro rounded corners, no cutout image -> ColorOS 17's default oplus_rc_cutout.png, which
# is fully transparent. Live-verified 2026-10-16 15:21 (no hole, no crash).
f=oplus_framework_res_overlay.display.product.24831.apk
[ -f "$T/my_product/overlay/$f" ] || { echo "display overlay $f missing in donor"; exit 1; }
rm "$T/my_product/overlay/$f"
mkdir -p /mnt/b14-h40sys /mnt/b14-h40eodm
mountpoint -q /mnt/b14-h40sys && umount -R /mnt/b14-h40sys; mount -o ro,loop $P/StockRom/H40-images/system.img /mnt/b14-h40sys
mount -o ro,loop /mnt/b14-h40sys/system/euclid/odm.img /mnt/b14-h40eodm
h=oplus_framework_res_overlay.display.product.18821.apk
echo "1c2200edd65a8383d402612f11a01e8f0dcf6db5097ba1103bdb7d58b0f4ed2c  /mnt/b14-h40eodm/overlay/$h" | sha256sum -c --quiet || exit 1
install -m 0644 -o root -g root "/mnt/b14-h40eodm/overlay/$h" "$T/my_product/overlay/$h"
setfattr -n security.selinux -v "u:object_r:system_file:s0" "$T/my_product/overlay/$h"
# Power profile: the GSI's framework-res power_profile is a placeholder (battery.capacity=2.0, every component 0.1)
# -> Settings "2 mAh (typical)" (DeviceInfoUtils.getBatteryCapacity uses PowerProfile, the prop only on confidential
# builds) and meaningless battery-usage stats. ColorOS reads <partition>/etc/power_profile/power_profile.xml
# (oplus-framework.jar); stock H.40 ships this phone's profile in odm and my_product (identical, capacity 4065).
# LOS has the same data in its vendor overlay OPlusFrameworksResTarget, but /vendor/overlay is hidden by the Axis GSI
# (rw-system.sh: mount -o bind /system/axisgsi/vo /vendor/overlay). Live-verified 2026-10-16 15:30: 4065, user OK.
pp=/mnt/b14-h40eodm/etc/power_profile/power_profile.xml
echo "fbe1bffc1e328b9527dac42e321aab0fdcb9554faae425809757e90399f276dc  $pp" | sha256sum -c --quiet || exit 1
[ ! -e "$T/my_product/etc/power_profile" ] || { echo "donor my_product already has power_profile"; exit 1; }
install -d -m 0755 -o root -g root "$T/my_product/etc/power_profile"
install -m 0644 -o root -g root "$pp" "$T/my_product/etc/power_profile/power_profile.xml"
setfattr -n security.selinux -v "u:object_r:system_file:s0" "$T/my_product/etc/power_profile"
setfattr -n security.selinux -v "u:object_r:system_file:s0" "$T/my_product/etc/power_profile/power_profile.xml"
# Wireless charging: the donor declares the OnePlus 15's 50 W wireless charging (About phone "50W 无线闪充" via
# app feature os.charge.settings.wirelesscharging.power, read since CUST_LEVEL_LIST). OP7 Pro = Warp Charge 30, wired
# only; stock H.40 declares no wireless feature. Drop exactly these features (live-verified 2026-10-16, user OK).
python3 -I - "$T/my_product/etc/extension" <<'PY'
import sys, os
ext = sys.argv[1]
drop = {
    'com.oplus.app-features.xml': ['os.charge.settings.wirelesscharging.power', 'os.charge.settings.wirelesscharge.support',
                                   'oplus.power.onwirelesscharger.support', 'oplus.power.wirelesschgwhenwired.support',
                                   'os.charge.settings.wirelesschargingcoil.position'],
    'feature_com.android.battery.xml': ['oplus.power.onwirelesscharger.support'],
}
for fn, names in drop.items():
    p = os.path.join(ext, fn)
    lines = open(p).read().split('\n')
    out = []
    for l in lines:
        hit = [n for n in names if 'name="%s"' % n in l]
        if hit:
            names.remove(hit[0])
            continue
        out.append(l)
    assert not names, '%s: not found %s' % (fn, names)
    with open(p, 'r+') as f:   # in place: keeps the SELinux label
        f.seek(0); f.write('\n'.join(out)); f.truncate()
print('my_product: wireless charging features removed')
PY
umount /mnt/b14-h40eodm /mnt/b14-h40sys
# The android overlay (24831) stays for its colour modes, but its cutout path/rect approximation are the OnePlus 15's
# 78x141 hole -> emptied in place by tools/patch-cutout-overlay.py (the rect approximation references the same
# string). Live-verified 2026-10-16 15:24 with no fabricated overlays: DisplayCutout insets 0, colour mode 301 valid.
a=android_framework_res_overlay.display.product.24831.apk
echo "d0ddc215d6e0acbb01b7886403478e791de46af66998b517bf3a96f8703b3efc  $T/my_product/overlay/$a" | sha256sum -c --quiet || exit 1
python3 -I $P/tools/patch-cutout-overlay.py "$T/my_product/overlay/$a" "$W/$a"
echo "72ffbbddf5a7712e7be6bc1e89683929f9b3ce05b3caadd4870bc302d6b17121  $W/$a" | sha256sum -c --quiet || exit 1
cat "$W/$a" > "$T/my_product/overlay/$a"   # in place: keeps owner/mode/SELinux label
# About device: show the real phone. Only display values change (market names, LUMO camera badge, typical battery);
# ro.product.model/name/device stay PLK110/OP60FFL1 because ColorOS apps and services key features on them.
# ro.product.batterycapacity is unset in every partition (stock sets it at runtime) -> Settings showed "2 mAh";
# OnePlus 7 Pro typical capacity 4000 mAh.
python3 -I - "$T/my_manifest/build.prop" "$T/my_product/build.prop" <<'PY'
import sys, re
man, prod = sys.argv[1], sys.argv[2]
m = open(man).read()
for old, new in (('ro.vendor.oplus.market.name=一加 15', 'ro.vendor.oplus.market.name=一加 7 Pro'),
                 ('ro.vendor.oplus.market.enname=OnePlus 15', 'ro.vendor.oplus.market.enname=OnePlus 7 Pro')):
    assert m.count(old + '\n') == 1, old
    m = m.replace(old + '\n', new + '\n')
open(man, 'w').write(m)
p = open(prod).read()
assert p.count('\nro.oplus.camera.isSupportLumo=1\n') == 1
p = p.replace('\nro.oplus.camera.isSupportLumo=1\n', '\nro.oplus.camera.isSupportLumo=0\n')
assert 'ro.product.batterycapacity=' not in p
p += '\n# OnePlus7Port: typical battery capacity (Settings > About device)\nro.product.batterycapacity=4000\n'
open(prod, 'w').write(p)
print('about device: OnePlus 7 Pro names, battery 4000 mAh, LUMO off')
PY
# Storage size prop: stock supersize.rc runs system_ext/bin/getsuperlayoutsize.sh (CRLF file) at boot_completed; it
# sums lpdump sectors of the super partition. OnePlus 7 Pro has no super -> lpdump fails -> the prop becomes "\r".
# com.oplus.wallpapers OdinHeaderTools parses `getprop` with readLine() (splits on \r) -> "[...super_size]: [" ->
# StringIndexOutOfBounds -> process dies (Flux theme editing, build 12). Set it from the real slot-B partitions
# (system_b 3640655872 + vendor_b 1073741824 + odm_b 104857600 bytes on GM1910) and drop the script's trigger.
grep -q '^ro.oplus.storage.super_size=' "$T/system_ext/etc/build.prop" && { echo "super_size already in system_ext build.prop"; exit 1; }
printf '\n# OnePlus7Port: no super partition (getsuperlayoutsize.sh would set "\\r")\nro.oplus.storage.super_size=4819255296\n' >> "$T/system_ext/etc/build.prop"
rm "$T/system_ext/etc/init/supersize.rc"
# Incoming SMS (live-verified 2026-10-17, ims-volte-findings-2026-10-17.md): the donor ships persist.vendor.radio.poweron_opt=1.
# With it qcrild buffers incoming SMS ("MT SMS ACK NEEDED Power Opt buffer") and waits for an ACK handshake ColorOS never
# sends, times out after ~20 s and the network redelivers forever; nothing reaches Android. 0 + qcrild restart: all texts arrived.
grep -qx 'persist.vendor.radio.poweron_opt=1' "$T/system_ext/etc/build.prop" || { echo "poweron_opt line changed in donor"; exit 1; }
sed -i 's/^persist\.vendor\.radio\.poweron_opt=1$/persist.vendor.radio.poweron_opt=0/' "$T/system_ext/etc/build.prop"
# Version string follows the OnePlus 7 Pro convention (stock: GM1910_11.H.40_4400_202303231745); only the Settings "show" string
# changes, not ro.build.version.ota / display.ota / full_id. Format: GM1910_<ColorOS version>(<yyyymmddhhmm>).
grep -qx 'ro.build.display.id.show=PLK110_17.0.0.100(SP09CN01)' "$T/my_manifest/build.prop" || { echo "display.id.show changed in donor"; exit 1; }
sed -i 's/^ro\.build\.display\.id\.show=.*$/ro.build.display.id.show=GM1910_17.0.0.100(202610171200)/' "$T/my_manifest/build.prop"
# Auto-brightness (live-verified 2026-10-17): ColorOS 17's lux->nit curve is built in; the donor's nit->level table in
# display_brightness_config_default.xml is for the donor panel. The OP7 Pro maps level/10 -> panel raw, and H.40's stock lux->raw
# curve is 2.55 x that nit curve at every sampled lux, so nit(level) = level/10/2.55 (tools/live/brightness/rescale_nits.py).
BR=$P/tools/live/brightness/display_brightness_config_default.h40nits.xml
[ "$(sha256sum "$T/system_ext/etc/display_brightness_config_default.xml" | cut -d' ' -f1)" = 0cf4765eddae24ccbb7847635e8b21b26d5bcd9c7915391e4e27852cca8e28c7 ] || { echo "donor brightness table changed"; exit 1; }
[ "$(sha256sum $BR | cut -d' ' -f1)" = ae420be14e7dbff8f2c46f2a035749e829cec49a939748d1510ffef40651cf3c ] || { echo "brightness table sha"; exit 1; }
cat $BR > "$T/system_ext/etc/display_brightness_config_default.xml"
# IMS / VoLTE (live-verified 2026-10-17: outgoing calls over VoLTE, SMS over IMS). ColorOS 17's org.codeaurora.ims only has an
# AIDL IImsRadio client; the LOS24 vendor only has the HIDL one, so MMTEL stayed UNAVAILABLE and calls fell back to CS (cause 248).
# Ship the LOS24 ims.apk (HIDL ImsRadio) with: QtiImsExt.<init> calling ColorOS's QtiImsExtBase.<init>(Executor, Context) (the base
# class from ColorOS ims-ext-common stores mContext; the no-arg call left it null -> NPE -> com.android.phone crash), ColorOS's
# own signing block (tools/transplant-apk-sigblock.py; system apps are scanned without digest checks, same signer keeps the shared
# uid android.uid.qtiphone), the matching LOS JNI libs, and a library dependency so the app can load android.hidl.manager-V1.0-java.
# Artifacts and how they were made: tools/live/ims/ (smali edit, apktool 3.0.3).
I=$P/tools/live/ims
sha256sum -c --quiet <<SUMS || exit 1
93c199d707cd6dd908b82e3d24d7aa3bdc15f28aa858aae9b9b14c362ca1f48c  $T/system_ext/priv-app/ims/ims.apk
2d0231984a8b68c24f312f5b3ee227354e5cc706371476eff5cf67d892e8c3c0  $T/product/etc/permissions/ims_ext_common.xml
470b8c126db668869c04cff8854d33afa0fe5d9e465e7e681136cb1dfc9fa78d  $I/los/ims-los24-ctx-cossig.apk
a0e3a93431cdc272374fe3b3c47654f27f1b0a4d97cf0eafb7082f66d994a5c9  $I/ims_ext_common.xml
96101b310219f1ce1c4f52c3f5fadd1a609aec7128a06d8a8811bd05540d7902  $I/los/lib-arm64/libimsmedia_jni.so
c34698971641c9536e50ab69b9225ed97954f0c57f641d31e56537e414813177  $I/los/lib-arm64/libimscamera_jni.so
SUMS
cat "$I/los/ims-los24-ctx-cossig.apk" > "$T/system_ext/priv-app/ims/ims.apk"     # keeps owner, mode and label
cat "$I/ims_ext_common.xml" > "$T/product/etc/permissions/ims_ext_common.xml"
rm -rf "$T/system_ext/priv-app/ims/oat"                                           # odex/vdex belong to the ColorOS apk
IL=$T/system_ext/priv-app/ims/lib/arm64
rm -f "$IL/libimsmedia_jni.so"                                                    # donor: symlink to the ColorOS jni lib
for f in libimsmedia_jni.so libimscamera_jni.so; do
  install -m 0644 -o root -g root "$I/los/lib-arm64/$f" "$IL/$f"
  setfattr -n security.selinux -v u:object_r:system_lib_file:s0 "$IL/$f"
done
# Breeno wake-up on the H.40 DSP (live-verified 2026-10-17 14:18, user confirmed; handoff-2026-10-17.md §11d, tools/live/breeno-sva/):
# ColorOS 17's own wake service (com.oplus.ovoicemanager.wakeup, its settings switch and enroll screen) runs on the H.40 Qualcomm SVA first
# stage. Its donor model/uuid (Breeno-Speech 68ac2d41-..., aispeech container) cannot run on the H.40 ADSP, so: (1) the donor
# OVoiceManagerService.apk is the smali-patched copy (keyphrase xiaobuxiaobu, raw model file, SVA 3.0 opaque start data; ColorOS 17
# signing block transplanted), (2) OVMS_settings.xml uses the QTI SVA vendor uuid 68ab2d40-e860-11e3-95ef-0002a5d5c51b, (3) the model
# OVMS_1st_wakeup.bin is H.40's sm3_xiaobuxiaobu.uim. The package stays ENABLED (earlier builds disabled it at boot because the unpatched
# app crash-looped the audio HAL through the SoundTrigger HAL), so there is no 01-port-audio-fix.rc any more. The OnePlus
# com.oneplus.voicewakeup app and the H.40 listen libs are not shipped (build 17/17b had them; not needed).
BS=$P/tools/live/breeno-sva
sha256sum -c --quiet <<SUMS || exit 1
cd68824e961323f7b2f47b42638150a5f99e236fa79d85e18b65b5fea6f34238  $BS/OVoiceManagerService-sva-c17sig.apk
0d1ce62eef5fb551173d563b8c59a26e708a377c5ca4a4268c817b80917d54b9  $BS/OVMS_settings.xml
b8591733916c56872df3879ba4f733d7d297500e08dd40409454236a106e6371  $BS/OVMS_1st_wakeup.bin
SUMS
[ "$(unzip -p "$BS/OVoiceManagerService-sva-c17sig.apk" 'classes*.dex' | grep -ac svaOpaque)" -ge 1 ] || { echo "breeno apk lacks svaOpaque"; exit 1; }   # grep -c reads all (grep -q + pipefail = SIGPIPE)
OV=$T/my_product/priv-app/OVoiceManagerService
[ -f "$OV/OVoiceManagerService.apk" ] || { echo "donor OVoiceManagerService.apk missing"; exit 1; }
for f in "$T/my_product/etc/OVMS_settings.xml" "$T/my_product/etc/breenospeech2/OVMS_settings.xml" "$T/my_product/etc/OVMS_1st_wakeup.bin" "$T/my_product/etc/breenospeech2/OVMS_1st_wakeup.bin"; do
  [ -f "$f" ] || { echo "donor lacks $f"; exit 1; }
done
replace_file "$OV/OVoiceManagerService.apk" "$BS/OVoiceManagerService-sva-c17sig.apk"      # keeps owner, mode and label
rm -rf "$OV/oat"                                                                           # odex/vdex belong to the donor apk
for d in "$T/my_product/etc" "$T/my_product/etc/breenospeech2"; do
  replace_file "$d/OVMS_settings.xml" "$BS/OVMS_settings.xml"
  replace_file "$d/OVMS_1st_wakeup.bin" "$BS/OVMS_1st_wakeup.bin"
done
rm -f "$T/system/etc/init/01-port-audio-fix.rc"
# OMAPI for Wallet "Se Service Connection Error" (handoff-2026-10-17 §9b): the donor has no com.android.se, only the overlay
# SecureElementResTarget_Vendor. Use the LOS24 build (targetSdk 37 = this Android; it registers "secure_element" and, with the
# secure_element_vintf_enabled resource, android.se.omapi.ISecureElementService/default). The H.40 one is Android 12, binds by intent
# and needs the H.40 com.vendor.nfc library. It reaches the SIM1/SIM2 secure_element HALs of the LOS vendor; the eSE (stock
# android.hardware.secure_elementnq330 HAL) is shipped since 17d and needs the CONFIG_NFC_P73_ESE kernel + corrected eSE power GPIO (handoff §12).
SE=$P/tools/live/odm-services/app/SecureElement-los24.apk
[ "$(sha256sum < $SE | cut -d' ' -f1)" = 78a219c9a447857913750780763e69a4b0b4f1ceb92a2e49801d3f183faec644 ] || { echo "SecureElement apk sha"; exit 1; }
[ ! -e "$T/system_ext/app/SecureElement" ] || { echo "donor already has SecureElement"; exit 1; }
install -d -m 0755 -o root -g root "$T/system_ext/app/SecureElement"
install -m 0644 -o root -g root "$SE" "$T/system_ext/app/SecureElement/SecureElement.apk"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system_ext/app/SecureElement" "$T/system_ext/app/SecureElement/SecureElement.apk"
# Volume panel: OnePlus 7 Pro volume keys are on the left; the PLK110 donor says right (SystemUI
# FeatureOption.isOplusVolumeKeyInRight reads this prop).
python3 -I - "$T/my_product/build.prop" <<'PY'
import sys
p = sys.argv[1]; d = open(p).read(); old = '\npersist.oplus.software.audio.right_volume_key=true\n'
assert d.count(old) == 1, 'right_volume_key line changed in donor'
open(p, 'r+').write(d.replace(old, '\npersist.oplus.software.audio.right_volume_key=false\n'))
PY
# Video codecs: ColorOS sets debug.stagefright.ccodec=1 ("Codec2 for audio, OMX for video"), which drops every vendor
# C2 codec except *.avc.*; the LOS vendor has no OMX (disabled on purpose), so HEVC/VP8/VP9 fell to the software
# decoders (10-bit HEVC fails -> fingerprint-enroll guide video hangs Settings). 4 = all components, normal ranks.
python3 -I - "$T/system/build.prop" <<'PY'
import sys
p = sys.argv[1]; d = open(p).read()
assert d.count('\ndebug.stagefright.ccodec=1\n') == 1, 'ccodec line changed in donor'
open(p, 'r+').write(d.replace('\ndebug.stagefright.ccodec=1\n', '\ndebug.stagefright.ccodec=4\n'))
PY
# Root checks: OPPO Health, Wallet and Find My Device (and the cloud apps) refuse to run when ro.secure=0 / ro.debuggable=1 (their
# isRoot / isDeviceRoot code reads both; found 2026-10-17). The donor GSI ships a "Force ADB" block with ro.secure=0, ro.debuggable=1.
# PROD_PROPS=1 makes them production values, disables adb root, enables ADB host-key authorization, and removes the builder's
# baked-in adb key. PROD_PROPS=0 (default) keeps the development image with adb root. Unlocked-bootloader state is left alone.
if [ "${PROD_PROPS:-0}" = 1 ]; then
python3 -I - "$T/system/build.prop" <<'PY'
import sys
p = sys.argv[1]; d = open(p).read()
for old, new in (('\nro.secure=0\n', '\nro.secure=1\n'), ('\nro.debuggable=1\n', '\nro.debuggable=0\n'), ('\nro.adb.secure=0\n', '\nro.adb.secure=1\n')):
    assert d.count(old) == 1, 'donor Force ADB block changed: ' + old.strip()
    d = d.replace(old, new)
open(p, 'w').write(d)
PY
fi
# WiFi: LineageOS vendor links firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini -> /odm/vendor/etc/wifi/... (LOS: /odm ->
# /vendor/odm). ColorOS's /odm is a dir of per-subdir links without "vendor" -> ini not found -> icnss probe fails.
ln -s /vendor/odm/vendor "$T/odm/vendor"
setfattr -h -n security.selinux -v "u:object_r:vendor_file:s0" "$T/odm/vendor"   # same as the other /odm links
# Camera: LOS vendor camera provider needs libcamera_metadata.so from system as LLNDK; LOS lists it, ColorOS doesn't
# (linkerconfig builds the vendor namespace from this list). ColorOS ships the lib itself.
grep -qx libcamera_metadata.so "$T/system/etc/llndk.libraries.txt" || echo libcamera_metadata.so >> "$T/system/etc/llndk.libraries.txt"
# Property contexts: init merges system + vendor *_property_contexts into one trie; a prefix defined on both sides
# with different contexts fails the trie build → property area init LOG(FATAL) (Phase B build 1, second failure).
# Keep LineageOS vendor's labels (its HALs use them); drop the system-side duplicates (computed per donor).
python3 -I $P/tools/drop-propctx-conflicts.py "$T" /mnt/losv
# SELinux xperms: ColorOS init (phh legacy-kernel patch) caps policy to v29 on this kernel and strips only `allowx`;
# the remaining auditallowx/dontauditx (logging-only rules) make the v29 compile fail → init fatal (found with the
# boot logger). Strip them from the system-side CIL in place (keeps labels).
for f in "$T/system/etc/selinux/plat_sepolicy.cil" "$T/system_ext/etc/selinux/system_ext_sepolicy.cil" "$T/product/etc/selinux/product_sepolicy.cil"; do
  [ -f "$f" ] || continue
  grep -vE '^\((auditallowx|dontauditx) ' "$f" > "$f.new"
  echo "$(basename "$f"): removed $(( $(wc -l < "$f") - $(wc -l < "$f.new") )) auditallowx/dontauditx"
  cat "$f.new" > "$f" && rm "$f.new"
done
# Tethering APEX kernel gates. ColorOS's APEX components hard-check the kernel version (4.14 < 4.19 / 5.x) and do not
# know ro.bpf.kver_override; LineageOS builds of the same mainline sources do. Swapping the whole APEX (PLK builds 1-2)
# broke system_server (its Java needs ColorOS framework APIs: ClassNotFoundException NetworkPolicyManager$
# AllowedTransportsCallback), so keep ColorOS's APEX and bind-mount LineageOS's copies of exactly the override-aware
# binaries/libs over it (identical exported-symbol sets, checked with nm below), plus LineageOS's eBPF programs
# (ColorOS's hard-reset this kernel under the override, PLK build 4).
# Fixes: netbpfload kernel gate; libnetd_updatable "V+ platform with kernel version < 4.19.0" (netd1shot-fail).
KV_FILES="bin/netbpfload lib/libframework-connectivity-jni.so lib64/libframework-connectivity-jni.so
  lib64/libandroid_net_connectivity_com_android_net_module_util_jni.so lib64/libnetd_resolv.so
  lib64/libnetd_updatable.so lib64/libnetworkstats.so lib64/libservice-connectivity.so"
W2=$W/losapex; rm -rf "$W2" && mkdir -p "$W2/los" "$W2/cos"
unzip -p /mnt/los/system/apex/com.android.tethering.capex original_apex > "$W2/los.apex"
unzip -p "$W2/los.apex" apex_payload.img > "$W2/los.img"
unzip -p "$T/system/apex/com.android.tethering.apex" apex_payload.img > "$W2/cos.img"
mount -o ro,loop "$W2/los.img" "$W2/los"; mount -o ro,loop "$W2/cos.img" "$W2/cos"
D="$T/system/etc/port-los-tether"
rm -rf "$D" "$T/system/bin/port-netbpfload-los" "$T/system/etc/port-los-bpf"
RC="$T/system/etc/init/00-port-netbpfload.rc"   # 00-: parsed before netbpfload.rc → runs first in the trigger
printf '%s\n' "# OnePlus7Port: LineageOS (ro.bpf.kver_override-aware) builds over ColorOS's tethering APEX." \
  "on load-bpf-programs" > "$RC"
labels=""
for rel in $KV_FILES; do
  nm -D --defined-only "$W2/cos/$rel" | awk '{print $3}' | sort > /tmp/kv-a
  nm -D --defined-only "$W2/los/$rel" | awk '{print $3}' | sort > /tmp/kv-b
  cmp -s /tmp/kv-a /tmp/kv-b || { echo "export mismatch: $rel"; exit 1; }
  lab=$(getfattr -n security.selinux --only-values "$W2/cos/$rel"); mode=$(stat -c %a "$W2/cos/$rel")
  install -D -m "$mode" -o root -g 2000 "$W2/los/$rel" "$D/$rel"
  setfattr -n security.selinux -v "$lab" "$D/$rel"
  echo "    mount none /system/etc/port-los-tether/$rel /apex/com.android.tethering/$rel bind" >> "$RC"
  labels="$labels ${lab#u:object_r:}"; echo "  $rel ($lab)"
done
cp -a "$W2/los/etc/bpf" "$D/bpf"
echo "    mount none /system/etc/port-los-tether/bpf /apex/com.android.tethering/etc/bpf bind" >> "$RC"
umount "$W2/los" "$W2/cos"
for dir in "$D" "$D/bin" "$D/lib" "$D/lib64"; do setfattr -n security.selinux -v u:object_r:system_file:s0 "$dir"; done
chmod 0644 "$RC"; setfattr -n security.selinux -v u:object_r:system_file:s0 "$RC"
cat "$RC"
# Let init bind-mount over those files/dirs (appended to plat policy; checked by preflight's compile).
PL="$T/system/etc/selinux/plat_sepolicy.cil"
for t in $(echo $labels | tr ' ' '\n' | sed 's/:s0$//' | sort -u); do
  grep -q "^(allow init $t (file (mounton)))" "$PL" || printf '(allow init %s (file (mounton)))\n' "$t" >> "$PL"
done
grep -q '^(allow init system_file (dir (mounton)))' "$PL" || printf '(allow init system_file (dir (mounton)))\n' >> "$PL"
ls -lZ "$T/system/apex/" | grep -i tether

echo "== system.img (EROFS + AVB hashtree footer)"
rm -f "$W/system.img"
mkfs.erofs -zlz4hc,12 -E legacy-compress -b4096 --mount-point=/ "$W/system.img" "$T" > "$W/mkfs.log"
ls -l "$W/system.img"
$AVB add_hashtree_footer --image "$W/system.img" --partition_name system --partition_size $SYSTEM_PART \
  --hash_algorithm sha256 --do_not_generate_fec --algorithm SHA256_RSA4096 --key "$KEY"

echo "== boot.img (first-stage fstab)"
rm -rf "$W/boot" && mkdir -p "$W/boot/rd"
python3 -I $P/tools/bootimg_v2.py unpack "$L/boot.img" "$W/boot"
lz4 -dc "$W/boot/ramdisk" > "$W/boot/ramdisk.cpio"
(cd "$W/boot/rd" && cpio -idm --quiet < ../ramdisk.cpio)
add_erofs_line "$W/boot/rd/first_stage_ramdisk/system/etc/fstab.qcom"
add_erofs_line "$W/boot/rd/system/etc/recovery.fstab"
(cd "$W/boot/rd" && find . | LC_ALL=C sort | cpio -o -H newc --quiet -R 0:0) > "$W/boot/ramdisk.new.cpio"
lz4 -l -12 -f -q "$W/boot/ramdisk.new.cpio" "$W/boot/ramdisk.new"
python3 -I $P/tools/bootimg_v2.py repack "$L/boot.img" "$W/boot/ramdisk.new" "$W/boot.img"
# ColorOS init (phh legacy-kernel patch) wrongly decides this 4.14 kernel lacks SELinux xperms, caps the policy to v29
# and strips xperms only from system-side CIL; vendor's remain → secilc "policy version 29 does not support extended
# permissions" → init fatal (Phase B build 1, third failure, found with the boot logger). The LineageOS kernel reports
# policyvers 31 and supports xperms; ColorOS init honours ro.boot.selinux_xperms_supported.
python3 -I $P/tools/bootimg_v2.py cmdline "$W/boot.img" "$W/boot.img" androidboot.selinux_xperms_supported=1

echo "== vendor.img (/etc/fstab.qcom)"
cp "$L/payload/vendor.img" "$W/vendor.img"
mkdir -p /mnt/vend && mount -o loop "$W/vendor.img" /mnt/vend
add_erofs_line /mnt/vend/etc/fstab.qcom
ls -lZ /mnt/vend/etc/fstab.qcom; grep -E ' /system ' /mnt/vend/etc/fstab.qcom
# SELinux: init compiles ColorOS system policy + this vendor policy at boot; 3 names clash (Phase B build 1 failure).
python3 -I $P/tools/patch-vendor-sepolicy.py /mnt/vend "$T"
# FBE: `fileencryption=ice` = FSCRYPT_MODE_PRIVATE (Qualcomm legacy); only a vold with the CAF ICE/wrapped-key patches
# can install keys for it. The MediaTek-built PLG110 vold failed with "Failed to install fscrypt key to /data: Invalid
# argument" → enablefilecrypto_failed. "standard" = AOSP policy; the kernel has FS_ENCRYPTION_INLINE_CRYPT and
# BLK_INLINE_ENCRYPTION_FALLBACK. Changing the policy requires a fresh /data (tools/reset-data-keys.sh).
if [ "$FBE_MODE" = standard ]; then
  sed 's/fileencryption=ice,/fileencryption=aes-256-xts:aes-256-cts:v2,/' /mnt/vend/etc/fstab.qcom > /tmp/fstab.new
  cat /tmp/fstab.new > /mnt/vend/etc/fstab.qcom   # in place: `sed -i` replaces the inode and drops the SELinux label
fi
grep ' /data ' /mnt/vend/etc/fstab.qcom | grep -o 'fileencryption=[^,]*' | sort -u
# SoundTrigger: with LineageOS's @2.3 adapter the Qualcomm audio HAL crashes in adev_open →
# audio_extn_sound_trigger_update_battery_status → sound_trigger_hw_call_back (pthread_mutex_lock on a destroyed mutex),
# looping audio.service and taking SurfaceFlinger/system_server down (PLK build 7). Stock H.40 pairs the byte-identical
# 32-bit sound_trigger.primary.msmnile.so with Qualcomm's @2.1 adapter; use that genuine stock adapter + declaration.
# audio.service registers the newest declared/available version (2.3 → 2.0), so the 2.3 adapter must go.
ST_STOCK=/mnt/stockv; mkdir -p $ST_STOCK
mountpoint -q $ST_STOCK || mount -o ro,loop $P/StockRom/H40-images/vendor.img $ST_STOCK
cmp -s $ST_STOCK/lib/hw/sound_trigger.primary.msmnile.so /mnt/vend/lib/hw/sound_trigger.primary.msmnile.so \
  || { echo "sound_trigger.primary.msmnile.so differs from stock: 2.1 adapter pairing not verified"; exit 1; }
STL=$(getfattr -n security.selinux --only-values /mnt/vend/lib/hw/android.hardware.soundtrigger@2.3-impl.so)
install -m 0644 -o root -g root $ST_STOCK/lib/hw/android.hardware.soundtrigger@2.1-impl.so /mnt/vend/lib/hw/
setfattr -n security.selinux -v "$STL" /mnt/vend/lib/hw/android.hardware.soundtrigger@2.1-impl.so
rm -f /mnt/vend/lib/hw/android.hardware.soundtrigger@2.3-impl.so /mnt/vend/lib64/hw/android.hardware.soundtrigger@2.3-impl.so
sed 's|<fqname>@2.3::ISoundTriggerHw/default</fqname>|<fqname>@2.1::ISoundTriggerHw/default</fqname>|' \
  /mnt/vend/etc/vintf/manifest.xml > /tmp/manifest.new
cat /tmp/manifest.new > /mnt/vend/etc/vintf/manifest.xml   # in place: keep the SELinux label
grep -c '@2.1::ISoundTriggerHw/default' /mnt/vend/etc/vintf/manifest.xml
ls -lZ /mnt/vend/lib/hw/ | grep -i soundtrigger
umount $ST_STOCK
bash "$P/tools/patch-soundtrigger.sh" /mnt/vend
# (build 13) The engine also accepts ColorOS 17 SF's SET_LAYER_GENERIC_METADATA (0x40e, length 19, rejected by AOSP ->
# with CUST_LEVEL_LIST features on, build 12 composer aborted "too little data read" -> display stack crash loop) and
# never LOG_FATALs on an under-consumed command. Live-verified: 3 min after a full stack restart, 0 frame failures.
# Composer: AOSP composer@2.4 service built from source (tools/build-hwc.sh, tools/hwc-port/patch-engine.py) against
# this vendor's libs: accepts ColorOS SF's QTI SET_LAYER_TYPE and ORs FOD_PRESSED_LAYER_ZORDER (0x20000000) into the z
# of the layer whose frame = persist.vendor.port.fod_rect (default: the pressed fingerprint icon) → kernel PLANE_CUST=2.
HWC=/mnt/vend/bin/hw/android.hardware.graphics.composer@2.4-service
[ "$(sha256sum < $P/tools/live/hwc/composer-service-port | cut -d' ' -f1)" = c8042313960793a6eafdc4206fe11bdd6994184ae6a7c8d07d5ad75ad695756a ]
cat $P/tools/live/hwc/composer-service-port > "$HWC"   # in place: keep label/mode
# Fingerprint: LineageOS's fingerprint@2.3-service.oplus wrapper hides the Goodix HAL (fps_hal, /odm) from ColorOS
# (no onFingerprintCmd). Retire it so fps_hal registers the 2.x and vendor.oplus 2.1 names itself, as on stock H.40.
rm -f /mnt/vend/etc/init/android.hardware.biometrics.fingerprint@2.3-service.oplus.rc
# Action button position for the gesture app (OplusGestureUI default: /odm/etc/devices_config/sidekey_config.xml, /odm/etc
# -> /vendor/odm/etc): the slider sits on the right edge at 620..790 of a 2376-px reference height (OnePlus 15: left).
ODM_LABEL=$(getfattr -n security.selinux --only-values /mnt/vend/odm/etc)
install -D -m 0644 -o root -g root $P/tools/live/sidekey/sidekey_config.xml /mnt/vend/odm/etc/devices_config/sidekey_config.xml
chmod 0755 /mnt/vend/odm/etc/devices_config
for f in /mnt/vend/odm/etc/devices_config /mnt/vend/odm/etc/devices_config/sidekey_config.xml; do
  setfattr -n security.selinux -v "$ODM_LABEL" "$f"
done
# Camcorder profiles: libmedia reads the plural ro.media.xml_variant.profiles property. The singular spelling
# used through build 15 is ignored; without the variant H.40 video reports "camera 0 quality 6 not found".
# With _vendor loaded at framework startup, the app advances past profile selection (later HAL crash unresolved).
sed -i '/^ro.media.xml_variant.profile=/d; /^ro.media.xml_variant.profiles=/d' /mnt/vend/build.prop
printf '\n# OnePlus7Port: camcorder profiles\nro.media.xml_variant.profiles=_vendor\n' >> /mnt/vend/build.prop
# OpenCamera AAC: this port uses the LOS24 Codec2-only media stack (OMX service disabled). ColorOS defaults
# vendor.audio.hw.aac.encoder=true and its Oplus recorder requests the missing OMX.qcom AAC component. The live
# build 15 A/B test passed with this false, routing AAC creation through c2.android.aac.encoder.
sed -i '/^vendor\.audio\.hw\.aac\.encoder=/d' /mnt/vend/build.prop
printf '\n# OnePlus7Port: AAC through Codec2 on the LOS24 base\nvendor.audio.hw.aac.encoder=false\n' >> /mnt/vend/build.prop
# H.40 stock camera video: the EIS node (com.oneplus.node.eis.so -> libvidhance) SIGSEGVs in the camera provider as soon
# as recording starts (EisNode enableEIS 1; bad ANativeWindowBuffer incRef inside eglCreateImageKHR). Live build 15 test:
# vendor.vidhance.enabled=0 gives valid 1080p HEVC+AAC recordings and no provider crash. Cost: no vidhance EIS.
sed -i '/^vendor\.vidhance\.enabled=/d' /mnt/vend/build.prop
printf '\n# OnePlus7Port: vidhance EIS crashes the H.40 camera video path\nvendor.vidhance.enabled=0\n' >> /mnt/vend/build.prop
# Ultrasound proximity (Elliptic) thread in the odm audio HAL: audio.primary.msmnile.so receive_sensor_state ->
# ultrasound_apply_param_to_usecase -> ultrasound_extn_start dereferences NULL ([adev+0xbc]) on screen on/off, killing
# android.hardware.audio.service (tombstones 17-25, 2026-10-16/17) -> audioserver restarts, recording fails.
# Build 16 disabled ultra_sound_thread_loop entirely (noultra), which also silenced the main proximity sensor (type 8).
# Build 17 uses the narrower guard patch (live-verified 2026-10-17: type 8 reports, 4 sleep/wake cycles, no tombstones):
# ultrasound_apply_param_to_usecase calls ultrasound_extn_start only when [adev+0xbc] != 0.
AH=/mnt/vend/odm/lib/hw/audio.primary.msmnile.so
AU=$P/tools/live/audio-ultrasound
sha256sum -c --quiet <<SUMS || exit 1
08a20a73c123c793d717f1b8e7078df1b9efb3853753fae7fac269d3a20a829f  $AH
08a20a73c123c793d717f1b8e7078df1b9efb3853753fae7fac269d3a20a829f  $AU/audio.primary.msmnile.so
a76ab72beacd4e2aacc907e0958885f1ca9b2602edea331e65954afa8f072e37  $AU/audio.primary.msmnile.guard.so
SUMS
cat "$AU/audio.primary.msmnile.guard.so" > "$AH"     # keeps owner, mode and label
# Oplus odm services missing from the LOS24 odm (stock H.40; handoff-2026-10-17 §9b, build 17b): charger HAL (Battery Health,
# "getIChargerService fail") and cryptoeng HAL (Find My Device RPMB channel). The stock binaries need two symbols the LOS24 libbase /
# libjsoncpp export differently; their rc LD_PRELOADs libportcompat.so (tools/live/odm-services/compat). Build 17 without it: CANNOT LINK.
# Everything is listed in tools/live/odm-services/install.list; the closure of NEEDED libraries was resolved against this vendor
# + the LLNDK list (only libevent had to come from H.40 system/lib64); preflight re-runs that check on the built images.
OS=$P/tools/live/odm-services
(cd "$OS" && sha256sum -c --quiet SHA256SUMS) || { echo "odm-services sources changed"; exit 1; }
while read -r src dst mode label; do
  case "$src" in ''|\#*) continue;; esac
  [ ! -e "/mnt/vend/odm/$dst" ] || { echo "LOS odm already has $dst"; exit 1; }
  install -D -m "$mode" -o root -g root "$OS/$src" "/mnt/vend/odm/$dst"
  setfattr -n security.selinux -v "u:object_r:$label:s0" "/mnt/vend/odm/$dst"
done < "$OS/install.list"
grep -q 'hal_secure_element_default_exec' /mnt/vend/etc/selinux/vendor_sepolicy.cil || { echo "no hal_secure_element_default_exec type in vendor policy"; exit 1; }
ls -lZ "$HWC"; ls /mnt/vend/etc/init | grep -c fingerprint || true
umount /mnt/vend
e2fsck -fn "$W/vendor.img" > /dev/null && echo "vendor fsck clean"

cp "$W/system.img" "$W/boot.img" "$W/vendor.img" "$OUT/"
# direct I/O: a plain cp of the 5 GB my_stock.img into /mnt/c hit ENOMEM (page cache) in builds 17b/17c
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
dd if="$W/my_stock.img" of="$OUT/my_stock.img" bs=16M oflag=direct status=none
(cd "$OUT" && sha256sum system.img boot.img vendor.img | tee SHA256SUMS)
