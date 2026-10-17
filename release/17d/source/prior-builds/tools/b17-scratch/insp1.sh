P=/mnt/c/Users/Han/Project/OnePlus7Port
mkdir -p /mnt/i-odm /mnt/i-sys /mnt/i-myp /mnt/i-vend
mount -o ro,loop $P/StockRom/H40-images/odm.img /mnt/i-odm
mount -o ro,loop $P/StockRom/H40-images/system.img /mnt/i-sys
mount -o ro,loop /mnt/i-sys/system/euclid/my_product.img /mnt/i-myp
cd /mnt/i-odm
echo ---odm top; ls -la . 
for p in charger cryptoeng commondcs secure_element; do echo "--- $p"; find . -iname "*$p*" | xargs ls -ldZ 2>/dev/null; done
echo --- fw; ls vendor/firmware | grep -i crypto
echo --- sys SE; find /mnt/i-sys -ipath '*SecureElement*' | head; find /mnt/i-myp -ipath '*SecureElement*' -o -ipath '*voicewakeup*' -o -ipath '*OVoiceManagerServiceOnePlus*' | head
grep -rl 'secure_element' /mnt/i-odm/etc 2>/dev/null
