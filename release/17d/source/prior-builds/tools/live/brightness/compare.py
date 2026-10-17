import re,sys,bisect
lv=[];nit=[]
for m in re.finditer(r'<level>\s*(\d+)\s*,\s*\d+\s*,\s*([\d.]+)',open('logs/brightness-default.xml').read()):
    lv.append(int(m.group(1)));nit.append(float(m.group(2)))
def lvl_of_nit(n):
    for i,x in enumerate(nit):
        if x>=n: return lv[i]
    return lv[-1]
def interp(xs,ys,x):
    if x<=xs[0]:return ys[0]
    for i in range(1,len(xs)):
        if x<=xs[i]:return ys[i-1]+(ys[i]-ys[i-1])*(x-xs[i-1])/(xs[i]-xs[i-1])
    return ys[-1]
t=open('logs/brightness-common.xml').read()
tab=re.search(r'<lux_table id="3">(.*?)</lux_table>',t,re.S).group(1)
pts=[(float(a),float(b)) for a,b in re.findall(r'<lux>\s*([\d.]+)\s*,\s*([\d.]+)\s*</lux>',tab)]
xs=[0,1,2,3,8,16,36,60,100,260,540,1000,2000,3500,5900,7000]
ys=[9,17,25,33,78,121,212,214,221,252,309,428,687,896,1023,1023]
print("lux  portNit portLevel portRaw(=lvl/10)  H40raw")
for l in [0,2,10,20,50,100,200,500,1000,2000,3500,5000]:
    n=interp([p[0] for p in pts],[p[1] for p in pts],l)
    L=lvl_of_nit(n)
    print(l,round(n,1),L,round(L/10),round(interp(xs,ys,l)))
