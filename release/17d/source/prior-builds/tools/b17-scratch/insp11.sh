. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m $P/LineageOS24/payload/system.img /mnt/i-ls
echo --- LOS system SE; find /mnt/i-ls /mnt/i-s16 -ipath '*SecureElement*' -o -iname '*com.android.se*' -o -iname '*omapi*' -o -iname 'android.se*' 2>/dev/null | head -20
ls /mnt/i-ls | head; 
echo --- S16 overlay; find /mnt/i-s16 -iname '*SecureElement*overlay*' -o -iname '*se*overlay*' | head
grep -rl 'com.android.se' /mnt/i-s16/system/etc/permissions /mnt/i-s16/system_ext/etc /mnt/i-s16/product/etc 2>/dev/null | head
echo --- sepolicy secure_element in s16
grep -c secure_element /mnt/i-s16/system/etc/selinux/plat_sepolicy.cil
grep 'secure_element' /mnt/i-s16/system/etc/selinux/plat_service_contexts /mnt/i-s16/system/etc/selinux/plat_hwservice_contexts 2>/dev/null | head
grep -rn 'hal_charger_oplus\|cryptoeng\|hal_secure_element_default\|charger@1.0\|ICharger\|ICryptoeng' /mnt/i-s16/system/etc/selinux/*_contexts /mnt/i-s16/system_ext/etc/selinux/*_contexts /mnt/i-lv/etc/selinux/*contexts 2>/dev/null | head -20
echo --- owner s16 hwservice
ls /mnt/i-s16/system_ext/etc/selinux
