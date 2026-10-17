. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
find /mnt/i-eodm /mnt/i-eodm/lib -name '*nxp*' -not -path '*/etc/nfc/*' | sort
ls /mnt/i-eodm/lib64/hw | head -30
echo ---; grep -rn 'config_ready\|ese' /mnt/i-eodm/etc/init/init.pn8x.nfc.rc /mnt/i-eodm/etc/init/android.hardware.nfc@1.2-service.rc /mnt/i-eodm/etc/init/vendor.oplus.hardware.nfc@1.0-service.rc | head -20
cat /mnt/i-eodm/etc/vintf/manifest/manifest_nfc_nq330.xml
