# OnePlus7Port: pop-up front camera motor, started by init as root (not an app: ColorOS FastClear killed the
# repackaged LineageOS OnePlusCameraHelper user app, leaving the camera up).
# Same logic as LineageOS android_device_oneplus_sm8150-common camera_helper CameraMotorService, without a Context:
# it registers an ICameraServiceListener with cameraserver directly (what CameraManager's AvailabilityCallback uses).
# Camera ID "1" (front) STATUS_NOT_AVAILABLE (-2, a client opened it) -> raise; STATUS_PRESENT (1, released) -> lower.
# 100 ms debounce like LOS CAMERA_EVENT_DELAY_TIME; the last event wins. Motor nodes as in LOS CameraMotorController:
# /sys/class/motor/direction (1 up, 0 down) then enable=1. Calibration is done by the LOS vendor init already.
# At start (no camera open at boot) the camera is lowered if /sys/class/motor/position says up (0).
# If cameraserver dies the process exits; init restarts it and it registers again.
#   CLASSPATH=oplus-port-stubs.dex app_process /system/bin port.MotorBridge
.class public Lport/MotorBridge;
.super Landroid/hardware/ICameraServiceListener$Stub;
.implements Landroid/os/Handler$Callback;
.implements Landroid/os/IBinder$DeathRecipient;

.field private mHandler:Landroid/os/Handler;

.method public constructor <init>()V
    .registers 2
    invoke-direct {p0}, Landroid/hardware/ICameraServiceListener$Stub;-><init>()V
    return-void
.end method

.method private static log(Ljava/lang/String;)V
    .registers 2
    const-string v0, "MotorBridge"
    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

.method private static write(Ljava/lang/String;Ljava/lang/String;)V
    .registers 5
    :try_start
    new-instance v0, Ljava/io/FileOutputStream;
    invoke-direct {v0, p0}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;)V
    invoke-virtual {p1}, Ljava/lang/String;->getBytes()[B
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/io/FileOutputStream;->write([B)V
    invoke-virtual {v0}, Ljava/io/FileOutputStream;->close()V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :caught
    return-void
    :caught
    move-exception v0
    new-instance v1, Ljava/lang/StringBuilder;
    const-string v2, "write failed: "
    invoke-direct {v1, v2}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v1, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v2, " "
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v1}, Lport/MotorBridge;->log(Ljava/lang/String;)V
    return-void
.end method

.method private static readPosition()Ljava/lang/String;
    .registers 3
    :try_start
    new-instance v0, Ljava/io/BufferedReader;
    new-instance v1, Ljava/io/FileReader;
    const-string v2, "/sys/class/motor/position"
    invoke-direct {v1, v2}, Ljava/io/FileReader;-><init>(Ljava/lang/String;)V
    invoke-direct {v0, v1}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V
    invoke-virtual {v0}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0}, Ljava/io/BufferedReader;->close()V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :caught
    if-eqz v1, :caught
    invoke-virtual {v1}, Ljava/lang/String;->trim()Ljava/lang/String;
    move-result-object v1
    return-object v1
    :caught
    const-string v1, ""
    return-object v1
.end method

# direction: "1" up, "0" down
.method private static move(Ljava/lang/String;)V
    .registers 3
    const-string v0, "/sys/class/motor/direction"
    invoke-static {v0, p0}, Lport/MotorBridge;->write(Ljava/lang/String;Ljava/lang/String;)V
    const-string v0, "/sys/class/motor/enable"
    const-string v1, "1"
    invoke-static {v0, v1}, Lport/MotorBridge;->write(Ljava/lang/String;Ljava/lang/String;)V
    new-instance v0, Ljava/lang/StringBuilder;
    const-string v1, "motor direction="
    invoke-direct {v0, v1}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lport/MotorBridge;->log(Ljava/lang/String;)V
    return-void
.end method

# Handler.Callback: 1001 = raise, 1000 = lower
.method public handleMessage(Landroid/os/Message;)Z
    .registers 4
    iget v0, p1, Landroid/os/Message;->what:I
    const/16 v1, 0x3e9
    if-ne v0, v1, :not_up
    const-string v1, "1"
    invoke-static {v1}, Lport/MotorBridge;->move(Ljava/lang/String;)V
    goto :done
    :not_up
    const/16 v1, 0x3e8
    if-ne v0, v1, :done
    const-string v1, "0"
    invoke-static {v1}, Lport/MotorBridge;->move(Ljava/lang/String;)V
    :done
    const/4 v0, 0x1
    return v0
.end method

# ICameraServiceListener.onStatusChanged(status, cameraId, deviceId) — binder thread -> main looper
.method public onStatusChanged(ILjava/lang/String;I)V
    .registers 8
    const-string v0, "1"
    invoke-virtual {v0, p2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :ret
    const/4 v0, -0x2
    if-ne p1, v0, :not_open
    const/16 v1, 0x3e9
    goto :post
    :not_open
    const/4 v0, 0x1
    if-ne p1, v0, :ret
    const/16 v1, 0x3e8
    :post
    iget-object v2, p0, Lport/MotorBridge;->mHandler:Landroid/os/Handler;
    const/16 v3, 0x3e8
    invoke-virtual {v2, v3}, Landroid/os/Handler;->removeMessages(I)V
    const/16 v3, 0x3e9
    invoke-virtual {v2, v3}, Landroid/os/Handler;->removeMessages(I)V
    const-wide/16 v4, 0x64
    invoke-virtual {v2, v1, v4, v5}, Landroid/os/Handler;->sendEmptyMessageDelayed(IJ)Z
    :ret
    return-void
.end method

.method public onCameraAccessPrioritiesChanged()V
    .registers 1
    return-void
.end method

.method public onCameraClosed(Ljava/lang/String;I)V
    .registers 3
    return-void
.end method

.method public onCameraOpened(Ljava/lang/String;Ljava/lang/String;I)V
    .registers 4
    return-void
.end method

.method public onCameraOpenedInSharedMode(Ljava/lang/String;Ljava/lang/String;IZ)V
    .registers 5
    return-void
.end method

.method public onPhysicalCameraStatusChanged(ILjava/lang/String;Ljava/lang/String;I)V
    .registers 5
    return-void
.end method

.method public onTorchStatusChanged(ILjava/lang/String;I)V
    .registers 4
    return-void
.end method

.method public onTorchStrengthLevelChanged(Ljava/lang/String;II)V
    .registers 4
    return-void
.end method

# cameraserver died: exit, init restarts the service and it registers again
.method public binderDied()V
    .registers 2
    const-string v0, "cameraserver died, exiting for restart"
    invoke-static {v0}, Lport/MotorBridge;->log(Ljava/lang/String;)V
    const/4 v0, 0x1
    invoke-static {v0}, Ljava/lang/System;->exit(I)V
    return-void
.end method

.method public static main([Ljava/lang/String;)V
    .registers 7
    invoke-static {}, Landroid/os/Looper;->prepareMainLooper()V
    new-instance v0, Lport/MotorBridge;
    invoke-direct {v0}, Lport/MotorBridge;-><init>()V
    new-instance v1, Landroid/os/Handler;
    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;
    move-result-object v2
    invoke-direct {v1, v2, v0}, Landroid/os/Handler;-><init>(Landroid/os/Looper;Landroid/os/Handler$Callback;)V
    iput-object v1, v0, Lport/MotorBridge;->mHandler:Landroid/os/Handler;

    # no camera is open at start: lower it if it was left up (position 0 = up)
    invoke-static {}, Lport/MotorBridge;->readPosition()Ljava/lang/String;
    move-result-object v1
    const-string v2, "0"
    invoke-virtual {v2, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v2
    if-eqz v2, :wait_service
    const-string v2, "camera was up at start, lowering"
    invoke-static {v2}, Lport/MotorBridge;->log(Ljava/lang/String;)V
    const-string v2, "0"
    invoke-static {v2}, Lport/MotorBridge;->move(Ljava/lang/String;)V

    :wait_service
    const-string v1, "media.camera"
    invoke-static {v1}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v1
    if-nez v1, :got_service
    const-wide/16 v2, 0x3e8
    invoke-static {v2, v3}, Ljava/lang/Thread;->sleep(J)V
    goto :wait_service

    :got_service
    const/4 v2, 0x0
    invoke-interface {v1, v0, v2}, Landroid/os/IBinder;->linkToDeath(Landroid/os/IBinder$DeathRecipient;I)V
    invoke-static {v1}, Landroid/hardware/ICameraService$Stub;->asInterface(Landroid/os/IBinder;)Landroid/hardware/ICameraService;
    move-result-object v2
    invoke-interface {v2, v0}, Landroid/hardware/ICameraService;->addListener(Landroid/hardware/ICameraServiceListener;)[Landroid/hardware/CameraStatus;
    const-string v2, "listening to cameraserver (front camera id 1)"
    invoke-static {v2}, Lport/MotorBridge;->log(Ljava/lang/String;)V
    invoke-static {}, Landroid/os/Looper;->loop()V
    return-void
.end method
