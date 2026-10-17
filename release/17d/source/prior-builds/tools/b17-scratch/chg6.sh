export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
K=/mnt/k-odm; mkdir -p $K; mountpoint -q $K || mount -o ro,loop /mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/out/odm.img $K
find $K -iname '*cryptoeng*' | grep -v oat | head -20; find $K -iname '*secure_element*' | head
cat $K/etc/vintf/manifest/manifest_oplus_cryptoeng*.xml 2>/dev/null | grep -v '^ *\*\|^<!--\|-->'
readelf -d $K/lib64/vendor.oplus.hardware.charger-V3-ndk_platform.so | grep NEEDED | sed 's/.*\[//;s/\]//' | tr '\n' ' '
echo; readelf -d $K/bin/hw/vendor.oplus.hardware.charger-V3-service | grep NEEDED | sed 's/.*\[//;s/\]//' | tr '\n' ' '
