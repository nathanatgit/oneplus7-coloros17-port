import subprocess, os, sys
E="/mnt/k-odm"
port_dirs=['/mnt/o-lv/lib64','/mnt/o-lv/odm/lib64']
sys_dirs=['/mnt/o-s/system/lib64']
ll=set(l.strip() for l in open('/mnt/o-s/system/etc/llndk.libraries.txt'))
def needed(p):
    o=subprocess.run(['readelf','-d',p],capture_output=True,text=True).stdout
    return [l.split('[')[1].rstrip(']') for l in o.splitlines() if 'NEEDED' in l]
need_add=set(); seen=set()
def walk(p):
    for n in needed(p):
        if n in seen: continue
        seen.add(n)
        if any(os.path.exists(d+'/'+n) for d in port_dirs): continue
        if n in ll or n in ('libc.so','libm.so','libdl.so'): continue   # LLNDK / bionic
        if os.path.exists(E+'/lib64/'+n):
            need_add.add(n); walk(E+'/lib64/'+n)
        else:
            print('UNRESOLVED',n,'(in system lib64: %s)'%os.path.exists('/mnt/o-s/system/lib64/'+n))
for b in sys.argv[1:]:
    print('##',b); walk(E+'/bin/hw/'+b)
print('ADD',sorted(need_add))
