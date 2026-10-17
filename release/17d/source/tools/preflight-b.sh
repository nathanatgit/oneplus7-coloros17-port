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
grep -qx 'ro.build.display.id.show=GM1910_17.0.0.100(202610171200)' $S/my_manifest/build.prop || { echo "display.id.show not in 7 Pro style"; ok=0; }
if [ "${PROD_PROPS:-0}" = 1 ]; then
  grep -qx 'ro.secure=1' $S/system/build.prop && grep -qx 'ro.debuggable=0' $S/system/build.prop && grep -qx 'ro.adb.secure=1' $S/system/build.prop || { echo "root/ADB properties not production (PROD_PROPS=1 only)"; ok=0; }
  [ ! -e $S/product/etc/security/adb_keys ] || { echo "builder adb key must not ship in PROD_PROPS=1"; ok=0; }
fi
chk_sha_first ae420be14e7dbff8f2c46f2a035749e829cec49a939748d1510ffef40651cf3c $S/system_ext/etc/display_brightness_config_default.xml
chk_sha_first 470b8c126db668869c04cff8854d33afa0fe5d9e465e7e681136cb1dfc9fa78d $S/system_ext/priv-app/ims/ims.apk
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
grep -q 'port.Main' $V/odm/etc/init/port-charger-aidl.rc && grep -q '<version>12</version>' $V/odm/etc/vintf/manifest/manifest_oplus_charger.xml || { echo "AIDL ICharger stub (what ColorOS 17 OplusBatteryServiceFeature looks up) rc/vintf missing"; ok=0; }
grep -qx '    mkdir /data/vendor_de/0/cryptoeng 0770 system system encryption=None' $V/odm/etc/init/vendor.oplus.hardware.cryptoeng@1.0-service.rc || { echo "cryptoeng mkdir line"; ok=0; }
grep -q 'vendor_de 0770\|mkdir /data/vendor_de 0\|mkdir /data/vendor_de/0 ' $V/odm/etc/init/vendor.oplus.hardware.cryptoeng@1.0-service.rc && { echo "cryptoeng rc re-owns /data/vendor_de"; ok=0; }
f=$V/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc
grep -q 'setenv LD_PRELOAD /odm/lib64/libport_shim_trim.so' $f && grep -q 'chown secure_element secure_element /dev/p73' $f && grep -q 'setprop vendor.nfc_se.config_ready true' $f || { echo "SE HAL rc incomplete (shim, /dev/p73, config_ready)"; ok=0; }
for k in 'ISecureElement/eSE1' 'INxpEse/default' 'INxpEseEvtProcessor/default'; do grep -q "$k" $V/odm/etc/vintf/manifest/manifest_port_secure_element.xml || { echo "SE vintf lacks $k (HAL aborts: Could not register service for Power Secure Element Extn Iface)"; ok=0; }; done
grep -q 'android.se.omapi' $V/odm/etc/vintf/manifest/manifest_oplus_charger.xml || { echo "android.se.omapi not declared (com.android.se crash loop)"; ok=0; }
ls $S/system_ext/app/SecureElement/SecureElement.apk >/dev/null || ok=0
grep -rq 'com.android.se' $S/system/etc/init $S/system_ext/etc/init $V/etc/init $V/odm/etc/init 2>/dev/null && { echo "an rc touches com.android.se"; ok=0; }
chk_sha_first 78a219c9a447857913750780763e69a4b0b4f1ceb92a2e49801d3f183faec644 $S/system_ext/app/SecureElement/SecureElement.apk
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
echo "== props"; grep -E '^(ro.bpf.kver_override|persist.sys.usb.config)=' $S/system/build.prop; ls $S/system/apex | grep tether
grep -q '^ro.port.sf_first_api_level=' $S/system/build.prop && { echo "noqti SF prop still set (composer now parses QTI)"; ok=0; }
umount $S $V
[ $ok = 1 ] && echo "PREFLIGHT PASS" || echo "PREFLIGHT FAIL"
