# Also serves AIDL vendor.oplus.hardware.misc.IOplusMisc (V1, hash a899a863...: same txn 1-4 shapes; 5 =
# saveCalibrationData -> false). Misc flag 122 = /proc/tristatekey/tri_state (AlertSliderHw.getHwKeyState, "1/2/3");
# other misc flags are only logged (stock H.40 misc@1.0-service table order unknown).
# OnePlus7Port: AIDL vendor.oplus.hardware.touch.IOplusTouch (V2, hash ef41c5fa...), the ColorOS 17 path to the
# touch-panel nodes (ColorTouchNodeManagerService; no HIDL fallback). The LOS vendor only has vendor.lineage.touch.
# nodeFlag = com.oplus.touchnode.OplusTouchNodeManager constants = index into the stock H.40
# vendor.oplus.hardware.touch@1.0-service path table (1 double_tap_enable, 2 coordinate, ... 22 oplus_optimized_time).
#   1 initialize()I                          -> 0
#   2 isTouchNodeSupport(int dId, int flag)I -> 1 if the node exists
#   3 touchReadNodeFile(int dId, int flag)String
#   4 touchWriteNodeFile(int dId, int flag, String)I -> 0 / -1
#   6 touchWriteNodeFileOneWay(int, int, String) (oneway)
#   5 touchWriteBtInfo, 7 touchNotifyClient, 8/9 (un)registerEventCallback -> 0
.class public Lport/TouchBinder;
.super Lport/StubBinder;

.field private final mDesc:Ljava/lang/String;
.field private final mMisc:Z

.method public constructor <init>(Ljava/lang/String;)V
    .registers 3
    invoke-direct {p0, p1}, Lport/StubBinder;-><init>(Ljava/lang/String;)V
    iput-object p1, p0, Lport/TouchBinder;->mDesc:Ljava/lang/String;
    const-string v0, "hardware.misc.IOplusMisc"
    invoke-virtual {p1, v0}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v0
    iput-boolean v0, p0, Lport/TouchBinder;->mMisc:Z
    return-void
.end method

.method private nodePath(I)Ljava/lang/String;
    .registers 4
    iget-boolean v0, p0, Lport/TouchBinder;->mMisc:Z
    if-nez v0, :misc
    invoke-static {p1}, Lport/TouchBinder;->portPath(I)Ljava/lang/String;
    move-result-object v0
    return-object v0
    :misc
    const/16 v0, 0x7a
    if-ne p1, v0, :none
    const-string v0, "/proc/tristatekey/tri_state"
    return-object v0
    :none
    const/4 v0, 0x0
    return-object v0
.end method

.method protected onTransact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    .registers 12
    const v0, 0xffffff
    if-ne p1, v0, :not_version
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    const/4 v0, 0x2
    iget-boolean v1, p0, Lport/TouchBinder;->mMisc:Z
    if-eqz v1, :touch_ver
    const/4 v0, 0x1
    :touch_ver
    invoke-virtual {p3, v0}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v0, 0x1
    return v0
    :not_version
    const v0, 0xfffffe
    if-ne p1, v0, :not_hash
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    const-string v0, "ef41c5fab372bb5ad6a417f606845c87cf0e9b17"
    iget-boolean v1, p0, Lport/TouchBinder;->mMisc:Z
    if-eqz v1, :touch_hash
    const-string v0, "a899a863d8a7e0b5ed35ced2275f2ba68aaad329"
    :touch_hash
    invoke-virtual {p3, v0}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V
    const/4 v0, 0x1
    return v0
    :not_hash
    const/4 v0, 0x1
    if-lt p1, v0, :super
    const/16 v0, 0x9
    if-gt p1, v0, :super
    iget-object v0, p0, Lport/TouchBinder;->mDesc:Ljava/lang/String;
    invoke-virtual {p2, v0}, Landroid/os/Parcel;->enforceInterface(Ljava/lang/String;)V
    const/4 v1, 0x0
    const/4 v0, 0x2
    if-ne p1, v0, :not_support
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    move-result v3
    invoke-direct {p0, v3}, Lport/TouchBinder;->nodePath(I)Ljava/lang/String;
    move-result-object v4
    if-eqz v4, :reply_int
    new-instance v5, Ljava/io/File;
    invoke-direct {v5, v4}, Ljava/io/File;-><init>(Ljava/lang/String;)V
    invoke-virtual {v5}, Ljava/io/File;->exists()Z
    move-result v1
    goto :reply_int
    :not_support
    const/4 v0, 0x3
    if-ne p1, v0, :not_read
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    move-result v3
    invoke-direct {p0, v3}, Lport/TouchBinder;->nodePath(I)Ljava/lang/String;
    move-result-object v4
    invoke-static {v3, v4}, Lport/TouchBinder;->portRead(ILjava/lang/String;)Ljava/lang/String;
    move-result-object v5
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    invoke-virtual {p3, v5}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V
    const/4 v0, 0x1
    return v0
    :not_read
    const/4 v0, 0x4
    if-eq p1, v0, :write
    const/4 v0, 0x6
    if-ne p1, v0, :reply_int
    :write
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    invoke-virtual {p2}, Landroid/os/Parcel;->readInt()I
    move-result v3
    invoke-virtual {p2}, Landroid/os/Parcel;->readString()Ljava/lang/String;
    move-result-object v5
    invoke-direct {p0, v3}, Lport/TouchBinder;->nodePath(I)Ljava/lang/String;
    move-result-object v4
    invoke-static {v3, v4, v5}, Lport/TouchBinder;->portWrite(ILjava/lang/String;Ljava/lang/String;)I
    move-result v1
    const/4 v0, 0x6
    if-ne p1, v0, :reply_int
    const/4 v0, 0x1
    return v0
    :reply_int
    invoke-virtual {p3}, Landroid/os/Parcel;->writeNoException()V
    invoke-virtual {p3, v1}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v0, 0x1
    return v0
    :super
    invoke-super {p0, p1, p2, p3, p4}, Lport/StubBinder;->onTransact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    move-result v0
    return v0
.end method

# nodeFlag -> /proc/touchpanel/<name> (stock H.40 table order), null when unknown
.method public static portPath(I)Ljava/lang/String;
    .registers 5
    const-string v0, "|double_tap_enable|coordinate|baseline_test|calibration|oplus_tp_direction|oplus_tp_limit_whitelist|oplus_tp_limit_enable|kernel_grip_handle|report_rate_white_list|charge_detect|wireless_charge_detect|headset_detect|black_screen_test|baseline_result|black_screen_result|tp_aging_test|debug_info/delta|debug_info/baseline|earsense/hover_selfdata|debug_info/health_monitor|double_tap_enable_indep|oplus_optimized_time"
    const-string v1, "\\|"
    invoke-virtual {v0, v1}, Ljava/lang/String;->split(Ljava/lang/String;)[Ljava/lang/String;
    move-result-object v0
    const/4 v2, 0x0
    if-lt p0, v2, :none
    array-length v1, v0
    if-ge p0, v1, :none
    if-eqz p0, :none
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V
    const-string v3, "/proc/touchpanel/"
    invoke-virtual {v1, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    aget-object v3, v0, p0
    invoke-virtual {v1, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    return-object v0
    :none
    const/4 v0, 0x0
    return-object v0
.end method

.method private static portRead(ILjava/lang/String;)Ljava/lang/String;
    .registers 6
    const-string v0, ""
    if-eqz p1, :log
    :try_start
    new-instance v1, Ljava/io/FileInputStream;
    invoke-direct {v1, p1}, Ljava/io/FileInputStream;-><init>(Ljava/lang/String;)V
    invoke-virtual {v1}, Ljava/io/InputStream;->readAllBytes()[B
    move-result-object v2
    invoke-virtual {v1}, Ljava/io/FileInputStream;->close()V
    new-instance v0, Ljava/lang/String;
    invoke-direct {v0, v2}, Ljava/lang/String;-><init>([B)V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :caught
    goto :log
    :caught
    move-exception v1
    const-string v0, ""
    :log
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V
    const-string v2, "touch read flag="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v2, " -> "
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    const-string v2, "OplusStub"
    invoke-static {v2, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-object v0
.end method

.method private static portWrite(ILjava/lang/String;Ljava/lang/String;)I
    .registers 7
    const/4 v0, -0x1
    if-eqz p1, :log
    if-eqz p2, :log
    :try_start
    # flag 21 = double_tap_enable_indep gesture mask. With AOD on, SystemUI writes mode 16 (|0x10000 single tap,
    # &~0x2 double tap) while the screen is off, expecting stock firmware that still reports double taps. The LOS
    # driver then drops double taps -> nothing wakes the phone. Keep double tap (KEY_WAKEUP) on; single tap stays as
    # SystemUI asked (scancode 262 -> F4 via touchpanel.kl -> AOD tap).
    const/16 v1, 0x15
    if-ne p0, v1, :open
    invoke-virtual {p2}, Ljava/lang/String;->trim()Ljava/lang/String;
    move-result-object v1
    invoke-static {v1}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v1
    or-int/lit8 v1, v1, 0x2
    invoke-static {v1}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
    move-result-object p2
    :open
    new-instance v1, Ljava/io/FileOutputStream;
    invoke-direct {v1, p1}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;)V
    invoke-virtual {p2}, Ljava/lang/String;->getBytes()[B
    move-result-object v2
    invoke-virtual {v1, v2}, Ljava/io/FileOutputStream;->write([B)V
    invoke-virtual {v1}, Ljava/io/FileOutputStream;->close()V
    const/4 v0, 0x0
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :caught
    goto :log
    :caught
    move-exception v1
    const/4 v0, -0x1
    :log
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V
    const-string v2, "touch write flag="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v2, " v="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, p2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v2, " ret="
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    const-string v2, "OplusStub"
    invoke-static {v2, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return v0
.end method
