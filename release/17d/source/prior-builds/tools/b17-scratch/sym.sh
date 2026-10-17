export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=/mnt/c/Users/Han/Project/OnePlus7Port
mkdir -p /mnt/o-s /mnt/o-v; mountpoint -q /mnt/o-s || mount -o ro,loop -t erofs $P/out-plk-build17/system.img /mnt/o-s
mountpoint -q /mnt/o-v || mount -o ro,loop $P/out-plk-build17/vendor.img /mnt/o-v
python3 -I $P/tools/odm-symbols-check.py /mnt/o-v /mnt/o-s
