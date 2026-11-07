# OnePlus7Port: alert slider -> ColorOS 17 action button (user's mapping).
# The PLK110 donor (OnePlus 15) has an action button instead of a slider: ColorOS's slider path (AlertSliderHw) is off
# (feature oplus.software.audio.alert_slider absent) and ring/vibrate/silent is on volume-up + power. The guacamole
# tri-state key driver reports KEY_F3 on input device "oplus,tri-state-key" and the position in
# /proc/tristatekey/tri_state (1 up, 2 middle, 3 down). Like LineageOS's KeyHandler, this reads the position on each
# event and acts once per change:
#   up     -> action button press      (KEYCODE_ACTION_BUTTON_CLICK 780, released at once; a held key is released first)
#   middle -> nothing
#   down   -> B24: action button HELD (780 ACTION_DOWN, kept down until the slider leaves DOWN; port.SliderHold)
# ColorOS's StrategyActionButtonKeyLaunchApp turns 780 into its click/long-press events for com.oplus.gesture, which
# runs the action chosen in Settings. The input device is grabbed (EVIOCGRAB) so KEY_F3 doesn't reach apps.
#   CLASSPATH=oplus-port-stubs.dex app_process /system/bin port.SliderBridge
.class public Lport/SliderBridge;
.super Ljava/lang/Object;

.method private static log(Ljava/lang/String;)V
    .registers 2
    const-string v0, "SliderBridge"
    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

.method public static readLine(Ljava/lang/String;)Ljava/lang/String;
    .registers 4
    :try_start
    new-instance v0, Ljava/io/BufferedReader;
    new-instance v1, Ljava/io/FileReader;
    invoke-direct {v1, p0}, Ljava/io/FileReader;-><init>(Ljava/lang/String;)V
    invoke-direct {v0, v1}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V
    invoke-virtual {v0}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0}, Ljava/io/BufferedReader;->close()V
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :caught
    if-eqz v1, :done
    invoke-virtual {v1}, Ljava/lang/String;->trim()Ljava/lang/String;
    move-result-object v1
    :done
    return-object v1
    :caught
    const/4 v0, 0x0
    return-object v0
.end method

# "1".."3" -> 1..3, anything else -> 0
.method public static parseState(Ljava/lang/String;)I
    .registers 4
    const/4 v0, 0x0
    if-eqz p0, :done
    invoke-virtual {p0}, Ljava/lang/String;->length()I
    move-result v1
    if-eqz v1, :done
    invoke-virtual {p0, v0}, Ljava/lang/String;->charAt(I)C
    move-result v1
    add-int/lit8 v1, v1, -0x30
    const/4 v2, 0x1
    if-lt v1, v2, :done
    const/4 v2, 0x3
    if-gt v1, v2, :done
    move v0, v1
    :done
    return v0
.end method

# /dev/input/eventN whose name is "oplus,tri-state-key", or null
.method private static findDevice()Ljava/lang/String;
    .registers 6
    const/4 v0, 0x0
    :loop
    const/16 v1, 0x20
    if-ge v0, v1, :none
    new-instance v1, Ljava/lang/StringBuilder;
    const-string v2, "/sys/class/input/event"
    invoke-direct {v1, v2}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v2, "/device/name"
    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v1}, Lport/SliderBridge;->readLine(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    const-string v3, "oplus,tri-state-key"
    invoke-virtual {v3, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :next
    new-instance v1, Ljava/lang/StringBuilder;
    const-string v2, "/dev/input/event"
    invoke-direct {v1, v2}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    return-object v1
    :next
    add-int/lit8 v0, v0, 0x1
    goto :loop
    :none
    const/4 v0, 0x0
    return-object v0
.end method

.method public static main([Ljava/lang/String;)V
    .registers 14
    invoke-static {}, Lport/SliderBridge;->findDevice()Ljava/lang/String;
    move-result-object v0
    if-nez v0, :found
    const-string v1, "tri-state-key input device not found"
    invoke-static {v1}, Lport/SliderBridge;->log(Ljava/lang/String;)V
    return-void
    :found
    const-string v1, "/proc/tristatekey/tri_state"
    invoke-static {v1}, Lport/SliderBridge;->readLine(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lport/SliderBridge;->parseState(Ljava/lang/String;)I
    move-result v3
    new-instance v4, Ljava/io/FileInputStream;
    invoke-direct {v4, v0}, Ljava/io/FileInputStream;-><init>(Ljava/lang/String;)V
    :try_grab
    invoke-virtual {v4}, Ljava/io/FileInputStream;->getFD()Ljava/io/FileDescriptor;
    move-result-object v5
    const v6, 0x40044590
    invoke-static {v5, v6}, Landroid/system/Os;->ioctlInt(Ljava/io/FileDescriptor;I)I
    :try_grab_end
    .catch Ljava/lang/Throwable; {:try_grab .. :try_grab_end} :grab_fail
    const-string v5, "grabbed "
    goto :log_start
    :grab_fail
    move-exception v5
    const-string v5, "not grabbed "
    :log_start
    new-instance v6, Ljava/lang/StringBuilder;
    invoke-direct {v6, v5}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v6, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v5, ", position "
    invoke-virtual {v6, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v6, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v6
    invoke-static {v6}, Lport/SliderBridge;->log(Ljava/lang/String;)V
    invoke-static {}, Lport/SliderHold;->recover()V
    new-instance v9, Ljava/lang/Thread;
    new-instance v11, Lport/SliderHold;
    const/4 v12, 0x0
    invoke-direct {v11, v12}, Lport/SliderHold;-><init>(I)V
    invoke-direct {v9, v11}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    const/4 v12, 0x1
    invoke-virtual {v9, v12}, Ljava/lang/Thread;->setDaemon(Z)V
    invoke-virtual {v9}, Ljava/lang/Thread;->start()V
    invoke-static {}, Ljava/lang/Runtime;->getRuntime()Ljava/lang/Runtime;
    move-result-object v9
    new-instance v11, Ljava/lang/Thread;
    new-instance v12, Lport/SliderHold;
    const/4 v13, 0x1
    invoke-direct {v12, v13}, Lport/SliderHold;-><init>(I)V
    invoke-direct {v11, v12}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    invoke-virtual {v9, v11}, Ljava/lang/Runtime;->addShutdownHook(Ljava/lang/Thread;)V
    const/16 v5, 0x18
    new-array v5, v5, [B
    :read
    invoke-virtual {v4, v5}, Ljava/io/FileInputStream;->read([B)I
    move-result v6
    if-ltz v6, :eof
    const/16 v7, 0x18
    if-lt v6, v7, :read
    # struct input_event (arm64): timeval 16 bytes, u16 type, u16 code, s32 value (little endian)
    const/16 v7, 0x10
    aget-byte v7, v5, v7
    const/4 v8, 0x1
    if-ne v7, v8, :read
    const/16 v7, 0x12
    aget-byte v7, v5, v7
    const/16 v8, 0x3d
    if-ne v7, v8, :read
    const-wide/16 v7, 0x64
    invoke-static {v7, v8}, Ljava/lang/Thread;->sleep(J)V
    invoke-static {v1}, Lport/SliderBridge;->readLine(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lport/SliderBridge;->parseState(Ljava/lang/String;)I
    move-result v6
    if-eq v6, v3, :read
    move v3, v6
    new-instance v7, Ljava/lang/StringBuilder;
    const-string v8, "position "
    invoke-direct {v7, v8}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v7, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v7}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v7
    invoke-static {v7}, Lport/SliderBridge;->log(Ljava/lang/String;)V
    const/16 v10, 0x30c
    const/4 v7, 0x3
    if-eq v6, v7, :to_down
    const-string v7, "slider left DOWN"
    invoke-static {v7}, Lport/SliderHold;->up(Ljava/lang/String;)V
    const/4 v7, 0x1
    if-ne v6, v7, :read
    const-wide/16 v7, 0x0
    invoke-static {v10, v7, v8}, Lport/KeyInject;->press(IJ)V
    goto :read
    :to_down
    invoke-static {}, Lport/SliderHold;->down()V
    goto :read
    :eof
    const-string v1, "input device closed"
    invoke-static {v1}, Lport/SliderHold;->up(Ljava/lang/String;)V
    invoke-static {v1}, Lport/SliderBridge;->log(Ljava/lang/String;)V
    return-void
.end method
