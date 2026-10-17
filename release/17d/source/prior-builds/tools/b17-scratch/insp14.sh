. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
cd /mnt/i-s16
echo --- jars; ls system_ext/framework | grep -i 'vendor.nfc\|nfcvendor\|cryptoeng\|charger\|oplus.hardware' | head; ls system/framework | grep -i 'cryptoeng\|charger\|vendor.oplus' | head
ls system_ext/etc/permissions | grep -i 'nfc\|crypto\|charger\|vendor-oplus\|se\.' | head -20
grep -rl 'cryptoeng\|hardware.charger' system_ext/etc/permissions system/etc/permissions my_*/etc/permissions 2>/dev/null | head
echo --- donor NFC apps; find system_ext system product my_product my_stock -maxdepth 3 -iname '*nfc*' 2>/dev/null | head -20
echo --- wallet; find . -maxdepth 4 -iname '*wallet*' 2>/dev/null | head
echo --- stock SE conf; ls /mnt/i-eodm/etc | grep -i 'ese\|nfc\|se_' ; ls /mnt/i-eodm/etc/nfc | head -3
echo --- config_ready strings; strings /mnt/i-eodm/lib64/ese_spi_nxp_nq330.so | grep -i 'config_ready\|nfc_se\|/dev/\|\.conf\|vendor\.nfc\|persist\|ro\.' | head -30
strings /mnt/i-eodm/lib64/vendor.nxp.nxpnfc@1.0.so | grep -i INxp | head -3
echo --- LOS nfc props; strings /mnt/i-lv/bin/hw/android.hardware.nfc-service.nxp | grep -i 'config_ready\|vendor.nfc' | head; strings /mnt/i-lv/lib64/nfc_nci_nxp_snxxx.so | grep -i 'config_ready\|nfc_se' | head
