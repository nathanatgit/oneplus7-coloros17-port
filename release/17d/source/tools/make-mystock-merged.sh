#!/usr/bin/env bash
# OnePlus7Port: my_stock with the ColorOS 17 stock apps the Axis GSI donor lacks. Run as root inside WSL.
# The PLK110 GSI ships a reduced my_stock (40 apps). stock-app-source/ColorOS17-PLK110-app-source-clean.zip
# (KB2003 port of the same PLK110 ColorOS 17 build, payload FILE_HASH verified) has the full one (153 apps): same
# build.prop, same etc/ (permissions, sysconfig) and lib/overlay/media trees, 37 of the 40 common APKs byte-identical.
# Base = that full my_stock; the 3 APKs that differ (Aod, AIUnit, OppoGallery2: the port carries older builds) and
# etc/extension/com.oplus.app-features.xml are taken from the GSI donor's my_stock, so nothing already installed is
# downgraded. Output goes to /data/port/my_stock.img (loop-mounted by 00-port-mystock.rc).
#   make-mystock-merged.sh <full my_stock.img> <GSI donor my_stock.img> <out.img> [extra dir]
# [extra dir] is copied over the tree last (e.g. apps whose v2 signature was stripped: they only scan on a system partition).
set -euo pipefail
FULL=$1 DONOR=$2 OUT=$3 EXTRA=${4:-}
W=$(mktemp -d /root/mystock-merge.XXXX)
mkdir -p "$W/full" "$W/donor"
mount -o ro,loop "$FULL" "$W/full"; mount -o ro,loop "$DONOR" "$W/donor"
trap 'umount "$W/full" "$W/donor" 2>/dev/null; rm -rf "$W"' EXIT
cmp -s "$W/full/build.prop" "$W/donor/build.prop" || { echo "build.prop differs: not the same build"; exit 1; }
cp -a "$W/full" "$W/tree"
for d in app/Aod priv-app/AIUnit priv-app/OppoGallery2; do
  rm -rf "$W/tree/$d"; cp -a "$W/donor/$d" "$W/tree/$d"
done
cp -a "$W/donor/etc/extension/com.oplus.app-features.xml" "$W/tree/etc/extension/com.oplus.app-features.xml"
# Every APK that both images carry must now be the donor's.
(cd "$W/donor" && find . -name '*.apk') | while read -r a; do cmp -s "$W/donor/$a" "$W/tree/$a" || { echo "mismatch $a"; exit 1; }; done
[ -n "$EXTRA" ] && cp -a "$EXTRA/." "$W/tree/"
echo "apps: $(find "$W/tree" -name '*.apk' | wc -l) (donor $(find "$W/donor" -name '*.apk' | wc -l))"
rm -f "$OUT"
mkfs.erofs -zlz4hc,12 -E legacy-compress -b4096 --mount-point=/my_stock "$OUT" "$W/tree" > "$W/mkfs.log"
rm -rf "$W/tree"
ls -l "$OUT"; sha256sum "$OUT"
