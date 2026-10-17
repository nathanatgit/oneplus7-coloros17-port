#!/usr/bin/env bash
# OnePlus7Port: stock H.40 OnePlusCamera (ColorOS 12, 7.2.47) for ColorOS 17. Run as root inside WSL.
# The app's haptics helper (com.oneplus.util.Vibrator$Companion.vibrate) takes the OnePlus "OS1" path, which casts
# getSystemService("linearmotor") to com.oplus.os.LinearmotorVibrator. ColorOS 17 only registers that service with
# feature oplus.software.vibrator_lmvibrator (absent for this device) -> null -> TypeCastException on the shutter /
# record button (video recording crashed). Patch: the first isSupportedOS1() check in vibrate() reads false, so
# vibrate() returns without vibrating (no linear-motor path). Everything else is untouched.
# The APK ships without its v2 signature (system-partition app), so it is only usable from a system partition
# (here: /my_stock, see make-mystock-merged.sh extra dir), where PackageManager doesn't verify digests.
#   patch-h40-camera.sh <OnePlusCamera.apk> <out.apk>
set -euo pipefail
IN=$1 OUT=$2
W=$(mktemp -d /root/h40cam-patch.XXXX); trap 'rm -rf "$W"' EXIT
unzip -q -o "$IN" classes2.dex -d "$W"
baksmali d "$W/classes2.dex" -o "$W/smali"
python3 -I - "$W/smali/com/oneplus/util/Vibrator\$Companion.smali" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = ('    invoke-static {}, Lcom/oneplus/base/Device;->isSupportedOS1()Z\n\n    move-result v0\n\n'
       '    if-nez v0, :cond_18\n\n    return v1\n')
new = ('    # OnePlus7Port: no linearmotor service on ColorOS 17 -> skip the OS1 haptics path\n    const/4 v0, 0x0\n\n'
       '    if-nez v0, :cond_18\n\n    return v1\n')
assert s.count(old) == 1, 'vibrate() isSupportedOS1 check changed'
open(p, 'w').write(s.replace(old, new))
PY
smali a --api 29 "$W/smali" -o "$W/classes2.dex"
cp "$IN" "$OUT"
# Rewrite with zipalign -p semantics: stored .so data on 4096-byte boundaries (the system app loads its libs straight
# from the APK; unaligned -> UnsatisfiedLinkError at startup), other stored entries on 4.
python3 -I - "$OUT" "$W/classes2.dex" <<'PY'
import sys, zipfile, os, struct, copy
apk, dex = sys.argv[1], sys.argv[2]
tmp = apk + '.tmp'
with zipfile.ZipFile(apk) as zin, zipfile.ZipFile(tmp, 'w') as zout:
    for i in zin.infolist():
        data = open(dex, 'rb').read() if i.filename == 'classes2.dex' else zin.read(i.filename)
        zi = copy.copy(i); zi.extra = b''
        if zi.compress_type == zipfile.ZIP_STORED:
            align = 4096 if i.filename.endswith('.so') else 4
            start = zout.fp.tell() + 30 + len(i.filename.encode()) + 4
            pad = (-start) % align
            zi.extra = struct.pack('<HH', 0xD935, pad) + b'\0' * pad
        zout.writestr(zi, data)
with zipfile.ZipFile(tmp) as z:
    for i in z.infolist():
        if i.compress_type == zipfile.ZIP_STORED and i.filename.endswith('.so'):
            off = i.header_offset + 30 + len(i.filename.encode()) + len(i.extra)
            assert off % 4096 == 0, i.filename
os.replace(tmp, apk)
PY
unzip -l "$OUT" | grep classes2.dex; sha256sum "$OUT"
