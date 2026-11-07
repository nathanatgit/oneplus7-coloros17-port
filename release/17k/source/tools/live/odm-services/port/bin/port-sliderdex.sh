#!/system/bin/sh
# OnePlus7Port 17k-r2 (BAKE-LIST B24/B25b): alert slider DOWN = press-and-hold, release ends the one-key-memo capture.
# Bind-mounts /odm/bin/port-slider-hold.dex over /system/framework/oplus-port-stubs.dex BEFORE port_slider_bridge starts
# (it starts at sys.boot_completed; this runs at "on boot"). Nothing here loops or waits. Any problem = exit 0 and the stock
# dex in system.img stays in use (same classes minus port.SliderHold, i.e. the old behaviour: down = 1 s click).
# Undo live: umount /system/framework/oplus-port-stubs.dex; stop port_slider_bridge; start port_slider_bridge
D=/system/framework/oplus-port-stubs.dex
S=/odm/bin/port-slider-hold.dex
SHA=5ac5b643ae23bfb6bd078c7d7a341ea2ff54b2094fcf8987593595c22d609f54
[ -f "$S" ] || { log -t sliderdex "missing $S, stock dex kept"; exit 0; }
[ -f "$D" ] || { log -t sliderdex "missing $D, nothing to do"; exit 0; }
case "$(sha256sum "$S" 2>/dev/null)" in
  "$SHA "*) ;;
  *) log -t sliderdex "unexpected sha of $S, stock dex kept"; exit 0 ;;
esac
grep -q " $D " /proc/mounts && { log -t sliderdex "already mounted"; exit 0; }
mount -o bind "$S" "$D" || { log -t sliderdex "bind mount failed, stock dex kept"; exit 0; }
case "$(sha256sum "$D" 2>/dev/null)" in
  "$SHA "*) log -t sliderdex "hold dex bound over $D" ;;
  *) umount "$D"; log -t sliderdex "verify failed after bind, unmounted, stock dex kept"; exit 0 ;;
esac
# only matters if the bridge is already running (manual re-run): restart it to load the new dex
[ "$(getprop init.svc.port_slider_bridge)" = running ] && { stop port_slider_bridge; start port_slider_bridge; }
exit 0
