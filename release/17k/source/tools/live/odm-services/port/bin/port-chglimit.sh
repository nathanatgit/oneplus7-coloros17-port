#!/system/bin/sh
# OnePlus7Port: enforce ColorOS "regular charge protection" (Settings > Battery > charging limit).
# ColorOS only sends the limit to the (absent) vendor charger HAL via OplusBatteryManager.setChgConfig(14,"2++sw+level");
# our Java ICharger stand-in (tools/live/charger-aidl) ignores it, so nothing ever stops charging. This service reads the
# settings (system: regular_charge_protection_switch_state / _open_power_level) and drives the kernel node
# /sys/class/power_supply/battery/mmi_charging_enable (0 = stop charging, status Discharging; 1 = charge).
# Hold at level >= limit; release when the switch is off, unplugged, the limit was changed above the level,
# or the level fell 2 below the limit.
P=/sys/class/power_supply
# Newer LineageOS kernels (device commit f4918091b, 2026-10-18) moved the OEM charger nodes to /sys/class/oplus_chg/battery/;
# this port's current kernel (0521dc291c) still has them under power_supply/battery. Use the new node when it exists.
N=/sys/class/oplus_chg/battery/mmi_charging_enable
[ -e "$N" ] || N=$P/battery/mmi_charging_enable
held=0; lastL=""
[ "$(cat $N 2>/dev/null)" = 0 ] && held=1   # we (or an earlier run) left it off
rel() { [ $held = 1 ] && { echo 1 > $N; held=0; log -t chglimit "release (cap=$cap L=$L sw=$sw)"; }; }
while :; do
  cap=$(cat $P/bms/capacity 2>/dev/null); [ -n "$cap" ] || cap=$(cat $P/battery/capacity); on=$(cat $P/usb/online)
  if [ "$on" != 1 ] && [ "$(cat $P/ac/online 2>/dev/null)" != 1 ]; then rel; sleep 60; continue; fi
  sw=$(settings get system regular_charge_protection_switch_state)
  L=$(settings get system regular_charge_protection_open_power_level)
  case "$L" in ''|null|*[!0-9]*) L=0;; esac
  if [ "$sw" != 1 ] || [ "$L" -lt 1 ]; then rel
  elif [ "$cap" -ge "$L" ]; then
    [ $held = 0 ] && { echo 0 > $N; held=1; log -t chglimit "hold (cap=$cap L=$L)"; }
  elif [ $held = 1 ] && { [ "$L" != "$lastL" ] || [ "$cap" -le $((L-2)) ]; }; then rel
  fi
  lastL=$L
  if [ "$cap" -ge $((L-3)) ]; then sleep 20; else sleep 60; fi
done
