#!/usr/bin/env python3
"""OnePlus7Port: blank the OnePlus 15 punch-hole cutout in the donor's android display overlay.

my_product/overlay/android_framework_res_overlay.display.product.24831.apk must stay (it also holds
config_availableColorModes; without it system_server crash-loops on "Invalid colorMode: 301"), but its
config_mainBuiltInDisplayCutout (and ...RectApproximation, a reference to the same string) is the OnePlus 15's
"M -39,0 L -39,141 L 39,141 L 39,0 Z". The OnePlus 7 Pro has no cutout (stock H.40's display overlay defines none).

resources.arsc is stored uncompressed, so the string8 entry is emptied in place (both length bytes -> 0, which is the
value the live-verified fabricated overlays use) and the CRC-32 in the local header and central directory is updated.
Offsets don't move, so the original APK Signing Block stays in place; system-partition APKs are scanned with
skipVerify (see transplant-apk-sigblock.py).

Usage: patch-cutout-overlay.py <in.apk> <out.apk>
"""
import struct
import sys
import zlib

CUTOUT = b'M -39,0 L -39,141 L 39,141 L 39,0 Z'

src, dst = sys.argv[1], sys.argv[2]
d = bytearray(open(src, 'rb').read())

# locate resources.arsc (central directory -> local header -> data)
e = d.rfind(b'PK\x05\x06')
n_entries, cd_size, cd_off = struct.unpack_from('<HII', d, e + 10)
p = cd_off
for _ in range(n_entries):
    assert d[p:p + 4] == b'PK\x01\x02'
    method, = struct.unpack_from('<H', d, p + 10)
    csize, usize = struct.unpack_from('<II', d, p + 20)
    nlen, xlen, clen = struct.unpack_from('<HHH', d, p + 28)
    loff, = struct.unpack_from('<I', d, p + 42)
    name = bytes(d[p + 46:p + 46 + nlen])
    if name == b'resources.arsc':
        cd_entry = p
        break
    p += 46 + nlen + xlen + clen
else:
    sys.exit('resources.arsc not found')
assert method == 0 and csize == usize, 'resources.arsc is not stored'
lnlen, lxlen = struct.unpack_from('<HH', d, loff + 26)
data = loff + 30 + lnlen + lxlen

arsc = d[data:data + usize]
assert arsc.count(CUTOUT) == 1, 'cutout string not found exactly once (donor changed?)'
i = arsc.index(CUTOUT)
# string8 entry: [utf16 len (1 byte for <128)][utf8 len (1 byte)][bytes][NUL]
assert arsc[i - 2] == len(CUTOUT) and arsc[i - 1] == len(CUTOUT) and arsc[i + len(CUTOUT)] == 0, 'unexpected encoding'
arsc[i - 2] = 0
arsc[i - 1] = 0
arsc[i:i + len(CUTOUT)] = b'\0' * len(CUTOUT)
d[data:data + usize] = arsc

crc = zlib.crc32(bytes(arsc)) & 0xffffffff
struct.pack_into('<I', d, loff + 14, crc)        # local header CRC-32
struct.pack_into('<I', d, cd_entry + 16, crc)    # central directory CRC-32
open(dst, 'wb').write(d)
print('cutout blanked:', dst)
