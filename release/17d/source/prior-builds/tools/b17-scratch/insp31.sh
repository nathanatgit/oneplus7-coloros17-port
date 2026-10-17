. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m $P/LineageOS24/payload/system.img /mnt/i-ls
for r in /mnt/i-s16 /mnt/i-ls/system; do echo "## $r"; grep -rl 'android.se.omapi' $r/etc/vintf $r/system/etc/vintf $r/system_ext/etc/vintf $r/product/etc/vintf $r/etc/permissions 2>/dev/null | head; done
grep -rn -B3 -A8 'android.se.omapi' /mnt/i-s16/system/etc/vintf/*.xml 2>/dev/null | head -40
find /mnt/i-ls/system -name '*.xml' -path '*vintf*' | head; 
grep -c . /mnt/i-s16/system/etc/vintf/manifest.xml; ls /mnt/i-s16/system/etc/vintf /mnt/i-s16/system/etc/vintf/manifest | head -40
