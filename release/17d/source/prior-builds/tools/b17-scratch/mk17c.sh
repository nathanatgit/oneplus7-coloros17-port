cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/build-port-b.sh'; s=open(p).read()
i=s.index("# Breeno wake word (live-verified)"); j=s.index("# OMAPI for Wallet")
new='''# Breeno wake-up on the H.40 DSP (live-verified 2026-10-17 14:18, user confirmed; handoff-2026-10-17.md §11d, tools/live/breeno-sva/):
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
unzip -p "$BS/OVoiceManagerService-sva-c17sig.apk" classes.dex | grep -aq svaOpaque || unzip -p "$BS/OVoiceManagerService-sva-c17sig.apk" 'classes*.dex' | grep -aq svaOpaque || { echo "breeno apk lacks svaOpaque"; exit 1; }
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
'''
s=s[:i]+new+s[j:]
open(p,'w').write(s)

p='tools/preflight-b.sh'; L=open(p).read().split('\n')
out=[]; skip=False
for n,l in enumerate(L,1):
    if n in (86,87) or 136<=n<=149: continue
    out.append(l)
s='\n'.join(out)
a="echo \"== props\"; grep -E"
assert a in s
add='''echo "== build 17c: Breeno wake-up on the H.40 SVA first stage"
BO=$S/my_product/priv-app/OVoiceManagerService
chk_sha_first cd68824e961323f7b2f47b42638150a5f99e236fa79d85e18b65b5fea6f34238 $BO/OVoiceManagerService.apk
unzip -p $BO/OVoiceManagerService.apk 'classes*.dex' | grep -aq svaOpaque || { echo "breeno apk dex lacks svaOpaque"; ok=0; }
python3 -I $P/tools/apk-signer-certs.py $BO/OVoiceManagerService.apk | grep -q e49802409584ce53 || { echo "OVoiceManagerService not signed with the ColorOS 17 platform cert"; ok=0; }
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
'''
s=s.replace(a,add+a,1)
open(p,'w').write(s)
PY
bash -n tools/build-port-b.sh && bash -n tools/preflight-b.sh && echo syntax-ok
