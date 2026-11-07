#!/system/bin/sh
# Magisk service.d hook: register dummy IOfflineCameraService (B27).
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
sleep 5
N=vendor.qti.hardware.camera.offlinecamera.IOfflineCameraService/default
service list | grep -q "$N" && exit 0
CLASSPATH=/system/framework/oplus-port-stubs.dex setsid app_process /system/bin port.OplusStubs $N >/dev/null 2>&1 </dev/null &
