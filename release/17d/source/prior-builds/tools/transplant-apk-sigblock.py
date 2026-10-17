#!/usr/bin/env python3
"""OnePlus7Port: put an APK's original APK Signing Block back into a patched copy of it.

tools/patch-systemui-dim.py rewrites classes4.dex and drops the v2/v3 signing block, so a fresh package scan finds no
certificates and rejects the APK. APKs on the system partitions are trusted (verified boot): PackageManager reads their
certificates without checking the content digests (ParsingPackageUtils, PARSE_IS_SYSTEM_DIR → skipVerify), so the
original block keeps the original (platform) signer. Not valid for /data installs.

Usage: transplant-apk-sigblock.py <original.apk> <patched.apk> <out.apk>
"""
import struct
import sys

MAGIC = b'APK Sig Block 42'


def eocd(d):
    i = d.rfind(b'PK\x05\x06')
    assert i >= 0 and len(d) - i < 65536 + 22, 'no EOCD'
    cd_size, cd_off = struct.unpack_from('<II', d, i + 12)
    return i, cd_off, cd_size


def sig_block(d):
    _, cd_off, _ = eocd(d)
    assert d[cd_off - 16:cd_off] == MAGIC, 'original has no APK Signing Block'
    size = struct.unpack_from('<Q', d, cd_off - 24)[0]
    start = cd_off - size - 8
    assert struct.unpack_from('<Q', d, start)[0] == size, 'signing block size fields differ'
    return d[start:cd_off]


orig, patched, out = sys.argv[1:4]
o = open(orig, 'rb').read()
p = open(patched, 'rb').read()
block = sig_block(o)
e, cd_off, cd_size = eocd(p)
assert p[cd_off - 16:cd_off] != MAGIC, 'patched APK already has a signing block'
assert cd_off + cd_size == e, 'unexpected data between central directory and EOCD'
new_eocd = bytearray(p[e:])
struct.pack_into('<I', new_eocd, 16, cd_off + len(block))
open(out, 'wb').write(p[:cd_off] + block + p[cd_off:e] + bytes(new_eocd))
print(f'{out}: signing block {len(block)} bytes from {orig}')
