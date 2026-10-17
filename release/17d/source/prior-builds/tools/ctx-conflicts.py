"""Generic check: keys defined on both the system side and the vendor side of a merged *_contexts file family
with a different value. Covers service/hwservice/keystore2_key/seapp contexts (property contexts: see
propctx-conflicts.py).

Usage: ctx-conflicts.py <system root> <vendor root>
"""
import sys
from pathlib import Path

FAMILIES = {
    "service_contexts": ("system/etc/selinux/plat_service_contexts", "system_ext/etc/selinux/system_ext_service_contexts",
                         "product/etc/selinux/product_service_contexts", "|", "etc/selinux/vendor_service_contexts"),
    "hwservice_contexts": ("system/etc/selinux/plat_hwservice_contexts", "system_ext/etc/selinux/system_ext_hwservice_contexts",
                           "product/etc/selinux/product_hwservice_contexts", "|", "etc/selinux/vendor_hwservice_contexts"),
    "keystore2_key_contexts": ("system/etc/selinux/plat_keystore2_key_contexts",
                               "system_ext/etc/selinux/system_ext_keystore2_key_contexts",
                               "product/etc/selinux/product_keystore2_key_contexts", "|",
                               "etc/selinux/vendor_keystore2_key_contexts"),
    "seapp_contexts": ("system/etc/selinux/plat_seapp_contexts", "system_ext/etc/selinux/system_ext_seapp_contexts",
                       "product/etc/selinux/product_seapp_contexts", "|", "etc/selinux/vendor_seapp_contexts"),
}


def load(root, rels, seapp):
    out = {}
    for rel in rels:
        p = root / rel
        if not p.exists():
            continue
        for line in p.read_text(errors="replace").splitlines():
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if seapp:   # key = input selectors, value = outputs
                kv = dict(x.split("=", 1) for x in line.split() if "=" in x)
                outs = {k: kv.pop(k) for k in ("domain", "type", "levelFrom", "level") if k in kv}
                key, val = " ".join(f"{k}={v}" for k, v in sorted(kv.items())), str(sorted(outs.items()))
            else:
                parts = line.split()
                key, val = parts[0], " ".join(parts[1:])
            out.setdefault(key, set()).add(val)
    return out


s, v = Path(sys.argv[1]), Path(sys.argv[2])
for fam, spec in FAMILIES.items():
    i = spec.index("|")
    sysd = load(s, spec[:i], fam == "seapp_contexts")
    vend = load(v, spec[i + 1:], fam == "seapp_contexts")
    bad = [k for k in sorted(set(sysd) & set(vend)) if sysd[k] != vend[k]]
    print(f"== {fam}: {len(bad)} conflicting keys")
    for k in bad:
        print(f"   {k}\n      system: {sorted(sysd[k])}\n      vendor: {sorted(vend[k])}")
