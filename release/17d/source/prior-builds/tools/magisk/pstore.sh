ls -la /sys/fs/pstore/
for x in /sys/fs/pstore/*; do cp "$x" "/data/local/tmp/pstore-${x##*/}"; done
chmod 0644 /data/local/tmp/pstore-*
