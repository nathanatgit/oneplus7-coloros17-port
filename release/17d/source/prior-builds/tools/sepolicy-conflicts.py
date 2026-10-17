"""List names declared by both the system-side policy (plat/system_ext/product) and the vendor/odm policy.

Usage: sepolicy-conflicts.py <system root> <vendor root>
Each conflict is printed with its kind on both sides, e.g. `hal_oplus_sensor_aidl system:type vendor:typeattribute`.
"""
import re
import sys
from pathlib import Path

DECL = re.compile(r"^\((type|typeattribute|attribute|role|class|common|classpermission|sensitivity|category)\s+([^\s()]+)\)",
                  re.M)


def decls(paths):
    out = {}
    for p in paths:
        if p.exists():
            for kind, name in DECL.findall(p.read_text(errors="replace")):
                out.setdefault(name, set()).add(f"{kind}@{p.name}")
    return out


sysroot, vroot = Path(sys.argv[1]), Path(sys.argv[2])
system = decls([sysroot / "system/etc/selinux/plat_sepolicy.cil",
                sysroot / "system/etc/selinux/mapping/202604.cil",
                sysroot / "system_ext/etc/selinux/system_ext_sepolicy.cil",
                sysroot / "system_ext/etc/selinux/mapping/202604.cil",
                sysroot / "product/etc/selinux/product_sepolicy.cil",
                sysroot / "product/etc/selinux/mapping/202604.cil"])
vendor = decls([vroot / "etc/selinux/vendor_sepolicy.cil", vroot / "odm/etc/selinux/odm_sepolicy.cil"])
both = sorted(set(system) & set(vendor))
for n in both:
    print(f"{n:50} system:{','.join(sorted(system[n]))}  vendor:{','.join(sorted(vendor[n]))}")
print(f"{len(both)} conflicting names", file=sys.stderr)
