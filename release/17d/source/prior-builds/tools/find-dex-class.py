import struct, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    for name in z.namelist():
        if not name.endswith('.dex'): continue
        b=z.read(name)
        n,off=struct.unpack_from('<II',b,56)
        strings=[]
        for i in range(n):
            p=struct.unpack_from('<I',b,off+4*i)[0]
            while b[p]&128: p+=1
            p+=1
            strings.append(b[p:b.index(0,p)].decode('utf-8',errors='replace'))
        tn,to=struct.unpack_from('<II',b,64)
        types=[strings[struct.unpack_from('<I',b,to+4*i)[0]] for i in range(tn)]
        cn,co=struct.unpack_from('<II',b,96)
        for i in range(cn):
            descriptor=types[struct.unpack_from('<I',b,co+32*i)[0]]
            if sys.argv[2] in descriptor: print(name,descriptor)
