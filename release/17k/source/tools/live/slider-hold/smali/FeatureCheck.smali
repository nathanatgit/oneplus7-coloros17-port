# OnePlus7Port: print OplusFeatureConfigManager.hasFeature(<name>) as system_server-side code sees it.
#   CLASSPATH=oplus-stubs.dex app_process /system/bin port.FeatureCheck <feature>
.class public Lport/FeatureCheck;
.super Ljava/lang/Object;

.method public static main([Ljava/lang/String;)V
    .registers 5
    const/4 v0, 0x0
    aget-object v0, p0, v0
    invoke-static {}, Lcom/oplus/content/OplusFeatureConfigManager;->getInstacne()Lcom/oplus/content/OplusFeatureConfigManager;
    move-result-object v1
    invoke-virtual {v1, v0}, Lcom/oplus/content/OplusFeatureConfigManager;->hasFeature(Ljava/lang/String;)Z
    move-result v1
    sget-object v2, Ljava/lang/System;->out:Ljava/io/PrintStream;
    new-instance v3, Ljava/lang/StringBuilder;
    invoke-direct {v3, v0}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    const-string v0, " = "
    invoke-virtual {v3, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-virtual {v2, v0}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    return-void
.end method
