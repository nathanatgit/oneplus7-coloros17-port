#!/usr/bin/env bash
# Build 17k-r2 vendor = first 17k vendor (out-plk-build17k/vendor.img d7e9a440) + B22 odm files (port-netguard .sh/.rc)
# + B24/B25b odm files (port-slider-hold.dex, port-sliderdex.sh/.rc) + B26 (audio policy: primary input maxOpenCount 2 -> 1, 2 XMLs)
# installed exactly as tools/build-port-b.sh does from tools/live/odm-services/install.list. Run as root in WSL.
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
OS=$P/tools/live/odm-services
IN=$P/out-plk-build17k/vendor.img
OUT=${OUT:-$P/out-plk-build17k-r2}
W=/root/k17r2; mkdir -p $W /mnt/k17r2v "$OUT"
(cd "$OS" && sha256sum -c --quiet SHA256SUMS)
echo "d7e9a440d5a0fb6cbb7f3de6d3b04639488a262bcaaac4a6c072776da5fbe874  $IN" | sha256sum -c
cp "$IN" $W/vendor.img
mount -o loop $W/vendor.img /mnt/k17r2v
trap 'umount /mnt/k17r2v 2>/dev/null || true' EXIT
for f in port/bin/port-netguard.sh port/etc/init/port-netguard.rc port/bin/port-slider-hold.dex port/bin/port-sliderdex.sh port/etc/init/port-sliderdex.rc; do
  line=$(awk -v s=$f '$1==s' $OS/install.list); [ -n "$line" ] || { echo "no install.list line for $f"; exit 1; }
  read -r src dst mode label <<<"$line"
  [ ! -e /mnt/k17r2v/odm/$dst ] || { echo "already has $dst"; exit 1; }
  install -D -m "$mode" -o root -g root "$OS/$src" "/mnt/k17r2v/odm/$dst"
  setfattr -n security.selinux -v "u:object_r:$label:s0" "/mnt/k17r2v/odm/$dst"
  ls -lZ /mnt/k17r2v/odm/$dst
done
# B26: write the edited XMLs INTO the existing inodes (cat >), so owner/mode/SELinux label stay as they are.
AP=$P/tools/live/audio-policy-1input
for f in audio_policy_configuration audio_policy_configuration_a2dp_offload_disabled; do
  t=/mnt/k17r2v/etc/$f.xml
  cmp -s $AP/$f.orig.xml $t || { echo "$f.xml in the vendor is not the .orig we edited"; exit 1; }
  [ "$(grep -c 'name="primary input" role="sink" maxOpenCount="2"' $t)" = 1 ] || { echo "primary input attribute count in $f"; exit 1; }
  cat $AP/$f.xml > $t
  [ "$(grep -c 'name="primary input" role="sink" maxOpenCount="1" maxActiveCount="2"' $t)" = 1 ] && cmp -s $AP/$f.xml $t || { echo "edit failed in $f"; exit 1; }
  ls -lZ $t
done
umount /mnt/k17r2v; trap - EXIT
e2fsck -fn $W/vendor.img >/dev/null && echo "vendor fsck clean"
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
dd if=$W/vendor.img of="$OUT/vendor.img" bs=16M oflag=direct status=none
sha256sum "$OUT/vendor.img"
