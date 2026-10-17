export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p /mnt/o-lv; mountpoint -q /mnt/o-lv || mount -o ro,loop /mnt/c/Users/Han/Project/OnePlus7Port/LineageOS24/payload/vendor.img /mnt/o-lv
mkdir -p /mnt/k-odm; mountpoint -q /mnt/k-odm || mount -o ro,loop /mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/out/odm.img /mnt/k-odm
mkdir -p /mnt/o-s; mountpoint -q /mnt/o-s || mount -o ro,loop -t erofs /mnt/c/Users/Han/Project/OnePlus7Port/out-plk-build16/system.img /mnt/o-s
python3 -I /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/deps8t.py vendor.oplus.hardware.charger-V3-service
