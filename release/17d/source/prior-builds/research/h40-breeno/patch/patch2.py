p='sm/com/qualcomm/qti/sva/session/legacy/LegacyWakeupSession.smali'
s=open(p,encoding='utf-8').read()
old='invoke-static {v0}, Landroid/hardware/soundtrigger/SoundTrigger;->listModules(Ljava/util/ArrayList;)I'
assert s.count(old)==1
s=s.replace(old,'invoke-static {v0}, Lcom/qualcomm/qti/sva/session/legacy/LegacyWakeupSession;->listModulesCompat(Ljava/util/ArrayList;)I')
helper='''
# Android 17: SoundTrigger.listModules(ArrayList) is a stub that returns 0 without filling the list; use listModulesAsOriginator.
.method public static listModulesCompat(Ljava/util/ArrayList;)I
    .registers 4
    new-instance v0, Landroid/media/permission/Identity;
    invoke-direct {v0}, Landroid/media/permission/Identity;-><init>()V
    invoke-static {}, Landroid/os/Process;->myUid()I
    move-result v1
    iput v1, v0, Landroid/media/permission/Identity;->uid:I
    invoke-static {}, Landroid/os/Process;->myPid()I
    move-result v1
    iput v1, v0, Landroid/media/permission/Identity;->pid:I
    const-string v1, "com.oneplus.voicewakeup"
    iput-object v1, v0, Landroid/media/permission/Identity;->packageName:Ljava/lang/String;
    invoke-static {p0, v0}, Landroid/hardware/soundtrigger/SoundTrigger;->listModulesAsOriginator(Ljava/util/ArrayList;Landroid/media/permission/Identity;)I
    move-result v1
    return v1
.end method
'''
open(p,'w',encoding='utf-8',newline='\n').write(s.rstrip('\n')+'\n'+helper)

# --- attachModule: replace the reflective private SoundTrigger.attachModule(int,StatusListener,Handler) (A17: needs an Identity) ---
s=open(p,encoding='utf-8').read()
a=s.index('    :try_start_42')+len('    :try_start_42\n')
iput='    iput-object v0, p0, Lcom/qualcomm/qti/sva/session/legacy/LegacyWakeupSession;->mSTModule:Landroid/hardware/soundtrigger/SoundTriggerModule;'
b=s.index(iput,a)
new='''
    const/4 v3, 0x0

    invoke-virtual {v0, v3}, Ljava/util/ArrayList;->get(I)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/hardware/soundtrigger/SoundTrigger$ModuleProperties;

    invoke-virtual {v0}, Landroid/hardware/soundtrigger/SoundTrigger$ModuleProperties;->getId()I

    move-result v0

    invoke-static {v0, p0}, Lcom/qualcomm/qti/sva/session/legacy/LegacyWakeupSession;->attachCompat(ILandroid/hardware/soundtrigger/SoundTrigger$StatusListener;)Landroid/hardware/soundtrigger/SoundTriggerModule;

    move-result-object v0

'''
s=s[:a]+new+s[b:]
helper2='''
.method public static attachCompat(ILandroid/hardware/soundtrigger/SoundTrigger$StatusListener;)Landroid/hardware/soundtrigger/SoundTriggerModule;
    .registers 6
    new-instance v0, Landroid/media/permission/Identity;
    invoke-direct {v0}, Landroid/media/permission/Identity;-><init>()V
    invoke-static {}, Landroid/os/Process;->myUid()I
    move-result v1
    iput v1, v0, Landroid/media/permission/Identity;->uid:I
    invoke-static {}, Landroid/os/Process;->myPid()I
    move-result v1
    iput v1, v0, Landroid/media/permission/Identity;->pid:I
    const-string v1, "com.oneplus.voicewakeup"
    iput-object v1, v0, Landroid/media/permission/Identity;->packageName:Ljava/lang/String;
    const/4 v2, 0x0
    invoke-static {p0, p1, v2, v0}, Landroid/hardware/soundtrigger/SoundTrigger;->attachModuleAsOriginator(ILandroid/hardware/soundtrigger/SoundTrigger$StatusListener;Landroid/os/Handler;Landroid/media/permission/Identity;)Landroid/hardware/soundtrigger/SoundTriggerModule;
    move-result-object v1
    return-object v1
.end method
'''
open(p,'w',encoding='utf-8',newline='\n').write(s.rstrip('\n')+'\n'+helper2)
