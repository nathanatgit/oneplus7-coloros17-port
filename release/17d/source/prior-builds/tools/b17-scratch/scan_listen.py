import os, sys, zipfile
roots=sys.argv[1:]
n=0
for r in roots:
    for dp,dn,fn in os.walk(r):
        for f in fn:
            if not f.endswith('.apk'): continue
            p=os.path.join(dp,f); n+=1
            try:
                z=zipfile.ZipFile(p)
                for i in z.namelist():
                    if i.endswith('.dex') or (i.startswith('lib/') and 'listen' in i):
                        d=z.read(i) if i.endswith('.dex') else b'listenjni'
                        if b'listenjni' in d or b'listensoundmodel' in d: print('HIT',p,i); break
            except Exception as e: pass
print('scanned',n)
