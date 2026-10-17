O=/data/local/tmp/oplogs
rm -rf $O; mkdir -p $O
cp -r /mnt/vendor/oplusreserve/recovery $O/
cp -r /mnt/vendor/oplusreserve/boot_log $O/ 2>/dev/null
cp /mnt/vendor/oplusreserve/fs_mgr_log $O/ 2>/dev/null
cp /mnt/vendor/oplusreserve/normal_reboot $O/ 2>/dev/null
cp -r /mnt/vendor/oplusreserve/media/log/criticalLog $O/ 2>/dev/null
chmod -R a+rX $O
ls -laR $O | head -80
