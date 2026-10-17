"""Find property_contexts entries that system-side (plat/system_ext/product) and vendor-side (vendor/odm) files
define differently. init merges them into one trie at boot (property_service.cpp / property_info_serializer); an
"exact" or prefix entry with a different context or type on each side is a known fatal-boot cause in ports.

Usage: propctx-conflicts.py <system root> <vendor root>
"""
import sys
from pathlib import Path


def load(paths):
    out = {}
    for p in paths:
        if not p.exists():
            continue
        for line in p.read_text(errors="replace").splitlines():
            parts = line.split("#", 1)[0].split()
            if len(parts) < 2:
                continue
            name, ctx = parts[0], parts[1]
            match = parts[2] if len(parts) > 2 else "prefix"
            typ = " ".join(parts[3:]) if len(parts) > 3 else "string"
            out.setdefault((name, match), set()).add((ctx, typ, p.name))
    return out


s, v = Path(sys.argv[1]), Path(sys.argv[2])
system = load([s / "system/etc/selinux/plat_property_contexts", s / "system_ext/etc/selinux/system_ext_property_contexts",
               s / "product/etc/selinux/product_property_contexts"])
vendor = load([v / "etc/selinux/vendor_property_contexts", v / "odm/etc/selinux/odm_property_contexts"])
n = 0
for key in sorted(set(system) & set(vendor)):
    sc = {(c, t) for c, t, _ in system[key]}
    vc = {(c, t) for c, t, _ in vendor[key]}
    if sc != vc:
        n += 1
        print(f"{key[0]} ({key[1]})\n    system: {sorted(system[key])}\n    vendor: {sorted(vendor[key])}")
# same name declared on both sides with different match kinds is also worth seeing
names_s = {k[0] for k in system}
names_v = {k[0] for k in vendor}
print(f"{n} conflicting entries; {len(names_s & names_v)} names defined on both sides", file=sys.stderr)
