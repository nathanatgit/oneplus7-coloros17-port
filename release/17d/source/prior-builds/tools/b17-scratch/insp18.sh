. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
cd /mnt/i-lv
echo --- odm tree; find odm -maxdepth 3 -type d | sort; echo; ls -laZ odm/vendor/firmware | head -20; ls odm/vendor/firmware | wc -l; ls odm/etc odm/etc/init odm/etc/vintf/manifest 2>&1 | head -40
echo --- odm/firmware; ls odm/firmware | head -5
echo --- labels; getfattr -n security.selinux --only-values odm/etc/init/* 2>/dev/null | head -3; echo; for d in odm odm/bin/hw odm/lib64 odm/etc/init odm/etc/vintf/manifest odm/vendor/firmware; do echo "$d $(getfattr -n security.selinux --only-values $d) $(stat -c '%U:%G %a' $d)"; done
ls -lZ odm/bin/hw/ odm/lib64/vendor.oplus.hardware.commondcs@1.0.so
echo --- ls /mnt/i-lv/firmware cryptoeng; ls /mnt/i-lv/firmware 2>/dev/null | head; find /mnt/i-lv -iname 'cryptoeng*' | head
echo --- file_contexts in LOS vendor for odm
grep -n 'odm' etc/selinux/vendor_file_contexts | head -30
echo --- kernel qseecomd firmware path: strings
strings lib64/libQSEEComAPI.so | grep -i 'firmware\|/odm' | head
