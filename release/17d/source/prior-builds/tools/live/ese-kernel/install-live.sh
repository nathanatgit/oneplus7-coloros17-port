mount -o remount,rw /vendor
cp /data/local/tmp/se.rc /vendor/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc
cp /data/local/tmp/se.xml /vendor/odm/etc/vintf/manifest/manifest_port_secure_element.xml
chmod 644 /vendor/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc /vendor/odm/etc/vintf/manifest/manifest_port_secure_element.xml
chcon u:object_r:vendor_configs_file:s0 /vendor/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc /vendor/odm/etc/vintf/manifest/manifest_port_secure_element.xml 2>&1
ls -lZ /vendor/odm/etc/init/vendor.oplus.hardware.charger@1.0-service.rc /vendor/odm/etc/init/android.hardware.secure_elementnq330@1.1-service.rc
mount -o remount,ro /vendor
