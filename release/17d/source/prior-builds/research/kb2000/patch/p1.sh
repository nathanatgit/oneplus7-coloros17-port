set -e
cd /mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/patch
rm -rf dex sm; mkdir dex
unzip -o -q ../OVoiceManagerServiceOnePlus.apk classes.dex -d dex
baksmali d dex/classes.dex -o sm 2>&1 | tail -2
f=sm/com/oneplus/voicewakeup/common/SoundModelConfig.smali
grep -n "KB2005" $f | head -3
sed -n '/KB2005/,$p' $f | head -40
