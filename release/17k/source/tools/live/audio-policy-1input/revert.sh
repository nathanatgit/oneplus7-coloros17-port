#!/system/bin/sh
# Undo B26 (a reboot also undoes it).
[ "$(id -u)" = 0 ] || { echo "need root"; exit 1; }
for f in audio_policy_configuration audio_policy_configuration_a2dp_offload_disabled; do
  grep -q " /vendor/etc/$f.xml " /proc/mounts && umount /vendor/etc/$f.xml
done
setprop ctl.restart audioserver
sleep 4
echo "audioserver pid: $(pidof audioserver)"
