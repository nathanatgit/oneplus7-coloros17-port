"""Remove property_contexts entries from the ColorOS system_ext file that the vendor side also defines with a
different context (init's property trie build fails on such duplicates → property area LOG(FATAL)).
The vendor's definition is kept because the vendor HALs that set those properties depend on it. Edits in place.

Usage: drop-propctx-conflicts.py <system root (writable tree)> <vendor root>
"""
import sys
from pathlib import Path


def entries(path):
    out = {}
    if path.exists():
        for line in path.read_text(errors="replace").splitlines():
            parts = line.split("#", 1)[0].split()
            if len(parts) >= 2:
                match = parts[2] if len(parts) > 2 else "prefix"
                out.setdefault((parts[0], match), set()).add(tuple(parts[1:2] + parts[3:4]))
    return out


s, v = Path(sys.argv[1]), Path(sys.argv[2])
vend = {}
for f in (v / "etc/selinux/vendor_property_contexts", v / "odm/etc/selinux/odm_property_contexts"):
    for k, val in entries(f).items():
        vend.setdefault(k, set()).update(val)
total = 0
for f in (s / "system/etc/selinux/plat_property_contexts", s / "system_ext/etc/selinux/system_ext_property_contexts",
          s / "product/etc/selinux/product_property_contexts"):
    if not f.exists():
        continue
    keep, dropped = [], []
    for line in f.read_text(errors="replace").splitlines(keepends=True):
        parts = line.split("#", 1)[0].split()
        if len(parts) >= 2:
            key = (parts[0], parts[2] if len(parts) > 2 else "prefix")
            if key in vend and {tuple(parts[1:2] + parts[3:4])} != vend[key]:
                dropped.append(parts[0])
                continue
        keep.append(line)
    if dropped:
        with open(f, "r+") as fh:   # in place: keep the SELinux label
            fh.write("".join(keep))
            fh.truncate()
        print(f"{f.name}: dropped {dropped}")
        total += len(dropped)
print(f"{total} conflicting property_contexts entries removed")
