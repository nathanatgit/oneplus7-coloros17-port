#!/system/bin/sh
# B24 live deploy (root): bind-mount the hold dex over /system/framework/oplus-port-stubs.dex and restart ONLY port_slider_bridge.
# Revert: sh /data/local/tmp/slider-hold/revert-live.sh   (reboot also reverts: the mount is not persistent)
[ "$(id -u)" = 0 ] || { echo need root; exit 1; }
W=/data/local/tmp/slider-hold; D=/system/framework/oplus-port-stubs.dex
[ -f $W/oplus-port-stubs.hold.dex ] || { echo missing hold dex; exit 1; }
chmod 0644 $W/oplus-port-stubs.hold.dex
stop port_slider_bridge; sleep 1
while grep -q " $D " /proc/mounts; do umount $D || break; done
mount -o bind $W/oplus-port-stubs.hold.dex $D || { echo bind failed; exit 1; }
sha256sum $D
start port_slider_bridge; sleep 3
getprop init.svc.port_slider_bridge
