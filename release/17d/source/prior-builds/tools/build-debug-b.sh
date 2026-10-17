#!/usr/bin/env bash
# DEBUG ONLY: boot-time kernel log capture for the Phase B port (LineageOS kernel has no pstore).
#   out-b-debug/boot.img   = out-b/boot.img + /bb (static busybox) + /init wrapper that streams /dev/kmsg into
#                            <metadata>/port-kmsg.txt (mounted -o sync, so lines survive init's fatal reboot)
#   out-b-debug/vendor.img = out-b/vendor.img + (typepermissive kernel) so SELinux cannot stop the logger
# Read the log afterwards from Lineage Recovery: mount the metadata partition, cat port-kmsg.txt.
set -euo pipefail
P=/mnt/c/Users/Han/Project/OnePlus7Port
BB=/mnt/c/Users/Han/AppData/Local/Temp/claude/C--Users-Han-Project-OnePlus7Port/33535023-9458-4dd6-9a41-edc03a2d24ff/scratchpad/magisk/lib/arm64-v8a/libbusybox.so
SRC=${SRC_OUT:-$P/out-b}; W=/root/cos17b-debug; OUT=${DBG_OUT:-$P/out-b-debug}
rm -rf "$W" && mkdir -p "$W/rd" "$OUT"

python3 -I $P/tools/bootimg_v2.py unpack $SRC/boot.img "$W"
lz4 -dc "$W/ramdisk" > "$W/ramdisk.cpio"
(cd "$W/rd" && cpio -idm --quiet < ../ramdisk.cpio)
[ -L "$W/rd/init" ] || { echo "expected /init symlink"; exit 1; }
rm "$W/rd/init"
# v2: static C logger (v1 busybox script crashed even a plain LineageOS boot: the kernel has no DEVTMPFS).
command -v aarch64-linux-gnu-gcc >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gcc-aarch64-linux-gnu >/dev/null
aarch64-linux-gnu-gcc -static -O2 -Wall -o "$W/rd/init" $P/tools/port-logger.c
chmod 0750 "$W/rd/init"; file "$W/rd/init"
if false; then   # v1 wrapper kept for reference; not installed
cat > "$W/rd/init" <<'EOF'
#!/bb sh
# kmsg logger, then the real first-stage init (/system/bin/init in this ramdisk). Debug builds only.
/bb mkdir -p /dev /proc /sys /logmnt
/bb mount -t devtmpfs devtmpfs /dev
/bb mount -t proc proc /proc
/bb mount -t sysfs sysfs /sys
for u in /sys/class/block/*/uevent; do
  if /bb grep -qx 'PARTNAME=metadata' "$u"; then dev=$(/bb sed -n 's/^DEVNAME=//p' "$u"); fi
done
if [ -n "${dev:-}" ] && /bb mount -t ext4 -o sync,noatime "/dev/$dev" /logmnt; then
  /bb mv -f /logmnt/port-kmsg.txt /logmnt/port-kmsg.prev.txt 2>/dev/null
  echo "port-logger: start, metadata=/dev/$dev" > /dev/kmsg
  /bb cat /dev/kmsg > /logmnt/port-kmsg.txt &
  /bb usleep 300000          # let cat open both files before the mounts are detached
  /bb umount -l /logmnt      # lazy: cat keeps its open fds; the mount leaves the mount table
else
  echo "port-logger: metadata mount failed (dev=${dev:-none})" > /dev/kmsg
fi
# First-stage init's SwitchRoot() MS_MOVEs every mount of the ramdisk root into /system and PLOG(FATAL)s on
# failure (crashed debug build 1 into 900E). Leave no mounts behind: lazy-detach devtmpfs (open fds survive).
/bb umount /sys; /bb umount /proc; /bb umount -l /dev
exec /system/bin/init "$@"
EOF
fi
(cd "$W/rd" && find . | LC_ALL=C sort | cpio -o -H newc --quiet -R 0:0) > "$W/ramdisk.new.cpio"
lz4 -l -12 -f -q "$W/ramdisk.new.cpio" "$W/ramdisk.new"
python3 -I $P/tools/bootimg_v2.py repack $SRC/boot.img "$W/ramdisk.new" "$OUT/boot.img"
# Debug: no /dev/kmsg rate limiting, so init's own error lines reach the log.
python3 -I $P/tools/bootimg_v2.py cmdline "$OUT/boot.img" "$OUT/boot.img" printk.devkmsg=on

cp $SRC/vendor.img "$W/vendor.img"
mkdir -p /mnt/vdbg && mount -o loop "$W/vendor.img" /mnt/vdbg
F=/mnt/vdbg/etc/selinux/vendor_sepolicy.cil
grep -q '^(typepermissive kernel)' $F || printf '(typepermissive kernel)\n' >> $F
# logcat capture (vold/keystore2 log to logcat, not kmsg): run in the existing logpersist domain, permissive here.
grep -q '^(typepermissive logpersist)' $F || printf '(typepermissive logpersist)\n' >> $F
cat > /mnt/vdbg/etc/init/port-logcat.rc <<'EOF'
# DEBUG ONLY (OnePlus7Port): persist logcat of every boot to /metadata/port-logcat.txt (rotated to .prev).
service port_logcat /system/bin/logcat -b all -v threadtime -f /metadata/port-logcat.txt -r 8192 -n 1
    user root
    group log
    seclabel u:r:logpersist:s0
    oneshot
    disabled

on post-fs
    rm /metadata/port-logcat.txt.1
    start port_logcat
EOF
chmod 0644 /mnt/vdbg/etc/init/port-logcat.rc
setfattr -n security.selinux -v u:object_r:vendor_configs_file:s0 /mnt/vdbg/etc/init/port-logcat.rc
tail -2 $F; ls -lZ /mnt/vdbg/etc/init/port-logcat.rc; umount /mnt/vdbg
e2fsck -fn "$W/vendor.img" > /dev/null && echo "vendor fsck clean"
cp "$W/vendor.img" "$OUT/vendor.img"
(cd "$OUT" && sha256sum boot.img vendor.img)
