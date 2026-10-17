. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
ls /root /usr/local/bin | head -50; ls /root/jadx/bin 2>/dev/null
E=/mnt/i-eodm
echo --- stock eodm etc; ls $E/etc | head -60
echo --- conf; ls $E/etc/nfc | grep 18821
strings $E/lib64/ese_spi_nxp_nq330.so | grep -i 'config_ready\|nfc_se\|/dev/\|\.conf\|vendor\.nfc\|persist\|ro\.' | head -30
strings $E/lib64/ls_client.so | grep -i '\.conf\|/data\|persist\|vendor\.' | head
