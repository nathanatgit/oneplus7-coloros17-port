# OnePlus7Port: inject one key press with an arbitrary key code (input(1) maps codes it doesn't know, e.g. Oplus's
# 780 action button, to KEYCODE_UNKNOWN). Usage:
#   CLASSPATH=oplus-stubs.dex app_process /system/bin port.KeyInject <keycode> <hold ms>
.class public Lport/KeyInject;
.super Ljava/lang/Object;

.method public static press(IJ)V
    .registers 9
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v0
    const/4 v2, 0x0
    invoke-static {v0, v1, v2, p0}, Lport/KeyInject;->make(JII)Landroid/view/KeyEvent;
    move-result-object v3
    invoke-static {v3}, Lport/KeyInject;->inject(Landroid/view/KeyEvent;)V
    const-wide/16 v3, 0x0
    cmp-long v3, p1, v3
    if-lez v3, :up
    invoke-static {p1, p2}, Ljava/lang/Thread;->sleep(J)V
    :up
    const/4 v2, 0x1
    invoke-static {v0, v1, v2, p0}, Lport/KeyInject;->make(JII)Landroid/view/KeyEvent;
    move-result-object v3
    invoke-static {v3}, Lport/KeyInject;->inject(Landroid/view/KeyEvent;)V
    return-void
.end method

.method private static make(JII)Landroid/view/KeyEvent;
    .registers 16
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v4
    new-instance v1, Landroid/view/KeyEvent;
    move-wide v2, p0
    move v6, p2
    move v7, p3
    const/4 v8, 0x0
    const/4 v9, 0x0
    const/4 v10, -0x1
    const/4 v11, 0x0
    const/16 v12, 0x8
    const/16 v13, 0x101
    invoke-direct/range {v1 .. v13}, Landroid/view/KeyEvent;-><init>(JJIIIIIIII)V
    return-object v1
.end method

.method private static inject(Landroid/view/KeyEvent;)V
    .registers 3
    invoke-static {}, Landroid/hardware/input/InputManagerGlobal;->getInstance()Landroid/hardware/input/InputManagerGlobal;
    move-result-object v0
    const/4 v1, 0x0
    invoke-virtual {v0, p0, v1}, Landroid/hardware/input/InputManagerGlobal;->injectInputEvent(Landroid/view/InputEvent;I)Z
    return-void
.end method

.method public static main([Ljava/lang/String;)V
    .registers 5
    const/4 v0, 0x0
    aget-object v0, p0, v0
    invoke-static {v0}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v0
    const/4 v1, 0x1
    aget-object v1, p0, v1
    invoke-static {v1}, Ljava/lang/Long;->parseLong(Ljava/lang/String;)J
    move-result-wide v1
    invoke-static {v0, v1, v2}, Lport/KeyInject;->press(IJ)V
    return-void
.end method

# B24: ACTION_DOWN only (no UP); returns the downTime to pass to up()
.method public static down(I)J
    .registers 6
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J
    move-result-wide v0
    const/4 v2, 0x0
    invoke-static {v0, v1, v2, p0}, Lport/KeyInject;->make(JII)Landroid/view/KeyEvent;
    move-result-object v3
    invoke-static {v3}, Lport/KeyInject;->inject(Landroid/view/KeyEvent;)V
    return-wide v0
.end method

# B24: ACTION_UP matching an earlier down()
.method public static up(IJ)V
    .registers 7
    const/4 v0, 0x1
    invoke-static {p1, p2, v0, p0}, Lport/KeyInject;->make(JII)Landroid/view/KeyEvent;
    move-result-object v1
    invoke-static {v1}, Lport/KeyInject;->inject(Landroid/view/KeyEvent;)V
    return-void
.end method
