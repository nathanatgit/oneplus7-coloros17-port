#!/system/bin/sh
# Run in Lineage Recovery (root). Mounts slot-B system/vendor like init does and runs the *ColorOS* secilc with
# init's exact split-policy arguments (system/core/init/selinux.cpp, Android 17). Prints secilc's verdict.
R=/tmp/r
mkdir -p $R
mount -t erofs -o ro /dev/block/by-name/system_b $R 2>/dev/null || mount -t ext4 -o ro /dev/block/by-name/system_b $R
mount -t ext4 -o ro /dev/block/by-name/vendor_b $R/vendor
for d in proc sys dev; do mount --bind /$d $R/$d; done
V=$(cat $R/vendor/etc/selinux/plat_sepolicy_vers.txt)
PV=$(cat /sys/fs/selinux/policyvers)
GV=$(grep -h '^ro.board.genfs_labels_version=' $R/vendor/build.prop $R/vendor/etc/build.prop 2>/dev/null | cut -d= -f2)
echo "vendor plat vers=$V kernel policyvers=$PV genfs_labels_version=${GV:-unset}"
ls -ld $R/odm $R/system_ext $R/product
ls $R/system/etc/selinux/ | grep -E 'genfs|mapping'
set -- /system/etc/selinux/plat_sepolicy.cil -m -M true -G -N -c $PV /system/etc/selinux/mapping/$V.cil -o /dev/null -f /dev/null
add() { [ -e "$R$1" ] && set -- "$@" "$1"; echo "$@" > /tmp/args; }
ARGS="/system/etc/selinux/plat_sepolicy.cil -m -M true -G -N -c $PV /system/etc/selinux/mapping/$V.cil -o /dev/null -f /dev/null"
for f in /system/etc/selinux/mapping/$V.compat.cil /system_ext/etc/selinux/system_ext_sepolicy.cil \
         /system_ext/etc/selinux/mapping/$V.cil /system_ext/etc/selinux/mapping/$V.compat.cil \
         /product/etc/selinux/product_sepolicy.cil /product/etc/selinux/mapping/$V.cil \
         /vendor/etc/selinux/plat_pub_versioned.cil /vendor/etc/selinux/vendor_sepolicy.cil \
         /odm/etc/selinux/odm_sepolicy.cil /system/etc/selinux/plat_sepolicy_genfs_${GV:-none}.cil; do
  if [ -e "$R$f" ]; then ARGS="$ARGS $f"; echo "  + $f"; else echo "  - $f (absent)"; fi
done
echo "== ColorOS secilc"
chroot $R /system/bin/bootstrap/linker64 /system/bin/secilc $ARGS 2>&1 | tail -8
echo "secilc rc=$?"
for d in proc sys dev; do umount $R/$d; done
umount $R/vendor; umount $R
