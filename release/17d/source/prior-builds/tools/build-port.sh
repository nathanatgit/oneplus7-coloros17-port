#!/usr/bin/env bash
# Build the ColorOS 17 (Axis GSI) port images for OnePlus 7 Pro H.40. Run as root inside WSL.
#   out/system.img  EROFS system without my_stock contents + AVB hashtree footer (partition-sized)
#   out/reserve.img ext4 holding reserve/my_stock.img, for /data/reserve/reserve.img (stock fstab path)
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
GSI=$P/ColorOS17-GSI/system.img
SRC=/mnt/gsi
W=/root/cos17            # Linux-side scratch (fast); final images copied to $P/out
OUT=$P/out
SYSTEM_PART=3640655872   # fastboot getvar partition-size:system_a = 0xD9000000
AVB="python3 -I $P/tools/avb/avbtool.py"
KEY=$P/tools/avb/port_key.pem

mkdir -p "$SRC" "$W" "$OUT"
mountpoint -q "$SRC" || mount -o ro,loop "$GSI" "$SRC"
[ -f "$KEY" ] || openssl genrsa -out "$KEY" 4096 2>/dev/null

echo "== writable copy of the GSI tree (cp -a keeps owners, modes, SELinux xattrs, capabilities)"
rm -rf "$W/tree"
cp -a "$SRC" "$W/tree"
SRC=$W/tree
# TEST BUILD: adb enabled from first boot so bootloops can be debugged. Authentication stays on;
# only this PC's adb key is pre-authorized via /adb_keys (read by adbd on user builds).
PCKEY=/mnt/c/Users/Han/.android/adbkey.pub
[ -s "$PCKEY" ] || { echo "missing $PCKEY"; exit 1; }
# /adb_keys is an absolute symlink to /product/etc/security/adb_keys (absent in the GSI); write the
# target inside the tree with the label from plat_file_contexts.
K="$SRC/product/etc/security/adb_keys"
install -m 0644 -o root -g root "$PCKEY" "$K"
setfattr -n security.selinux -v "u:object_r:adb_keys_file:s0" "$K"
printf '\n# --- OnePlus7Port test build: adb on at boot (key-authenticated) ---\npersist.sys.usb.config=adb\n' \
  >> "$SRC/system/build.prop"

echo "== system (EROFS, my_stock left as an empty mount point)"
rm -f "$W/system.img"
# Options accepted by the H.40 4.14 OPLUS erofs backport (verified by loop-mount + full hash compare).
mkfs.erofs -zlz4hc,12 -E legacy-compress -b4096 --mount-point=/ \
  --exclude-regex='^my_stock/.+' "$W/system.img" "$SRC" > "$W/system-mkfs.log"
ls -l "$W/system.img"
# Two kernel cmdline descriptors, like stock: dm-verity root when hashtree is enabled,
# root=PARTUUID when vbmeta has verity disabled. No FEC (no fec tool; stock-only feature).
$AVB add_hashtree_footer --image "$W/system.img" --partition_name system \
  --partition_size $SYSTEM_PART --hash_algorithm sha256 --setup_as_rootfs_from_kernel \
  --do_not_generate_fec --algorithm SHA256_RSA4096 --key "$KEY"
$AVB info_image --image "$W/system.img" | grep -E 'Image size|Original image size|Kernel Cmdline|Partition Name|Root Digest'

echo "== my_stock.img (ext4, contents + xattrs copied by mke2fs -d)"
rm -f "$W/my_stock.img"
mb=$(du -sm --apparent-size "$SRC/my_stock" | cut -f1)
truncate -s $(( (mb * 110 / 100 + 64) * 1024 * 1024 )) "$W/my_stock.img"
mkfs.ext4 -q -F -b 4096 -L my_stock -m 0 -O ^has_journal -d "$SRC/my_stock" "$W/my_stock.img"
e2fsck -fn "$W/my_stock.img" > /dev/null && echo "my_stock.img fsck clean"
resize2fs -M "$W/my_stock.img" > /dev/null 2>&1 && ls -l "$W/my_stock.img"

echo "== reserve.img (ext4 with /reserve/my_stock.img, mirrors stock layout)"
rm -rf "$W/reserve-root" "$W/reserve.img"
mkdir -p "$W/reserve-root/reserve"
cp "$W/my_stock.img" "$W/reserve-root/reserve/my_stock.img"
rsz=$(( $(stat -c%s "$W/my_stock.img") + 64 * 1024 * 1024 ))
truncate -s $rsz "$W/reserve.img"
mkfs.ext4 -q -F -b 4096 -m 0 -O ^has_journal -d "$W/reserve-root" "$W/reserve.img"
e2fsck -fn "$W/reserve.img" > /dev/null && echo "reserve.img fsck clean"

cp "$W/system.img" "$W/reserve.img" "$OUT/"
(cd "$OUT" && sha256sum system.img reserve.img | tee SHA256SUMS)
