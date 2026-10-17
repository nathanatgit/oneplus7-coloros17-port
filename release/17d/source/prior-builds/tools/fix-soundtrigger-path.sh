#!/usr/bin/env bash
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
OUT="$P/out-plk-audiofix"
M=/mnt/port-audiofix
mkdir -p "$OUT" "$M"
mountpoint -q "$M" && { echo 'Mountpoint already occupied'; exit 1; }
cp "$P/out-plk-debug/vendor.img" "$OUT/vendor.img"
mount -o loop "$OUT/vendor.img" "$M"
trap 'umount "$M"' EXIT
test -f "$M/odm/lib/hw/audio.primary.msmnile.so"
test ! -e "$M/lib/hw/audio.primary.msmnile.so"
ln -s ../../odm/lib/hw/audio.primary.msmnile.so "$M/lib/hw/audio.primary.msmnile.so"
setfattr -h -n security.selinux -v u:object_r:vendor_file:s0 "$M/lib/hw/audio.primary.msmnile.so"
test "$(readlink -f "$M/lib/hw/audio.primary.msmnile.so")" = "$M/odm/lib/hw/audio.primary.msmnile.so"
cmp "$M/lib/hw/audio.primary.msmnile.so" "$M/odm/lib/hw/audio.primary.msmnile.so"
ls -lZ "$M/lib/hw/audio.primary.msmnile.so"
umount "$M"
trap - EXIT
e2fsck -fn "$OUT/vendor.img"
sha256sum "$OUT/vendor.img" > "$OUT/SHA256SUMS"
