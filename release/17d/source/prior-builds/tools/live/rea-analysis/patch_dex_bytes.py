"""Offset-preserving byte patch of a stored dex entry inside an APK.

usage: patch_dex_bytes.py in.apk out.apk ENTRY DEX_OFFSET_HEX EXPECTED_HEX NEW_HEX
Refuses unless the expected bytes are at the offset; rebuilds dex SHA-1/Adler-32 and the ZIP CRCs.
"""
import hashlib, pathlib, struct, sys, zipfile, zlib

src, dst, entry = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
off_in_dex, exp, new = int(sys.argv[4], 16), bytes.fromhex(sys.argv[5]), bytes.fromhex(sys.argv[6])
assert len(exp) == len(new)
raw = bytearray(src.read_bytes())
with zipfile.ZipFile(src) as z:
    info = z.getinfo(entry)
    assert info.compress_type == zipfile.ZIP_STORED
    hdr = info.header_offset
    n, e = struct.unpack_from("<HH", raw, hdr + 26)
    off = hdr + 30 + n + e
    dex = bytearray(raw[off:off + info.file_size])
    start = z.start_dir
assert bytes(dex[off_in_dex:off_in_dex + len(exp)]) == exp, "unexpected bytes: " + dex[off_in_dex:off_in_dex + len(exp)].hex()
dex[off_in_dex:off_in_dex + len(new)] = new
dex[12:32] = hashlib.sha1(dex[32:]).digest()
struct.pack_into("<I", dex, 8, zlib.adler32(dex[12:]) & 0xFFFFFFFF)
crc = zlib.crc32(dex) & 0xFFFFFFFF
raw[off:off + len(dex)] = dex
struct.pack_into("<I", raw, hdr + 14, crc)
cur, found = start, 0
while raw[cur:cur + 4] == b"PK\x01\x02":
    ns, es, cs = struct.unpack_from("<HHH", raw, cur + 28)
    if bytes(raw[cur + 46:cur + 46 + ns]).decode() == entry:
        struct.pack_into("<I", raw, cur + 16, crc); found += 1
    cur += 46 + ns + es + cs
assert found == 1
dst.write_bytes(raw)
with zipfile.ZipFile(dst) as z:
    assert z.testzip() is None
print("ok", dst.name, hashlib.sha256(dst.read_bytes()).hexdigest())
