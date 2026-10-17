. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m $P/LineageOS24/payload/system.img /mnt/i-ls
mkdir -p /root/b17; cd /root/b17
cp /mnt/i-ls/system/app/SecureElement/SecureElement.apk los-se.apk
cp /mnt/i-sys/system/system_ext/app/SecureElement/SecureElement.apk h40-se.apk
cp /mnt/i-s16/system_ext/priv-app/SystemUI/SystemUI.apk c17-sysui.apk
cp /mnt/i-sys/system/system_ext/priv-app/SystemUI/SystemUI.apk h40-sysui.apk 2>/dev/null
ls -la
for a in los-se h40-se c17-sysui h40-sysui; do echo "## $a"; (apksigner verify --print-certs -v $a.apk 2>&1 | grep -i 'certificate SHA-256\|Verifies\|DOES' | head -3); done
