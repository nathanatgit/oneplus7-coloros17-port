cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/preflight-b.sh'; s=open(p).read()
def rep(a,b):
    global s
    assert a in s, a[:50]; s=s.replace(a,b)
rep("for t in hal_secure_element_default_exec hal_secure_element_default; do grep -q \"^(type $t)\" $V/etc/selinux/vendor_sepolicy.cil || { echo \"vendor policy lacks $t\"; ok=0; }; done\n","python3 -I $P/tools/odm-symbols-check.py $V $S | tee /tmp/pf6; grep -q 'all symbols resolve' /tmp/pf6 || ok=0   # build 17 failed with 'cannot locate symbol' (Trim, Json::Value::operator=)\n")
rep("for rc in vendor.oplus.hardware.charger@1.0-service vendor.oplus.hardware.cryptoeng@1.0-service android.hardware.secure_elementnq330@1.1-service; do","for rc in vendor.oplus.hardware.charger@1.0-service vendor.oplus.hardware.cryptoeng@1.0-service; do")
rep("  [ \"$(grep -c '^service ' $f)\" = 1 ]","  grep -q 'setenv LD_PRELOAD /odm/lib64/libportcompat.so' $f || { echo \"rc $rc: no LD_PRELOAD shim\"; ok=0; }\n  [ \"$(grep -c '^service ' $f)\" = 1 ]")
i=s.index("grep -qx '    setprop vendor.nfc_se.config_ready true'"); j=s.index("\n",i)
s=s[:i]+"ls $V/odm/bin/hw | grep -q secure_element && { echo \"SE HAL installed but the kernel has no /dev/p73 (restart loop)\"; ok=0; }"+s[j:]
open(p,'w').write(s)
p='tools/odm-symbols-check.py'; s=open(p).read()
a="    defs = set()\n"
assert a in s
s=s.replace(a,"    defs = set()\n    shim = V + '/odm/lib64/libportcompat.so'    # LD_PRELOAD'ed by the services' rc: its definitions count for the process\n    if os.path.exists(shim) and p != shim: defs |= nm(shim, True)\n")
open(p,'w').write(s)
PY
bash -n tools/preflight-b.sh && echo ok
