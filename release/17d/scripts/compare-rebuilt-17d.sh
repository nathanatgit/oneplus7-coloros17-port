#!/usr/bin/env bash
set -euo pipefail
P="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
R="$P/release/17d"
mkdir -p /mnt/17d-old-system /mnt/17d-new-system /mnt/17d-old-vendor /mnt/17d-new-vendor /mnt/17d-old-mystock /mnt/17d-new-mystock
mountpoint -q /mnt/17d-old-system || mount -t erofs -o loop,ro "$P/out-plk-build17d/system.img" /mnt/17d-old-system
mountpoint -q /mnt/17d-new-system || mount -t erofs -o loop,ro "$R/images/rootless/system.img" /mnt/17d-new-system
mountpoint -q /mnt/17d-old-vendor || mount -t ext4 -o loop,ro "$P/out-plk-build17d/vendor.img" /mnt/17d-old-vendor
mountpoint -q /mnt/17d-new-vendor || mount -t ext4 -o loop,ro "$R/images/rootless/vendor.img" /mnt/17d-new-vendor
mountpoint -q /mnt/17d-old-mystock || mount -t erofs -o loop,ro "$P/out-plk-build17d/my_stock.img" /mnt/17d-old-mystock
mountpoint -q /mnt/17d-new-mystock || mount -t erofs -o loop,ro "$R/images/rootless/my_stock.img" /mnt/17d-new-mystock
echo '== system differences'
diff -qr --no-dereference /mnt/17d-old-system /mnt/17d-new-system || true
echo '== vendor differences'
diff -qr --no-dereference /mnt/17d-old-vendor /mnt/17d-new-vendor || true
echo '== my_stock differences'
diff -qr --no-dereference /mnt/17d-old-mystock /mnt/17d-new-mystock || true
