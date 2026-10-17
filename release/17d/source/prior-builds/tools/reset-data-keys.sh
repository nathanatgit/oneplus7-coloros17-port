#!/system/bin/sh
# Run in Lineage Recovery (root) on slot B. Makes the next boot create fresh metadata encryption for userdata:
# - removes /metadata/vold (keystore-wrapped metadata_encryption key made under a different OS; ColorOS keystore
#   rejects it with error -38 → vold read_key fails → /data never mounts → init_user0_failed)
# - zeroes the first 64 MiB of userdata so fs_mgr sees it as wiped and formats it through dm-default-key.
# DESTROYS userdata contents. Keeps the boot-logger files on metadata.
M=/tmp/md
mkdir -p $M
umount $M 2>/dev/null
mount -t ext4 /dev/block/by-name/metadata $M || exit 1
echo "before: $(ls $M | tr '\n' ' ')"
rm -rf $M/vold
echo "after:  $(ls $M | tr '\n' ' ')"
sync; umount $M
grep -q ' /data ' /proc/mounts && umount /data
dd if=/dev/zero of=/dev/block/by-name/userdata bs=1048576 count=64 2>&1 | tail -1
sync
echo DONE
