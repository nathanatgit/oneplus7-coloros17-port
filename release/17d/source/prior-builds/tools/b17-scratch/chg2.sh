export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p /mnt/o-s; mountpoint -q /mnt/o-s || mount -o ro,loop -t erofs /mnt/c/Users/Han/Project/OnePlus7Port/out-plk-build16/system.img /mnt/o-s
cd /root/b17; for d in classes classes2; do unzip -o -q -j /mnt/o-s/system/framework/oplus-services.jar $d.dex -d os-$d; done
for d in classes classes2; do echo "## $d"; strings -a os-$d/$d.dex | grep -iE 'charger.*(ICharger|default)|ICharger|getIChargerService|ServiceManager.*charger|isDeclared' | sort -u | head -30; done
which dexdump
