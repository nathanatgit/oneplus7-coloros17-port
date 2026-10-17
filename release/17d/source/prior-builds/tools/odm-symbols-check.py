"""Check that every undefined (non-weak) dynamic symbol of the ELFs installed by tools/live/odm-services/install.list is defined by
one of the libraries it links (NEEDED, transitive; vendor lib64 + odm lib64, LLNDK libs from the system image's own files).
Catches 'cannot locate symbol' linker errors that odm-deps-check.py (library presence only) cannot.
Usage: odm-symbols-check.py <vendor root> <system root>"""
import os, subprocess, sys
V, S = sys.argv[1:3]
OS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'live', 'odm-services')
search = [V + '/odm/lib64', V + '/lib64']
llndk = [l.strip() for l in open(S + '/system/etc/llndk.libraries.txt')] + ['libc.so', 'libm.so', 'libdl.so']
sysdirs = [S + '/system/lib64', S + '/system/lib64/bootstrap', S + '/apex/com.android.runtime/lib64/bionic']
def find(n):
    for d in search + sysdirs:
        p = d + '/' + n
        if os.path.exists(p):
            return p
    return None
cache = {}
def nm(p, defined):
    k = (p, defined)
    if k not in cache:
        out = subprocess.run(['nm', '-D', '--defined-only' if defined else '--undefined-only', p], capture_output=True, text=True).stdout
        res = set()
        for l in out.splitlines():
            f = l.split()
            if not f: continue
            if not defined and f[0] in ('w', 'W', 'v', 'V'): continue
            res.add(f[-1].split('@')[0])
        cache[k] = res
    return cache[k]
def needed(p):
    out = subprocess.run(['readelf', '-d', p], capture_output=True, text=True).stdout
    return [l.split('[')[1].rstrip(']') for l in out.splitlines() if 'NEEDED' in l]
def closure(p, seen):
    for n in needed(p):
        if n in seen: continue
        q = find(n)
        seen[n] = q
        if q: closure(q, seen)
    return seen
bad = 0
for line in open(OS + '/install.list'):
    if line.startswith('#') or not line.strip(): continue
    dst = line.split()[1]
    if not (dst.startswith('bin/hw/') or (dst.startswith('lib64/') and dst.endswith('.so'))): continue
    if 'shim' in dst or 'portcompat' in dst: continue   # LD_PRELOAD forwarders: undefined refs resolve from the process's global scope
    p = V + '/odm/' + dst
    libs = closure(p, {})
    defs = set()
    shim = V + '/odm/lib64/libportcompat.so'    # LD_PRELOAD'ed by the services' rc: its definitions count for the process
    if os.path.exists(shim) and p != shim: defs |= nm(shim, True)
    for n, q in libs.items():
        if q: defs |= nm(q, True)
    miss = sorted(s for s in nm(p, False) if s not in defs)
    if miss:
        bad = 1
        print('UNRESOLVED in %s (%d): %s' % (dst, len(miss), ' '.join(miss[:6])))
print('odm-symbols: %s' % ('FAIL' if bad else 'all symbols resolve'))
sys.exit(bad)
