export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=/mnt/c/Users/Han/Project/OnePlus7Port
m() { mkdir -p $2; mountpoint -q $2 || mount -o ro,loop $1 $2; }
m $P/StockRom/H40-images/odm.img /mnt/i-odm
m $P/StockRom/H40-images/system.img /mnt/i-sys
m /mnt/i-sys/system/euclid/my_product.img /mnt/i-myp
m $P/StockRom/H40-images/vendor.img /mnt/i-hv
m $P/LineageOS24/payload/vendor.img /mnt/i-lv
m $P/out-plk-build16/system.img /mnt/i-s16
m /mnt/i-sys/system/euclid/odm.img /mnt/i-eodm
