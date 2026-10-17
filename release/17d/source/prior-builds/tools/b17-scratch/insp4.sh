. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
mkdir -p /mnt/i-hv; mountpoint -q /mnt/i-hv || mount -o ro,loop $P/StockRom/H40-images/vendor.img /mnt/i-hv
python3 -I - <<'PY'
import subprocess, os
def needed(p):
    o=subprocess.run(['readelf','-d',p],capture_output=True,text=True).stdout
    return [l.split('[')[1].rstrip(']') for l in o.splitlines() if 'NEEDED' in l]
roots={'lv':'/mnt/i-lv','hv':'/mnt/i-hv','ho':'/mnt/i-odm','s':'/mnt/i-s16'}
def find(lib,arch):
    r=[]
    for k,sub in (('lv','vendor/'),):pass
    for name,paths in (('LOSvendor',['/mnt/i-lv/lib64','/mnt/i-lv/odm/lib64']),('SYS',['/mnt/i-s16/system/lib64','/mnt/i-s16/system_ext/lib64','/mnt/i-s16/system/lib64/vndk-sp','/mnt/i-s16/system/system_ext/lib64'])):
        if arch=='32': paths=[p.replace('lib64','lib') for p in paths]
        for p in paths:
            if os.path.exists(p+'/'+lib): r.append(name+':'+p.replace('/mnt/i-','')); 
    return r
bins=['/mnt/i-odm/bin/hw/vendor.oplus.hardware.charger@1.0-service','/mnt/i-odm/bin/hw/vendor.oplus.hardware.cryptoeng@1.0-service','/mnt/i-odm/bin/hw/android.hardware.secure_elementnq330@1.1-service']
seen=set()
def walk(p,depth,arch='64'):
    for n in needed(p):
        if n in seen: continue
        seen.add(n)
        f=find(n,arch)
        hl=[x for x in ('/mnt/i-odm/lib64/','/mnt/i-hv/lib64/') if os.path.exists(x+n)]
        print('  '*depth+n, '->', f or 'MISSING', '| stock:',[h[7:10] for h in hl])
        # recurse into found stock copy if missing in port
        if not f and hl: walk(hl[0]+n,depth+1)
for b in bins:
    print('#####',b); seen=set(); walk(b,0)
PY
