#!/bin/sh
export MSYS_NO_PATHCONV=1
# Host-side. Magisk edition only (needs /data/adb/service.d). Usage: ANDROID_SERIAL=... sh install.sh
D=$(dirname "$0")
adb push "$D/offlinecam-stub.sh" /data/local/tmp/offlinecam-stub.sh >/dev/null || exit 1
adb shell "su -c 'cp /data/local/tmp/offlinecam-stub.sh /data/adb/service.d/offlinecam-stub.sh && chmod 755 /data/adb/service.d/offlinecam-stub.sh && chcon u:object_r:adb_data_file:s0 /data/adb/service.d/offlinecam-stub.sh; ls -l /data/adb/service.d/offlinecam-stub.sh; sh /data/adb/service.d/offlinecam-stub.sh; sleep 3; service list | grep -i offlinecamera'"
