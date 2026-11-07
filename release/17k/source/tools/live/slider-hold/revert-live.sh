#!/system/bin/sh
# B24 revert (root): drop the bind mount (original 17k dex is back underneath) and restart port_slider_bridge.
[ "$(id -u)" = 0 ] || { echo need root; exit 1; }
D=/system/framework/oplus-port-stubs.dex
while grep -q " $D " /proc/mounts; do umount $D || break; done
sha256sum $D   # expect a77bd144...b35dd
stop port_slider_bridge; sleep 1
while grep -q " $D " /proc/mounts; do umount $D || break; done
start port_slider_bridge; sleep 3
getprop init.svc.port_slider_bridge
