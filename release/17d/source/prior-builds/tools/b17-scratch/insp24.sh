. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
strings /mnt/i-s16/system/bin/vold | grep -n 'vendor_de\|vendor_ce' | head
sed -n 1580,1600p /mnt/i-s16/system/etc/init/hw/init.rc
grep -rn 'vendor_de' /mnt/i-lv/etc/init/ /mnt/i-lv/odm/etc/init 2>/dev/null | head -5
grep -rn 'vendor_de' /mnt/i-sys/system/etc/init/hw/init.rc | head -5
