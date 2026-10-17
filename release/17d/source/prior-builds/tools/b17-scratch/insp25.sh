. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
grep -rn 'p73\|/dev/ese\|secure_element\|nq-nci\|st21nfc' /mnt/i-lv/etc/init /mnt/i-lv/ueventd.rc /mnt/i-lv/etc/ueventd.rc /mnt/i-lv/odm/etc/init 2>/dev/null | head
grep -n 'ESE\|SE_\|ESE_\|SPI' /mnt/i-lv/etc/libnfc-nxp.conf | head -20
echo --- stock cfg 18821; grep -n 'ESE\|NXP_SE\|SPI\|NXP_NFC_SE\|DEFAULT_SE' /mnt/i-eodm/etc/nfc/libnfc-nxp.conf_18821 | head -20; ls /mnt/i-eodm/etc/ | grep libese; head -30 /mnt/i-eodm/etc/libese-nxp.conf
echo --- kernel strings p73
strings $P/LineageOS24/boot.img 2>/dev/null | grep -m3 'p73'
