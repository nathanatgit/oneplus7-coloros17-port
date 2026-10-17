"""Minimal AVB vbmeta parser: prints header flags and every descriptor (libavb format)."""
import struct
import sys

TAGS = {0: "property", 1: "hashtree", 2: "hash", 3: "kernel_cmdline", 4: "chain_partition"}


def read_vbmeta(path):
    """Return vbmeta bytes from a bare vbmeta image or from a partition image's AVB footer."""
    with open(path, "rb") as fh:
        head = fh.read(4)
        if head == b"AVB0":
            fh.seek(0)
            return fh.read()
        fh.seek(-64, 2)
        foot = fh.read(64)
        if foot[:4] != b"AVBf":
            sys.exit(f"{path}: no vbmeta header or AVB footer")
        orig, off, size = struct.unpack(">QQQ", foot[12:36])
        print(f"{path}: AVB footer original_image_size={orig} vbmeta_offset={off} vbmeta_size={size}")
        fh.seek(off)
        return fh.read(size)


def dump(path):
    d = read_vbmeta(path)
    if d[:4] != b"AVB0":
        sys.exit(f"{path}: not a vbmeta image")
    (maj, mnr, auth_sz, aux_sz, alg) = struct.unpack(">IIQQI", d[4:32])
    desc_off, desc_sz, rollback, flags = struct.unpack(">QQQI", d[96:124])
    release = d[128:176].rstrip(b"\0").decode()
    print(f"{path}: avb {maj}.{mnr} alg={alg} flags={flags} rollback={rollback} release={release!r}")
    p = 256 + auth_sz + desc_off
    end = p + desc_sz
    while p < end:
        tag, n = struct.unpack(">QQ", d[p:p + 16])
        b = d[p + 16:p + 16 + n]
        name = TAGS.get(tag, f"tag{tag}")
        if tag == 3:
            fl, ln = struct.unpack(">II", b[:8])
            print(f"  {name} flags={fl}: {b[8:8 + ln].decode()}")
        elif tag == 1:
            (ver, img, toff, tsz, dbs, hbs, roots, foff, fsz) = struct.unpack(">IQQQIIIQQ", b[:56])
            alg_s = b[56:88].rstrip(b"\0").decode()
            nl, sl, rl, fl = struct.unpack(">IIII", b[88:104])
            q = 164
            pname = b[q:q + nl].decode()
            print(f"  {name} {pname}: image_size={img} tree_off={toff} fec_off={foff} alg={alg_s} flags={fl}")
        elif tag == 2:
            img = struct.unpack(">Q", b[:8])[0]
            nl = struct.unpack(">I", b[40:44])[0]
            pname = b[116:116 + nl].decode()
            print(f"  {name} {pname}: image_size={img}")
        elif tag == 4:
            loc, nl = struct.unpack(">II", b[:8])
            print(f"  {name} {b[76:76 + nl].decode()} rollback_loc={loc}")
        elif tag == 0:
            kl, vl = struct.unpack(">QQ", b[:16])
            print(f"  {name} {b[16:16 + kl].decode()}={b[17 + kl:17 + kl + vl].decode(errors='replace')}")
        p += 16 + n


for f in sys.argv[1:]:
    dump(f)
