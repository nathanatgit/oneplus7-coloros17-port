cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/preflight-b.sh'
s=open(p).read()
a='for pair in "vendor.oplus.hardware.charger@1.0::ICharger" "vendor.oplus.hardware.cryptoeng@1.0::ICryptoeng"; do :; done\n'
assert a in s; s=s.replace(a,'')
b="""  p=$(awk '$1=="service" {print $3}' $f); [ -x $V$(echo $p | sed 's|^/odm|/odm|') ] || [ -x $V/odm${p#/odm} ] || { echo "rc $rc: binary $p missing"; ok=0; }"""
c="""  p=$(awk '$1=="service" {print $3}' $f); [ -x $V/odm${p#/odm} ] || { echo "rc $rc: binary $p missing"; ok=0; }"""
assert b in s; s=s.replace(b,c)
open(p,'w').write(s)
PY
bash -n tools/preflight-b.sh && echo pf-syntax-ok; bash -n tools/build-port-b.sh && echo build-syntax-ok
