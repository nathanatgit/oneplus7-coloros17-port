. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
H=$P/research/h40-breeno
echo --- donor libs; ls -la /mnt/i-s16/system_ext/lib*/liblisten* ; ls -la /mnt/i-sys/system/system_ext/lib*/liblisten*; ls -la $H/*.so
sha256sum $H/*.H40.so /mnt/i-sys/system/system_ext/lib64/liblisten*.so /mnt/i-sys/system/system_ext/lib/liblisten*.so /mnt/i-s16/system_ext/lib64/liblisten*.so /mnt/i-s16/system_ext/lib/liblisten*.so
echo --- who NEEDs them
for f in $(find /mnt/i-s16/system /mnt/i-s16/system_ext /mnt/i-s16/product /mnt/i-s16/my_product -type f \( -name '*.so' -o -path '*/bin/*' \) 2>/dev/null); do
  if readelf -d $f 2>/dev/null | grep -q 'liblisten'; then echo "NEEDED-BY $f"; fi; done 2>/dev/null | head -20
echo --- who dlopen/strings
grep -rl 'liblistenjni\|liblistensoundmodel\|listenjni' /mnt/i-s16/system_ext /mnt/i-s16/system/lib64 /mnt/i-s16/system/etc /mnt/i-s16/my_product 2>/dev/null | head -20
echo --- apks embedding libs
for a in $(find /mnt/i-s16/system_ext /mnt/i-s16/product /mnt/i-s16/system/app /mnt/i-s16/system/priv-app /mnt/i-s16/my_product -name '*.apk' 2>/dev/null); do unzip -l $a 2>/dev/null | grep -q 'liblisten' && echo "APK-WITH $a"; done | head
echo --- exports; for f in $H/liblistenjni.qti.H40.so /mnt/i-s16/system_ext/lib64/liblistenjni.qti.so; do echo $f; nm -D --defined-only $f | awk '{print $3}' | sort | md5sum; nm -D --defined-only $f | wc -l; done
for f in $H/liblistensoundmodel2.qti.H40.so /mnt/i-s16/system_ext/lib64/liblistensoundmodel2.qti.so; do echo $f; nm -D --defined-only $f | awk '{print $3}' | sort | md5sum; nm -D --defined-only $f | wc -l; done
echo --- permissions; grep -n 'voicewakeup' -A12 /mnt/i-s16/system/etc/permissions/privapp-permissions-oplus.xml | head -30
ls -d /mnt/i-s16/my_product/priv-app /mnt/i-s16/my_product/app | head; ls /mnt/i-s16/my_product/priv-app | head -30
find /mnt/i-s16 -ipath '*voicewakeup*' -o -ipath '*OVoiceManagerService*' 2>/dev/null | head
