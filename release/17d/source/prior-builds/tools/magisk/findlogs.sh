date
for m in /mnt/vendor/oplusreserve /mnt/oplus/op2 /mnt/vendor/opporeserve; do
  echo "== $m"; ls $m 2>&1 | head -20
done
echo "== recently modified files (last 60 min)"
find /mnt/vendor/oplusreserve /mnt/oplus/op2 /data/system/dropbox /data/misc/logd /cache -type f -mmin -60 2>/dev/null | head -60
echo "== phoenix"
find / -xdev -iname '*phoenix*' 2>/dev/null | head; find /mnt/vendor/oplusreserve /mnt/oplus -iname '*phx*' -o -iname '*phoenix*' -o -iname '*kmsg*' -o -iname '*last*' 2>/dev/null | head -30
ls /proc/last_kmsg /sys/fs/pstore 2>&1
getprop | grep -iE 'phx|phoenix|bootreason|boot.reason' | head
