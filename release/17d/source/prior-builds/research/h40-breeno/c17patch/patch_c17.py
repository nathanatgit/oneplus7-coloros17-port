import re,sys
p='sm/classes2/com/oplus/ovoicemanager/wakeup/adapter/u/c.smali'
s=open(p,encoding='utf-8').read()
def sub1(old,new,s,count=1):
    assert s.count(old)==count,(s.count(old),old[:80])
    return s.replace(old,new)

# --- l([B): keyphrase "xiaobuxiaobu", recognition mode VOICE_TRIGGER only, no users / confidence levels, confidence 80 ---
a=s.index('.method public final l([B)')
b=s.index('.end method',a)
m=s[a:b]
m=sub1('    add-int/2addr v0, v1\n','',m)
m=sub1('    new-array v7, v1, [I\n','    const/4 v4, 0x0\n\n    new-array v7, v4, [I\n',m)
m=sub1('const-string v6, "aispeech"','const-string v6, "xiaobuxiaobu"',m)
old_cl=re.search(r'    new-array v1, v1, \[Lcom/oplus/wrapper/hardware/soundtrigger/SoundTrigger\$ConfidenceLevel;.*?    aput-object v3, v1, v2\n',m,re.S)
assert old_cl
new_cl='''    const/4 v3, 0x0

    new-array v1, v3, [Lcom/oplus/wrapper/hardware/soundtrigger/SoundTrigger$ConfidenceLevel;

    const/16 v5, 0x50
'''
m=m.replace(old_cl.group(0),new_cl)
s=s[:a]+m+s[b:]

# --- n(String): raw SVA model data instead of the aispeech container j([B) ---
k=s.index('invoke-static {p1}, Lcom/oplus/ovoicemanager/wakeup/utils/o;->n(Ljava/lang/String;)[B')
import re as _re
mm=_re.compile(r'    invoke-virtual \{p0, p1\}, Lcom/oplus/ovoicemanager/wakeup/adapter/u/c;->j\(\[B\)\[B\n(?:\s*\.line \d+\n|\n)*    move-result-object v4\n').search(s,k)
assert mm and mm.start()-k<400
s=s[:mm.start()]+'    move-object v4, p1\n'+s[mm.end():]

# --- start: captureRequested false + SVA opaque data {1,0,0,0} (what the H.40 SVA app sends) ---
mm=_re.compile(r'    invoke-static \{v0\}, Lcom/oplus/ovoicemanager/wakeup/utils/h0;->b\(I\)\[B\n(?:\s*\.line \d+\n|\n)*    move-result-object v0\n').search(s)
assert mm
s=s[:mm.start()]+"""    invoke-static {}, Lcom/oplus/ovoicemanager/wakeup/adapter/u/c;->svaOpaque()[B

    move-result-object v0
"""+s[mm.end():]
# captureRequested stays true: Breeno's second stage needs the DSP capture buffer (history buffer config is in the opaque data)
# b()I now uses v6/v7 as scratch: raise the register count (p0 is renamed, params are addressed by pN)
old='.method public final declared-synchronized b()I\n    .registers 7\n'
assert s.count(old)==1
s=s.replace(old,old.replace('.registers 7','.registers 9'))
s=s.rstrip('\n')+'\n'+open('sva_opaque_helper.smali.txt').read()
open(p,'w',encoding='utf-8',newline='\n').write(s)
print('patched')
