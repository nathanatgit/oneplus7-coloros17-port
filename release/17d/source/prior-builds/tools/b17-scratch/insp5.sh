. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
for l in libqsee_keybox_ca.so ese_spi_nxp_nq330.so ls_client.so vendor.nxpnq330.nxpese@1.0.so vendor.nxp.eventprocessor@1.0.so vendor.nxp.nxpnfc@1.0.so ese_client.so android.hardware.nfc@1.0.so android.hardware.nfc@1.1.so android.hardware.secure_element@1.2.so vendor.oplus.hardware.charger@1.0.so; do
 echo "== $l"; for r in /mnt/i-odm /mnt/i-hv /mnt/i-lv /mnt/i-sys/system /mnt/i-s16; do find $r -name "$l" 2>/dev/null; done; done
echo === LOS nfc; ls -la /mnt/i-lv/bin/hw | grep -i 'nfc\|se_\|secure\|esese'; ls /mnt/i-lv/lib64 | grep -i 'nxp\|nfc\|ese'; ls /mnt/i-lv/etc/init | grep -i nfc; cat /mnt/i-lv/etc/init/nfc-service-nxp.rc
echo === LOS manifest SE; sed -n 50,75p /mnt/i-lv/etc/vintf/manifest.xml; ls /mnt/i-lv/etc/vintf/manifest /mnt/i-lv/odm/etc/vintf 2>&1
echo === LOS secure_element
find /mnt/i-lv -iname '*secure_element*' | head
