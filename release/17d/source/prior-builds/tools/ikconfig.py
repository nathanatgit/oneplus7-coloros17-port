"""Extract the embedded kernel config (CONFIG_IKCONFIG, between IKCFG_ST / IKCFG_ED) from a boot.img kernel.

Usage: ikconfig.py <boot.img> [grep regex]
"""
import gzip
import re
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0].rsplit("\\", 1)[0])
from bootimg_v2 import parse  # noqa: E402

d = open(sys.argv[1], "rb").read()
o, n = parse(d)[2]["kernel"]
k = d[o:o + n]
s = k.find(b"IKCFG_ST")
if s < 0:
    sys.exit("no IKCONFIG in kernel (raw Image); it may be compressed or IKCONFIG is off")
cfg = gzip.decompress(k[s + 8:k.find(b"IKCFG_ED", s)]).decode()
pat = re.compile(sys.argv[2]) if len(sys.argv) > 2 else None
for line in cfg.splitlines():
    if pat is None or pat.search(line):
        print(line)
