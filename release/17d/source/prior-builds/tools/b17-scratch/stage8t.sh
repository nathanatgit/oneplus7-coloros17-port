export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
K=/mnt/k-odm; mkdir -p $K; mountpoint -q $K || mount -o ro,loop /mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/out/odm.img $K
D=/mnt/c/Users/Han/Project/OnePlus7Port/tools/live/odm-services/stock8t; mkdir -p $D/bin/hw $D/lib64 $D/etc/vintf/manifest
cp $K/bin/hw/vendor.oplus.hardware.charger-V3-service $D/bin/hw/
for l in libosenseaidlhalclient vendor.oplus.hardware.charger-V3-ndk_platform vendor.oplus.hardware.osense.client-V1-ndk_platform; do cp $K/lib64/$l.so $D/lib64/; done
cp $K/etc/vintf/manifest/manifest_oplus_charger_aidl.xml $D/etc/vintf/manifest/
ls -R $D | head -20
