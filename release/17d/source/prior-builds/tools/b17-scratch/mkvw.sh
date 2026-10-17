. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
H=$P/research/h40-breeno; O=$P/tools/live/voicewakeup
unzip -p $H/patch/aligned.apk classes.dex | grep -c PLK110
unzip -p $H/patch/unsigned.apk classes.dex | cmp - <(unzip -p $H/patch/aligned.apk classes.dex) && echo dex-same
python3 -I $P/tools/transplant-apk-sigblock.py /mnt/i-s16/system_ext/priv-app/SystemUI/SystemUI.apk $H/patch/aligned.apk $O/OVoiceManagerServiceOnePlus-H40-plk110-c17sig.apk
python3 -I $P/tools/b17-scratch/sigcert.py $O/OVoiceManagerServiceOnePlus-H40-plk110-c17sig.apk
python3 -I - <<'PY'
import zipfile
z=zipfile.ZipFile('/mnt/c/Users/Han/Project/OnePlus7Port/tools/live/voicewakeup/OVoiceManagerServiceOnePlus-H40-plk110-c17sig.apk'); print(z.testzip(), len(z.namelist()))
PY
sha256sum $O/*.apk
cp $H/liblistenjni.qti.H40.so $H/liblistensoundmodel2.qti.H40.so $O/
cp /mnt/i-sys/system/system_ext/lib/liblistenjni.qti.so $O/liblistenjni.qti.H40.32.so
cp /mnt/i-sys/system/system_ext/lib/liblistensoundmodel2.qti.so $O/liblistensoundmodel2.qti.H40.32.so
cp $P/research/h40-breeno/patch/mk.sh $O/mk-dex-patch.sh
sha256sum $O/*.so
