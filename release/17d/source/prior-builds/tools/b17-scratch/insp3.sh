P=/mnt/c/Users/Han/Project/OnePlus7Port
mkdir -p /mnt/i-lv; mountpoint -q /mnt/i-lv || mount -o ro,loop $P/LineageOS24/payload/vendor.img /mnt/i-lv
cd /mnt/i-lv
echo --- odm; ls -la odm odm/bin odm/bin/hw 2>&1 | head -60
echo --- sepolicy hits
for d in hal_charger_oplus hal_cryptoeng_oppo hal_secure_element_default hal_secure_element hal_cryptoeng_oplus charger_hal_oplus cryptoeng; do echo "$d: vendor=$(grep -c "$d" etc/selinux/vendor_sepolicy.cil) pubver=$(grep -c "$d" etc/selinux/plat_pub_versioned.cil)"; done
grep -o '(type [a-z_]*\(charger\|cryptoeng\|secure_element\)[a-z_]*' etc/selinux/vendor_sepolicy.cil | sort -u
grep -o '(type [a-z_]*\(charger\|cryptoeng\|secure_element\)[a-z_]*' /mnt/i-sys/system/etc/selinux/plat_sepolicy.cil 2>/dev/null | sort -u
echo --- deps
for b in vendor.oplus.hardware.charger@1.0-service vendor.oplus.hardware.cryptoeng@1.0-service android.hardware.secure_elementnq330@1.1-service; do echo "## $b"; readelf -d /mnt/i-odm/bin/hw/$b | grep NEEDED; done
echo --- vintf; grep -n 'secure_element\|charger\|cryptoeng\|nfc' etc/vintf/manifest.xml etc/vintf/manifest/* odm/etc/vintf/manifest/* 2>/dev/null
echo --- libs present
for l in libhidlbase libhwbinder libutils libcutils liblog libbase libqseecomapi libQSEEComAPI libGPQeSE libtinyxml2 libese-hal libnqnfc_ese libpn54x; do echo "$l: $(ls lib64/$l.so 2>&1 | head -1) | $(ls odm/lib64/$l.so 2>&1|head -1)"; done
ls odm/lib64 | head -100
ls etc/init | grep -i 'nfc\|se\b\|secure\|charg'
ls /vendor 2>/dev/null | head -0
