. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m /mnt/i-sys/system/euclid/odm.img /mnt/i-eodm
ls /mnt/i-odm/vendor /mnt/i-odm/vendor/*; 
echo; find /mnt/i-odm /mnt/i-eodm /mnt/i-hv /mnt/i-sys -name 'nfc_nci*' -o -name 'hal_libnfc*' -o -name 'ese_client*' 2>/dev/null
echo; grep -h 'ro.product\|ro.odm' /mnt/i-odm/build.prop | head; 
ls -la /mnt/i-eodm/bin/hw | grep -i 'nfc\|secure\|charger\|crypto'; ls /mnt/i-eodm/lib64 | head -50
