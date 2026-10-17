import os,sys,zipfile
needle8=b'com.oneplus.voicewakeup'; needle16=needle8.decode().encode('utf-16le')
for root in sys.argv[1:]:
    for dp,dn,fn in os.walk(root):
        for f in fn:
            if f.endswith('.apk'):
                p=os.path.join(dp,f)
                try:
                    m=zipfile.ZipFile(p).read('AndroidManifest.xml')
                except Exception: continue
                if needle8 in m or needle16 in m: print(p)
