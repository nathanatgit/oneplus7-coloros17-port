. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
readelf -d /mnt/i-odm/bin/hw/android.hardware.nfc@1.2-service | grep NEEDED
find /mnt/i-odm /mnt/i-hv /mnt/i-sys -iname '*nfc*' | grep -v '/etc/nfc/\|app/\|overlay\|oat' | head -40
ls /mnt/i-hv/lib64 | wc -l; ls /mnt/i-odm/lib64 | wc -l
ls /mnt/i-odm/lib64 | head -80
echo ---- strings of SE service for libs
strings /mnt/i-odm/bin/hw/android.hardware.secure_elementnq330@1.1-service | grep -i '\.so\|/dev/\|conf' | head -30
