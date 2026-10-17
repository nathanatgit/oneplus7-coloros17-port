cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/preflight-b.sh'; s=open(p).read()
a="grep -qx '    mkdir /data/vendor_de/0/cryptoeng"
assert a in s
add="""f=$V/odm/etc/init/vendor.oplus.hardware.charger-V3-service.rc
grep -q 'interface aidl vendor.oplus.hardware.charger.ICharger/default' $f && [ -x $V/odm/bin/hw/vendor.oplus.hardware.charger-V3-service ] || { echo "AIDL charger HAL (what ColorOS 17 OplusBatteryServiceFeature looks up) missing"; ok=0; }
grep -q 'vendor.oplus.hardware.charger' $V/odm/etc/vintf/manifest/manifest_oplus_charger_aidl.xml || { echo "AIDL charger vintf"; ok=0; }
"""
s=s.replace(a,add+a,1)
open(p,'w').write(s)
PY
bash -n tools/preflight-b.sh && echo ok
