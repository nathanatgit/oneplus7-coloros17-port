#!/bin/sh
export MSYS_NO_PATHCONV=1
adb shell "su -c 'rm -f /data/adb/service.d/offlinecam-stub.sh; pkill -f IOfflineCameraService'"
echo "removed (stub process killed; reboot not needed)"
