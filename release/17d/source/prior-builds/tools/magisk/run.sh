set -e
mkdir -p /data/reserve
chown system:system /data/reserve
chmod 0771 /data/reserve
mv /data/local/tmp/reserve.img /data/reserve/reserve.img
chown root:root /data/reserve/reserve.img
chmod 0644 /data/reserve/reserve.img
restorecon -R /data/reserve
ls -laZ /data/reserve
sha256sum /data/reserve/reserve.img
sync