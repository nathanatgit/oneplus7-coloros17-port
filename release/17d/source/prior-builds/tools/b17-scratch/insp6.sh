. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
for r in /mnt/i-odm /mnt/i-hv /mnt/i-lv /mnt/i-sys /mnt/i-myp; do echo "## $r"; find $r -iname '*nxp*' -o -iname '*ese_*' -o -iname 'ls_client*' -o -iname '*keybox*' 2>/dev/null | head -30; done
echo; ls /mnt/i-sys/system/euclid
