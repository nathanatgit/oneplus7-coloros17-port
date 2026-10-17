"""Make a LineageOS (hardware/oplus) vendor policy compile against a ColorOS system policy. Edits in place.

Usage: patch-vendor-sepolicy.py <vendor root> <system root>

Conflicts are computed (not hard-coded) from the declarations on both sides, so this works for any donor:
- system declares X as an attribute, vendor as a type (LineageOS HAL domains vs ColorOS system_ext attributes):
  rename the vendor's type to los_X in every vendor/odm policy and contexts file.
- both declare X as a type: drop the vendor's (type X)/(roletype object_r X) so its rules use the system type.
- other kind clashes: reported, left alone (preflight's compile will catch them).
Also strips xperms rules from plat_pub_versioned.cil: ColorOS init (phh legacy-kernel patch) caps the policy to v29
and strips xperms from plat/system_ext/vendor/odm CIL but not from this file → "policy version 29 does not support
ioctl extendedpermissions rules" → init fatal. dontaudit(x)/auditallow(x) only affect logging.
"""
import re
import sys
from pathlib import Path

DECL = re.compile(r"^\((type|typeattribute)\s+([^\s()]+)\)", re.M)


def decls(paths):
    out = {}
    for p in paths:
        if p.exists():
            for kind, name in DECL.findall(p.read_text(errors="replace")):
                out.setdefault(name, set()).add(kind)
    return out


vroot, sroot = Path(sys.argv[1]), Path(sys.argv[2])
system = decls([sroot / "system/etc/selinux/plat_sepolicy.cil", sroot / "system_ext/etc/selinux/system_ext_sepolicy.cil",
                sroot / "product/etc/selinux/product_sepolicy.cil"])
vendor = decls([vroot / "etc/selinux/vendor_sepolicy.cil", vroot / "odm/etc/selinux/odm_sepolicy.cil"])
rename, drop = {}, []
for name in sorted(set(system) & set(vendor)):
    if system[name] == {"typeattribute"} and vendor[name] == {"type"}:
        rename[name] = "los_" + name
    elif system[name] == {"type"} and vendor[name] == {"type"}:
        drop.append(name)
    else:
        print(f"UNHANDLED conflict {name}: system {system[name]} vendor {vendor[name]}")
print(f"rename: {sorted(rename)}\ndrop:   {drop}")

files = [p for d in ("etc/selinux", "odm/etc/selinux") for p in sorted((vroot / d).glob("*"))
         if p.is_file() and (p.suffix == ".cil" or "contexts" in p.name)]
word = re.compile(r"(?<![\w])(" + "|".join(map(re.escape, rename)) + r")(?![\w])") if rename else None
for p in files:
    text = p.read_text(errors="surrogateescape")
    new = word.sub(lambda m: rename[m.group(1)], text) if word else text
    if p.name in ("vendor_sepolicy.cil", "odm_sepolicy.cil"):
        for t in drop:
            new = re.sub(rf"^\(type {re.escape(t)}\)\n", "", new, flags=re.M)
            new = re.sub(rf"^\(roletype object_r {re.escape(t)}\)\n", "", new, flags=re.M)
    if p.name == "plat_pub_versioned.cil":
        new = re.sub(r"^\((?:allowx|auditallowx|dontauditx|neverallowx) .*\n", "", new, flags=re.M)
    if new != text:
        with open(p, "r+", encoding="utf-8", errors="surrogateescape") as fh:   # in place: keep inode/xattrs
            fh.write(new)
            fh.truncate()
        print(f"patched {p.relative_to(vroot)}")
