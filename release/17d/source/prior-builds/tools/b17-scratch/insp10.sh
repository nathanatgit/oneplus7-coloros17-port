. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m /mnt/i-sys/system/euclid/odm.img /mnt/i-eodm
cd /mnt/i-eodm
echo; for f in lib64/ese_client.so lib64/libqsee_keybox_ca.so lib64/vendor.oplus.hardware.commondcs@1.0.so; do cmp $f /mnt/i-odm/$f 2>&1|head -1; done
ls /mnt/i-odm/lib64 | wc -l
# port odm lib64 vs stock odm same names
cd /mnt/i-lv/odm/lib64; for f in vendor.oplus.hardware.commondcs@1.0.so libwvhidl.so; do cmp $f /mnt/i-eodm/lib64/$f && echo "same as euclid $f"; cmp $f /mnt/i-odm/lib64/$f && echo "same as odm $f"; done
echo; ls -lZ /mnt/i-eodm/lib64/ese_client.so /mnt/i-eodm/lib64/libqsee_keybox_ca.so /mnt/i-eodm/lib64/ls_client.so /mnt/i-eodm/lib64/vendor.nxp.nxpnfc@1.0.so
echo ---- eodm vintf; ls /mnt/i-eodm/etc/vintf /mnt/i-eodm/etc/vintf/manifest
echo ---- deps of other new libs
for l in ese_spi_nxp_nq330 ls_client ese_client vendor.nxpnq330.nxpese@1.0 vendor.nxp.eventprocessor@1.0 vendor.nxp.nxpnfc@1.0 libqsee_keybox_ca vendor.oplus.hardware.cryptoeng@1.0 vendor.oplus.hardware.charger@1.0 vendor.oplus.hardware.commondcs@1.0; do echo "## $l"; readelf -d /mnt/i-eodm/lib64/$l.so | grep NEEDED | sed 's/.*\[//;s/\]//' | tr '\n' ' '; echo; done
