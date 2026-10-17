cd /mnt/i-odm
for f in etc/init/vendor.oplus.hardware.charger@1.0-service.rc etc/vintf/manifest/manifest_oplus_charger.xml etc/permissions/vendor-oplus-hardware-charger.xml etc/init/vendor.oplus.hardware.cryptoeng@1.0-service_FDE.rc etc/vintf/manifest/manifest_oplus_cryptoeng.xml etc/permissions/vendor-oplus-hardware-cryptoeng.xml etc/init/android.hardware.secure_elementnq330@1.1-service.rc etc/init/init.pn8x.se.rc init.oplus.seccommon.rc; do echo "=== $f"; cat $f; done
echo === manifests; ls etc/vintf; grep -n -B2 -A8 secure_element etc/vintf/manifest_dsds.xml
echo === odm-bin; ls bin bin/hw
echo === SE app; ls -la /mnt/i-sys/system/system_ext/app/SecureElement /mnt/i-sys/system/system_ext/app/SecureElement/*; grep -il secure /mnt/i-sys/system/system_ext/etc/permissions/* /mnt/i-sys/system/etc/permissions/* 2>/dev/null
echo === mount ls; ls /mnt/i-myp/priv-app | head -50; ls -la /mnt/i-myp/priv-app/OVoiceManagerServiceOnePlus/*
