# Generates smali for a minimal Java AIDL service vendor.oplus.hardware.charger.ICharger/default (ColorOS 17 framework asks for the
# AIDL V12 interface; the H.40 HIDL HAL does not match). Real values from sysfs for a few getters, 0 / "" for the rest.
import re,os
SYS={ 'getPsyBatteryFcc':('batt_fcc',1),'getPsyBatteryRm':('batt_rm',1),'getPsyBatteryCC':('batt_cc',1),
      'getPsyBatteryLevel':('capacity',1),'getBatteryVoltageNow':('voltage_now',1),'getPsyBatteryTemp':('temp',1),
      'getUIsohValue':('batt_soh',10),'getBattAuthenticate':('authenticate',1),'getPsyBatteryNotify':('notify_code',1),
      'getBattShortIcOtpStatus':('short_ic_otp_status',1),'getPsyBatteryShortStatus':('short_c_hw_status',1),
      'getPsyBatteryShortFeature':('short_c_hw_feature',1),'getChargerIdVolt':('chargerid_volt',1),'getPsyBatteryCurrentNow':('current_now',1) }
CONST={'getPsyBatteryHmac':1}   # stock sysfs has no hmac node here; 1 = battery genuine
SKIP={'getInterfaceHash','getInterfaceVersion','<clinit>','CHG_FUNC_FLAG_MAX','DESCRIPTOR','HASH','VERSION'}
out=[ '.class public Lport/PortCharger;','.super Lvendor/oplus/hardware/charger/ICharger$Stub;','',
 '.method public constructor <init>()V','    .registers 1','    invoke-direct {p0}, Lvendor/oplus/hardware/charger/ICharger$Stub;-><init>()V','    return-void','.end method','']
n=0
for line in open('iface-methods.txt'):
    name,sig,acc=line.split()
    if name in SKIP or not sig.startswith('('): continue
    ret=sig[sig.index(')')+1:]
    out.append('.method public %s%s'%(name,sig)); n+=1
    if name in SYS:
        f,div=SYS[name]
        out+=['    .registers 6','    const-string v0, "%s"'%f,'    invoke-static {v0}, Lport/H;->r(Ljava/lang/String;)I','    move-result v0']
        if div!=1: out+=['    const/16 v1, %d'%div,'    div-int/2addr v0, v1']
        out+=['    return v0']
    elif name in CONST:
        out+=['    .registers 3','    const/4 v0, 0x%d'%CONST[name],'    return v0']
    elif ret=='I' or ret=='Z' or ret=='J':
        # args occupy registers; use a local
        out+=['    .registers %d'%(1+1+len(re.findall(r'\[?(?:L[^;]+;|[IZJ])',sig[1:sig.index(')')]))+ (sig[1:sig.index(')')].count('J'))), '    const/4 v0, 0x0']
        out+=['    return v0' if ret!='J' else '    return v0']
    elif ret=='V':
        out+=['    .registers %d'%(1+len(re.findall(r'\[?(?:L[^;]+;|[IZJ])',sig[1:sig.index(')')]))+sig[1:sig.index(')')].count('J')+0),'    return-void']
    elif ret=='Ljava/lang/String;':
        out+=['    .registers %d'%(2+len(re.findall(r'\[?(?:L[^;]+;|[IZJ])',sig[1:sig.index(')')]))+sig[1:sig.index(')')].count('J')),'    const-string v0, ""','    return-object v0']
    else:
        raise SystemExit('unhandled '+name+sig)
    out.append('.end method'); out.append('')
os.makedirs('smali/port',exist_ok=True)
open('smali/port/PortCharger.smali','w',newline='\n').write('\n'.join(out)+'\n')
print('methods',n)
