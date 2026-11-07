# OnePlus7Port: AIDL vendor.oplus.hardware.displaypanelfeature.IDisplayPanelFeature (V1, hash 86d5512f...).
# Wire format from ColorOS 17 SystemUI's generated proxy. Getters have `out` arrays: the reply MUST carry an array of
# exactly the length the caller sent (Java readIntArray throws "bad array lengths" otherwise -> system_server crash).
#   1 getDisplayPanelFeatureValue(int id, out int[] v) -> value from persist.vendor.port.dpf.<id>; unset: 211 = 2,
#     others ret -1, zeros
#   2 setDisplayPanelFeatureValue(int id, in int[] v)  -> 22 = dimlayer_hbm, 12 = hbm, 28 = notify_fppress
#     (stock H.40 jump table: SetDisplayPanelDimlayHBM / SetDisplayPanelHBM / SetDisplayPanelFPPress)
#   3 getDisplayPanelInfo(int id, out String[] s)      -> ret -1, empty strings
.class public Lport/PanelBinder;
.super Lport/StubBinder;

.method public constructor <init>(Ljava/lang/String;)V
    .registers 2
    invoke-direct {p0, p1}, Lport/StubBinder;-><init>(Ljava/lang/String;)V
    return-void
.end method

.method protected onTransact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    .registers 14
    const v0, 0xffffff
    if-ne p1, v0, :not_version
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    const/4 v0, 0x1
    invoke-virtual {p3, v0}, Landroid/os/Parcel;->writeInt(I)V
    return v0
    :not_version
    const v0, 0xfffffe
    if-ne p1, v0, :not_hash
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    const-string v0, "86d5512f98a34fe15c70d7bb459d3f7e853bcde3"
    invoke-virtual {p3, v0}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V
    const/4 v0, 0x1
    return v0
    :not_hash
    const/4 v0, 0x1
    if-lt p1, v0, :super
    const/4 v0, 0x3
    if-gt p1, v0, :super
    const-string v0, "vendor.oplus.hardware.displaypanelfeature.IDisplayPanelFeature"
    invoke-virtual {p2, v0}, Landroid/os/Parcel;->enforceInterface(Ljava/lang/String;)V
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    move-result v1
    const/4 v0, 0x2
    if-ne p1, v0, :not_set
    invoke-virtual {p2}, Landroid/os/Parcel;->createIntArray()[I
    move-result-object v2
    invoke-static {v1, v2}, Lport/PanelBinder;->portSet(I[I)I
    move-result v3
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    invoke-virtual {p3, v3}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v0, 0x1
    return v0
    :not_set
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    move-result v2
    const/4 v0, 0x1
    if-ne p1, v0, :info
    const/4 v3, 0x0
    if-ltz v2, :get_call
    new-array v3, v2, [I
    :get_call
    invoke-static {v1, v3}, Lport/PanelBinder;->portGet(I[I)I
    move-result v4
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    invoke-virtual {p3, v4}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p3, v3}, Landroid/os/Parcel;->writeIntArray([I)V
    const/4 v0, 0x1
    return v0
    :info
    const/4 v3, 0x0
    if-ltz v2, :info_reply
    new-array v3, v2, [Ljava/lang/String;
    const/4 v4, 0x0
    const-string v5, ""
    :fill
    if-ge v4, v2, :info_reply
    aput-object v5, v3, v4
    add-int/lit8 v4, v4, 0x1
    goto :fill
    :info_reply
    const-string v0, "OplusStub"
    new-instance v5, Ljava/lang/StringBuilder;
    invoke-direct {v5}, Ljava/lang/StringBuilder;-><init>()V
    const-string v6, "panel getInfo id="
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v5}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v5
    invoke-static {v0, v5}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    const/4 v0, -0x1
    invoke-virtual {p3, v0}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p3, v3}, Landroid/os/Parcel;->writeStringArray([Ljava/lang/String;)V
    const/4 v0, 0x1
    return v0
    :super
    invoke-super {p0, p1, p2, p3, p4}, Lport/StubBinder;->onTransact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    move-result v0
    return v0
.end method

# persist.vendor.port.dpf.<id> into out[0]: ret 0 when set, -1 (out stays zero) otherwise
.method private static portGet(I[I)I
    .registers 10
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "persist.vendor.port.dpf."
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    const/high16 v1, -0x80000000
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v2
    # unset 211 (fpType) -> 2: SF/SystemUI FOD path that calls 28 (notify_fppress) per press
    if-ne v2, v1, :have
    const/16 v4, 0xd3
    if-ne p0, v4, :have
    const/4 v2, 0x2
    :have
    const/4 v3, -0x1
    if-eq v2, v1, :log
    const/4 v3, 0x0
    if-eqz p1, :log
    array-length v4, p1
    if-eqz v4, :log
    const/4 v4, 0x0
    aput v2, p1, v4
    :log
    const-string v4, "OplusStub"
    new-instance v5, Ljava/lang/StringBuilder;
    invoke-direct {v5}, Ljava/lang/StringBuilder;-><init>()V
    const-string v6, "panel get id="
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " ret="
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " out="
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {p1}, Ljava/util/Arrays;->toString([I)Ljava/lang/String;
    move-result-object v6
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v5
    invoke-static {v4, v5}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return v3
.end method

.method private static portSet(I[I)I
    .registers 7
    const-string v0, "OplusStub"
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V
    const-string v2, "panel set id="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v2, " v="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {p1}, Ljava/util/Arrays;->toString([I)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    if-eqz p1, :done
    array-length v1, p1
    if-eqz v1, :done
    const/4 v1, 0x0
    aget v1, p1, v1
    const/4 v2, 0x0
    const/16 v3, 0x16
    if-ne p0, v3, :not22
    const-string v2, "/sys/kernel/oplus_display/dimlayer_hbm"
    :not22
    const/16 v3, 0xc
    if-ne p0, v3, :not12
    const-string v2, "/sys/kernel/oplus_display/hbm"
    :not12
    const/16 v3, 0x1c
    if-ne p0, v3, :write
    const-string v2, "/sys/kernel/oplus_display/notify_fppress"
    :write
    if-eqz v2, :done
    invoke-static {v2, v1}, Lport/PanelBinder;->portWrite(Ljava/lang/String;I)V
    :done
    const/4 v0, 0x0
    return v0
.end method

.method private static portWrite(Ljava/lang/String;I)V
    .registers 5
    :try_start
    new-instance v0, Ljava/io/FileOutputStream;
    invoke-direct {v0, p0}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;)V
    invoke-static {p1}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v1}, Ljava/lang/String;->getBytes()[B
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/io/FileOutputStream;->write([B)V
    invoke-virtual {v0}, Ljava/io/FileOutputStream;->close()V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :caught
    return-void
    :caught
    move-exception v0
    const-string v1, "OplusStub"
    const-string v2, "panel write failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method
