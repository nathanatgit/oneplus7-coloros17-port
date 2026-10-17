"""Offset-preserving patch of a single 32-bit `const vA, #literal` in classes.dex of a stored-dex APK.

usage: patch_dex_const.py in.apk out.apk REG OLD NEW  (REG = dex register number, OLD/NEW = ints)
Pattern: opcode 0x14, reg byte, 4-byte LE literal; must match exactly once in classes.dex.
"""
import hashlib, pathlib, struct, sys, zipfile, zlib

src, dst, reg, old, new = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4], 0), int(sys.argv[5], 0)
raw = bytearray(src.read_bytes())
with zipfile.ZipFile(src) as z:
    info = z.getinfo("classes.dex")
    assert info.compress_type == zipfile.ZIP_STORED
    hdr = info.header_offset
    n, e = struct.unpack_from("<HH", raw, hdr + 26)
    off = hdr + 30 + n + e
    dex = bytearray(raw[off:off + info.file_size])
    start = z.start_dir
pat = bytes([0x14, reg]) + struct.pack("<I", old)
hits = []
i = dex.find(pat)
while i >= 0:
    hits.append(i); i = dex.find(pat, i + 1)
print("hits", [hex(h) for h in hits])
assert len(hits) == 1, "pattern must be unique"
dex[hits[0] + 2:hits[0] + 6] = struct.pack("<I", new)
dex[12:32] = hashlib.sha1(dex[32:]).digest()
struct.pack_into("<I", dex, 8, zlib.adler32(dex[12:]) & 0xFFFFFFFF)
crc = zlib.crc32(dex) & 0xFFFFFFFF
raw[off:off + len(dex)] = dex
struct.pack_into("<I", raw, hdr + 14, crc)
cur, found = start, 0
while raw[cur:cur + 4] == b"PK\x01\x02":
    ns, es, cs = struct.unpack_from("<HHH", raw, cur + 28)
    if bytes(raw[cur + 46:cur + 46 + ns]) == b"classes.dex":
        struct.pack_into("<I", raw, cur + 16, crc); found += 1
    cur += 46 + ns + es + cs
assert found == 1
dst.write_bytes(raw)
with zipfile.ZipFile(dst) as z:
    assert z.testzip() is None
print("ok", dst, hashlib.sha256(dst.read_bytes()).hexdigest())
