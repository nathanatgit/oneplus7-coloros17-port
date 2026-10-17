export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=/mnt/c/Users/Han/Project/OnePlus7Port
mkdir -p /mnt/o-v /mnt/o-lv; mountpoint -q /mnt/o-lv || mount -o ro,loop $P/LineageOS24/payload/vendor.img /mnt/o-lv
grep -n 'oplus_charger\|charger_aidl' /mnt/o-lv/etc/selinux/vendor_file_contexts /mnt/o-lv/etc/selinux/vendor_service_contexts 2>/dev/null | head
find /mnt/o-lv -iname '*charger*' | grep -v 'firmware\|selinux' | head -20
ls /mnt/o-lv/bin/hw | head -60
