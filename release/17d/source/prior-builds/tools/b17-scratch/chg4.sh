export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
K=/mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/out
for i in odm vendor system_ext product; do mkdir -p /mnt/k-$i; mountpoint -q /mnt/k-$i || mount -o ro,loop $K/$i.img /mnt/k-$i 2>&1 | head -1; done
for i in odm vendor system_ext product; do echo "## $i"; find /mnt/k-$i -iname '*charger*' 2>/dev/null | grep -v 'res/\|firmware' | head -20; done
echo; find /mnt/o-s/system/framework /mnt/o-s/system_ext/framework -name 'vendor.oplus.hardware.charger*' | head
