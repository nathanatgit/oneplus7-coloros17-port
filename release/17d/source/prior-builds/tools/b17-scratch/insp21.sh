. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
cd /root/b17
cp /mnt/i-s16/system/framework/framework-res.apk c17-fwres.apk 2>/dev/null || find /mnt/i-s16 -name framework-res.apk | head -2
python3 -I /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/sigcert.py c17-sysui.apk h40-sysui.apk h40-se.apk c17-fwres.apk /mnt/c/Users/Han/Project/OnePlus7Port/research/h40-breeno/OVoiceManagerServiceOnePlus-H40.apk /mnt/c/Users/Han/Project/OnePlus7Port/research/h40-breeno/patch/OVoiceManagerServiceOnePlus-H40-plk110.apk
for a in h40-sysui h40-se; do unzip -p $a.apk META-INF/CERT.RSA | openssl pkcs7 -inform DER -print_certs | openssl x509 -outform DER | sha256sum; done
