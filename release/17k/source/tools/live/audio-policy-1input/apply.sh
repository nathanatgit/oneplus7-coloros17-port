#!/system/bin/sh
# B26 live: make AudioPolicy share ONE "primary input" HAL stream between concurrent capture clients
# (maxOpenCount 2 -> 1) so the HAL never opens the starved audio-record-compress2 stream.
[ "$(id -u)" = 0 ] || { echo "need root"; exit 1; }
W=/data/local/tmp/audio-policy-1input
for f in audio_policy_configuration audio_policy_configuration_a2dp_offload_disabled; do
  [ -f $W/$f.xml ] || { echo "missing $W/$f.xml"; exit 1; }
  grep -q 'name="primary input" role="sink" maxOpenCount="1"' $W/$f.xml || { echo "bad $f.xml"; exit 1; }
  chcon u:object_r:vendor_configs_file:s0 $W/$f.xml
  grep -q " /vendor/etc/$f.xml " /proc/mounts && umount /vendor/etc/$f.xml
  mount -o bind $W/$f.xml /vendor/etc/$f.xml || exit 1
done
grep audio_policy_configuration /proc/mounts
setprop ctl.restart audioserver
sleep 4
echo "audioserver pid: $(pidof audioserver)"
