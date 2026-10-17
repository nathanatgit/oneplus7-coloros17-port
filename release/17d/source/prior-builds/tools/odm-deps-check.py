"""Check that every ELF installed by tools/live/odm-services/install.list resolves all NEEDED libraries the way the vendor
linker namespace would: vendor lib64, odm lib64 (both inside the vendor image), the LLNDK list of the system image, or bionic.

Usage: odm-deps-check.py <vendor root> <system root>      (exit 1 and a MISSING line per unresolved library)
"""
import os
import subprocess
import sys

V, S = sys.argv[1:3]
OS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'live', 'odm-services')
search = [V + '/lib64', V + '/odm/lib64']
llndk = {l.strip() for l in open(S + '/system/etc/llndk.libraries.txt')} | {'libc.so', 'libm.so', 'libdl.so'}


def needed(path):
    out = subprocess.run(['readelf', '-d', path], capture_output=True, text=True).stdout
    return [l.split('[')[1].rstrip(']') for l in out.splitlines() if 'NEEDED' in l]


bad = 0
for line in open(OS + '/install.list'):
    if line.startswith('#') or not line.strip():
        continue
    src, dst = line.split()[:2]
    if not (dst.startswith('bin/hw/') or (dst.startswith('lib64/') and dst.endswith('.so'))):
        continue
    for n in needed(V + '/odm/' + dst):
        if n in llndk or any(os.path.exists(d + '/' + n) for d in search):
            continue
        print('MISSING %s needs %s' % (dst, n))
        bad = 1
print('odm-deps: %s' % ('FAIL' if bad else 'all NEEDED libraries resolve'))
sys.exit(bad)
