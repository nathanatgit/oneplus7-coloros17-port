#!/usr/bin/env bash
# Assemble out-plk-build17k (dev) and run preflight for dev + production pairs; vendor file-level diff vs 17j-r2. Root, WSL.
set -uo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port; R=$P/release/17j/images; OUT=$P/out-plk-build17k; L=$P/logs/plk-build17k
cp_d() { sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true; dd if="$1" of="$2" bs=16M oflag=direct status=none; }
[ "${SKIP_COPY:-0}" = 1 ] || { cp_d $R/bootstrap-system.img $OUT/system.img; cp_d $P/out-plk-build17j-r2/boot.img $OUT/boot.img; cp_d $R/my_stock.img $OUT/my_stock.img; }
(cd $OUT && sha256sum system.img boot.img vendor.img my_stock.img | tee SHA256SUMS)
grep -q '^e64a10ca.*system.img\|^e64a10ca' $OUT/SHA256SUMS && grep -q '^135022d0' $OUT/SHA256SUMS || { echo "UNEXPECTED SHAS"; exit 1; }
OUT=$OUT bash $P/tools/preflight-b.sh > $L/preflight-17k-development.txt 2>&1; tail -1 $L/preflight-17k-development.txt
PF=/root/port17k-prod-preflight; rm -rf $PF; mkdir -p $PF
ln -s $R/system.img $PF/system.img; ln -s $OUT/vendor.img $PF/vendor.img; ln -s $OUT/boot.img $PF/boot.img; ln -s $OUT/my_stock.img $PF/my_stock.img
PROD_PROPS=1 OUT=$PF bash $P/tools/preflight-b.sh > $L/preflight-17k-production.txt 2>&1; tail -1 $L/preflight-17k-production.txt
mkdir -p /mnt/k17a /mnt/k17b
mount -t ext4 -o loop,ro $R/vendor.img /mnt/k17a; mount -t ext4 -o loop,ro $OUT/vendor.img /mnt/k17b
{ echo "== vendor 17j-r2 (release/17j/images/vendor.img d8f45456) vs 17k (out-plk-build17k/vendor.img)"; diff -qr --no-dereference /mnt/k17a /mnt/k17b; echo "diff exit=$?"; } > $L/vendor-17j-vs-17k-diff.txt 2>&1
umount /mnt/k17a /mnt/k17b; cat $L/vendor-17j-vs-17k-diff.txt
