cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/preflight-b.sh'; s=open(p).read()
i=s.index("f=$V/odm/etc/init/vendor.oplus.hardware.charger-V3-service.rc"); j=s.index("grep -qx '    mkdir /data/vendor_de/0/cryptoeng")
new="""grep -q 'port.Main' $V/odm/etc/init/port-charger-aidl.rc && grep -q '<version>12</version>' $V/odm/etc/vintf/manifest/manifest_oplus_charger.xml || { echo "AIDL ICharger stub (what ColorOS 17 OplusBatteryServiceFeature looks up) rc/vintf missing"; ok=0; }
"""
s=s[:i]+new+s[j:]
open(p,'w').write(s)
PY
bash -n tools/preflight-b.sh && echo ok
