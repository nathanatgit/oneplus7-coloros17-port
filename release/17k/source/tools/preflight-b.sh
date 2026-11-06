#!/usr/bin/env bash
# Pre-flash checks for out-b/ (run as root in WSL). Each line is a known boot-fatal class in cross-vendor ports.
export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=/mnt/c/Users/Han/Project/OnePlus7Port; O=${OUT:-$P/out-b}
S=/mnt/pf-sys; V=/mnt/pf-vendor
mkdir -p $S $V
mount -o ro,loop -t erofs $O/system.img $S && mount -o ro,loop $O/vendor.img $V || exit 1
ok=1
echo "== first-stage fstab erofs line (boot ramdisk)"
python3 -I $P/tools/bootimg_v2.py unpack $O/boot.img /tmp >/dev/null
lz4 -dc /tmp/ramdisk | cpio -i --quiet --to-stdout first_stage_ramdisk/system/etc/fstab.qcom | grep -c ' /system .*erofs' || ok=0
echo "== vendor fstab erofs line"; grep -c ' /system .*erofs' $V/etc/fstab.qcom || ok=0
echo "== vendor fstab label (sed -i once dropped it)"; getfattr -n security.selinux --only-values $V/etc/fstab.qcom; echo
getfattr -n security.selinux --only-values $V/etc/fstab.qcom 2>/dev/null | grep -q vendor_configs_file || ok=0
echo "== SoundTrigger: stock @2.1 adapter only, declared as 2.1"
ls $V/lib/hw $V/lib64/hw 2>/dev/null | grep -i 'soundtrigger@' | sort -u
[ -f $V/lib/hw/android.hardware.soundtrigger@2.1-impl.so ] || { echo "2.1 adapter missing"; ok=0; }
ls $V/lib/hw $V/lib64/hw 2>/dev/null | grep -q 'soundtrigger@2.3-impl' && { echo "2.3 adapter still present"; ok=0; }
grep -q '@2.1::ISoundTriggerHw/default' $V/etc/vintf/manifest.xml || { echo "manifest not 2.1"; ok=0; }
getfattr -n security.selinux --only-values $V/etc/vintf/manifest.xml; echo
echo "== /data encryption option"; grep ' /data ' $V/etc/fstab.qcom | grep -o 'fileencryption=[^,]*' | sort -u
echo "== split sepolicy compile (init args)"; bash $P/tools/sepolicy-compile-test.sh $S $V 2>&1 | tail -1 | tee /tmp/pf1; grep -q 'COMPILE OK' /tmp/pf1 || ok=0
echo "== split sepolicy compile as ColorOS init really does it (v29, strips only allowx from plat/system_ext/vendor/odm)"
X=/tmp/pf-x; mkdir -p $X
for f in system/etc/selinux/plat_sepolicy.cil system_ext/etc/selinux/system_ext_sepolicy.cil; do grep -v '^(allowx ' $S/$f > $X/$(basename $f); done
grep -v '^(allowx ' $V/etc/selinux/vendor_sepolicy.cil > $X/vendor_sepolicy.cil
secilc $X/plat_sepolicy.cil -m -M true -G -N -c 29 $S/system/etc/selinux/mapping/202604.cil $X/system_ext_sepolicy.cil \
  $S/product/etc/selinux/product_sepolicy.cil $V/etc/selinux/plat_pub_versioned.cil $X/vendor_sepolicy.cil \
  $S/system/etc/selinux/plat_sepolicy_genfs_202604.cil -o /tmp/pf-pol -f /dev/null > /tmp/pf-v29 2>&1 \
  && echo "V29 COMPILE OK" || { echo "V29 COMPILE FAILED"; tail -2 /tmp/pf-v29; ok=0; }
echo "== sepolicy name conflicts"; python3 -I $P/tools/sepolicy-conflicts.py $S $V 2>&1 | tail -1 | tee /tmp/pf2; grep -q '^0 ' /tmp/pf2 || ok=0
echo "== property_contexts conflicts"; python3 -I $P/tools/propctx-conflicts.py $S $V 2>&1 | tail -1 | tee /tmp/pf3; grep -q '^0 conflicting' /tmp/pf3 || ok=0
echo "== other contexts conflicts"; python3 -I $P/tools/ctx-conflicts.py $S $V | grep '^==' | tee /tmp/pf4; grep -qv ': 0 conflicting' /tmp/pf4 && ok=0
echo "== eBPF loader: ColorOS tethering APEX kept, LineageOS netbpfload bind-mounted over it"
ls $S/system/apex | grep -E 'tethering'; ls $S/system/apex | grep -q 'tethering.capex' && { echo "tethering is a .capex"; ok=0; }
getfattr -n security.selinux --only-values $S/system/etc/port-los-tether/bin/netbpfload 2>/dev/null | grep -q bpfloader_exec || { echo "port netbpfload missing/mislabeled"; ok=0; }
for f in $(grep -o '/system/etc/port-los-tether/[^ ]*' $S/system/etc/init/00-port-netbpfload.rc); do
  [ -e "$S$f" ] || { echo "missing bind source $f"; ok=0; }
done
grep -c 'mount none' $S/system/etc/init/00-port-netbpfload.rc
echo "== live-validated fixes (handoff-2026-10-15 §0d/§0e): exact tested artifacts in place"
sha() { sha256sum < "$1" | cut -d' ' -f1; }
chk() { [ "$(sha "$1")" = "$2" ] && echo "ok  $1" || { echo "BAD $1"; ok=0; }; }
chk $S/system/framework/services.jar 07d07fb31d2e00b3070d377ccc469db8eda227d63a60bf3b92499d95add5e23a
chk $S/system_ext/priv-app/SystemUI/SystemUI.apk c5a79b2a52a3b5324f64eb797a4206ee137fc0ff194e2260fe6275f215a14dbf
chk $V/bin/hw/android.hardware.graphics.composer@2.4-service c8042313960793a6eafdc4206fe11bdd6994184ae6a7c8d07d5ad75ad695756a
chk $S/system/framework/oplus-port-stubs.dex $(sha $P/tools/oplus-stubs/oplus-stubs.dex)
ls $S/system/framework/oat/*/services.odex $S/system_ext/priv-app/SystemUI/oat 2>/dev/null && { echo "stale odex left"; ok=0; }
grep -q 'port.OplusStubs' $S/system/etc/init/00-port-oplus-stubs.rc || { echo "stub rc missing"; ok=0; }
grep -q 'service port_motor_bridge .* port.MotorBridge' $S/system/etc/init/00-port-oplus-stubs.rc || { echo "motor bridge service missing (pop-up camera)"; ok=0; }
grep -q '^(type su)' $S/system/etc/selinux/plat_sepolicy.cil || { echo "no su domain for the stub seclabel"; ok=0; }
[ -e $V/etc/init/android.hardware.biometrics.fingerprint@2.3-service.oplus.rc ] && { echo "LOS fingerprint wrapper rc still present"; ok=0; }
grep -q '^service fps_hal ' $V/odm/etc/init/vendor.oplus.hardware.biometrics.fingerprint@2.1-service.rc || { echo "Goodix fps_hal rc missing"; ok=0; }
grep -qx 'persist.oplus.software.audio.right_volume_key=false' $S/my_product/build.prop || { echo "volume key side not set"; ok=0; }
chk $S/system/usr/keylayout/touchpanel.kl $(sha $P/tools/live/keylayout/touchpanel.kl)
grep -q '^ro.oplus.storage.super_size=[0-9]' $S/system_ext/etc/build.prop || { echo "super_size prop not set (wallpapers getprop crash)"; ok=0; }
# display overlays (handoff-2026-10-16 §0): H.40 oplus corners overlay + donor android overlay with the cutout blanked
[ -e $S/my_product/overlay/oplus_framework_res_overlay.display.product.24831.apk ] && { echo "OnePlus 15 oplus display overlay still present (hole mask)"; ok=0; }
chk $S/my_product/overlay/oplus_framework_res_overlay.display.product.18821.apk 1c2200edd65a8383d402612f11a01e8f0dcf6db5097ba1103bdb7d58b0f4ed2c
chk $S/my_product/overlay/android_framework_res_overlay.display.product.24831.apk 72ffbbddf5a7712e7be6bc1e89683929f9b3ce05b3caadd4870bc302d6b17121
# About phone: H.40 power profile (4065 mAh) and no wireless-charging features
chk $S/my_product/etc/power_profile/power_profile.xml fbe1bffc1e328b9527dac42e321aab0fdcb9554faae425809757e90399f276dc
grep -l -E 'name="(os\.charge\.settings\.wirelesscharg|oplus\.power\.onwirelesscharger|oplus\.power\.wirelesschgwhenwired)' $S/my_product/etc/extension/*.xml && { echo "wireless charging feature still declared"; ok=0; }
grep -qx 'debug.stagefright.ccodec=4' $S/system/build.prop || { echo "ccodec not 4 (HW video decoders dropped)"; ok=0; }
grep -qx 'ro.media.xml_variant.profiles=_vendor' $V/build.prop || { echo "camcorder profile variant missing (plural property)"; ok=0; }
grep -q '^ro.media.xml_variant.profile=' $V/build.prop && { echo "stale singular camcorder profile property"; ok=0; }
grep -qx 'vendor.audio.hw.aac.encoder=false' $V/build.prop || { echo "AAC must use Codec2 on the LOS24 base"; ok=0; }
grep -qx 'vendor.vidhance.enabled=0' $V/build.prop || { echo "vidhance must be off (H.40 camera video provider crash)"; ok=0; }
echo "== calls/SMS/audio fixes (live-verified 2026-10-17)"
grep -qx 'persist.vendor.radio.poweron_opt=0' $S/system_ext/etc/build.prop || { echo "poweron_opt must be 0 (incoming SMS stay buffered in qcrild otherwise)"; ok=0; }
grep -q 'persist.vendor.radio.poweron_opt=1' $S/system_ext/etc/build.prop && { echo "stale poweron_opt=1"; ok=0; }
chk_sha_first() { [ "$(sha256sum "$2" 2>/dev/null | cut -d' ' -f1)" = "$1" ] || { echo "wrong or missing: $2"; ok=0; }; }
grep -qx 'ro.product.model=GM1910' $S/my_manifest/build.prop || { echo "ro.product.model not GM1910 (About chip)"; ok=0; }
for kv in ro.product.bootimage.model=GM1910 ro.product.bootimage.name=OnePlus7Pro_CH ro.product.bootimage.device=OnePlus7Pro; do grep -qx "$kv" $S/my_manifest/build.prop || { echo "identity $kv missing (B17)"; ok=0; }; done
grep -qx 'ro.product.authentication=2018CP7481' $S/my_product/build.prop || { echo "authentication not 2018CP7481 (B17)"; ok=0; }
# (B17 test keys, 17j) device/name/build.product in my_manifest, exactly once, and no other partition overriding them
for kv in ro.product.device=OnePlus7Pro ro.product.name=OnePlus7Pro_CH ro.build.product=GM1910; do
  k=${kv%%=*}
  [ "$(grep -c "^$k=" $S/my_manifest/build.prop)" = 1 ] && grep -qx "$kv" $S/my_manifest/build.prop || { echo "identity $kv not set once in my_manifest (B17)"; ok=0; }
  for f in $S/system/build.prop $S/system_ext/etc/build.prop $S/product/etc/build.prop $S/my_product/build.prop $V/build.prop $V/odm/etc/build.prop; do
    [ -f $f ] && grep -q "^$k=" $f && { echo "identity $k also set in $f (B17)"; ok=0; }
  done
done
grep -q 'B17-test' $V/build.prop && { echo "live B17-test block must not be in the vendor image (B17)"; ok=0; }
grep -qx 'ro.build.display.id.show=GM1910_17.0.0.100(202610171200)' $S/my_manifest/build.prop || { echo "display.id.show not in 7 Pro style"; ok=0; }
if [ "${PROD_PROPS:-0}" = 1 ]; then
  grep -qx 'ro.secure=1' $S/system/build.prop && grep -qx 'ro.debuggable=0' $S/system/build.prop && grep -qx 'ro.adb.secure=1' $S/system/build.prop || { echo "root/ADB properties not production (PROD_PROPS=1 only)"; ok=0; }
  [ ! -e $S/product/etc/security/adb_keys ] || { echo "builder adb key must not ship in PROD_PROPS=1"; ok=0; }
fi
chk_sha_first ae420be14e7dbff8f2c46f2a035749e829cec49a939748d1510ffef40651cf3c $S/system_ext/etc/display_brightness_config_default.xml
chk_sha_first 296bc757dc9d99373c815c594529494a72e79859baa5ddabb25ada296f18acbf $S/system_ext/priv-app/ims/ims.apk   # 17h: SMS-fix APK, zipaligned
chk_sha_first a0e3a93431cdc272374fe3b3c47654f27f1b0a4d97cf0eafb7082f66d994a5c9 $S/product/etc/permissions/ims_ext_common.xml
chk_sha_first 96101b310219f1ce1c4f52c3f5fadd1a609aec7128a06d8a8811bd05540d7902 $S/system_ext/priv-app/ims/lib/arm64/libimsmedia_jni.so
chk_sha_first c34698971641c9536e50ab69b9225ed97954f0c57f641d31e56537e414813177 $S/system_ext/priv-app/ims/lib/arm64/libimscamera_jni.so
[ -d $S/system_ext/priv-app/ims/oat ] && { echo "stale ColorOS oat dir for the replaced ims.apk"; ok=0; }
grep -q 'android.hidl.manager-V1.0-java' $S/product/etc/permissions/ims_ext_common.xml || { echo "ims-ext-common lacks the HIDL manager dependency"; ok=0; }
getfattr -n security.selinux --only-values $S/system_ext/priv-app/ims/lib/arm64/libimsmedia_jni.so | grep -q system_lib_file || { echo "ims jni lib label"; ok=0; }
chk_sha_first a76ab72beacd4e2aacc907e0958885f1ca9b2602edea331e65954afa8f072e37 $V/odm/lib/hw/audio.primary.msmnile.so   # guard patch (build 17); noultra (aeb84cc1…) broke proximity
getfattr -n security.selinux --only-values $S/my_product/etc/power_profile/power_profile.xml | grep -q system_file || { echo "power_profile label"; ok=0; }
[ -e $S/system_ext/etc/init/supersize.rc ] && { echo "supersize.rc still present"; ok=0; }
# light sensor: LOS IAreaCapture service (handoff-2026-10-16 §00)
chk $S/system_ext/bin/hw/vendor.lineage.oplus_als.service 6654a74d56e85c038c64706fcf9646f3c9d87d8a10fbaf5a74b9e9d38da4979b
chk $S/system/lib64/vendor.lineage.oplus_als-V1-ndk.so 23da00307930cb130bcb2d96391647fddd4056f7f0845817008b9b6880f701da
grep -q 'IAreaCapture/default' $S/system_ext/etc/vintf/manifest/vendor.lineage.oplus_als.service.xml || { echo "ALS VINTF fragment missing"; ok=0; }
grep -q 'seclabel u:r:su:s0' $S/system_ext/etc/init/vendor.lineage.oplus_als.service.rc || { echo "ALS rc seclabel missing"; ok=0; }
echo "== build 17: odm services (charger, cryptoeng, secure element), SecureElement app, voice wake-up app + libs"
OS=$P/tools/live/odm-services
while read -r src dst mode label; do
  case "$src" in ''|\#*) continue;; esac
  want=$(awk -v s="$src" '$2==s || $2=="*"s {print $1}' $OS/SHA256SUMS)
  chk_sha_first "$want" $V/odm/$dst
  [ "$(stat -c %a $V/odm/$dst)" = "${mode#0}" ] || { echo "mode of odm/$dst is $(stat -c %a $V/odm/$dst), want $mode"; ok=0; }
  [ "$(getfattr -n security.selinux --only-values $V/odm/$dst 2>/dev/null | tr -d '\0')" = "u:object_r:$label:s0" ] || { echo "label of odm/$dst"; ok=0; }
done < $OS/install.list
python3 -I $P/tools/odm-deps-check.py $V $S | tee /tmp/pf5; grep -q 'all NEEDED libraries resolve' /tmp/pf5 || ok=0
python3 -I $P/tools/odm-symbols-check.py $V $S | tee /tmp/pf6; grep -q 'all symbols resolve' /tmp/pf6 || ok=0   # build 17 failed with 'cannot locate symbol' (Trim, Json::Value::operator=)
python3 -I - $V/odm/etc/vintf/manifest <<'PY' || ok=0
import sys, glob, xml.dom.minidom as md, collections
seen = collections.Counter()
for f in sorted(glob.glob(sys.argv[1] + '/*.xml')):
    d = md.parse(f)     # well-formed or the whole odm manifest fails to load at boot
    for h in d.getElementsByTagName('hal'):
        name = h.getElementsByTagName('name')[0].firstChild.data
        for fq in h.getElementsByTagName('fqname'):
            seen[(name, fq.firstChild.data)] += 1
        for i in h.getElementsByTagName('interface'):
            for inst in i.getElementsByTagName('instance'):
                seen[(name, i.getElementsByTagName('name')[0].firstChild.data, inst.firstChild.data)] += 1
dup = [k for k, v in seen.items() if v > 1]
print('odm vintf fragments parse; duplicate declarations: %s' % dup)
sys.exit(1 if dup else 0)
PY
grep -q 'vendor.oplus.hardware.charger' $V/etc/vintf/manifest.xml $V/etc/vintf/manifest/*.xml && { echo "charger already declared outside the odm fragment"; ok=0; }
grep -q 'vendor.oplus.hardware.cryptoeng' $V/etc/vintf/manifest.xml $V/etc/vintf/manifest/*.xml && { echo "cryptoeng already declared outside the odm fragment"; ok=0; }
for rc in vendor.oplus.hardware.charger@1.0-service vendor.oplus.hardware.cryptoeng@1.0-service; do
  f=$V/odm/etc/init/$rc.rc
  p=$(awk '$1=="service" {print $3}' $f); [ -x $V/odm${p#/odm} ] || { echo "rc $rc: binary $p missing"; ok=0; }
  grep -q 'setenv LD_PRELOAD /odm/lib64/libportcompat.so' $f || { echo "rc $rc: no LD_PRELOAD shim"; ok=0; }
  [ "$(grep -c '^service ' $f)" = 1 ] || { echo "rc $rc: expected one service"; ok=0; }
done
grep -q 'livedisplay.IDisplayModes' $V/odm/bin/port-colormode.sh && grep -q 'service port_colormode' $V/odm/etc/init/port-colormode.rc || { echo "color mode bridge (port-colormode) missing"; ok=0; }
grep -q 'inotifyd - $DIR:w' $V/odm/bin/port-colormode.sh && ! grep -q '^[^#]*logcat' $V/odm/bin/port-colormode.sh || { echo "port-colormode.sh still reads logcat (B15)"; ok=0; }
echo "== B20+B21: charge cap + real gauge (port-chglimit, port-bmslevel)"
for n in chglimit bmslevel; do
  sh_=$V/odm/bin/port-$n.sh; rc_=$V/odm/etc/init/port-$n.rc
  [ -f "$sh_" ] && [ -f "$rc_" ] || { echo "port-$n script/rc missing (B20/B21)"; ok=0; continue; }
  [ "$(stat -c %a $sh_)" = 755 ] && [ "$(stat -c %a $rc_)" = 644 ] || { echo "modes of port-$n (B20/B21)"; ok=0; }
  getfattr -n security.selinux --only-values $sh_ 2>/dev/null | tr -d '\0' | grep -qx 'u:object_r:vendor_file:s0' || { echo "label of port-$n.sh"; ok=0; }
  getfattr -n security.selinux --only-values $rc_ 2>/dev/null | tr -d '\0' | grep -qx 'u:object_r:vendor_configs_file:s0' || { echo "label of port-$n.rc"; ok=0; }
  grep -q $'\r' $sh_ $rc_ && { echo "CRLF in port-$n (B20/B21)"; ok=0; }
  grep -qx "service port_$n /system/bin/sh /odm/bin/port-$n.sh" $rc_ && grep -qx '    seclabel u:r:su:s0' $rc_ && grep -qx '    disabled' $rc_ \
    && grep -qx 'on property:sys.boot_completed=1' $rc_ && grep -qx "    start port_$n" $rc_ || { echo "rc content of port-$n (B20/B21)"; ok=0; }
done
grep -q 'mmi_charging_enable' $V/odm/bin/port-chglimit.sh && grep -q 'bms/capacity' $V/odm/bin/port-chglimit.sh || { echo "port-chglimit.sh content (B20)"; ok=0; }
grep -q 'mount -o bind \$F \$P/battery/capacity' $V/odm/bin/port-bmslevel.sh && grep -q '^F=/dev/port-battery-capacity$' $V/odm/bin/port-bmslevel.sh || { echo "port-bmslevel.sh content (B21)"; ok=0; }
grep -qx '    user root' $V/odm/etc/init/port-bmslevel.rc && grep -qx '    user system' $V/odm/etc/init/port-chglimit.rc || { echo "B20/B21 rc users"; ok=0; }
echo "== B22: restricted_networking_mode guard (port-netguard)"
sh_=$V/odm/bin/port-netguard.sh; rc_=$V/odm/etc/init/port-netguard.rc
if [ -f "$sh_" ] && [ -f "$rc_" ]; then
  [ "$(stat -c %a $sh_)" = 755 ] && [ "$(stat -c %a $rc_)" = 644 ] || { echo "modes of port-netguard (B22)"; ok=0; }
  getfattr -n security.selinux --only-values $sh_ 2>/dev/null | tr -d '\0' | grep -qx 'u:object_r:vendor_file:s0' || { echo "label of port-netguard.sh"; ok=0; }
  getfattr -n security.selinux --only-values $rc_ 2>/dev/null | tr -d '\0' | grep -qx 'u:object_r:vendor_configs_file:s0' || { echo "label of port-netguard.rc"; ok=0; }
  grep -q $'\r' $sh_ $rc_ && { echo "CRLF in port-netguard (B22)"; ok=0; }
  grep -qx "service port_netguard /system/bin/sh /odm/bin/port-netguard.sh" $rc_ && grep -qx '    seclabel u:r:su:s0' $rc_ && grep -qx '    disabled' $rc_ && grep -qx '    oneshot' $rc_ \
    && grep -qx 'on property:sys.boot_completed=1' $rc_ && grep -qx "    start port_netguard" $rc_ || { echo "rc content of port-netguard (B22)"; ok=0; }
  grep -q 'settings get global "\$KEY"' $sh_ && grep -q 'settings put global "\$KEY" 0' $sh_ && grep -qx 'KEY=restricted_networking_mode' $sh_ && grep -qx '#!/system/bin/sh' $sh_ \
    && ! grep -Eq '^[[:space:]]*(while|until|for)[[:space:]]' $sh_ && ! grep -q 'set -e' $sh_ || { echo "port-netguard.sh content (B22: guard logic / must not loop)"; ok=0; }
  [ "$(grep -c '^sleep ' $sh_)" = 3 ] || { echo "port-netguard.sh: expected exactly 3 sleeps (+30/+120/+300 s)"; ok=0; }
else echo "port-netguard script/rc missing (B22)"; ok=0; fi
grep -q 'port.Main' $V/odm/etc/init/port-charger-aidl.rc && grep -q '<version>12</version>' $V/odm/etc/vintf/manifest/manifest_oplus_charger.xml || { echo "AIDL ICharger stub (what ColorOS 17 OplusBatteryServiceFeature looks up) rc/vintf missing"; ok=0; }
grep -qx '    mkdir /data/vendor_de/0/cryptoeng 0770 system system encryption=None' $V/odm/etc/init/vendor.oplus.hardware.cryptoeng@1.0-service.rc || { echo "cryptoeng mkdir line"; ok=0; }
grep -q 'vendor_de 0770\|mkdir /data/vendor_de 0\|mkdir /data/vendor_de/0 ' $V/odm/etc/init/vendor.oplus.hardware.cryptoeng@1.0-service.rc && { echo "cryptoeng rc re-owns /data/vendor_de"; ok=0; }
f=$V/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc
grep -q 'setenv LD_PRELOAD /odm/lib64/libport_shim_trim.so' $f && grep -q 'chown secure_element secure_element /dev/p73' $f && grep -q 'setprop vendor.nfc_se.config_ready true' $f || { echo "SE HAL rc incomplete (shim, /dev/p73, config_ready)"; ok=0; }
for k in 'ISecureElement/eSE1' 'INxpEse/default' 'INxpEseEvtProcessor/default'; do grep -q "$k" $V/odm/etc/vintf/manifest/manifest_port_secure_element.xml || { echo "SE vintf lacks $k (HAL aborts: Could not register service for Power Secure Element Extn Iface)"; ok=0; }; done
grep -q 'android.se.omapi' $V/odm/etc/vintf/manifest/manifest_oplus_charger.xml || { echo "android.se.omapi not declared (com.android.se crash loop)"; ok=0; }
ls $S/system_ext/app/SecureElement/SecureElement.apk >/dev/null || ok=0
grep -rq 'com.android.se' $S/system/etc/init $S/system_ext/etc/init $V/etc/init $V/odm/etc/init 2>/dev/null && { echo "an rc touches com.android.se"; ok=0; }
chk_sha_first 25691543bdcbabbb6dfad199bf842e9d08bebd788ffba8f8b789d7d3c5a8e0e2 $S/system_ext/app/SecureElement/SecureElement.apk   # + INTERACT_ACROSS_USERS (B7)
ls -d $S/system_ext/app/SecureElement/oat 2>/dev/null && { echo "stale oat for SecureElement"; ok=0; }
echo "== build 17c: Breeno wake-up on the H.40 SVA first stage"
BO=$S/my_product/priv-app/OVoiceManagerService
chk_sha_first cd68824e961323f7b2f47b42638150a5f99e236fa79d85e18b65b5fea6f34238 $BO/OVoiceManagerService.apk
unzip -p $BO/OVoiceManagerService.apk 'classes*.dex' | grep -aq svaOpaque || { echo "breeno apk dex lacks svaOpaque"; ok=0; }
python3 -I $P/tools/apk-signer-certs.py $BO/OVoiceManagerService.apk | grep -q b0a9bbfc05eee5e7 || { echo "OVoiceManagerService lost the donor signer b0a9bbfc"; ok=0; }
[ -e $BO/oat ] && { echo "stale oat for OVoiceManagerService"; ok=0; }
for d in $S/my_product/etc $S/my_product/etc/breenospeech2; do
  chk_sha_first 0d1ce62eef5fb551173d563b8c59a26e708a377c5ca4a4268c817b80917d54b9 $d/OVMS_settings.xml
  chk_sha_first b8591733916c56872df3879ba4f733d7d297500e08dd40409454236a106e6371 $d/OVMS_1st_wakeup.bin
  getfattr -n security.selinux --only-values $d/OVMS_settings.xml | tr -d '\0' | grep -q system_file || { echo "label of $d/OVMS_settings.xml"; ok=0; }
done
grep -q '68ab2d40-e860-11e3-95ef-0002a5d5c51b' $S/my_product/etc/OVMS_settings.xml || { echo "OVMS_settings lacks the QTI SVA uuid"; ok=0; }
[ -e $S/system/etc/init/01-port-audio-fix.rc ] && { echo "port_disable_wakeup rc still present (wake service must stay enabled)"; ok=0; }
grep -rq 'disable-user --user 0 com.oplus.ovoicemanager.wakeup' $S/system/etc/init $S/system_ext/etc/init && { echo "something still disables com.oplus.ovoicemanager.wakeup"; ok=0; }
[ -e $S/my_product/priv-app/OVoiceManagerServiceOnePlus ] && { echo "OnePlus voicewakeup app must not be shipped in 17c"; ok=0; }
echo "== build 17f: IR proximity only while the display is off (BAKE-LIST §1/§2)"
chk $V/lib64/sensors.ssc.so 3bc45a33f1ebc810814237f2fd09fd2d37bad7535de44dde86a446c91eaeb226
chk $S/system/framework/oplus-port-proxfeed.dex af275ed36c6c9dc26cbb6ba234ed5bba03e3d2db22f93152858c931dd91a8c49   # event-driven (B15)
f=$S/system/etc/init/00-port-proxfeed.rc
grep -q '^service port_prox_fifo .*mkfifo /data/vendor/aus' $f && grep -q 'exec 3<>/data/vendor/aus' $f && grep -q '^    start port_prox_fifo' $f || { echo "prox FIFO holder service incomplete"; ok=0; }
grep -q '^service port_prox_feeder /system/bin/app_process /system/bin ScreenStateFeeder' $f && grep -q 'setenv CLASSPATH /system/framework/oplus-port-proxfeed.dex' $f && grep -q '^on property:sys.boot_completed=1' $f && grep -q '^    start port_prox_feeder' $f || { echo "prox feeder service incomplete"; ok=0; }
grep -q '^    disabled' $f || { echo "prox services must be disabled until started"; ok=0; }
getfattr -n security.selinux --only-values $f | tr -d '\0' | grep -q system_file || { echo "label of 00-port-proxfeed.rc"; ok=0; }
getfattr -n security.selinux --only-values $V/lib64/sensors.ssc.so | tr -d '\0' | grep -q vendor_file || { echo "label of patched sensors.ssc.so"; ok=0; }
grep -a -q '/data/vendor/aus' $V/lib64/sensors.ssc.so && ! grep -a -q '/dev/audio_ultrasound' $V/lib64/sensors.ssc.so || { echo "sensors.ssc.so path patch not applied"; ok=0; }
grep -qx 'persist.vendor.port.dpf.217=3' $V/build.prop || { echo "dpf.217 prop missing"; ok=0; }
echo "== build 17g: Play Store placeholder, DC bridge + text, nandswap (BAKE-LIST B1-B3)"
GPD=$S/my_product/priv-app/GooglePlayServicesUpdater
chk_sha_first d31ceb5db0cd3560cb71246f466ce286baffd14993100ce1e075561738812e9f $GPD/GooglePlayServicesUpdater.apk
python3 -I $P/tools/apk-signer-certs.py $GPD/GooglePlayServicesUpdater.apk | grep -q f0fd6c5b410f25cb || { echo "Play Store placeholder lost the Google signer"; ok=0; }
getfattr -n security.selinux --only-values $GPD/GooglePlayServicesUpdater.apk | tr -d '\0' | grep -q system_file || { echo "label of Play Store placeholder"; ok=0; }
ls -d $GPD/oat 2>/dev/null && { echo "stale oat for placeholder"; ok=0; }
chk_sha_first 17a83bdfdfa2fa9ff558dbb16cea5154e7c97de9672379612fa1a426c6457646 $S/system_ext/app/OplusEyeProtect/OplusEyeProtect.apk
chk $S/system/framework/oplus-port-dcbridge.dex 44ef9e2c30d70373f09ae142ad29a6d07d4124ed08488e33a4a70f5a4a8e952b
grep -qx 'vendor.display.enable_optimize_refresh=0' $V/build.prop && grep -qx 'persist.oplus.display.vrr=0' $S/my_product/build.prop || { echo "DC flicker refresh-switch fix missing (B10)"; ok=0; }
f=$S/system/etc/init/00-port-dcbridge.rc
grep -q '^service port_dc_bridge /system/bin/app_process /system/bin DcBridge' $f && grep -q 'setenv CLASSPATH /system/framework/oplus-port-dcbridge.dex' $f && grep -q '^    start port_dc_bridge' $f && grep -q '^    disabled' $f || { echo "dc bridge rc incomplete"; ok=0; }
chk $S/system/bin/port-nandswap.sh 9979c1feaf2182e03087627a7af1a665ef99380025dd8e02be4f9bba9dc3530a
f=$S/system/etc/init/00-port-nandswap.rc
grep -q '^service port_nandswap ' $f && grep -q '^on property:persist.sys.oplus.nandswap.swapsize=\*' $f && grep -q '^on property:sys.boot_completed=1' $f && grep -q '^    oneshot' $f || { echo "nandswap rc incomplete"; ok=0; }
for g in $S/system/etc/init/00-port-dcbridge.rc $f $S/system/framework/oplus-port-dcbridge.dex $S/system/bin/port-nandswap.sh; do
  getfattr -n security.selinux --only-values $g | tr -d '\0' | grep -q system_file || { echo "label of $g"; ok=0; }
done
f=$S/system/etc/init/00-port-health-poke.rc
grep -q '^service port_health_poke ' $f && grep -q 'IHealth/default 3' $f && grep -q '^    start port_health_poke' $f && grep -q '^    disabled' $f || { echo "health poke rc incomplete"; ok=0; }
getfattr -n security.selinux --only-values $f | tr -d '\0' | grep -q system_file || { echo "label of health poke rc"; ok=0; }
echo "== build 17h: offline-charging image path, ICharger online getters, IMS APK alignment"
grep -qx 'ro.qboot.res.path=/system_ext/etc/media/quickboot/' $V/build.prop || { echo "ro.qboot.res.path missing (quickboot SIGSEGV loop in power-off charging)"; ok=0; }
[ -f $S/system_ext/etc/media/quickboot/boot_charger_01.png ] || { echo "quickboot images missing at ro.qboot.res.path"; ok=0; }
[ "$(sha256sum < $V/etc/init/android.hardware.camera.provider@2.4-service_64.rc | cut -d' ' -f1)" = dc250d3eaeac75cef9e6048582da08eac4ce456b655fa145737d86bf0ee729d0 ] || { echo "camera provider rc without SIGPIPE ignore (B14)"; ok=0; }
getfattr -n security.selinux --only-values $V/etc/init/android.hardware.camera.provider@2.4-service_64.rc 2>/dev/null | grep -q vendor_configs_file || { echo "camera provider rc label"; ok=0; }
[ "$(sha256sum < $V/odm/lib64/port-charger.dex | cut -d' ' -f1)" = d9a0dce7cadc6e41a66cb6792356077d1c51186fadef86afcb6b7f7739388e7d ] || { echo "port-charger.dex is not the 17h online-getter build"; ok=0; }
python3 -I - $S/system_ext/priv-app/ims/ims.apk <<'PY' || { echo "ims.apk resources.arsc not stored/4-aligned (PackageManager skips it)"; ok=0; }
import sys, zipfile, struct
z = zipfile.ZipFile(sys.argv[1]); i = z.getinfo('resources.arsc'); f = open(sys.argv[1], 'rb'); f.seek(i.header_offset)
h = f.read(30); n, e = struct.unpack('<HH', h[26:30]); off = i.header_offset + 30 + n + e
sys.exit(0 if i.compress_type == 0 and off % 4 == 0 else 1)
PY
[ -e $S/system_ext/etc/init/loc_sys_service.rc ] && { echo "loc_sys_service.rc still shipped (ILocAidlGnss retry loop, B9)"; ok=0; }
[ -e $S/my_product/overlay/aon.frameworkres.overlay.product.apk ] && { echo "AON framework overlay still shipped (keep-on-looking / pop-up camera, B12)"; ok=0; }
grep -qE 'oplus.(hardware|software).aon_' $S/my_product/etc/extension/com.oplus.oplus-feature.xml && { echo "AON features still declared (keep-on-looking / pop-up camera, B12)"; ok=0; }
[ "$(sha256sum < $S/product/bin/getprop | cut -d' ' -f1)" = f92f6644530d11d3062d8685fe65bf8c32ec4976dc728b57e6858ecac65ed5b0 ] || { echo "app getprop shim missing (Health root check, B13)"; ok=0; }
getfattr -n security.selinux --only-values $S/product/bin/getprop 2>/dev/null | grep -q system_file || { echo "getprop shim label"; ok=0; }
# (B15) schedtune for the LOS power HAL + IMS ImsRilService rebind loop
chk $S/system/etc/task_profiles/cgroups_28.json 18497edda1c81883eac3063708ded1b7deb493c519d6ae320b3048c5e090056c
chk $S/system/etc/task_profiles/task_profiles_28.json ec4614ffdb5fe69b6108b9a66b383918ae24e4d5426d2bc6b20a04f968542d6b
chk $S/system/etc/init/00-port-stune.rc 593d5b0b42f41071fa3e97236878473da6c311d6e2ed95bb35a93b6409c994ef
chk $S/system/etc/init/00-port-ims-rilsvc.rc 2eda53c0af42580fd1b166b339f2c3e3aa91ba2acec7264922e9eb3ad470a9d0
getfattr -n security.selinux --only-values $S/system/etc/task_profiles/cgroups_28.json 2>/dev/null | grep -q cgroup_desc_file && getfattr -n security.selinux --only-values $S/system/etc/task_profiles/task_profiles_28.json 2>/dev/null | grep -q task_profiles_file || { echo "task_profiles/ labels (B15)"; ok=0; }
for f in 00-port-stune.rc 00-port-ims-rilsvc.rc; do getfattr -n security.selinux --only-values $S/system/etc/init/$f 2>/dev/null | grep -q system_file || { echo "label of $f (B15)"; ok=0; }; done
python3 -I -c 'import json,sys; [json.load(open(f)) for f in sys.argv[1:]]' $S/system/etc/task_profiles/cgroups_28.json $S/system/etc/task_profiles/task_profiles_28.json || { echo "task_profiles/ json does not parse (B15)"; ok=0; }
grep -qx 'ro.product.first_api_level=28' $V/build.prop || { echo "vendor first_api_level is not 28: libprocessgroup would not load task_profiles/cgroups_28.json (B15)"; ok=0; }
echo "== B18: keep the user's live wallpaper (oneshot re-apply + separate inotifyd saver)"
WK=$P/tools/live/power-drain/wallpaper/keep
chk $S/system/framework/oplus-port-wpset.dex ef2826e697224b5f5823cf506472d63ab5de3c39e08103ec3b3c72869560c186
chk $S/system/bin/port-wp-keep.sh $(sha $WK/port-wp-keep.sh)
chk $S/system/bin/port-wp-save.sh $(sha $WK/port-wp-save.sh)
chk $S/system/etc/init/00-port-wpkeep.rc $(sha $WK/00-port-wpkeep.rc)
for g in system/framework/oplus-port-wpset.dex system/bin/port-wp-keep.sh system/bin/port-wp-save.sh system/etc/init/00-port-wpkeep.rc; do
  getfattr -n security.selinux --only-values $S/$g 2>/dev/null | tr -d '\0' | grep -q 'object_r:system_file:' || { echo "label of $g (B18)"; ok=0; }
done
[ "$(stat -c %a $S/system/bin/port-wp-keep.sh)" = 755 ] && [ "$(stat -c %a $S/system/bin/port-wp-save.sh)" = 755 ] && [ "$(stat -c %a $S/system/framework/oplus-port-wpset.dex)" = 644 ] || { echo "modes of the B18 scripts/dex"; ok=0; }
grep -q $'\r' $S/system/bin/port-wp-keep.sh $S/system/bin/port-wp-save.sh $S/system/etc/init/00-port-wpkeep.rc && { echo "CRLF in B18 files"; ok=0; }
grep -q '/data/system/users/0:wmny$' $S/system/etc/init/00-port-wpkeep.rc && grep -q "SET_STATIC" $S/system/bin/port-wp-save.sh && grep -q 'rm -f $S/wallpaper-component' $S/system/bin/port-wp-save.sh || { echo "B18 saver: inotify mask lacks y (moved-to) or static-wallpaper removal missing"; ok=0; }
grep -q '/data/local/tmp' $S/system/bin/port-wp-keep.sh $S/system/bin/port-wp-save.sh && { echo "B18 scripts still use /data/local/tmp"; ok=0; }
grep -q '^DEX=/system/framework/oplus-port-wpset.dex$' $S/system/bin/port-wp-keep.sh && grep -q '^S=/data/port/wp$' $S/system/bin/port-wp-keep.sh || { echo "B18 keep script dex guard / state path"; ok=0; }
python3 -I - $S/system/etc/init/00-port-wpkeep.rc <<'PY' || { echo "00-port-wpkeep.rc services (B18)"; ok=0; }
import sys, re
t = open(sys.argv[1]).read()
blocks = {m.group(1): m.group(0) for m in re.finditer(r'^service (\S+) .*?(?=^\S|\Z)', t, re.M | re.S)}
k, s = blocks.get('port_wp_keep', ''), blocks.get('port_wp_save', '')
okk = 'service port_wp_keep /system/bin/sh /system/bin/port-wp-keep.sh' in k and '    oneshot' in k and '    disabled' in k and 'seclabel u:r:su:s0' in k
oks = 'service port_wp_save /system/bin/inotifyd /system/bin/port-wp-save.sh /data/system/users/0:' in s and 'oneshot' not in s and '    disabled' in s and 'seclabel u:r:su:s0' in s
okt = re.search(r'^on property:sys\.boot_completed=1\n    mkdir /data/port/wp 0700 root root\n    start port_wp_keep\n    start port_wp_save\n', t, re.M) is not None
print('wpkeep rc: keep oneshot %s, saver non-oneshot %s, trigger %s' % (okk, oks, okt)); sys.exit(0 if okk and oks and okt else 1)
PY
[ -e $S/system/bin/inotifyd ] || [ -L $S/system/bin/inotifyd ] || { echo "no /system/bin/inotifyd for the B18 watcher"; ok=0; }
echo "== C1: donor camera com.oplus.camera baked (no restore-live.sh)"
CD=$P/tools/live/camera-donor17; OC=$S/my_product/app/OplusCamera
chk_sha_first 5d38a17594af24737b9a18b96aad7dc1ced35ec87fa2f215fda343de16e38423 $OC/OplusCamera.apk   # p9 + zipalign -p 4 + donor signing block
python3 -I $P/tools/apk-signer-certs.py $OC/OplusCamera.apk | grep -q b0a9bbfc05eee5e7 || { echo "OplusCamera lost the donor signer b0a9bbfc"; ok=0; }
unzip -p $OC/OplusCamera.apk classes12.dex | sha256sum | grep -q '^1e8c615710e43dd410b77f3c1387a4a0656924c6ce2ce598691f3422d457217d' || { echo "OplusCamera classes12.dex is not p9 (3x tele switch)"; ok=0; }
python3 -I - $OC/OplusCamera.apk <<'PY' || { echo "OplusCamera.apk: resources.arsc / lib/*.so not stored + aligned (system app loads libs from the APK)"; ok=0; }
import sys, zipfile, struct
z = zipfile.ZipFile(sys.argv[1]); f = open(sys.argv[1], 'rb'); bad = []
for i in z.infolist():
    if i.filename != 'resources.arsc' and not (i.filename.startswith('lib/') and i.filename.endswith('.so')): continue
    f.seek(i.header_offset); h = f.read(30); n, e = struct.unpack('<HH', h[26:30]); off = i.header_offset + 30 + n + e
    if i.compress_type != 0 or off % (4 if i.filename == 'resources.arsc' else 4096): bad.append(i.filename)
print('OplusCamera.apk unaligned/compressed:', bad[:5]); sys.exit(1 if bad else 0)
PY
ls -d $OC/oat 2>/dev/null && { echo "stale oat for OplusCamera"; ok=0; }
for g in $OC $OC/OplusCamera.apk; do getfattr -n security.selinux --only-values $g 2>/dev/null | tr -d '\0' | grep -q system_file || { echo "label of $g"; ok=0; }; done
chk_sha_first 736d601d616b82b746c62c7e3ae89efba9f512ae65add9d64942d7ea3ef2be2b $S/product/framework/com.oplus.camera.unit.sdk.jar          # SDK v11
chk_sha_first f6b71fd36935654df17a38c1c1669b2ef38e0dae702ea2197696b2474e917426 $S/product/framework/com.oplus.camera.unit.sdk.adapter.jar  # adapter v18
chk_sha_first 94ec843860349ce65480bcf9a90f1463b89956247e447a831d2d78e610d2b580 $S/system/etc/permissions/oneplus7port-camera-unit.xml
for g in $S/product/framework/com.oplus.camera.unit.sdk.jar $S/product/framework/com.oplus.camera.unit.sdk.adapter.jar $S/system/etc/permissions/oneplus7port-camera-unit.xml; do
  [ "$(stat -c %a $g)" = 644 ] || { echo "mode of $g (a writable dex is refused)"; ok=0; }
  getfattr -n security.selinux --only-values $g 2>/dev/null | tr -d '\0' | grep -q system_file || { echo "label of $g"; ok=0; }
done
(cd $S/my_product/lib64 && sha256sum -c --quiet $CD/bake/my_product-lib64.SHA256SUMS) || { echo "my_product/lib64 lacks the donor camera JNI libs"; ok=0; }
# 17j-r2 camera fix: the same 41 libs in /product/lib64 (the app's linker namespace does not see /my_product/lib64), mode 0644, system_lib_file
(cd $S/product/lib64 && sha256sum -c --quiet $CD/bake/my_product-lib64.SHA256SUMS) || { echo "product/lib64 lacks the 41 donor camera JNI libs (UnsatisfiedLinkError libCombineLutJni.so)"; ok=0; }
[ -f $S/product/lib64/libCombineLutJni.so ] || { echo "product/lib64/libCombineLutJni.so missing"; ok=0; }
awk '{print $2}' $CD/bake/my_product-lib64.SHA256SUMS | while read -r g; do
  [ "$(stat -c %a $S/product/lib64/$g 2>/dev/null)" = 644 ] && getfattr -n security.selinux --only-values $S/product/lib64/$g 2>/dev/null | tr -d '\0' | grep -qx u:object_r:system_lib_file:s0 || echo "product/lib64/$g mode/label"
done | tee /tmp/pf-plib | grep -q . && { echo "product/lib64 camera lib mode/label: $(head -3 /tmp/pf-plib)"; ok=0; }
echo "== 17j-r2: oplus-services.jar OplusEngineerFwService.getEngineerService() never blocks in waitForService (production boot)"
J=$S/system/framework/oplus-services.jar
rm -rf /tmp/pf-os; mkdir -p /tmp/pf-os
if unzip -p $J classes.dex > /tmp/pf-os/c.dex 2>/dev/null && baksmali d -o /tmp/pf-os/sm /tmp/pf-os/c.dex >/dev/null 2>&1; then
  M=/tmp/pf-os/sm/com/android/server/engineering/OplusEngineerFwService.smali
  awk '/^\.method private getEngineerService\(\)/{f=1} f{print} /^\.end method/{f=0}' $M > /tmp/pf-os/m.txt
  grep -q 'const/4 v0, 0x1' /tmp/pf-os/m.txt && ! grep -q 'isRootVersion' /tmp/pf-os/m.txt || { echo "getEngineerService still depends on isRootVersion (production bootloop, system_server watchdog)"; ok=0; }
  # the waitForService call stays in the method but must be dead code: const v0=1 immediately followed by the if-eqz that skips it
  awk '/const\/4 v0, 0x1/{c=NR} /if-eqz v0, :cond/{if(c&&NR-c<=2){ok=1}; exit} END{exit !ok}' /tmp/pf-os/m.txt || { echo "getEngineerService: const true + if-eqz not in place (waitForService reachable)"; ok=0; }
  grep -q 'initHalService' /tmp/pf-os/m.txt || { echo "getEngineerService lost initHalService"; ok=0; }
  grep -q 'ServiceManager;->waitForService' $M && echo "(waitForService elsewhere in the class: $(grep -c 'ServiceManager;->waitForService' $M))"
else echo "oplus-services.jar classes.dex cannot be read/baksmali'd"; ok=0; fi
ls $S/system/framework/oat/*/oplus-services.* 2>/dev/null | grep -v '^$' | grep . && { echo "stale oat/odex/vdex/art for the patched oplus-services.jar"; ok=0; }
if [ "${PROD_PROPS:-0}" = 1 ]; then grep -qx 'ro.adb.secure=1' $S/system/build.prop || { echo "production must keep ro.adb.secure=1"; ok=0; }; fi
grep -qx 'persist.camera.override_enable=true' $S/my_product/build.prop && grep -qx 'persist.camera.override_preview_hdr_support=false' $S/my_product/build.prop || { echo "persist.camera.override_* defaults missing (HDR preview)"; ok=0; }
for f in $S/product/etc/build.prop $S/system/build.prop $S/system_ext/etc/build.prop $V/build.prop $V/odm/etc/build.prop; do
  [ -f $f ] && grep -q '^persist\.camera\.override_' $f && { echo "persist.camera.override_* also set in $f"; ok=0; }
done
f=$S/system/etc/init/01-port-camera.rc
grep -qx '    mount none /my_stock/port-camera/odm-camera /vendor/odm/etc/camera bind' $f && grep -qx '    mount overlay overlay /vendor/odm/lib64 ro lowerdir=/my_stock/port-camera/odm-lib64:/vendor/odm/lib64' $f && grep -qx 'on post-fs-data' $f || { echo "01-port-camera.rc incomplete"; ok=0; }
grep -q 'mount erofs loop@/data/port/my_stock.img /my_stock ro' $S/system/etc/init/00-port-mystock.rc && [ "$(printf '%s\n' 00-port-mystock.rc 01-port-camera.rc | LC_ALL=C sort | head -1)" = 00-port-mystock.rc ] || { echo "my_stock is not mounted before 01-port-camera.rc"; ok=0; }
getfattr -n security.selinux --only-values $f 2>/dev/null | tr -d '\0' | grep -q system_file || { echo "label of 01-port-camera.rc"; ok=0; }
for t in vendor_file vendor_configs_file; do grep -q "^(allow init $t (dir (mounton)))" $S/system/etc/selinux/plat_sepolicy.cil || { echo "init may not mount on $t"; ok=0; }; done
getfattr -n security.selinux --only-values $V/odm/etc/camera | tr -d '\0' | grep -q vendor_configs_file && getfattr -n security.selinux --only-values $V/odm/lib64 | tr -d '\0' | grep -q 'object_r:vendor_file:' || { echo "vendor odm camera/lib64 dir labels changed (mounton rules)"; ok=0; }
for g in $(ls -A $V/odm/etc/camera); do cmp -s $V/odm/etc/camera/$g $CD/bake/odm-camera/$g || { echo "vendor odm/etc/camera/$g hidden by the bind but not in the bake copy"; ok=0; }; done
grep -rqs 'cos17-cam' $S/system/etc/init $S/system_ext/etc/init $V/etc/init $V/odm/etc/init && { echo "an rc still refers to the live /data/local/tmp/cos17-cam set"; ok=0; }
echo "== props"; grep -E '^(ro.bpf.kver_override|persist.sys.usb.config)=' $S/system/build.prop; ls $S/system/apex | grep tether
grep -q '^ro.port.sf_first_api_level=' $S/system/build.prop && { echo "noqti SF prop still set (composer now parses QTI)"; ok=0; }
echo "== B16: H.40 / ColorOS props in vendor build.prop"
B16=$P/tools/live/prop-compare/b16/vendor-build.prop.b16-block
[ "$(grep -c '^# OnePlus7Port B16' $V/build.prop)" = 1 ] || { echo "B16 block missing or duplicated in vendor build.prop"; ok=0; }
grep -v '^#' $B16 | grep '=' | while IFS= read -r kv; do
  k=${kv%%=*}
  last=$(grep "^$k=" $V/build.prop | tail -1)
  [ "$last" = "$kv" ] || echo "B16: vendor $k is '$last', want '$kv'"
  for f in $S/product/etc/build.prop $V/odm/etc/build.prop; do
    [ -f "$f" ] && grep -q "^$k=" "$f" && echo "B16: $k also set in $f (loads after vendor, would win)"
  done
done | tee /tmp/pf-b16.txt
[ -s /tmp/pf-b16.txt ] && ok=0
grep -q '^ro\.camera\.notify_nfc=' $V/build.prop && { echo "B16: camera prop notify_nfc must not be in vendor build.prop"; ok=0; }
umount $S $V
echo "== B15: patched WallpaperChooser in my_stock.img (video wallpaper decoder loop)"
MS=/mnt/pf-mystock; mkdir -p $MS
if mount -o ro,loop -t erofs $O/my_stock.img $MS; then
  WA=$MS/app/WallpaperChooser/WallpaperChooser.apk
  [ "$(sha256sum < $WA | cut -d' ' -f1)" = c6a0d13162f30360b1bffd177d4916fdef5dcf3224659e79d1662e7805f218e1 ] && echo "ok  $WA" || { echo "BAD $WA (not the B15 patched APK)"; ok=0; }
  getfattr -n security.selinux --only-values $WA 2>/dev/null | tr -d '\0' | grep -q system_file || { echo "WallpaperChooser.apk label (B15)"; ok=0; }
  [ -n "$(find $MS/app/WallpaperChooser \( -name '*.vdex' -o -name '*.odex' -o -name '*.art' \) 2>/dev/null)" ] && { echo "stale WallpaperChooser oat/vdex next to the patched APK (B15)"; ok=0; }
  umount $MS
else echo "cannot mount $O/my_stock.img"; ok=0; fi
echo "== C1: donor camera odm payload in my_stock.img (/my_stock/port-camera, bind/overlay sources of 01-port-camera.rc)"
MS=/mnt/pf-mystock-cam; mkdir -p $MS; CD=$P/tools/live/camera-donor17
if mount -o ro,loop -t erofs $O/my_stock.img $MS; then
  PC=$MS/port-camera
  (cd $PC && sha256sum -c --quiet $CD/bake/SHA256SUMS) && echo "ok  $PC ($(wc -l < $CD/bake/SHA256SUMS) files)" || { echo "BAD $PC content"; ok=0; }
  [ "$(cd $PC && find odm-camera odm-lib64 -type f | wc -l)" = "$(wc -l < $CD/bake/SHA256SUMS)" ] || { echo "extra files in $PC"; ok=0; }
  [ "$(find $PC/odm-camera | while read -r g; do getfattr -n security.selinux --only-values "$g" 2>/dev/null | tr -d '\0'; echo; done | sort -u)" = u:object_r:vendor_configs_file:s0 ] || { echo "port-camera/odm-camera labels (want vendor_configs_file)"; ok=0; }
  [ "$(find $PC/odm-lib64 | while read -r g; do getfattr -n security.selinux --only-values "$g" 2>/dev/null | tr -d '\0'; echo; done | sort -u)" = u:object_r:vendor_file:s0 ] || { echo "port-camera/odm-lib64 labels (want vendor_file)"; ok=0; }
  [ -z "$(find $PC \( -type f ! -perm 0644 \) -o \( -type d ! -perm 0755 \) 2>/dev/null)" ] || { echo "port-camera modes (want 0644 files / 0755 dirs)"; ok=0; }
  umount $MS
else echo "cannot mount $O/my_stock.img"; ok=0; fi
[ $ok = 1 ] && echo "PREFLIGHT PASS" || echo "PREFLIGHT FAIL"
