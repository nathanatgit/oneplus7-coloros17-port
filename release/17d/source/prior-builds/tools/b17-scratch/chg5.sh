export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
K=/mnt/k-odm; mkdir -p $K; mountpoint -q $K || mount -o ro,loop /mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/out/odm.img $K
cat $K/etc/init/vendor.oplus.hardware.charger-V3-service.rc; echo; cat $K/etc/vintf/manifest/manifest_oplus_charger_aidl.xml; echo; cat $K/etc/permissions/vendor-oplus-hardware-charger.xml
readelf -d $K/bin/hw/vendor.oplus.hardware.charger-V3-service | grep NEEDED | sed 's/.*\[//;s/\]//' | tr '\n' ' '; echo
ls -laZ $K/bin/hw/vendor.oplus.hardware.charger-V3-service $K/lib64/vendor.oplus.hardware.charger-V3-ndk_platform.so
strings $K/bin/hw/vendor.oplus.hardware.charger-V3-service | grep -E '^/(sys|proc|dev)' | head -40
