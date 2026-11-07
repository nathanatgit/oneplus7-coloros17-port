# OnePlus7Port: generic stand-in for an Oplus vendor AIDL service the LineageOS vendor lacks.
# Answers INTERFACE_TRANSACTION with the real descriptor (NDK fromBinder() check) and every method call with
# "no exception" + zeroed return values, so callers stop waiting 5 s in AServiceManager_getService.
.class public Lport/StubBinder;
.super Landroid/os/Binder;

.field private final desc:Ljava/lang/String;

.method public constructor <init>(Ljava/lang/String;)V
    .registers 2
    invoke-direct {p0, p1}, Landroid/os/Binder;-><init>(Ljava/lang/String;)V
    iput-object p1, p0, Lport/StubBinder;->desc:Ljava/lang/String;
    return-void
.end method

.method protected onTransact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    .registers 9
    const/4 v0, 0x1
    if-lt p1, v0, :super
    const v0, 0xffffff
    if-gt p1, v0, :super
    const-string v0, "OplusStub"
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V
    iget-object v2, p0, Lport/StubBinder;->desc:Ljava/lang/String;
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v2, " code="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v0, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I
    if-eqz p3, :done
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    const/4 v0, 0x0
    const/16 v1, 0x10
    :loop
    if-eqz v1, :done
    invoke-virtual {p3, v0}, Landroid/os/Parcel;->writeInt(I)V
    add-int/lit8 v1, v1, -0x1
    goto :loop
    :done
    const/4 v0, 0x1
    return v0
    :super
    invoke-super {p0, p1, p2, p3, p4}, Landroid/os/Binder;->onTransact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    move-result v0
    return v0
.end method
