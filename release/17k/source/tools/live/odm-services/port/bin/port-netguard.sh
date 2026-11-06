#!/system/bin/sh
# OnePlus7Port 17k-r2 (BAKE-LIST B22): defensive guard against Settings.Global restricted_networking_mode=1.
# Seen once on the author's phone after the first 17k upgrade: with the value 1 every normal app has NO network (Wi-Fi and
# cellular) while the adb shell still works. The component that writes it is UNKNOWN; this only clears it if it is exactly 1.
# Runs once per boot from port-netguard.rc (init oneshot at sys.boot_completed=1): checks at start, +30 s, +120 s, +300 s,
# then exits. No permanent loop, no periodic wakeups afterwards. A null/0 value is left alone.
KEY=restricted_networking_mode

check() {
  v=$(settings get global "$KEY" 2>/dev/null)
  if [ "$v" = "1" ]; then
    settings put global "$KEY" 0 2>/dev/null
    n=$(settings get global "$KEY" 2>/dev/null)
    log -t netguard "$KEY was 1 ($1), set to 0 (reads '$n')" 2>/dev/null
  fi
}

check boot
sleep 30
check +30s
sleep 90
check +120s
sleep 180
check +300s
exit 0
