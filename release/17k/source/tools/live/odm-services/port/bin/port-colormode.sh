#!/system/bin/sh
# OnePlus7Port: ColorOS 17's screen color mode (system display_color_mode: 301 标准 standard / 303 自然 natural / 307 鲜明 vivid)
# only reaches its own SurfaceFlinger extension, which on this HWC cannot map the request ("unknown render intent -> default").
# Forward it to the panel's real qdcm modes through LineageOS LiveDisplay (IDisplayModes ids: 0 Vivid, 1 Natural, 2 Cinematic,
# 3 Brilliant). Stock H.40 feel: its props ro.oplus.display.colormode.colorful=0 and .cinema=3 match LiveDisplay ids 0 and 3;
# the neutral/default look is Natural (sRGB).
# Watch (BAKE-LIST B15, 2026-11-03): inotify on the settings directory instead of `logcat -s ColorDisplayService` (logcat
# filtered client side, so it read every log line). SettingsProvider rewrites settings_system.xml(.new) after each change of a
# system setting; only then is display_color_mode read again, and LiveDisplay is called only when the value changed.
# Previous version: tools/live/colormode/port-colormode.sh.logcat.
LD=vendor.lineage.livedisplay.IDisplayModes/default
DIR=/data/system/users/0
apply() {
  case "$1" in
    301) m=1 ;;   # 标准 standard (neutral)         -> Natural
    303) m=3 ;;   # 自然 natural (cool, bright)     -> Brilliant (= stock cinema id 3)
    307) m=0 ;;   # 鲜明 vivid                      -> Vivid (= stock colorful id 0)
    *) return ;;
  esac
  service call $LD 4 i32 $m i32 0 >/dev/null 2>&1
}
cur=
check() {
  v=$(settings get system display_color_mode)
  [ "$v" = "$cur" ] && return
  apply "$v"; cur=$v
}
until service check $LD 2>/dev/null | grep -q "found" && [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
check
while :; do
  inotifyd - $DIR:w | while read -r ev dir file; do
    case "$file" in settings_system.xml*) check ;; esac
  done
  sleep 10; check    # inotifyd exited (should not happen): re-sync and watch again
done
