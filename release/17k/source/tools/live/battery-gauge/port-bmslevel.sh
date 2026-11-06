#!/system/bin/sh
# OnePlus7Port (BAKE-LIST B21): make the Android health HAL / BatteryService report the real Qualcomm fuel-gauge level.
# The oplus charger driver's ui_soc (battery/capacity) snaps to 100 when charging is held with mmi_charging_enable=0
# (port-chglimit), so health-service.qti -> BatteryService showed ~97 while bms/capacity (coulomb counter) says ~84.
# We bind-mount a small live-updated file over battery/capacity (health re-opens the node on every update; port_health_poke
# triggers one every 20 s). The file is rewritten in place every 5 s from bms/capacity, so it tracks (never a static value).
# Undo: umount /sys/class/power_supply/battery/capacity; pkill -f port-bmslevel
P=/sys/class/power_supply
F=/dev/port-battery-capacity
[ -r $P/bms/capacity ] || exit 0
v=$(cat $P/bms/capacity); echo "$v" > $F; chmod 0444 $F
chcon u:object_r:sysfs_batteryinfo:s0 $F 2>/dev/null || chcon u:object_r:sysfs:s0 $F 2>/dev/null
grep -q " $(readlink -f $P/battery)/capacity " /proc/mounts || mount -o bind $F $P/battery/capacity || exit 1
log -t bmslevel "bound battery/capacity -> bms/capacity ($v)"
while :; do
  n=$(cat $P/bms/capacity 2>/dev/null)
  case "$n" in ''|*[!0-9]*) ;; *) [ "$n" != "$v" ] && { chmod 0644 $F; echo "$n" > $F; chmod 0444 $F; v=$n; } ;; esac
  sleep 5
done
