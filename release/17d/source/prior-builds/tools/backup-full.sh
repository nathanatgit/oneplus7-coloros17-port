#!/usr/bin/env bash
# Full phone backup (needs Magisk root granted to adb shell).
# Each item is written to a temp dir on the phone, hashed there, pulled, and re-hashed on the PC.
# (Streaming large partitions through `adb exec-out` stalled, so everything goes via files.)
set -u
export MSYS_NO_PATHCONV=1
B=/c/Users/Han/Project/OnePlus7Port/Backup-2026-10-14
T=/data/local/tmp/bk
mkdir -p "$B/partitions" && cd "$B"
touch SHA256SUMS backup.log   # resumable: items already logged "ok" are skipped
done_ok() { grep -qx "ok $1" backup.log; }
adb shell "su -c 'rm -rf $T; mkdir -p $T'"

fetch() {  # fetch <remote file> <local name>: pull a file from $T and verify its hash
  local r l
  r=$(adb shell "su -c 'chmod 644 $1; sha256sum $1'" | tr -d '\r' | cut -d' ' -f1)
  adb pull "$1" "$2" > /dev/null
  l=$(sha256sum "$2" | cut -d' ' -f1)
  echo "$l  $2" >> SHA256SUMS
  if [ "$r" = "$l" ]; then echo "ok $2" | tee -a backup.log; else echo "MISMATCH $2" | tee -a backup.log; fi
  adb shell "su -c 'rm -f $1'"
}

# 1. Every partition except userdata (raw userdata is encrypted to this phone's hardware keys,
#    ~223 GB, and inconsistent while mounted; /data is captured at file level below).
parts=$(adb shell "su -c 'ls /dev/block/bootdevice/by-name'" | tr -d '\r' | grep -v '^userdata$')
for p in $parts; do
  done_ok "partitions/$p.img" && continue
  rm -f "partitions/$p.img"
  adb shell "su -c 'dd if=/dev/block/bootdevice/by-name/$p of=$T/$p.img bs=1048576 2>/dev/null'"
  fetch "$T/$p.img" "partitions/$p.img"
done

# 2. /data at file level while decrypted. Skipped: media (own archive), reserve/reserve.img
#    (byte-identical to StockRom/H40-images/reserve.img), and our own temp dir.
if ! done_ok data.tar; then
  adb shell "su -c 'tar -cf $T/data.tar -C /data --exclude=./media --exclude=./reserve --exclude=./local/tmp/bk . 2>$T/data-tar.err'"
  adb shell "su -c 'cat $T/data-tar.err'" > data-tar-warnings.txt
  fetch "$T/data.tar" data.tar
fi
# 3. Internal storage (photos, downloads, ...).
if ! done_ok media.tar; then
  adb shell "su -c 'tar -cf $T/media.tar -C /data/media . 2>$T/media-tar.err'"
  adb shell "su -c 'cat $T/media-tar.err'" > media-tar-warnings.txt
  fetch "$T/media.tar" media.tar
fi
adb shell "su -c 'rm -rf $T'"

for t in data.tar media.tar; do
  if n=$(tar -tf "$t" 2>/dev/null | wc -l); then echo "ok $t entries=$n" | tee -a backup.log; else echo "CORRUPT $t" | tee -a backup.log; fi
done
mkdir -p sdcard && tar -xf media.tar -C sdcard 2> tar-extract-warnings.txt
echo "DONE mismatches=$(grep -c MISMATCH backup.log)" | tee -a backup.log
du -sh "$B"
