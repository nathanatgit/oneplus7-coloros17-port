. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
for f in lib64/ese_spi_nxp_nq330.so lib64/ese_client.so lib64/ls_client.so bin/hw/android.hardware.secure_elementnq330@1.1-service; do echo "## $f"; strings /mnt/i-eodm/$f | grep -i 'conf\|/odm/\|/vendor/\|/data/\|/dev/\|ro\.\|persist\.\|vendor\.' | head -20; done
ls /mnt/i-lv/etc/libese* /mnt/i-lv/etc/libnfc* 2>&1 | head
ls -la /mnt/i-eodm/etc/libese-nxp.conf
