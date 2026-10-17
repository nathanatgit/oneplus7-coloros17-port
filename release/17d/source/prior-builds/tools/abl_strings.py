"""Print identifying strings from a Qualcomm abl.img (ELF -> UEFI FV -> LZMA-compressed section)."""
import lzma
import re
import sys

PAT = re.compile(rb"(?i)(loader build|build info|version|oneplus|oplus|oppo|lineage|unlock|force_normal|"
                 rb"skip_initramfs|androidboot\.[a-z_]+|[A-Z][a-z]{2} +\d{1,2} 20\d\d)")

for path in sys.argv[1:]:
    data = open(path, "rb").read()
    found = []
    for m in re.finditer(rb"\x5d\x00\x00.\x00", data, re.S):   # LZMA "alone" header: props 0x5d + dict size
        try:
            out = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(data[m.start():], max_length=64 << 20)
        except lzma.LZMAError:
            continue
        if len(out) > 100000:
            found.append(out)
    print(f"== {path}: {len(found)} LZMA payload(s)")
    seen = set()
    for blob in found:
        for s in re.findall(rb"[ -~]{8,}", blob) + [x.encode() for x in re.findall(r"(?:[ -~]\x00){8,}", blob.decode("latin1"))]:
            s = s.replace(b"\x00", b"")
            if PAT.search(s) and s not in seen:
                seen.add(s)
                print("  ", s.decode(errors="replace")[:140])
