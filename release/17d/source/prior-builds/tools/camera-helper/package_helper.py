import zipfile
from pathlib import Path
p=Path(__file__).resolve().parent
with zipfile.ZipFile(p/'manifest-only.apk') as manifest, zipfile.ZipFile(p.parent/'live/OnePlusCameraHelper.apk') as src, zipfile.ZipFile(p/'helper-unsigned.apk','w') as dst:
    for info in src.infolist():
        if info.filename.startswith('META-INF/'): continue
        dst.writestr(info,manifest.read('AndroidManifest.xml') if info.filename=='AndroidManifest.xml' else src.read(info.filename))
with zipfile.ZipFile(p.parent/'live/OnePlusCameraHelper.apk') as a,zipfile.ZipFile(p/'helper-unsigned.apk') as b:
    assert b.testzip() is None
    for n in b.namelist():
        if n!='AndroidManifest.xml': assert a.read(n)==b.read(n)
print('Original dex/resources retained byte-for-byte; only manifest adapted.')
