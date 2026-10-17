#!/usr/bin/env bash
# Build a temporary (fastboot boot only) H.40 boot image: Magisk 30.7 patched boot + an overlay.d init script
# that enables adb early and authorizes only this PC's key. For recovering a wiped/bootlooping stock slot A.
# Run as root in WSL. Output: tools/magisk/boot-H40-magisk-adbfix.img
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
IN=$P/tools/magisk/boot-H40-magisk30.7.img
OUT=$P/tools/magisk/boot-H40-magisk-adbfix.img
W=/root/adbfix
rm -rf "$W" && mkdir -p "$W/rd"

python3 -I "$P/tools/bootimg_v2.py" unpack "$IN" "$W"
cd "$W/rd"
case "$(head -c2 ../ramdisk | od -An -tx1 | tr -d ' ')" in
  1f8b) zcat ../ramdisk | cpio -idm --quiet ;;
  *) echo "unexpected ramdisk compression"; exit 1 ;;
esac
[ -d overlay.d ] || { echo "not a Magisk-patched ramdisk"; exit 1; }

mkdir -p overlay.d/sbin
install -m 0644 /mnt/c/Users/Han/.android/adbkey.pub overlay.d/sbin/adb_keys
cat > overlay.d/init.adbfix.rc <<'EOF'
# Temporary recovery aid (fastboot boot only): adb on early, this PC's key authorized, no rescue reboots.
on post-fs-data
    mkdir /data/misc/adb 02750 system shell
    copy ${MAGISKTMP}/adb_keys /data/misc/adb/adb_keys
    chown system shell /data/misc/adb/adb_keys
    chmod 0640 /data/misc/adb/adb_keys
    restorecon /data/misc/adb/adb_keys
    setprop persist.sys.disable_rescue true
    setprop persist.sys.usb.config adb
    setprop sys.usb.config adb

# Root helper without the Magisk app (wiped): `adb shell setprop debug.adbfix.run 1` runs
# /data/local/tmp/run.sh as root in Magisk's domain; output goes to /data/local/tmp/run.log.
on property:debug.adbfix.run=1
    exec_background u:r:magisk:s0 root root -- /system/bin/sh -c "/system/bin/sh /data/local/tmp/run.sh > /data/local/tmp/run.log 2>&1; chmod 0644 /data/local/tmp/run.log; setprop debug.adbfix.run 0"
EOF
chmod 0644 overlay.d/init.adbfix.rc

find . | LC_ALL=C sort | cpio -o -H newc --quiet -R 0:0 | gzip -9 > ../ramdisk.new
python3 -I "$P/tools/bootimg_v2.py" repack "$IN" "$W/ramdisk.new" "$OUT"
sha256sum "$OUT"
