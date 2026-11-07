#!/usr/bin/env bash
# Build 17k-r3 vendor = rebuilt 17k-r2 vendor (out-plk-build17k-r2/vendor-r2-final.img e61b3b19) + B27 odm file (port-offlinecam-stub.rc),
# installed exactly as tools/build-port-b.sh does from tools/live/odm-services/install.list. Run as root in WSL.
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
OS=$P/tools/live/odm-services
IN=$P/out-plk-build17k-r2/vendor-r2-final.img
OUT=${OUT:-$P/out-plk-build17k-r3}
W=/root/k17r3; mkdir -p $W /mnt/k17r3v "$OUT"
(cd "$OS" && sha256sum -c --quiet SHA256SUMS)
echo "e61b3b199ae48f3518119d489aced6425fec0f8bb086f8537f50e382be731f3c  $IN" | sha256sum -c
cp "$IN" $W/vendor.img
mount -o loop $W/vendor.img /mnt/k17r3v
trap 'umount /mnt/k17r3v 2>/dev/null || true' EXIT
for f in port/etc/init/port-offlinecam-stub.rc; do
  line=$(awk -v s=$f '$1==s' $OS/install.list); [ -n "$line" ] || { echo "no install.list line for $f"; exit 1; }
  read -r src dst mode label <<<"$line"
  [ ! -e /mnt/k17r3v/odm/$dst ] || { echo "already has $dst"; exit 1; }
  install -D -m "$mode" -o root -g root "$OS/$src" "/mnt/k17r3v/odm/$dst"
  setfattr -n security.selinux -v "u:object_r:$label:s0" "/mnt/k17r3v/odm/$dst"
  ls -lZ /mnt/k17r3v/odm/$dst
done
umount /mnt/k17r3v; trap - EXIT
e2fsck -fn $W/vendor.img >/dev/null && echo "vendor fsck clean"
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
dd if=$W/vendor.img of="$OUT/vendor.img" bs=16M oflag=direct status=none
sha256sum "$OUT/vendor.img"
