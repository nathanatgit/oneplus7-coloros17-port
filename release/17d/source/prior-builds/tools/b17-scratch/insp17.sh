. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
python3 -I /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/deps.py android.hardware.secure_elementnq330@1.1-service vendor.oplus.hardware.cryptoeng@1.0-service vendor.oplus.hardware.charger@1.0-service | grep ADD | tr ',' '\n'
find /mnt/i-hv /mnt/i-lv /mnt/i-s16/system /mnt/i-sys/system -name 'libevent*' 2>/dev/null
echo; readelf -d /mnt/i-eodm/lib64/libchrome.so | grep NEEDED
echo; readelf -d /mnt/i-hv/lib64/libevent.so 2>/dev/null| grep -i 'soname\|NEEDED'
