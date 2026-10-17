set -e
cd /mnt/c/Users/Han/Project/OnePlus7Port/research/h40-breeno/c17patch
python3 patch_c17.py
grep -n "registers" sm/classes2/com/oplus/ovoicemanager/wakeup/adapter/u/c.smali | sed -n 1,0p
smali a sm/classes2 -o d/classes2-new.dex
python3 - <<'PY'
import zipfile
src='../c17/OVoiceManagerService.apk'; dst='unsigned.apk'
zi=zipfile.ZipFile(src); zo=zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED)
for it in zi.infolist():
    if it.filename.startswith('META-INF/') and it.filename.endswith(('.SF','.MF','.RSA','.DSA','.EC')): continue
    data=zi.read(it.filename)
    if it.filename=='classes2.dex': data=open('d/classes2-new.dex','rb').read()
    ni=zipfile.ZipInfo(it.filename,it.date_time); ni.compress_type=it.compress_type; ni.external_attr=it.external_attr
    zo.writestr(ni,data)
zo.close()
PY
