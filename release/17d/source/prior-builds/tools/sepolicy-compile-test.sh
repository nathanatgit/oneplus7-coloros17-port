#!/usr/bin/env bash
# Reproduce init's on-device split-policy compile (system/core/init/selinux.cpp) on the PC.
# Usage: sepolicy-compile-test.sh <system root> <vendor root> [odm root]
# Prints secilc's error if the system (plat/system_ext/product) + vendor (+odm) policies don't combine.
set -u
S=$1; V=$2; O=${3:-$2/odm}
ver=$(cat "$V/etc/selinux/plat_sepolicy_vers.txt")
args=("$S/system/etc/selinux/plat_sepolicy.cil" -m -M true -G -N -c 30
      "$S/system/etc/selinux/mapping/$ver.cil")
[ -f "$S/system/etc/selinux/mapping/$ver.compat.cil" ] && args+=("$S/system/etc/selinux/mapping/$ver.compat.cil")
for part in system_ext product; do
  d="$S/$part/etc/selinux"
  [ -f "$d/${part}_sepolicy.cil" ] && args+=("$d/${part}_sepolicy.cil")
  [ -f "$d/mapping/$ver.cil" ] && args+=("$d/mapping/$ver.cil")
done
args+=("$V/etc/selinux/plat_pub_versioned.cil" "$V/etc/selinux/vendor_sepolicy.cil")
[ -f "$O/etc/selinux/odm_sepolicy.cil" ] && args+=("$O/etc/selinux/odm_sepolicy.cil")
echo "vendor plat version $ver; inputs:"; printf '  %s\n' "${args[@]}" | grep '\.cil'
out=$(mktemp)
if secilc "${args[@]}" -o "$out" -f /dev/null; then echo "COMPILE OK ($(stat -c%s "$out") bytes)"; else echo "COMPILE FAILED"; fi
rm -f "$out"
