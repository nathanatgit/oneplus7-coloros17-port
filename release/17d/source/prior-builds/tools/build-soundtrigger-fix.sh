#!/usr/bin/env bash
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
OUT="$P/out-plk-soundtrigger21"
M=/mnt/port-st21
mkdir -p "$OUT" "$M"
mountpoint -q "$M" && { echo 'Mountpoint already occupied'; exit 1; }
cp "$P/out-plk-debug/vendor.img" "$OUT/vendor.img"
mount -o loop "$OUT/vendor.img" "$M"
trap 'umount "$M"' EXIT
bash "$P/tools/patch-soundtrigger.sh" "$M"
umount "$M"
trap - EXIT
e2fsck -fn "$OUT/vendor.img"
sha256sum "$OUT/vendor.img" > "$OUT/SHA256SUMS"
