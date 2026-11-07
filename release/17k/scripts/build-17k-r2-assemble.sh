#!/usr/bin/env bash
# Assemble out-plk-build17k-r2 (dev) and run preflight for dev + production pairs; vendor file-level diff vs the first 17k vendor. Root, WSL.
# system/bootstrap/my_stock/boot are reused byte-for-byte from release/17k/images and out-plk-build17k (my_stock source is gone: never rebuild).
set -uo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port; R=$P/release/17k/images; O17=$P/out-plk-build17k; OUT=$P/out-plk-build17k-r2; L=$P/logs/plk-build17k-r2
mkdir -p $L
cp_d() { sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true; dd if="$1" of="$2" bs=16M oflag=direct status=none; }
[ "${SKIP_COPY:-0}" = 1 ] || { cp_d $R/bootstrap-system.img $OUT/system.img; cp_d $O17/boot.img $OUT/boot.img; cp_d $R/my_stock.img $OUT/my_stock.img; }
(cd $OUT && sha256sum system.img boot.img vendor.img my_stock.img | tee SHA256SUMS)
grep -q '^e64a10ca.*system.img' $OUT/SHA256SUMS && grep -q '^135022d0.*my_stock.img' $OUT/SHA256SUMS || { echo "UNEXPECTED SHAS"; exit 1; }
OUT=$OUT bash $P/tools/preflight-b.sh > $L/preflight-17k-r2-development.txt 2>&1; tail -1 $L/preflight-17k-r2-development.txt
PF=/root/port17k-r2-prod-preflight; rm -rf $PF; mkdir -p $PF
ln -s $R/system.img $PF/system.img; ln -s $OUT/vendor.img $PF/vendor.img; ln -s $OUT/boot.img $PF/boot.img; ln -s $OUT/my_stock.img $PF/my_stock.img
PROD_PROPS=1 OUT=$PF bash $P/tools/preflight-b.sh > $L/preflight-17k-r2-production.txt 2>&1; tail -1 $L/preflight-17k-r2-production.txt
mkdir -p /mnt/k17ra /mnt/k17rb
mount -t ext4 -o loop,ro $O17/vendor.img /mnt/k17ra; mount -t ext4 -o loop,ro $OUT/vendor.img /mnt/k17rb
{ echo "== vendor first 17k (out-plk-build17k/vendor.img d7e9a440) vs 17k-r2 (out-plk-build17k-r2/vendor.img)"; diff -qr --no-dereference /mnt/k17ra /mnt/k17rb; echo "diff exit=$?"; } > $L/vendor-17k-vs-17k-r2-diff.txt 2>&1
umount /mnt/k17ra /mnt/k17rb; cat $L/vendor-17k-vs-17k-r2-diff.txt
# previous (first-built) 17k-r2 vendor 3a70f811 vs the rebuilt r2: expect only the slider files + the 2 audio policy XMLs
if [ -f $OUT/vendor-r2-prev.img ]; then
  mkdir -p /mnt/k17rc; mount -t ext4 -o loop,ro $OUT/vendor-r2-prev.img /mnt/k17rc; mount -t ext4 -o loop,ro $OUT/vendor.img /mnt/k17rb
  { echo "== vendor previous 17k-r2 (3a70f811, vendor-r2-prev.img) vs rebuilt 17k-r2 (vendor.img)"; diff -qr --no-dereference /mnt/k17rc /mnt/k17rb; echo "diff exit=$?"; } > $L/vendor-r2-prev-vs-r2-rebuilt-diff.txt 2>&1
  umount /mnt/k17rc /mnt/k17rb; cat $L/vendor-r2-prev-vs-r2-rebuilt-diff.txt
fi
