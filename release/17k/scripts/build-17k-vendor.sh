#!/usr/bin/env bash
# Build 17k vendor = 17j-r2 vendor (release/17j/images/vendor.img) + B20/B21 odm files (port-chglimit, port-bmslevel .sh/.rc)
# installed exactly as tools/build-port-b.sh does from tools/live/odm-services/install.list. Run as root in WSL.
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
OS=$P/tools/live/odm-services
IN=$P/release/17j/images/vendor.img
OUT=${OUT:-$P/out-plk-build17k}
W=/root/k17; mkdir -p $W /mnt/k17v "$OUT"
(cd "$OS" && sha256sum -c --quiet SHA256SUMS)
echo "d8f45456e2f1a52bba820868f0ebba23ec6f525989f2d40e4b68e20355927313  $IN" | sha256sum -c
cp "$IN" $W/vendor.img
mount -o loop $W/vendor.img /mnt/k17v
trap 'umount /mnt/k17v 2>/dev/null || true' EXIT
for f in port/bin/port-chglimit.sh port/etc/init/port-chglimit.rc port/bin/port-bmslevel.sh port/etc/init/port-bmslevel.rc; do
  line=$(awk -v s=$f '$1==s' $OS/install.list); [ -n "$line" ] || { echo "no install.list line for $f"; exit 1; }
  read -r src dst mode label <<<"$line"
  [ ! -e /mnt/k17v/odm/$dst ] || { echo "already has $dst"; exit 1; }
  install -D -m "$mode" -o root -g root "$OS/$src" "/mnt/k17v/odm/$dst"
  setfattr -n security.selinux -v "u:object_r:$label:s0" "/mnt/k17v/odm/$dst"
  ls -lZ /mnt/k17v/odm/$dst
done
umount /mnt/k17v; trap - EXIT
e2fsck -fn $W/vendor.img >/dev/null && echo "vendor fsck clean"
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
dd if=$W/vendor.img of="$OUT/vendor.img" bs=16M oflag=direct status=none
sha256sum "$OUT/vendor.img"
