import sys, struct, hashlib, zipfile, subprocess
def certs_from_block(path):
    d=open(path,'rb').read()
    # EOCD
    i=d.rfind(b'PK\x05\x06'); cd_off=struct.unpack('<I',d[i+16:i+20])[0]
    if d[cd_off-16:cd_off]!=b'APK Sig Block 42': return None
    sz=struct.unpack('<Q',d[cd_off-24:cd_off-16])[0]
    start=cd_off-sz-8; pos=start+8; end=cd_off-24
    out={}
    while pos<end:
        l=struct.unpack('<Q',d[pos:pos+8])[0]; idv=struct.unpack('<I',d[pos+8:pos+12])[0]; val=d[pos+12:pos+8+l]; pos+=8+l
        if idv in (0x7109871a,0xf05368c0):
            # signers seq -> signer -> signed data -> digests, certs
            o=0
            def rd(b,o):
                n=struct.unpack('<I',b[o:o+4])[0]; return b[o+4:o+4+n],o+4+n
            sigs,_=rd(val,0); signer,_=rd(sigs,0); sd,_=rd(signer,0)
            _,o2=rd(sd,0); certs,_=rd(sd,o2); o3=0; res=[]
            while o3<len(certs):
                c,o3=rd(certs,o3); res.append(hashlib.sha256(c).hexdigest())
            out[hex(idv)]=res
    return out
for p in sys.argv[1:]:
    print(p, certs_from_block(p))
