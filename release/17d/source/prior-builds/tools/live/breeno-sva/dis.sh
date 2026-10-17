set -e
cd /mnt/c/Users/Han/Project/OnePlus7Port/research/h40-breeno/c17patch
rm -rf d sm; mkdir d
unzip -o -q ../c17/OVoiceManagerService.apk 'classes*.dex' -d d
ls d
for f in d/classes*.dex; do n=$(basename $f .dex); baksmali d $f -o sm/$n >/dev/null 2>&1; done
grep -l "aispeech" -r sm | head
