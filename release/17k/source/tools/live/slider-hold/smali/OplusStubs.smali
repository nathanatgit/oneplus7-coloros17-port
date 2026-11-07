# Usage: CLASSPATH=oplus-stubs.dex app_process /system/bin port.OplusStubs <descriptor>/<instance> ...
.class public Lport/OplusStubs;
.super Ljava/lang/Object;

.method public static main([Ljava/lang/String;)V
    .registers 8
    array-length v0, p0
    const/4 v1, 0x0
    :loop
    if-ge v1, v0, :wait
    aget-object v2, p0, v1
    const/16 v3, 0x2f
    invoke-virtual {v2, v3}, Ljava/lang/String;->indexOf(I)I
    move-result v3
    const/4 v4, 0x0
    invoke-virtual {v2, v4, v3}, Ljava/lang/String;->substring(II)Ljava/lang/String;
    move-result-object v4
    const-string v6, "displaypanelfeature"
    invoke-virtual {v4, v6}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v6
    if-eqz v6, :not_panel
    new-instance v5, Lport/PanelBinder;
    invoke-direct {v5, v4}, Lport/PanelBinder;-><init>(Ljava/lang/String;)V
    goto :made
    :not_panel
    const-string v6, "hardware.touch.IOplusTouch"
    invoke-virtual {v4, v6}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v6
    if-nez v6, :touch
    const-string v6, "hardware.misc.IOplusMisc"
    invoke-virtual {v4, v6}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v6
    if-eqz v6, :plain
    :touch
    new-instance v5, Lport/TouchBinder;
    invoke-direct {v5, v4}, Lport/TouchBinder;-><init>(Ljava/lang/String;)V
    goto :made
    :plain
    new-instance v5, Lport/StubBinder;
    invoke-direct {v5, v4}, Lport/StubBinder;-><init>(Ljava/lang/String;)V
    :made
    invoke-static {v2, v5}, Landroid/os/ServiceManager;->addService(Ljava/lang/String;Landroid/os/IBinder;)V
    const-string v6, "OplusStub"
    invoke-static {v6, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    add-int/lit8 v1, v1, 0x1
    goto :loop
    :wait
    invoke-static {}, Landroid/os/Binder;->joinThreadPool()V
    return-void
.end method
