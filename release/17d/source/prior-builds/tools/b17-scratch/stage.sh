set -e
. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
D=$P/tools/live/odm-services; rm -rf $D/stock; mkdir -p $D/stock/bin/hw $D/stock/lib64 $D/stock/firmware $D/stock/etc/vintf/manifest $D/stock/etc/init $D/app
E=/mnt/i-eodm
for b in vendor.oplus.hardware.charger@1.0-service vendor.oplus.hardware.cryptoeng@1.0-service android.hardware.secure_elementnq330@1.1-service; do cp $E/bin/hw/$b $D/stock/bin/hw/; done
for l in android.hardware.nfc@1.0 android.hardware.nfc@1.1 ese_client ese_spi_nxp_nq330 libchrome libqsee_keybox_ca ls_client vendor.nxp.eventprocessor@1.0 vendor.nxp.nxpnfc@1.0 vendor.nxpnq330.nxpese@1.0 vendor.oplus.hardware.charger@1.0 vendor.oplus.hardware.cryptoeng@1.0; do cp $E/lib64/$l.so $D/stock/lib64/; done
cp /mnt/i-sys/system/lib64/libevent.so $D/stock/lib64/libevent.so
cp $E/vendor/firmware/cryptoeng.* $D/stock/firmware/
cp $E/etc/libese-nxp.conf $D/stock/etc/
cp $E/etc/vintf/manifest/manifest_oplus_charger.xml $E/etc/vintf/manifest/manifest_oplus_cryptoeng.xml $D/stock/etc/vintf/manifest/
cp $E/etc/init/vendor.oplus.hardware.charger@1.0-service.rc $E/etc/init/vendor.oplus.hardware.cryptoeng@1.0-service_FDE.rc $E/etc/init/android.hardware.secure_elementnq330@1.1-service.rc $E/etc/init/init.pn8x.se.rc $D/stock/etc/init/
cp $P/tools/b17-scratch/se/los-SecureElement.apk $D/app/SecureElement-los24.apk
readelf -d $D/stock/lib64/libevent.so | grep -i 'soname\|NEEDED'
find $D -type f | wc -l; sha256sum $D/app/*.apk
