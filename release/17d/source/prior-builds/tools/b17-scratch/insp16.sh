. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
python3 -I /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/deps.py vendor.oplus.hardware.charger@1.0-service vendor.oplus.hardware.cryptoeng@1.0-service android.hardware.secure_elementnq330@1.1-service
echo; wc -l /mnt/i-s16/system/etc/llndk.libraries.txt; grep -c . /mnt/i-s16/system/etc/vndksp.libraries.txt
for l in libhidltransport.so libcutils.so liblog.so libbinder.so libhardware.so libjsoncpp.so libssl.so libcrypto.so libchrome.so libhwbinder.so; do echo "$l ll=$(grep -cx $l /mnt/i-s16/system/etc/llndk.libraries.txt) lv=$(ls /mnt/i-lv/lib64/$l 2>/dev/null)"; done
