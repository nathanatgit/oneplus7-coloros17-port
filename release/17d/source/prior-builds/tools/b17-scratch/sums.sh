cd /mnt/c/Users/Han/Project/OnePlus7Port/tools/live/odm-services
grep -v '^#' install.list | awk 'NF{print $1}' > /tmp/srcs.txt
(cat /tmp/srcs.txt; echo app/SecureElement-los24.apk) | xargs sha256sum > SHA256SUMS
wc -l SHA256SUMS; sha256sum -c --quiet SHA256SUMS && echo sums-ok
cat SHA256SUMS | cut -c1-20,65- | head -40
