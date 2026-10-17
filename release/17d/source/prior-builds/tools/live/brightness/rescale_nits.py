# Rescale the donor's nit column in display_brightness_config_default.xml so that the 7 Pro's linear level/10 -> panel raw mapping
# reproduces the H.40 stock auto-brightness (H.40 lux->raw curve is 2.55 * ColorOS17 lux->nit curve at every sampled lux).
import re,sys
K=2.55
src,dst=sys.argv[1],sys.argv[2]
def rep(m):
    L=int(m.group(2))
    nit=L/10/K
    return '%s%d%s,%s%.5f%s'%(m.group(1),L,m.group(3),m.group(4),nit,m.group(6)) if False else m.group(0)
out=[]
for line in open(src,newline=''):
    m=re.match(r'(\s*<level>)(\d+)(\s*,\s*\d+\s*,\s*)([\d.]+)(\s*,.*)$',line,re.S)
    if m:
        L=int(m.group(2)); nit=L/10/K if L>0 else 0
        line='%s%d%s%.5f%s'%(m.group(1),L,m.group(3),nit,m.group(5))
    out.append(line)
open(dst,'w',newline='').writelines(out)
