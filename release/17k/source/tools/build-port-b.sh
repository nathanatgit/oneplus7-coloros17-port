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
# (BAKE-LIST C1/C1b-fix, baked 2026-11-03) ColorOS 17 donor camera com.oplus.camera 7.006.125 = the live set of
# tools/live/camera-donor17/restore-live.sh (this replaces it; tools/live/camera-donor17/BAKE-NOTES.md). The H.40 OnePlusCamera
# above stays. Sources were pulled from the phone's /data/local/tmp/cos17-cam and match its live mounts byte for byte.
#  - app: /my_product/app/OplusCamera, where the full donor my_product ships it (not priv-app; the 41 JNI libs it needs from
#    /my_product/lib64 are already in this tree, checked below = the live /product/lib64 overlay). APK = p9 (patched classes7/9/12)
#    + zipalign -p 4 + the donor APK's own signing block (tools/transplant-apk-sigblock.py; signer b0a9bbfc, same as the /data
#    install). System-partition APKs are scanned without digest checks, like the transplanted SystemUI/ims/OVoiceManagerService.
#  - SDK v11 + adapter v18 jars in /product/framework, their <library> XML in /system/etc/permissions (the only file the live
#    /system/etc/permissions bind added); persist.camera.override_* defaults in my_product/build.prop.
#  - donor odm etc/camera (1.5 GB: LUTs, models, config/ with op7hw oplus_camera_config, simple2 camera_unit_config,
#    master-filter feature protobuf, SimTool_Master.ini ODT=0 CWCM=0) and 113 donor odm libs (735 MB) do not fit vendor_b
#    (~240 MB free): they go in my_stock.img (/my_stock/port-camera) and 01-port-camera.rc bind-mounts / overlays them at
#    post-fs-data, right after 00-port-mystock.rc mounts /my_stock, before any HAL or zygote starts.
CD=$P/tools/live/camera-donor17
sha256sum -c --quiet <<SUMS || { echo "donor camera sources changed"; exit 1; }
5d38a17594af24737b9a18b96aad7dc1ced35ec87fa2f215fda343de16e38423  $CD/OplusCamera-p9-sys.apk
736d601d616b82b746c62c7e3ae89efba9f512ae65add9d64942d7ea3ef2be2b  $CD/camera-sdk-v11.jar
f6b71fd36935654df17a38c1c1669b2ef38e0dae702ea2197696b2474e917426  $CD/camera-adapter-v18.jar
94ec843860349ce65480bcf9a90f1463b89956247e447a831d2d78e610d2b580  $CD/bake/oneplus7port-camera-unit.xml
SUMS
(cd "$CD/bake" && sha256sum -c --quiet SHA256SUMS) || { echo "camera-donor17/bake tree changed"; exit 1; }
[ "$(cd "$CD/bake" && find odm-camera odm-lib64 -type f | wc -l)" = "$(wc -l < "$CD/bake/SHA256SUMS")" ] || { echo "camera-donor17/bake has files not in SHA256SUMS"; exit 1; }
# the live config choices are what the bake tree carries
sha256sum -c --quiet <<SUMS || { echo "bake odm-camera config is not the live set"; exit 1; }
17eb6a99563d90b8398265b691cd2d6c51c4be2771092a4f4fbe08789eb8095a  $CD/bake/odm-camera/config/oplus_camera_config
2c9ff5c2c52b30d3dd3da1eb9503015559a94f24a1f470b5dedfb5742119d2f4  $CD/bake/odm-camera/config/camera_unit_config
44aa8023f1a57f3f7df73b43ee01ec22c6f4df433ea422a247c8b278001cdc69  $CD/bake/odm-camera/config/camera_unit_feature_config.protobuf
6a252b4d7193879ac85b173276ead926ff2c3d24a2b379d5eea4eb258c897ebf  $CD/bake/odm-camera/basictone/setting/SimTool_Master.ini
SUMS
(cd "$T/my_product/lib64" && sha256sum -c --quiet "$CD/bake/my_product-lib64.SHA256SUMS") || { echo "donor my_product/lib64 lacks the camera JNI libs"; exit 1; }
# 17j-r2: the camera app's linker namespace (product apk, my_product/app) searches /product/lib64, NOT /my_product/lib64, so the
# same 41 libs must also be in /product/lib64 (without them: UnsatisfiedLinkError libCombineLutJni.so not found; live-verified with
# the plib-upper overlay). Copies of the sha-checked donor my_product libs, system_lib_file like the rest of /product/lib64.
while read -r sum name; do
  [ ! -e "$T/product/lib64/$name" ] || { echo "donor product/lib64 already has $name"; exit 1; }
  install -m 0644 -o root -g root "$T/my_product/lib64/$name" "$T/product/lib64/$name"
  setfattr -n security.selinux -v u:object_r:system_lib_file:s0 "$T/product/lib64/$name"
done < "$CD/bake/my_product-lib64.SHA256SUMS"
(cd "$T/product/lib64" && sha256sum -c --quiet "$CD/bake/my_product-lib64.SHA256SUMS") || { echo "product/lib64 camera libs differ"; exit 1; }
OC=$T/my_product/app/OplusCamera
[ ! -e "$OC" ] || { echo "donor tree already has my_product/app/OplusCamera"; exit 1; }
install -d -m 0755 -o root -g root "$OC"
install -m 0644 -o root -g root "$CD/OplusCamera-p9-sys.apk" "$OC/OplusCamera.apk"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$OC"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$OC/OplusCamera.apk"
for j in com.oplus.camera.unit.sdk.jar:camera-sdk-v11.jar com.oplus.camera.unit.sdk.adapter.jar:camera-adapter-v18.jar; do
  [ ! -e "$T/product/framework/${j%%:*}" ] || { echo "donor already has product/framework/${j%%:*}"; exit 1; }
  install -m 0644 -o root -g root "$CD/${j#*:}" "$T/product/framework/${j%%:*}"
  setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/product/framework/${j%%:*}"
done
[ ! -e "$T/system/etc/permissions/oneplus7port-camera-unit.xml" ] || { echo "camera unit library XML already present"; exit 1; }
install -m 0644 -o root -g root "$CD/bake/oneplus7port-camera-unit.xml" "$T/system/etc/permissions/oneplus7port-camera-unit.xml"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/permissions/oneplus7port-camera-unit.xml"
# HDR (HLG) preview off (else the SDR preview is tagged HLG and looks oversaturated). A value already persisted in /data wins.
! grep -q '^persist\.camera\.override_' "$T/my_product/build.prop" || { echo "donor my_product already sets persist.camera.override_*"; exit 1; }
printf '\n# OnePlus7Port: donor camera, no HDR preview (BAKE-LIST C1)\npersist.camera.override_enable=true\npersist.camera.override_preview_hdr_support=false\n' >> "$T/my_product/build.prop"
# my_stock payload (merged image: via $CAMX, copied over the tree with xattrs; donor-only fallback: $T/my_stock directly)
if [ -f "$FULL_STOCK" ]; then MSC=$CAMX/port-camera; else MSC=$T/my_stock/port-camera; fi
[ ! -e "$MSC" ] || { echo "$MSC already exists"; exit 1; }
install -d -m 0755 -o root -g root "$MSC"
cp -r "$CD/bake/odm-camera" "$MSC/odm-camera"
cp -r "$CD/bake/odm-lib64" "$MSC/odm-lib64"
chown -R root:root "$MSC"; find "$MSC" -type d -exec chmod 0755 {} +; find "$MSC" -type f -exec chmod 0644 {} +
setfattr -n security.selinux -v u:object_r:system_file:s0 "$MSC"
find "$MSC/odm-camera" -exec setfattr -n security.selinux -v u:object_r:vendor_configs_file:s0 {} +   # = vendor odm/etc/camera
find "$MSC/odm-lib64" -exec setfattr -n security.selinux -v u:object_r:vendor_file:s0 {} +              # = vendor odm/lib64
# The bind hides vendor's own odm/etc/camera: the bake copy must still carry its 2 files unchanged (checked in the vendor stage too).
printf '%s\n' "# OnePlus7Port: donor camera odm data from /my_stock (build-port-b.sh, BAKE-LIST C1). 01- sorts after 00-port-mystock.rc," \
  "# whose post-fs-data action mounts /my_stock first. Read-only overlay: donor libs (top) over the LOS odm libs." \
  "on post-fs-data" \
  "    mount none /my_stock/port-camera/odm-camera /vendor/odm/etc/camera bind" \
  "    mount overlay overlay /vendor/odm/lib64 ro lowerdir=/my_stock/port-camera/odm-lib64:/vendor/odm/lib64" > "$T/system/etc/init/01-port-camera.rc"
chmod 0644 "$T/system/etc/init/01-port-camera.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/01-port-camera.rc"
PL="$T/system/etc/selinux/plat_sepolicy.cil"   # init may mount on vendor_file dirs already; add vendor_configs_file
grep -q '^(allow init vendor_file (dir (mounton)))' "$PL" || printf '(allow init vendor_file (dir (mounton)))\n' >> "$PL"
grep -q '^(allow init vendor_configs_file (dir (mounton)))' "$PL" || printf '(allow init vendor_configs_file (dir (mounton)))\n' >> "$PL"
# (BAKE-LIST B15 item 1, live-verified 2026-11-03) Video live wallpaper busy loop with the screen off: at screen off the stock
# engine prepares the video and seeks to frame 0 (preview), leaving a paused HEVC decoder waiting for output buffers; the SM8150
# vendor codec2 HAL is HIDL c2@1.0 (no SurfaceSyncObj) and polls dequeueBuffer ~92/s forever (hwcodec+mediaserver+wallpaper,
# ~6 % of a core). Patched WallpaperChooser 17.0.18 (classes.dex only, tools/live/power-drain/wallpaper/REPORT.md) releases the
# decoder 1.5 s after that preview and re-prepares on wake. Original signing block kept (system-partition APK, not re-verified).
# The merged image takes it from $CAMX (copied over the tree last; make-mystock-merged.sh drops the stale oat/ for it); the
# donor-only fallback gets it in $T/my_stock directly (the merged script requires $T/my_stock's APKs to be unmodified).
WPC=$P/tools/live/power-drain/wallpaper/WallpaperChooser-portwp.apk
[ "$(sha256sum < $WPC | cut -d' ' -f1)" = c6a0d13162f30360b1bffd177d4916fdef5dcf3224659e79d1662e7805f218e1 ] || { echo "patched WallpaperChooser sha"; exit 1; }
[ "$(sha256sum < $T/my_stock/app/WallpaperChooser/WallpaperChooser.apk | cut -d' ' -f1)" = 0b78c1b23bfc3304ac0123578daeb10b97064226207ed07644ea1aff1a288f11 ] || { echo "donor WallpaperChooser.apk changed: redo the B15 wallpaper patch"; exit 1; }
if [ -f "$FULL_STOCK" ]; then WPD=$CAMX/app/WallpaperChooser; install -d -m 0755 -o root -g root "$WPD"
else WPD=$T/my_stock/app/WallpaperChooser; rm -rf "$WPD/oat"; fi
install -m 0644 -o root -g root "$WPC" "$WPD/WallpaperChooser.apk"
[ -f "$FULL_STOCK" ] && setfattr -n security.selinux -v u:object_r:system_file:s0 "$CAMX/app"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$WPD" "$WPD/WallpaperChooser.apk"
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
# Proximity (type 8) through IR only while the display is off (live-verified 2026-10-18; tools/live/BAKE-LIST.md §1,
# tools/live/sensors-re/README.md). The vendor sensors HAL (patched sensors.ssc.so, see the vendor stage) reads its "audio state" from the
# FIFO /data/vendor/aus (4-byte ints). port_prox_feeder (tools/live/screen-state-feed/ScreenStateFeeder.java, root app_process) writes
# 0 = display off (HAL picks IR) / 8 = display on or AOD (HAL uses no IR, so the under-screen emitter does not blink). The FIFO must exist
# before the HAL starts and have a permanent writer, else its reader thread dies at start or busy-spins on EOF: port_prox_fifo creates it at
# post-fs-data and holds a read-write fd forever. The feeder starts after boot and init restarts it if it ever dies.
# (BAKE-LIST B15, live-verified 2026-11-03) Event-driven feeder: DisplayManager.DisplayListener instead of a 150 ms Display.getState()
# poll (binder call into system_server ~6.7x/s, also screen off); last value re-sent every 30 s. Poll build kept as ssfeed.dex.poll150 (3824ac2b…).
PF=$P/tools/live/screen-state-feed
[ "$(sha256sum < $PF/ssfeed.dex | cut -d' ' -f1)" = af275ed36c6c9dc26cbb6ba234ed5bba03e3d2db22f93152858c931dd91a8c49 ] || { echo "ssfeed.dex sha"; exit 1; }
install -m 0644 -o root -g root $PF/ssfeed.dex "$T/system/framework/oplus-port-proxfeed.dex"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/framework/oplus-port-proxfeed.dex"
printf '%s\n' "# OnePlus7Port: IR proximity only while the display is off (build-port-b.sh, tools/live/BAKE-LIST.md §1)" \
  'service port_prox_fifo /system/bin/sh -c "while [ ! -d /data/vendor ]; do sleep 1; done; [ -p /data/vendor/aus ] || mkfifo /data/vendor/aus; chmod 0666 /data/vendor/aus; exec 3<>/data/vendor/aus; while :; do sleep 3600; done"' \
  "    user root" \
  "    group root" \
  "    seclabel u:r:su:s0" \
  "    disabled" \
  "" \
  "on post-fs-data" \
  "    start port_prox_fifo" \
  "" \
  "service port_prox_feeder /system/bin/app_process /system/bin ScreenStateFeeder" \
  "    user root" \
  "    group root" \
  "    setenv CLASSPATH /system/framework/oplus-port-proxfeed.dex" \
  "    seclabel u:r:su:s0" \
  "    disabled" \
  "" \
  "on property:sys.boot_completed=1" \
  "    start port_prox_feeder" > "$T/system/etc/init/00-port-proxfeed.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-proxfeed.rc"
# (build 17g) Items B1-B3 of tools/live/BAKE-LIST.md.
# B3 Google Play Store placeholder: the donors (OnePlus 8 phb110 and OnePlus 15 full update) ship the genuine Google-signed Play Store 22.7.54
# as /my_product/priv-app/GooglePlayServicesUpdater (cert f0fd6c5b..., privapp allowlist already in my_product). Our donor tree lacks it, so
# the OPPO market installed Play Store as a plain user app that crashed (MANAGE_USERS). As a product priv-app the market's build is an update.
GP=$P/tools/live/playstore/GooglePlayServicesUpdater.apk
[ "$(sha256sum < $GP | cut -d' ' -f1)" = d31ceb5db0cd3560cb71246f466ce286baffd14993100ce1e075561738812e9f ] || { echo "GooglePlayServicesUpdater.apk sha"; exit 1; }
[ ! -e "$T/my_product/priv-app/GooglePlayServicesUpdater" ] || { echo "donor already has GooglePlayServicesUpdater"; exit 1; }
install -d -m 0755 -o root -g root "$T/my_product/priv-app/GooglePlayServicesUpdater"
install -m 0644 -o root -g root $GP "$T/my_product/priv-app/GooglePlayServicesUpdater/GooglePlayServicesUpdater.apk"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/my_product/priv-app/GooglePlayServicesUpdater" "$T/my_product/priv-app/GooglePlayServicesUpdater/GooglePlayServicesUpdater.apk" 2>/dev/null \
  || { for f in "$T/my_product/priv-app/GooglePlayServicesUpdater" "$T/my_product/priv-app/GooglePlayServicesUpdater/GooglePlayServicesUpdater.apk"; do setfattr -n security.selinux -v u:object_r:system_file:s0 "$f"; done; }
# B1 low-flicker options -> panel DC backlight: patched option text (same-size arsc edit) + DcBridge service.
EP=$T/system_ext/app/OplusEyeProtect/OplusEyeProtect.apk
[ "$(sha256sum < $EP | cut -d' ' -f1)" = 28574614ba00e534ed77e99c1ba9a72b88c36a08406c55b4a89918a9e1df8145 ] || { echo "OplusEyeProtect.apk donor sha"; exit 1; }
python3 -I $P/tools/patch-eyeprotect-strings.py $EP "$W/OplusEyeProtect.patched.apk"
[ "$(sha256sum < $W/OplusEyeProtect.patched.apk | cut -d' ' -f1)" = 17a83bdfdfa2fa9ff558dbb16cea5154e7c97de9672379612fa1a426c6457646 ] || { echo "patched OplusEyeProtect sha"; exit 1; }
cat "$W/OplusEyeProtect.patched.apk" > $EP   # in place: keeps owner/mode/SELinux label
DB=$P/tools/live/display-dc
# (B10, 2026-11-03) DcBridge also pins min_refresh_rate = peak while DC is on (was 1ce3c71e…, kept as tools/live/display-dc/dcbridge.dex.b1)
[ "$(sha256sum < $DB/dcbridge.dex | cut -d' ' -f1)" = 44ef9e2c30d70373f09ae142ad29a6d07d4124ed08488e33a4a70f5a4a8e952b ] || { echo "dcbridge.dex sha"; exit 1; }
install -m 0644 -o root -g root $DB/dcbridge.dex "$T/system/framework/oplus-port-dcbridge.dex"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/framework/oplus-port-dcbridge.dex"
printf '%s\n' "# OnePlus7Port: low-flicker option 2 -> kernel dimlayer_bl_en (DcBridge.java, tools/live/BAKE-LIST.md B1)" \
  "service port_dc_bridge /system/bin/app_process /system/bin DcBridge" \
  "    user root" \
  "    group root" \
  "    setenv CLASSPATH /system/framework/oplus-port-dcbridge.dex" \
  "    seclabel u:r:su:s0" \
  "    disabled" \
  "" \
  "on property:sys.boot_completed=1" \
  "    start port_dc_bridge" > "$T/system/etc/init/00-port-dcbridge.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-dcbridge.rc"
# B2 memory extension (nandswap) workaround for the LineageOS kernel: swap file on /data, see tools/live/nandswap/port-nandswap.sh.
NS=$P/tools/live/nandswap/port-nandswap.sh
[ "$(sha256sum < $NS | cut -d' ' -f1)" = 9979c1feaf2182e03087627a7af1a665ef99380025dd8e02be4f9bba9dc3530a ] || { echo "port-nandswap.sh sha"; exit 1; }
! grep -q $'\r' $NS || { echo "port-nandswap.sh has CRLF"; exit 1; }
install -m 0755 -o root -g root $NS "$T/system/bin/port-nandswap.sh"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/bin/port-nandswap.sh"
printf '%s\n' "# OnePlus7Port: ColorOS memory extension (tools/live/BAKE-LIST.md B2); the stock script races this one at boot, hence the delay" \
  "service port_nandswap /system/bin/sh -c \"sleep 5; /system/bin/port-nandswap.sh\"" \
  "    user root" \
  "    group root" \
  "    seclabel u:r:su:s0" \
  "    oneshot" \
  "    disabled" \
  "" \
  "on property:persist.sys.oplus.nandswap=*" \
  "    start port_nandswap" \
  "" \
  "on property:persist.sys.oplus.nandswap.swapsize=*" \
  "    start port_nandswap" \
  "" \
  "on property:sys.boot_completed=1" \
  "    start port_nandswap" > "$T/system/etc/init/00-port-nandswap.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-nandswap.rc"
# (build 17g) Battery level/voltage/temperature lag: android.hardware.health-service.qti ignores the kernel's 5 s battery uevents (it only
# refreshes on plug events and its periodic timer, 600 s while unplugged), so the level stayed stale for minutes with the screen off until a
# screen cycle forced an update. IHealth::update() (AIDL transaction 3) refreshes and notifies BatteryService; poke it every 20 s
# (live-verified 2026-10-25: each call updates BatteryService voltage; tools/live/BAKE-LIST.md B4).
printf '%s\n' "# OnePlus7Port: keep BatteryService fresh while unplugged (build-port-b.sh, BAKE-LIST B4)" \
  'service port_health_poke /system/bin/sh -c "while :; do /system/bin/service call android.hardware.health.IHealth/default 3 >/dev/null 2>&1; sleep 20; done"' \
  "    user root" \
  "    group root" \
  "    seclabel u:r:su:s0" \
  "    disabled" \
  "" \
  "on property:sys.boot_completed=1" \
  "    start port_health_poke" > "$T/system/etc/init/00-port-health-poke.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-health-poke.rc"
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
# 17j-r2 (production boot): oplus-services.jar OplusEngineerFwService.getEngineerService() blocks in waitForService on the
# non-existent vendor.oplus.hardware.engineer.IEngineer HAL whenever ro.adb.secure=1 (isRootVersion() false) -> system_server
# watchdog bootloop. tools/patch-oplus-services-engineer.py makes that call site use the non-blocking getService path
# (ro.adb.secure stays 1 in production). Same patch in the dev image (no behaviour change there: isRootVersion() is true).
# Prebuilt odex/vdex/art belong to the old dex: drop them like for services.jar.
need_sha "$T/system/framework/oplus-services.jar" 0c99f1f7f55be9908eefca6eb02e28dd4eee01c5542b7ea714a6ebdaddc96319
python3 -I $P/tools/patch-oplus-services-engineer.py "$T/system/framework/oplus-services.jar" "$W/oplus-services-engineer.jar"
replace_file "$T/system/framework/oplus-services.jar" "$W/oplus-services-engineer.jar"
rm -f "$T"/system/framework/oat/*/oplus-services.{odex,vdex,art}{,.fsv_meta}
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
# Device code shown in About phone (the grey chip next to the phone name = OplusDeviceInfoUtils.getDeviceModel() = Build.MODEL)
# PLK110 -> GM1910: only ro.product.model changes (Build.MODEL is read when zygote starts, so it shows after a reboot);
# ro.product.name/device, the vendor/odm model props and the fingerprints stay. If a ColorOS feature that keys on the model
# name misbehaves, revert this line.
grep -qx 'ro.product.model=PLK110' "$T/my_manifest/build.prop" || { echo "ro.product.model not PLK110 in donor my_manifest"; exit 1; }
sed -i 's/^ro\.product\.model=PLK110$/ro.product.model=GM1910/' "$T/my_manifest/build.prop"
# Identity (B17, tools/live/prop-compare/IDENTITY.md "safe to switch", user-approved 2026-11-03): display-only OnePlus 7 Pro
# values from H.40 odm/build.prop. Kept donor: fingerprints, security patch, OTA/version keys, prjname (device/name/build.product:
# switched since 17j, see the B17 test-key loop below).
for kv in ro.product.bootimage.model=PLK110:GM1910 ro.product.bootimage.name=PLK110:OnePlus7Pro_CH ro.product.bootimage.device=OP60FFL1:OnePlus7Pro; do
  k=${kv%%=*}; v=${kv#*=}; old=${v%%:*}; new=${v#*:}
  grep -qx "$k=$old" "$T/my_manifest/build.prop" || { echo "$k not $old in donor my_manifest"; exit 1; }
  sed -i "s/^$k=$old\$/$k=$new/" "$T/my_manifest/build.prop"
done
grep -qx 'ro.product.authentication=25C44PC2W477' "$T/my_product/build.prop" || { echo "authentication changed in donor my_product"; exit 1; }
sed -i 's/^ro\.product\.authentication=25C44PC2W477$/ro.product.authentication=2018CP7481/' "$T/my_product/build.prop"
# (B17 test keys, build 17j) IDENTITY.md "test first" keys, live-tested 2026-11-03 on 17i as a "# OnePlus7Port B17-test" block in
# /vendor/build.prop (camera photo OK, apps open): Build.DEVICE / Build.PRODUCT / ro.build.product = the H.40 values. Baked here in
# my_manifest (where the donor sets them), NOT in vendor: the vendor flash drops the live block. The camera HAL reads
# ro.build.product (GM1910 on H.40), libarcsoft_portrait_distortion_correction ro.product.device. Revert: drop these three.
for kv in ro.product.device=OP60FFL1:OnePlus7Pro ro.product.name=PLK110:OnePlus7Pro_CH ro.build.product=PLK110:GM1910; do
  k=${kv%%=*}; v=${kv#*=}; old=${v%%:*}; new=${v#*:}
  [ "$(grep -c "^$(printf '%s' "$k" | sed 's/\./\\./g')=" "$T/my_manifest/build.prop")" = 1 ] || { echo "$k not set exactly once in donor my_manifest"; exit 1; }
  grep -qx "$k=$old" "$T/my_manifest/build.prop" || { echo "$k not $old in donor my_manifest"; exit 1; }
  sed -i "s/^$k=$old\$/$k=$new/" "$T/my_manifest/build.prop"
done
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
# (build 17h) Incoming SMS fix (BAKE-LIST §B "Incoming SMS / IMS regression after 17g", user-verified live 2026-10-18): the 17g APK
# (470b8c12…) was skipped by PackageManager (resources.arsc not 4-byte aligned, R+ target) and, once aligned, the LOS app crashed on the
# donor oplus-ims-ext.jar factory (getImsServiceSub need +2 params). ims-sms-fix-cossig.apk = zipalign -f 4 BEFORE the signing-block
# transplant + OplusImsFactory.getInstance() using its own base factory (tools/live/ims/los/sms-fix-smali/). zipalign -c 4 verified.
I=$P/tools/live/ims
sha256sum -c --quiet <<SUMS || exit 1
93c199d707cd6dd908b82e3d24d7aa3bdc15f28aa858aae9b9b14c362ca1f48c  $T/system_ext/priv-app/ims/ims.apk
2d0231984a8b68c24f312f5b3ee227354e5cc706371476eff5cf67d892e8c3c0  $T/product/etc/permissions/ims_ext_common.xml
296bc757dc9d99373c815c594529494a72e79859baa5ddabb25ada296f18acbf  $I/los/ims-sms-fix-cossig.apk
a0e3a93431cdc272374fe3b3c47654f27f1b0a4d97cf0eafb7082f66d994a5c9  $I/ims_ext_common.xml
96101b310219f1ce1c4f52c3f5fadd1a609aec7128a06d8a8811bd05540d7902  $I/los/lib-arm64/libimsmedia_jni.so
c34698971641c9536e50ab69b9225ed97954f0c57f641d31e56537e414813177  $I/los/lib-arm64/libimscamera_jni.so
SUMS
python3 -I - "$I/los/ims-sms-fix-cossig.apk" <<'PY' || { echo "ims.apk resources.arsc not stored/4-aligned"; exit 1; }
import sys, zipfile, struct
z = zipfile.ZipFile(sys.argv[1]); i = z.getinfo('resources.arsc'); f = open(sys.argv[1], 'rb'); f.seek(i.header_offset)
h = f.read(30); n, e = struct.unpack('<HH', h[26:30]); off = i.header_offset + 30 + n + e
sys.exit(0 if i.compress_type == 0 and off % 4 == 0 else 1)
PY
cat "$I/los/ims-sms-fix-cossig.apk" > "$T/system_ext/priv-app/ims/ims.apk"     # keeps owner, mode and label
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
# (BAKE-LIST B9, live-verified 2026-11-02) /system_ext/bin/loc_sys_service bridges Qualcomm's AIDL location extras
# (vendor.qti.gnss.ILocAidl*: FLP, geofence, geocoder, debug report) for Qualcomm location apps that are not shipped here; the
# LOS24 vendor only has the HIDL GNSS stack, so it retried ILocAidlGnss/default about 3x per second forever (servicemanager lazy
# start + init control message each time). GPS uses the HIDL GNSS HAL directly. Do not start it.
[ -f "$T/system_ext/etc/init/loc_sys_service.rc" ] || { echo "donor loc_sys_service.rc moved"; exit 1; }
rm -f "$T/system_ext/etc/init/loc_sys_service.rc"
# (BAKE-LIST B12, user request 2026-11-03) Hide Settings > Display & brightness > 注视时不息屏 ("keep on looking" / screen
# attention): the OnePlus 15 has an always-on (AON) front camera; the OnePlus 7 Pro front camera is a motorised pop-up. The
# static overlay aon.frameworkres.overlay.product sets config_adaptive_sleep_available=true (the only gate Settings'
# KeepOnLookingController finds here; no oplus.hardware.aon_enable feature) and config_defaultAttentionService =
# com.aiunit.aon/.AONAttentionService. Without it the entry is hidden and AttentionManagerService has no camera-based service.
[ -f "$T/my_product/overlay/aon.frameworkres.overlay.product.apk" ] || { echo "donor AON framework overlay moved"; exit 1; }
rm -f "$T/my_product/overlay/aon.frameworkres.overlay.product.apk"
# The overlay is not the only gate: my_product com.oplus.oplus-feature.xml declares oplus.hardware.aon_enable (Settings shows the
# entry for it too) and the AON camera features aon_enable / aon_pay_qrcode_enable / aon_phone_enable / aon_phone_mute /
# aon_distance_detection_enable / aon_pose_detection_enable, all built for an always-on front camera. Drop every oplus.*.aon_* feature.
OF="$T/my_product/etc/extension/com.oplus.oplus-feature.xml"
grep -q '<oplus-feature name="oplus.hardware.aon_enable"/>' "$OF" || { echo "donor oplus.hardware.aon_enable feature moved"; exit 1; }
sed -i -E '/^[[:space:]]*<oplus-feature name="oplus\.(hardware|software)\.aon_[a-z_]+"[[:space:]]*\/>[[:space:]]*$/d' "$OF"
! grep -qE 'oplus\.(hardware|software)\.aon_' "$OF" || { echo "AON features left in oplus-feature.xml"; exit 1; }
# (BAKE-LIST B13, user request 2026-11-03) App root checks: the port keeps ro.debuggable=1 / ro.secure=0 for adb root, and OPPO
# Health (SafetyCheck.checkForDangerousProps, via `getprop` output) shows a "device rooted" dialog and closes. /product/bin is first
# on every app's PATH, so a getprop shim there shows app uids ro.debuggable=0 / ro.secure=1; callers of /system/bin/getprop and
# non-app uids get the real values. Independent of the app version.
GP=$P/tools/live/health-root/getprop
[ "$(sha256sum < $GP | cut -d' ' -f1)" = f92f6644530d11d3062d8685fe65bf8c32ec4976dc728b57e6858ecac65ed5b0 ] || { echo "getprop shim sha"; exit 1; }
[ -d "$T/product/bin" ] && [ ! -e "$T/product/bin/getprop" ] || { echo "donor /product/bin changed"; exit 1; }
install -m 0755 -o 0 -g 2000 "$GP" "$T/product/bin/getprop"
setfattr -n security.selinux -v "u:object_r:system_file:s0" "$T/product/bin/getprop"
# (BAKE-LIST B15, live-verified 2026-11-03) Battery: schedtune + IMS rebind loop.
# (a) /dev/stune: the LOS kernel has CONFIG_SCHED_TUNE (BOOSTGROUPS_COUNT 6) and the LOS vendor (powerhint.json, init.target.rc)
# writes /dev/stune/{top-app,camera-daemon}/schedtune.*; LOS mounts it from /system/etc/task_profiles/cgroups_28.json (libprocessgroup
# loads cgroups_<ro.product.first_api_level>.json; 28 here), which ColorOS does not ship -> the power HAL retried every 0.5 s forever.
# Ship LOS's cgroups_28.json, a task_profiles_28.json that keeps ColorOS's cpu actions and adds LOS's schedtune joins
# (make-task-profiles.py; LOS's own file would replace the 11 profiles), and LOS's mkdir/chown block as an early-init rc.
ST=$P/tools/live/stune
sha256sum -c --quiet <<SUMS || exit 1
a928742b8697cd78dece935dfc07238c5bbddde58764210e633c8332b95d5c1c  $T/system/etc/task_profiles.json
18497edda1c81883eac3063708ded1b7deb493c519d6ae320b3048c5e090056c  $ST/cgroups_28.json
ec4614ffdb5fe69b6108b9a66b383918ae24e4d5426d2bc6b20a04f968542d6b  $ST/task_profiles_28.json
593d5b0b42f41071fa3e97236878473da6c311d6e2ed95bb35a93b6409c994ef  $ST/00-port-stune.rc
SUMS
[ ! -e "$T/system/etc/task_profiles" ] && ! grep -q '"schedtune"' "$T/system/etc/cgroups.json" || { echo "donor already has task_profiles/ or a schedtune cgroup"; exit 1; }
install -d -m 0755 -o root -g root "$T/system/etc/task_profiles"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/task_profiles"
install -m 0644 -o root -g root "$ST/cgroups_28.json" "$T/system/etc/task_profiles/cgroups_28.json"
setfattr -n security.selinux -v u:object_r:cgroup_desc_file:s0 "$T/system/etc/task_profiles/cgroups_28.json"
install -m 0644 -o root -g root "$ST/task_profiles_28.json" "$T/system/etc/task_profiles/task_profiles_28.json"
setfattr -n security.selinux -v u:object_r:task_profiles_file:s0 "$T/system/etc/task_profiles/task_profiles_28.json"
install -m 0644 -o root -g root "$ST/00-port-stune.rc" "$T/system/etc/init/00-port-stune.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-stune.rc"
# (b) com.android.phone's ImsRilConnector rebinds org.codeaurora.ims/.ImsRilService every ~0.5 s (the LOS24-based ims.apk returns a
# null binder). Keep that component disabled from a boot_completed one-shot (no-op once disabled; survives a /data wipe).
# Revert on the phone: setprop persist.sys.port.imsrilsvc on; pm enable org.codeaurora.ims/org.codeaurora.ims.ImsRilService
IR=$P/tools/live/ims-rilsvc/00-port-ims-rilsvc.rc
[ "$(sha256sum < $IR | cut -d' ' -f1)" = 2eda53c0af42580fd1b166b339f2c3e3aa91ba2acec7264922e9eb3ad470a9d0 ] || { echo "ims rilsvc rc sha"; exit 1; }
install -m 0644 -o root -g root "$IR" "$T/system/etc/init/00-port-ims-rilsvc.rc"
setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/system/etc/init/00-port-ims-rilsvc.rc"
# (BAKE-LIST B18, build 17j, user-approved) Keep the user's live wallpaper across reboots: ColorOS WMS binds the default (Infiniti1)
# at every boot and rewrites wallpaper_info.xml. port_wp_keep (oneshot, 20 s after boot_completed) re-applies the component saved in
# /data/port/wp/wallpaper-component through IWallpaperManager.setWallpaperComponentChecked (system+lock; oplus-port-wpset.dex, helper
# verified live 2026-11-03); port_wp_save (separate non-oneshot inotifyd service) saves later user changes, never the boot default
# (/dev/.port_wp_ready set by the oneshot + 150 s system_server-uptime guard). No saved file: nothing happens until the user's next
# change (or seed the file by hand). Sources: tools/live/power-drain/wallpaper/keep/ (SHA256SUMS), helper source reapply/proj.
WK=$P/tools/live/power-drain/wallpaper/keep
(cd "$WK" && sha256sum -c --quiet SHA256SUMS) || { echo "wallpaper keep sources changed (B18)"; exit 1; }
sha256sum -c --quiet <<SUMS || { echo "wallpaper keep source shas (B18)"; exit 1; }
ef2826e697224b5f5823cf506472d63ab5de3c39e08103ec3b3c72869560c186  $WK/portwpset.dex
a8e189f128c78f7bbd093931f47d0daa26be4d720d03b43fbe294f3824bf6e6c  $WK/port-wp-keep.sh
12c414ac01ce04e2b34ec96e66e79e9f253270efd0fcfec484f289d173fa10d2  $WK/port-wp-save.sh
7b3e9cf3a0e6d63167ca40bfb9be2f3b24fb4d74a9343c0530ce98b321cba581  $WK/00-port-wpkeep.rc
SUMS
! grep -q $'\r' "$WK/port-wp-keep.sh" "$WK/port-wp-save.sh" "$WK/00-port-wpkeep.rc" || { echo "wallpaper keep sources have CRLF (B18)"; exit 1; }
for f in system/framework/oplus-port-wpset.dex system/bin/port-wp-keep.sh system/bin/port-wp-save.sh system/etc/init/00-port-wpkeep.rc; do
  [ ! -e "$T/$f" ] || { echo "donor already has $f"; exit 1; }
done
[ -e "$T/system/bin/inotifyd" ] || { echo "donor has no /system/bin/inotifyd (B18 watcher)"; exit 1; }
install -m 0644 -o root -g root "$WK/portwpset.dex" "$T/system/framework/oplus-port-wpset.dex"
install -m 0755 -o 0 -g 2000 "$WK/port-wp-keep.sh" "$T/system/bin/port-wp-keep.sh"
install -m 0755 -o 0 -g 2000 "$WK/port-wp-save.sh" "$T/system/bin/port-wp-save.sh"
install -m 0644 -o root -g root "$WK/00-port-wpkeep.rc" "$T/system/etc/init/00-port-wpkeep.rc"
for f in system/framework/oplus-port-wpset.dex system/bin/port-wp-keep.sh system/bin/port-wp-save.sh system/etc/init/00-port-wpkeep.rc; do
  setfattr -n security.selinux -v u:object_r:system_file:s0 "$T/$f"
done
# (c) port-colormode.sh (odm, from tools/live/odm-services, see the vendor stage) now watches the settings dir with inotifyd instead of
# reading the whole logcat (live-verified 2026-11-03; sha in odm-services/SHA256SUMS).
# (BAKE-LIST B10) ColorOS VRR's OTI director in SurfaceFlinger drops to 60 Hz on idle regardless of DisplayManager's range; every
# switch shows one undimmed frame with DC dimming on this kernel. Default it off (Android's own idle timer still idles to 60 Hz
# when DC is off; DcBridge pins 90 Hz while DC is on). A value already persisted in /data wins over this default.
grep -qx 'persist.oplus.display.vrr=1' "$T/my_product/build.prop" || { echo "donor persist.oplus.display.vrr line changed"; exit 1; }
sed -i 's/^persist\.oplus\.display\.vrr=1$/persist.oplus.display.vrr=0/' "$T/my_product/build.prop"
# OMAPI for Wallet "Se Service Connection Error" (handoff-2026-10-17 §9b): the donor has no com.android.se, only the overlay
# SecureElementResTarget_Vendor. Use the LOS24 build (targetSdk 37 = this Android; it registers "secure_element" and, with the
# secure_element_vintf_enabled resource, android.se.omapi.ISecureElementService/default). The H.40 one is Android 12, binds by intent
# and needs the H.40 com.vendor.nfc library. It reaches the SIM1/SIM2 secure_element HALs of the LOS vendor; the eSE (stock
# android.hardware.secure_elementnq330 HAL) is shipped since 17d and needs the CONFIG_NFC_P73_ESE kernel + corrected eSE power GPIO (handoff §12).
# (17h+, live-verified 2026-10-30, BAKE-LIST B7) The LOS24 APK (78a219c9…) requests only INTERACT_ACROSS_USERS_FULL (signature: denied,
# LOS platform key) and crash-looped every ~20 s without a SIM (Terminal.sendStateChangedBroadcast -> sendBroadcastAsUser(CURRENT)).
# SecureElement-iau.apk = same APK + <uses-permission INTERACT_ACROSS_USERS> (signature|privileged; the app is PRIVILEGED), rebuilt with
# apktool 3.0.3, zipalign -p 4, original LOS signing block transplanted (same cert 852a750c, shared uid android.uid.se unchanged).
SE=$P/tools/live/odm-services/app/SecureElement-iau.apk
[ "$(sha256sum < $SE | cut -d' ' -f1)" = 25691543bdcbabbb6dfad199bf842e9d08bebd788ffba8f8b789d7d3c5a8e0e2 ] || { echo "SecureElement apk sha"; exit 1; }
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
# Proximity type 8 (handoff 2026-10-18, tools/live/sensors-re/README.md): the stock sensors HAL picks its proximity source per screen
# state but never learns the state on this kernel, so it falls through to the dead Elliptic ultrasound path and type 8 stays silent.
# sensors.ssc.so.aud (tools/live/sensors-re/make-aud-patch.py) = stock + (1) the audio-state node /dev/audio_ultrasound redirected to the
# FIFO /data/vendor/aus and (2) Proximity::GetUseProximityType reading that audio state instead of the dead screen-state field.
# port_prox_feeder (system rc 00-port-proxfeed.rc) drives it: display off -> IR, on/AOD -> no IR (no visible emitter blink).
SS=/mnt/vend/lib64/sensors.ssc.so
SP=$P/tools/live/sensors-re
sha256sum -c --quiet <<SUMS || exit 1
f52b772de6f438124c9075fb7fcdf5da7dfcaa15551fd6c1a6f9240375b7b7d6  $SS
f52b772de6f438124c9075fb7fcdf5da7dfcaa15551fd6c1a6f9240375b7b7d6  $SP/sensors.ssc.so
3bc45a33f1ebc810814237f2fd09fd2d37bad7535de44dde86a446c91eaeb226  $SP/sensors.ssc.so.aud
SUMS
cat "$SP/sensors.ssc.so.aud" > "$SS"     # in place: keeps owner, mode and label
# Panel feature 217 (smooth transition bits: 2 = supported, 1 = doze without panel off), read by port.OplusStubs PanelBinder from
# persist.vendor.port.dpf.<id>. Kept on at the user's request (tools/live/BAKE-LIST.md §2); the lock-to-AOD fade is NOT fixed by it.
sed -i '/^persist\.vendor\.port\.dpf\.217=/d' /mnt/vend/build.prop
printf '\n# OnePlus7Port: display panel feature 217 for ColorOS smooth transition (stub reads this)\npersist.vendor.port.dpf.217=3\n' >> /mnt/vend/build.prop
# (build 17h) Offline charging (BAKE-LIST B5, user-verified live 2026-10-29): quickboot's Config::getResPath() defaults to
# system_ext/etc/media/quickboot/op818/ for prjname 18821; the donor has the images flat in that folder, so the first image load
# failed, quickboot SIGSEGV'd and its handler powered off (dead battery + cable -> ~40 s loop, static logo, no charging).
[ -f "$T/system_ext/etc/media/quickboot/boot_charger_01.png" ] || { echo "donor quickboot images moved"; exit 1; }
sed -i '/^ro\.qboot\.res\.path=/d' /mnt/vend/build.prop
printf '\n# OnePlus7Port: offline-charging UI images (quickboot defaults to the missing op818/ folder for prjname 18821, crashes and powers off)\nro.qboot.res.path=/system_ext/etc/media/quickboot/\n' >> /mnt/vend/build.prop
# (BAKE-LIST B14, live-tested 2026-11-03) Camera provider SIGPIPE: with the donor camera app a provider thread sometimes writes to
# one of the provider's own pipes after its read end closed; SIGPIPE's default action killed the whole provider (no tombstone)
# and the app with it, at capture or at open. Start it with SIGPIPE ignored (kept across exec), same domain via seclabel.
CR=/mnt/vend/etc/init/android.hardware.camera.provider@2.4-service_64.rc
[ "$(sha256sum < $CR | cut -d' ' -f1)" = a2b7392048e2bfd145955948ae6e6a4a29dccb99a9809e6cd1c2aa5ffffe9aef ] || { echo "LOS camera provider rc changed"; exit 1; }
CRN=$P/tools/live/camera-sigpipe/android.hardware.camera.provider@2.4-service_64.rc
[ "$(sha256sum < $CRN | cut -d' ' -f1)" = dc250d3eaeac75cef9e6048582da08eac4ce456b655fa145737d86bf0ee729d0 ] || { echo "camera provider rc sha"; exit 1; }
cat "$CRN" > "$CR"
# (BAKE-LIST C1) 01-port-camera.rc bind-mounts the donor odm/etc/camera over this dir: it must keep the LOS files it hides.
for f in $(ls -A /mnt/vend/odm/etc/camera); do
  cmp -s "/mnt/vend/odm/etc/camera/$f" "$CD/bake/odm-camera/$f" || { echo "vendor odm/etc/camera/$f not in the camera bake copy"; exit 1; }
done
# (BAKE-LIST B10, user-verified 2026-11-03) DC-dimming flicker: the LOS kernel skips the dim layer on the frame of every refresh-rate
# switch ("do not config dimlayer at the fps switch"), so with DC on (backlight held at 260) each 60<->90 Hz switch flashed an undimmed
# frame. One of the three switchers is Qualcomm's display-HAL idle drop (enable_optimize_refresh); the others are ColorOS VRR
# (persist.oplus.display.vrr, my_product) and Android's idle timer, which DcBridge pins out while DC is on.
grep -qx 'vendor.display.enable_optimize_refresh=1' /mnt/vend/build.prop || { echo "LOS vendor enable_optimize_refresh line changed"; exit 1; }
sed -i 's/^vendor\.display\.enable_optimize_refresh=1$/vendor.display.enable_optimize_refresh=0/' /mnt/vend/build.prop
# (BAKE-LIST B16, live-verified after reboot 2026-11-03 on vendor_b) H.40 / ColorOS props, REPORT.md
# (tools/live/prop-compare) section 3 items 2-9: density 600 + H.40 screenzoom, H.40 dalvik heap, confidential/allnet, mag_filter,
# OnePlus default sounds, keystore_desede + cuptsm, LTE RSRP thresholds + no data roaming, media_vol_default 15 + rc.size.
# vendor/build.prop because LOS vendor loads after my_* and wins; product/etc and odm/etc do not set any of these keys (preflight).
# No camera props (ro.camera.notify_nfc left out on purpose). Brightness tables (item 10) are NOT part of this.
B16=$P/tools/live/prop-compare/b16/vendor-build.prop.b16-block
[ "$(sha256sum < $B16 | cut -d' ' -f1)" = 958e8236cb146723c1b2a4ab5666b37f601f1e509175939d2ccd8839956d3dd6 ] || { echo "B16 prop block sha"; exit 1; }
grep -q '^# OnePlus7Port B16' /mnt/vend/build.prop && { echo "B16 block already in vendor build.prop"; exit 1; }
for k in $(grep -v '^#' "$B16" | grep '=' | cut -d= -f1); do
  sed -i "/^$(printf '%s' "$k" | sed 's/\./\\./g')=/d" /mnt/vend/build.prop
done
cat "$B16" >> /mnt/vend/build.prop
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
