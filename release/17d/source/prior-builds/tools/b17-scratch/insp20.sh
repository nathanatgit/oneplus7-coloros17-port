. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
cd /mnt/i-s16/system/etc/init
grep -n 'vendor_de\|init_user0\|^on post-fs-data\|^on boot$' hw/init.rc | head -30
grep -rn 'vendor_de' /mnt/i-lv/etc/init /mnt/i-lv/odm/etc/init | head
grep -rn 'vendor_de' /mnt/i-s16/system_ext/etc/init /mnt/i-s16/system/etc/init 2>/dev/null | head
