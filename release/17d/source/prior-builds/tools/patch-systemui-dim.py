"""Change only isDisableAppDimLayer's dex body; preserve all other APK entries.
Test artifact only: APK signature is invalid after modification; do not install it.
"""
import hashlib,struct,sys,zlib,zipfile
def uleb(b,p):
    v=0; shift=0
    while True:
        n=b[p];p+=1;v|=(n&127)<<shift
        if not n&128:return v,p
        shift+=7
src,dst=sys.argv[1:3]
with zipfile.ZipFile(src) as zin:
    name='classes4.dex'; b=bytearray(zin.read(name))
    sn,so=struct.unpack_from('<II',b,56); strings=[]
    for i in range(sn):
        p=struct.unpack_from('<I',b,so+4*i)[0];_,p=uleb(b,p)
        strings.append(bytes(b[p:b.index(0,p)]).decode('utf-8',errors='replace'))
    tn,to=struct.unpack_from('<II',b,64)
    types=[strings[struct.unpack_from('<I',b,to+i*4)[0]] for i in range(tn)]
    mn,mo=struct.unpack_from('<II',b,88)
    methods=[struct.unpack_from('<HHI',b,mo+i*8) for i in range(mn)]
    target='Lcom/oplusos/systemui/common/feature/KeyguardFeatureOption;'
    cn,co=struct.unpack_from('<II',b,96); hits=[]
    for i in range(cn):
        off=co+32*i
        if types[struct.unpack_from('<I',b,off)[0]]!=target:continue
        p=struct.unpack_from('<I',b,off+24)[0]; counts=[]
        for _ in range(4):v,p=uleb(b,p);counts.append(v)
        for _ in range(counts[0]+counts[1]):_,p=uleb(b,p);_,p=uleb(b,p)
        for count in counts[2:]:
            idx=0
            for _ in range(count):
                diff,p=uleb(b,p);idx+=diff;_,p=uleb(b,p);code,p=uleb(b,p)
                if strings[methods[idx][2]]=='isDisableAppDimLayer':hits.append(code)
    assert len(hits)==1,hits
    code=hits[0];regs,ins,outs,tries=struct.unpack_from('<HHHH',b,code)
    n=struct.unpack_from('<I',b,code+12)[0]
    assert regs==1 and ins==0 and tries==0 and n>=2
    original=bytes(b[code+16:code+16+2*n])
    b[code+16:code+16+2*n]=struct.pack('<HH',0x1012,0x000f)+bytes(2*n-4)
    b[12:32]=hashlib.sha1(b[32:]).digest()
    struct.pack_into('<I',b,8,zlib.adler32(b[12:])&0xffffffff)
    with zipfile.ZipFile(dst,'w') as zout:
        for info in zin.infolist():zout.writestr(info,b if info.filename==name else zin.read(info.filename))
    print('Patched offset',hex(code),'old body',original.hex(),'new return true; other methods untouched')
with zipfile.ZipFile(src) as a,zipfile.ZipFile(dst) as c:
    assert a.namelist()==c.namelist()
    assert c.testzip() is None
    assert all(a.read(k)==c.read(k) for k in a.namelist() if k!=name)
