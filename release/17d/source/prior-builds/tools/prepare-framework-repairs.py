from pathlib import Path
import re, zipfile
out=Path('/mnt/c/Users/Han/Project/OnePlus7Port/tools/live/framework-repairs')
out.mkdir(parents=True,exist_ok=True)
p=Path('/root/port-framework/framework3-smali/android/os/ProjectManager.smali')
s=p.read_text()
start=s.index('.method private static blacklist getProjectService()')
end=s.index('.end method',start)
part=s[start:end]
old='Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;'
assert part.count(old)==1
part=part.replace(old,'Landroid/os/ServiceManager;->checkService(Ljava/lang/String;)Landroid/os/IBinder;')
marker='    move-result-object v1\n\n    invoke-static {v1}, Lvendor/oplus/hardware/stability/oplus_project/IOplusProject$Stub;'
assert marker in part
part=part.replace(marker,'    move-result-object v1\n\n    if-nez v1, :port_project_present\n    const/4 v1, 0x0\n    return-object v1\n    :port_project_present\n\n    invoke-static {v1}, Lvendor/oplus/hardware/stability/oplus_project/IOplusProject$Stub;')
p.write_text(s[:start]+part+s[end:])
(out/'ProjectManager.patched.smali').write_text(part+'\n.end method\n')
# The framework already maps the native node's real 1/2/3 values. Preserve its ringer policy.
p=Path('/root/slider/smali_classes.dex/com/android/server/audio/AlertSliderHw.smali')
s=p.read_text(); start=s.index('.method private readNodeFile(I)'); end=s.index('.end method',start)
part=s[start:end]
marker='    .param p1, "nodeFlag"    # I\n'
assert marker in part
insert='''
    const/16 v0, 0x7a
    if-ne p1, v0, :port_original_misc
    :port_read_start
    new-instance v0, Ljava/io/File;
    const-string v1, "/proc/tristatekey/tri_state"
    invoke-direct {v0, v1}, Ljava/io/File;-><init>(Ljava/lang/String;)V
    const/16 v1, 0x10
    const/4 v2, 0x0
    invoke-static {v0, v1, v2}, Landroid/os/FileUtils;->readTextFile(Ljava/io/File;ILjava/lang/String;)Ljava/lang/String;
    move-result-object v0
    :port_read_end
    return-object v0
    .catch Ljava/io/IOException; {:port_read_start .. :port_read_end} :port_read_failed
    :port_read_failed
    move-exception v0
    :port_original_misc
'''
part=part.replace(marker,marker+insert)
p.write_text(s[:start]+part+s[end:])
(out/'AlertSliderHw.patched.smali').write_text(part+'\n.end method\n')
print('Prepared exact ProjectManager and slider-node repairs. Re-run only on fresh decoded sources.')
