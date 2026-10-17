export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=/mnt/c/Users/Han/Project/OnePlus7Port
mkdir -p /mnt/o-s; mountpoint -q /mnt/o-s || mount -o ro,loop -t erofs $P/out-plk-build16/system.img /mnt/o-s
cd /mnt/o-s
ls system_ext/framework | grep -i 'hardware.charger'; ls system/framework | grep -i 'hardware.charger'
for j in $(ls system/framework/*.jar system_ext/framework/*.jar 2>/dev/null); do for d in $(unzip -Z1 $j 2>/dev/null | grep '\.dex$'); do if unzip -p $j $d 2>/dev/null | grep -aq 'getIChargerService'; then echo "HIT $j $d"; fi; done; done
