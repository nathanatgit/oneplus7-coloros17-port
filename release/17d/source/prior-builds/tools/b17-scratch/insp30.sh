. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m $P/out-plk-build16/my_stock.img /mnt/i-ms16
cd /mnt/i-s16/system/framework
for j in framework.jar oplus-framework.jar; do [ -f $j ] || continue; for s in ACCESS_ESE SERVICE_UP android.se.omapi.ISecureElementService/default; do for d in $(unzip -Z1 $j | grep '\.dex$'); do unzip -p $j $d | grep -c "$s" | sed "s|^|$j $d $s |" ; done; done; done 2>/dev/null | grep -v ' 0$' | head
echo --- wallet apks; find /mnt/i-ms16 /mnt/i-s16 -iname '*wallet*' -name '*.apk' | head
