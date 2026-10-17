. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m $P/LineageOS24/payload/system.img /mnt/i-ls
cp /mnt/i-ls/system/app/SecureElement/SecureElement.apk $P/tools/b17-scratch/se/los-SecureElement.apk
ls -laZ /mnt/i-ls/system/app/SecureElement
grep -rn 'omapi\|secure_element' /mnt/i-s16/system/etc/vintf/manifest.xml /mnt/i-s16/system/etc/vintf/manifest/ 2>/dev/null | head; grep -rn 'omapi' /mnt/i-ls/system/etc/vintf/ 2>/dev/null | head -3
grep -rn 'SecureElement' /mnt/i-ls/system/etc/permissions /mnt/i-ls/system/etc/sysconfig 2>/dev/null | head -5
getfattr -n security.selinux --only-values /mnt/i-ls/system/app/SecureElement/SecureElement.apk; echo
