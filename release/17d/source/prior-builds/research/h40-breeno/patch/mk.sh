set -e
cd /mnt/c/Users/Han/Project/OnePlus7Port/research/h40-breeno/patch
rm -rf dex sm; mkdir dex
unzip -o -q ../OVoiceManagerServiceOnePlus-H40.apk classes.dex -d dex
baksmali d dex/classes.dex -o sm 2>&1 | tail -2
python3 - <<'PY'
p='sm/com/oneplus/voicewakeup/common/SoundModelConfig.smali'
s=open(p,encoding='utf-8').read()
i=s.index('.method static constructor <clinit>')
e=s.index('.end method',i)
j=s.rindex('    return-void',i,e)
add='''    const-string v3, "GM1910"

    invoke-virtual {v0, v3}, Ljava/util/HashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    const-string v3, "PLK110"

    invoke-virtual {v0, v3, v1}, Ljava/util/HashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

'''
open(p,'w',encoding='utf-8',newline='\n').write(s[:j]+add+s[j:])
PY
smali a sm -o dex/classes-new.dex
python3 - <<'PY'
import zipfile
src='../OVoiceManagerServiceOnePlus-H40.apk'; dst='unsigned.apk'
zi=zipfile.ZipFile(src); zo=zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED)
for it in zi.infolist():
    if it.filename.startswith('META-INF/') and it.filename.endswith(('.SF','.MF','.RSA','.DSA','.EC')): continue
    data=zi.read(it.filename)
    if it.filename=='classes.dex': data=open('dex/classes-new.dex','rb').read()
    ni=zipfile.ZipInfo(it.filename,it.date_time); ni.compress_type=it.compress_type; ni.external_attr=it.external_attr
    zo.writestr(ni,data)
zo.close()
PY
