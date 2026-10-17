. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
ls /usr/bin | grep -i 'objdump'
B=/mnt/i-eodm/bin/hw/android.hardware.secure_elementnq330@1.1-service
OD=$(ls /usr/bin/*aarch64*objdump 2>/dev/null | head -1); [ -z "$OD" ] && OD=objdump
$OD -d --no-show-raw-insn $B > /root/b17/se.dis 2>&1; wc -l /root/b17/se.dis; head -5 /root/b17/se.dis
python3 -I - <<'PY'
import re
# find string offsets
d=open('/mnt/i-eodm/bin/hw/android.hardware.secure_elementnq330@1.1-service','rb').read()
for s in [b'vendor.nfc_se.config_ready',b'ro.nfc.wait_config_retry',b'ro.boot.no_ese',b'nfc config is not ready!!!']:
    print(s, hex(d.find(s)))
PY
