. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
cp /mnt/i-sys/system/system_ext/app/SecureElement/SecureElement.apk $P/tools/b17-scratch/se/h40-SecureElement.apk
cp /mnt/i-sys/system/system_ext/etc/permissions/com.vendor.nfc.xml $P/tools/b17-scratch/se/ 2>/dev/null
cp /mnt/i-sys/system/system_ext/framework/com.vendor.nfc.jar $P/tools/b17-scratch/se/ 2>/dev/null
cat /mnt/i-sys/system/system_ext/etc/permissions/com.vendor.nfc.xml
grep -n 'secure_element' /mnt/i-s16/system/etc/passwd /mnt/i-s16/system/etc/group 2>/dev/null | head -2; strings /mnt/i-s16/system/bin/init | grep -m3 secure_element
