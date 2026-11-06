"""Unpack / repack the ramdisk of an Android boot image (header v0-v2), keeping every other section as-is.

  bootimg_v2.py unpack <boot.img> <outdir>          -> <outdir>/ramdisk (raw section bytes)
  bootimg_v2.py repack <boot.img> <ramdisk> <out>   -> boot image with the ramdisk replaced, sizes and id updated
  bootimg_v2.py kernel <boot.img> <Image> <out>     -> boot image with the kernel replaced, sizes and id updated
  bootimg_v2.py cmdline <boot.img> <out> <args...>  -> boot image with args appended to the header cmdline
                                                       (skips args already present; 512-byte field + 1024 extra)
"""
import hashlib
import struct
import sys


def parse(d):
    if d[:8] != b"ANDROID!":
        sys.exit("not an Android boot image")
    ks, ka, rs, ra, ss, sa, ta, pg, ver = struct.unpack("<IIIIIIIII", d[8:44])
    if ver > 2:
        sys.exit(f"header v{ver} not supported")
    rd_sz = struct.unpack("<I", d[1632:1636])[0] if ver >= 1 else 0   # recovery_dtbo_size
    dtb_sz = struct.unpack("<I", d[1648:1652])[0] if ver >= 2 else 0  # dtb_size

    def pages(n):
        return ((n + pg - 1) // pg) * pg

    off = pg
    sec = {}
    for name, size in (("kernel", ks), ("ramdisk", rs), ("second", ss), ("recovery_dtbo", rd_sz), ("dtb", dtb_sz)):
        sec[name] = (off, size)
        off += pages(size)
    return pg, ver, sec


def unpack(img, outdir):
    d = open(img, "rb").read()
    _, ver, sec = parse(d)
    o, n = sec["ramdisk"]
    open(f"{outdir}/ramdisk", "wb").write(d[o:o + n])
    print(f"header v{ver}; " + ", ".join(f"{k}={v[1]}" for k, v in sec.items()))


def repack(img, ramdisk, out, kernel=None):
    d = open(img, "rb").read()
    pg, ver, sec = parse(d)
    rd = open(ramdisk, "rb").read() if ramdisk else d[sec["ramdisk"][0]:sec["ramdisk"][0] + sec["ramdisk"][1]]
    parts = {k: d[o:o + n] for k, (o, n) in sec.items()}
    parts["ramdisk"] = rd
    if kernel:
        parts["kernel"] = open(kernel, "rb").read()

    hdr = bytearray(d[:pg])
    struct.pack_into("<I", hdr, 8, len(parts["kernel"]))
    struct.pack_into("<I", hdr, 16, len(rd))
    sha = hashlib.sha1()
    order = ["kernel", "ramdisk", "second"] + (["recovery_dtbo"] if ver >= 1 else []) + (["dtb"] if ver >= 2 else [])
    for k in order:
        sha.update(parts[k])
        sha.update(struct.pack("<I", len(parts[k])))
    hdr[576:608] = sha.digest().ljust(32, b"\0")   # id

    body = bytearray(hdr)
    for k in ["kernel", "ramdisk", "second", "recovery_dtbo", "dtb"]:
        b = parts[k]
        body += b + b"\0" * ((-len(b)) % pg)
    body += b"\0" * max(0, len(d) - len(body))      # keep the original image length (partition-sized)
    open(out, "wb").write(body)
    print(f"wrote {out}: {len(body)} bytes, ramdisk {sec['ramdisk'][1]} -> {len(rd)}")


def cmdline_append(img, out, args):
    d = bytearray(open(img, "rb").read())
    parse(bytes(d))
    full = (bytes(d[64:576]).rstrip(b"\0") + bytes(d[608:1632]).rstrip(b"\0")).decode()
    words = full.split()
    for a in args:
        if a not in words:
            words.append(a)
    new = " ".join(words).encode()
    if len(new) > 511 + 1023:
        sys.exit(f"cmdline too long ({len(new)} bytes)")
    d[64:576] = new[:511].ljust(512, b"\0")
    d[608:1632] = new[511:].ljust(1024, b"\0")
    open(out, "wb").write(bytes(d))   # the id hash covers sections, not the cmdline, so it stays valid
    print(f"cmdline: {new.decode()}")


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "cmdline":
        cmdline_append(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif len(sys.argv) == 4 and sys.argv[1] == "unpack":
        unpack(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 5 and sys.argv[1] == "kernel":
        repack(sys.argv[2], None, sys.argv[4], kernel=sys.argv[3])
    elif len(sys.argv) == 5 and sys.argv[1] == "repack":
        repack(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        sys.exit(__doc__)
