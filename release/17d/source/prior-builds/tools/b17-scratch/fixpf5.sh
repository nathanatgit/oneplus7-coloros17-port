cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/preflight-b.sh'; s=open(p).read()
i=s.index('ls $V/odm/bin/hw | grep -q secure_element'); j=s.index('\n',i)
new='''f=$V/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc
grep -q 'setenv LD_PRELOAD /odm/lib64/libport_shim_trim.so' $f && grep -q 'chown secure_element secure_element /dev/p73' $f && grep -q 'setprop vendor.nfc_se.config_ready true' $f || { echo "SE HAL rc incomplete (shim, /dev/p73, config_ready)"; ok=0; }
for k in 'ISecureElement/eSE1' 'INxpEse/default' 'INxpEseEvtProcessor/default'; do grep -q "$k" $V/odm/etc/vintf/manifest/manifest_port_secure_element.xml || { echo "SE vintf lacks $k (HAL aborts: Could not register service for Power Secure Element Extn Iface)"; ok=0; }; done
grep -q 'android.se.omapi' $V/odm/etc/vintf/manifest/manifest_oplus_charger.xml || { echo "android.se.omapi not declared (com.android.se crash loop)"; ok=0; }
ls $S/system_ext/app/SecureElement/SecureElement.apk >/dev/null || ok=0
grep -rq 'com.android.se' $S/system/etc/init $S/system_ext/etc/init $V/etc/init $V/odm/etc/init 2>/dev/null && { echo "an rc touches com.android.se"; ok=0; }'''
s=s[:i]+new+s[j:]
open(p,'w').write(s)
PY
bash -n tools/preflight-b.sh && echo ok
