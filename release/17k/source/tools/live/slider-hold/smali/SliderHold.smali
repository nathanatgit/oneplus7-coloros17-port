# OnePlus7Port B24: hold state of the action button for port.SliderBridge. DOWN = KEYCODE_ACTION_BUTTON_CLICK (780)
# pressed (ACTION_DOWN once) and kept down until released here; InputDispatcher then generates the key repeats
# (repeatCount>0, FLAG_LONG_PRESS) for the held injected key. Release is guaranteed by: SliderBridge on every
# position change away from DOWN, a watchdog thread (tri_state != 3, screen not interactive), and a shutdown hook.
.class public Lport/SliderHold;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

.field private final mode:I
.field private static held:Z
.field private static downTime:J
# B25b: DOWN counter (a pending cleanup is void if a newer hold started) and grace period after key UP before the
# 一键闪记 capture (com.oplus.aimemory voice task + FlashMemoryAnimation overlay) is force-stopped if still open
.field private static volatile gen:I
.field private static final GRACE_MS:J = 0xbb8L

.method public constructor <init>(I)V
    .registers 2
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    iput p1, p0, Lport/SliderHold;->mode:I
    return-void
.end method

.method private static log(Ljava/lang/String;)V
    .registers 2
    const-string v0, "SliderBridge"
    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

# B25b: if com.oplus.aimemory still holds a mic AudioRecord (dumpsys audio history: rec start without rec release) or its
# FlashMemoryAnimation overlay exists, force-stop aimemory (+ gleanerservice if running). Blocks until the script ends.
.method private static reap()V
    .registers 6
    :try_start
    const/4 v0, 0x3
    new-array v0, v0, [Ljava/lang/String;
    const/4 v1, 0x0
    const-string v2, "/system/bin/sh"
    aput-object v2, v0, v1
    const/4 v1, 0x1
    const-string v2, "-c"
    aput-object v2, v0, v1
    const/4 v1, 0x2
    const-string v2, "busy() { dumpsys audio | grep -q 'source client=.*pack:com.oplus.aimemory' && return 0; dumpsys window windows | grep -q 'Window{[^}]* FlashMemoryAnimation'; }; if busy; then am force-stop com.oplus.aimemory; pidof com.oplus.gleanerservice && am force-stop com.oplus.gleanerservice; echo reaped; fi 2>&1"
    aput-object v2, v0, v1
    invoke-static {}, Ljava/lang/Runtime;->getRuntime()Ljava/lang/Runtime;
    move-result-object v1
    invoke-virtual {v1, v0}, Ljava/lang/Runtime;->exec([Ljava/lang/String;)Ljava/lang/Process;
    move-result-object v1
    new-instance v2, Ljava/io/BufferedReader;
    new-instance v3, Ljava/io/InputStreamReader;
    invoke-virtual {v1}, Ljava/lang/Process;->getInputStream()Ljava/io/InputStream;
    move-result-object v4
    invoke-direct {v3, v4}, Ljava/io/InputStreamReader;-><init>(Ljava/io/InputStream;)V
    invoke-direct {v2, v3}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V
    :rd
    invoke-virtual {v2}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;
    move-result-object v3
    if-eqz v3, :eof
    const-string v4, "reaped"
    invoke-virtual {v4, v3}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v4
    if-eqz v4, :rd
    const-string v4, "hold: capture still open, force-stopped com.oplus.aimemory"
    invoke-static {v4}, Lport/SliderHold;->log(Ljava/lang/String;)V
    goto :rd
    :eof
    invoke-virtual {v1}, Ljava/lang/Process;->waitFor()I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :caught
    :caught
    return-void
.end method

# B25b: after a key UP, reap() after GRACE_MS unless a newer hold started (thread mode = gen + 2)
.method private static schedule()V
    .registers 4
    new-instance v0, Ljava/lang/Thread;
    new-instance v1, Lport/SliderHold;
    sget v2, Lport/SliderHold;->gen:I
    add-int/lit8 v2, v2, 0x2
    invoke-direct {v1, v2}, Lport/SliderHold;-><init>(I)V
    invoke-direct {v0, v1}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/lang/Thread;->setDaemon(Z)V
    invoke-virtual {v0}, Ljava/lang/Thread;->start()V
    return-void
.end method

# marker file (tmpfs, cleared by reboot) so a restarted bridge can release a key left down by a killed predecessor
# (SIGTERM/SIGKILL give the JVM no chance to run the shutdown hook)
.method private static mark(J)V
    .registers 5
    :try_start
    new-instance v0, Ljava/io/FileWriter;
    const-string v1, "/dev/port-slider-held"
    invoke-direct {v0, v1}, Ljava/io/FileWriter;-><init>(Ljava/lang/String;)V
    invoke-static {p0, p1}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/io/Writer;->write(Ljava/lang/String;)V
    invoke-virtual {v0}, Ljava/io/Writer;->close()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :caught
    :caught
    return-void
.end method

.method private static unmark()V
    .registers 3
    :try_start
    new-instance v0, Ljava/io/File;
    const-string v1, "/dev/port-slider-held"
    invoke-direct {v0, v1}, Ljava/io/File;-><init>(Ljava/lang/String;)V
    invoke-virtual {v0}, Ljava/io/File;->delete()Z
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :caught
    :caught
    return-void
.end method

# called once at bridge start: release a key a previous (killed) bridge left held
.method public static recover()V
    .registers 5
    :try_start
    const-string v0, "/dev/port-slider-held"
    invoke-static {v0}, Lport/SliderBridge;->readLine(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    if-eqz v0, :done
    invoke-static {v0}, Ljava/lang/Long;->parseLong(Ljava/lang/String;)J
    move-result-wide v1
    const/16 v0, 0x30c
    invoke-static {v0, v1, v2}, Lport/KeyInject;->up(IJ)V
    invoke-static {}, Lport/SliderHold;->unmark()V
    const-string v0, "hold: released stale key 780 left by a previous bridge"
    invoke-static {v0}, Lport/SliderHold;->log(Ljava/lang/String;)V
    invoke-static {}, Lport/SliderHold;->schedule()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :caught
    :done
    :caught
    return-void
.end method

# true if the screen is interactive (on); true when it cannot be determined
.method private static isInteractive()Z
    .registers 2
    :try_start
    const-string v0, "power"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    invoke-static {v0}, Landroid/os/IPowerManager$Stub;->asInterface(Landroid/os/IBinder;)Landroid/os/IPowerManager;
    move-result-object v0
    invoke-interface {v0}, Landroid/os/IPowerManager;->isInteractive()Z
    move-result v0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :caught
    return v0
    :caught
    move-exception v0
    const/4 v0, 0x1
    return v0
.end method

.method public static declared-synchronized down()V
    .registers 3
    sget-boolean v0, Lport/SliderHold;->held:Z
    if-nez v0, :done
    invoke-static {}, Lport/SliderHold;->isInteractive()Z
    move-result v0
    if-nez v0, :go
    const-string v0, "hold: DOWN ignored, screen off"
    invoke-static {v0}, Lport/SliderHold;->log(Ljava/lang/String;)V
    goto :done
    :go
    # B25b: new hold: void pending cleanups and clear a stale capture (mic/overlay left by an earlier hold) first
    sget v0, Lport/SliderHold;->gen:I
    add-int/lit8 v0, v0, 0x1
    sput v0, Lport/SliderHold;->gen:I
    invoke-static {}, Lport/SliderHold;->reap()V
    const/16 v0, 0x30c
    invoke-static {v0}, Lport/KeyInject;->down(I)J
    move-result-wide v1
    sput-wide v1, Lport/SliderHold;->downTime:J
    const/4 v0, 0x1
    sput-boolean v0, Lport/SliderHold;->held:Z
    invoke-static {v1, v2}, Lport/SliderHold;->mark(J)V
    const-string v0, "hold: key 780 DOWN (held)"
    invoke-static {v0}, Lport/SliderHold;->log(Ljava/lang/String;)V
    :done
    return-void
.end method

.method public static declared-synchronized up(Ljava/lang/String;)V
    .registers 5
    sget-boolean v0, Lport/SliderHold;->held:Z
    if-eqz v0, :done
    const/4 v0, 0x0
    sput-boolean v0, Lport/SliderHold;->held:Z
    const/16 v0, 0x30c
    sget-wide v1, Lport/SliderHold;->downTime:J
    invoke-static {v0, v1, v2}, Lport/KeyInject;->up(IJ)V
    invoke-static {}, Lport/SliderHold;->unmark()V
    new-instance v0, Ljava/lang/StringBuilder;
    const-string v1, "hold: key 780 UP ("
    invoke-direct {v0, v1}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, ")"
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lport/SliderHold;->log(Ljava/lang/String;)V
    invoke-static {}, Lport/SliderHold;->schedule()V
    :done
    return-void
.end method

# mode 1: shutdown hook; mode 0: watchdog (every 150 ms while held; 2 consecutive reads != 3 = slider left DOWN)
.method public run()V
    .registers 4
    iget v0, p0, Lport/SliderHold;->mode:I
    const/4 v1, 0x2
    if-lt v0, v1, :legacy
    # mode >= 2: delayed cleanup (see schedule())
    :try_clean
    sget-wide v1, Lport/SliderHold;->GRACE_MS:J
    invoke-static {v1, v2}, Ljava/lang/Thread;->sleep(J)V
    sget v1, Lport/SliderHold;->gen:I
    add-int/lit8 v1, v1, 0x2
    if-ne v1, v0, :clean_done
    sget-boolean v1, Lport/SliderHold;->held:Z
    if-nez v1, :clean_done
    invoke-static {}, Lport/SliderHold;->reap()V
    :clean_done
    return-void
    :try_clean_end
    .catch Ljava/lang/Throwable; {:try_clean .. :try_clean_end} :clean_caught
    :clean_caught
    return-void
    :legacy
    const/4 v2, 0x0
    const/4 v1, 0x1
    if-ne v0, v1, :loop
    :try_hook
    const-string v0, "service stopped"
    invoke-static {v0}, Lport/SliderHold;->up(Ljava/lang/String;)V
    invoke-static {}, Lport/SliderHold;->reap()V
    :try_hook_end
    .catch Ljava/lang/Throwable; {:try_hook .. :try_hook_end} :hook_caught
    :hook_caught
    return-void
    :loop
    :try_start
    const-wide/16 v0, 0x96
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    sget-boolean v0, Lport/SliderHold;->held:Z
    if-nez v0, :check
    const/4 v2, 0x0
    goto :loop
    :check
    const-string v0, "/proc/tristatekey/tri_state"
    invoke-static {v0}, Lport/SliderBridge;->readLine(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lport/SliderBridge;->parseState(Ljava/lang/String;)I
    move-result v0
    const/4 v1, 0x3
    if-eq v0, v1, :still_down
    add-int/lit8 v2, v2, 0x1
    const/4 v1, 0x2
    if-lt v2, v1, :loop
    const/4 v2, 0x0
    const-string v0, "watchdog: slider left DOWN"
    invoke-static {v0}, Lport/SliderHold;->up(Ljava/lang/String;)V
    goto :loop
    :still_down
    const/4 v2, 0x0
    invoke-static {}, Lport/SliderHold;->isInteractive()Z
    move-result v0
    if-nez v0, :loop
    const-string v0, "screen off"
    invoke-static {v0}, Lport/SliderHold;->up(Ljava/lang/String;)V
    goto :loop
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :caught
    :caught
    move-exception v0
    goto :loop
.end method
