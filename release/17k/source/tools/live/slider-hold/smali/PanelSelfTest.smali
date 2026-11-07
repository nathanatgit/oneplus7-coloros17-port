# OnePlus7Port: in-process check of PanelBinder's reply shapes, done the way ColorOS's generated proxy reads them.
# Usage: CLASSPATH=oplus-stubs.dex app_process /system/bin port.PanelSelfTest
.class public Lport/PanelSelfTest;
.super Ljava/lang/Object;

.method public static main([Ljava/lang/String;)V
    .registers 10
    const-string v0, "vendor.oplus.hardware.displaypanelfeature.IDisplayPanelFeature"
    new-instance v1, Lport/PanelBinder;
    invoke-direct {v1, v0}, Lport/PanelBinder;-><init>(Ljava/lang/String;)V
    sget-object v9, Ljava/lang/System;->out:Ljava/io/PrintStream;

    # 1: getDisplayPanelFeatureValue(211 = fpType, out int[3]) -> expect ret=0 [2, 0, 0] when the prop is unset
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v2
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v3
    invoke-virtual {v2, v0}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
    const/16 v4, 0xd3
    invoke-virtual {v2, v4}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v4, 0x3
    invoke-virtual {v2, v4}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v4, 0x1
    const/4 v5, 0x0
    invoke-virtual {v1, v4, v2, v3, v5}, Landroid/os/Binder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    invoke-virtual {v3, v5}, Landroid/os/Parcel;->setDataPosition(I)V
    invoke-virtual {v3}, Landroid/os/Parcel;->readException()V
    invoke-virtual {v3}, Landroid/os/Parcel;->readInt()I
    move-result v6
    const/4 v4, 0x3
    new-array v7, v4, [I
    invoke-virtual {v3, v7}, Landroid/os/Parcel;->readIntArray([I)V
    new-instance v8, Ljava/lang/StringBuilder;
    invoke-direct {v8}, Ljava/lang/StringBuilder;-><init>()V
    const-string v4, "get OK ret="
    invoke-virtual {v8, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v8, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-static {v7}, Ljava/util/Arrays;->toString([I)Ljava/lang/String;
    move-result-object v4
    invoke-virtual {v8, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v8}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v4
    invoke-virtual {v9, v4}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V

    # 3: getDisplayPanelInfo(7, out String[2])
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v2
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v3
    invoke-virtual {v2, v0}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
    const/4 v4, 0x7
    invoke-virtual {v2, v4}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v4, 0x2
    invoke-virtual {v2, v4}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v4, 0x3
    const/4 v5, 0x0
    invoke-virtual {v1, v4, v2, v3, v5}, Landroid/os/Binder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    invoke-virtual {v3, v5}, Landroid/os/Parcel;->setDataPosition(I)V
    invoke-virtual {v3}, Landroid/os/Parcel;->readException()V
    invoke-virtual {v3}, Landroid/os/Parcel;->readInt()I
    move-result v6
    const/4 v4, 0x2
    new-array v7, v4, [Ljava/lang/String;
    invoke-virtual {v3, v7}, Landroid/os/Parcel;->readStringArray([Ljava/lang/String;)V
    const-string v4, "info OK"
    invoke-virtual {v9, v4}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V

    # 2: setDisplayPanelFeatureValue(999, [5])  (id 999: logged only, no node write)
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v2
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v3
    invoke-virtual {v2, v0}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
    const/16 v4, 0x3e7
    invoke-virtual {v2, v4}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v4, 0x1
    new-array v7, v4, [I
    const/4 v5, 0x0
    const/4 v6, 0x5
    aput v6, v7, v5
    invoke-virtual {v2, v7}, Landroid/os/Parcel;->writeIntArray([I)V
    const/4 v4, 0x2
    invoke-virtual {v1, v4, v2, v3, v5}, Landroid/os/Binder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    invoke-virtual {v3, v5}, Landroid/os/Parcel;->setDataPosition(I)V
    invoke-virtual {v3}, Landroid/os/Parcel;->readException()V
    invoke-virtual {v3}, Landroid/os/Parcel;->readInt()I
    const-string v4, "set OK"
    invoke-virtual {v9, v4}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    return-void
.end method
