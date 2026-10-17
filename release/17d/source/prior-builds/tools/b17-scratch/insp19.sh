. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
cd /mnt/i-lv
ls -lZ odm/bin/hw/vendor.oplus.hardware.biometrics.fingerprint@2.1-service odm/bin/hw/vendor.oplus.hardware.oplusSensor@1.0-service
cat odm/etc/init/vendor.oplus.hardware.oplusSensor@1.0-service.rc odm/etc/init/vendor.oplus.hardware.biometrics.fingerprint@2.1-service.rc | head -40
df -h /mnt/i-lv | tail -1; ls -l $P/LineageOS24/payload/vendor.img
grep -n 'odm' etc/selinux/vendor_file_contexts | head; grep -c . etc/selinux/vendor_file_contexts
cat $P/tools/patch-vendor-sepolicy.py | head -60
