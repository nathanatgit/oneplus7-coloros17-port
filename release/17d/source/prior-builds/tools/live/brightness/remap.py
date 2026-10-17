# Rewrite lux_table id=3 nit values so the resulting panel raw (level/10) follows the H.40 stock curve, capped at level 8191.
import re
exec(open('tools/live/brightness/compare.py').read().split('print("lux')[0])
txt=open('logs/brightness-common.xml').read()
m=re.search(r'(<lux_table id="3">)(.*?)(</lux_table>)',txt,re.S)
body=m.group(2)
def rep(mm):
    l=float(mm.group(1))
    raw=interp(xs,ys,l)
    L=max(222,min(8191,round(raw*10)))
    return '<lux>%g, %g</lux>'%(l,nit[lv.index(L)])
nb=re.sub(r'<lux>\s*([\d.]+)\s*,\s*[\d.]+\s*</lux>',rep,body)
open('tools/live/brightness/display_brightness_config_common.h40curve.xml','w',newline='\n').write(txt[:m.start(2)]+nb+txt[m.end(2):])
