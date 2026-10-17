. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m /mnt/i-sys/system/euclid/odm.img /mnt/i-eodm
cd /mnt/i-eodm; ls; echo; ls bin/hw 2>&1 | head -50; echo; ls lib64 | wc -l; ls lib64
echo; ls etc/init etc/vintf etc/vintf/manifest 2>&1 | head -80
echo ---cmp; for f in bin/hw/vendor.oplus.hardware.charger@1.0-service bin/hw/vendor.oplus.hardware.cryptoeng@1.0-service bin/hw/android.hardware.secure_elementnq330@1.1-service lib64/vendor.oplus.hardware.charger@1.0.so; do cmp /mnt/i-eodm/$f /mnt/i-odm/$f && echo same $f; done
