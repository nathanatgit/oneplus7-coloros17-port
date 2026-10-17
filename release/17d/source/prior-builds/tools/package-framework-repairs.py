from pathlib import Path
import hashlib, zipfile
root=Path('/root/plk/tree/system/framework')
out=Path('/mnt/c/Users/Han/Project/OnePlus7Port/tools/live/framework-repairs')
for name,dex,src in [('framework.jar','classes3.dex','/root/port-framework/framework3.fixed.dex'),('oplus-services.jar','classes.dex','/root/port-framework/oplus-services.fixed.dex')]:
    with zipfile.ZipFile(root/name) as original, zipfile.ZipFile(out/name,'w') as target:
        for info in original.infolist():
            data=Path(src).read_bytes() if info.filename==dex else original.read(info.filename)
            target.writestr(info,data)
    with zipfile.ZipFile(root/name) as a, zipfile.ZipFile(out/name) as b:
        assert a.namelist()==b.namelist()
        for item in a.namelist():
            if item!=dex: assert a.read(item)==b.read(item)
        assert b.testzip() is None
    print(name, hashlib.sha256((out/name).read_bytes()).hexdigest())
