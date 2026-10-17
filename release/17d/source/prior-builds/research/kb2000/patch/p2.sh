set -e
cd /mnt/c/Users/Han/Project/OnePlus7Port/research/kb2000/patch
smali a sm -o dex/classes-new.dex 2>&1 | tail -3
python3 - <<'PY'
import zipfile,shutil
src='../OVoiceManagerServiceOnePlus.apk'; dst='patched-unsigned.apk'
zi=zipfile.ZipFile(src); zo=zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED)
for it in zi.infolist():
    if it.filename.startswith('META-INF/') and it.filename.endswith(('.SF','.MF','.RSA','.DSA','.EC')): continue
    data=zi.read(it.filename)
    if it.filename=='classes.dex': data=open('dex/classes-new.dex','rb').read()
    ni=zipfile.ZipInfo(it.filename,it.date_time); ni.compress_type=it.compress_type; ni.external_attr=it.external_attr
    zo.writestr(ni,data)
zo.close()
PY
python3 /mnt/c/Users/Han/Project/OnePlus7Port/tools/transplant-apk-sigblock.py ../OVoiceManagerServiceOnePlus.apk patched-unsigned.apk OVoiceManagerServiceOnePlus-plk110.apk
ls -la *.apk
