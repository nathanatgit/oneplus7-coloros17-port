#!/bin/bash
# Offline lint of port/etc/init/port-offlinecam-stub.rc (B27): only init constructs, one service, restartable, started at "on boot".
H=$(cd "$(dirname "$0")" && pwd); rc=$H/port/etc/init/port-offlinecam-stub.rc; fail=0
chk() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
chk "no CRLF" '! grep -q $'"'"'\r'"'"' $rc'
chk "one service" '[ "$(grep -c "^service " $rc)" = 1 ]'
chk "service line" 'grep -qx "service port_offlinecam_stub /system/bin/app_process /system/bin port.OplusStubs vendor.qti.hardware.camera.offlinecamera.IOfflineCameraService/default" $rc'
chk "not oneshot (init restarts it)" '! grep -qE "^[[:space:]]+oneshot" $rc'
chk "disabled + explicit start" 'grep -qx "    disabled" $rc && grep -qx "on boot" $rc && grep -qx "    start port_offlinecam_stub" $rc'
chk "user/group/seclabel/CLASSPATH" 'grep -qx "    user root" $rc && grep -qx "    group root system" $rc && grep -qx "    seclabel u:r:su:s0" $rc && grep -qx "    setenv CLASSPATH /system/framework/oplus-port-stubs.dex" $rc'
chk "only known keywords" '! grep -vE "^(#|service |on |    (class|user|group|setenv|seclabel|disabled|start) |    disabled$|$)" $rc | grep -q .'
chk "sha matches SHA256SUMS" 'grep -q "$(sha256sum $rc | cut -d" " -f1) \*port/etc/init/port-offlinecam-stub.rc" $H/SHA256SUMS'
[ $fail = 0 ] && echo "ALL PASS" || { echo "SOME FAILED"; exit 1; }
