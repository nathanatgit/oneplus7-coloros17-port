#!/usr/bin/env bash
# Match the SM8150 native SoundTrigger 1.0 HAL with stock H.40's HIDL 2.1 adapter.
# Tested with the actual Qualcomm HAL (not a stub): boot complete and HIDL 2.1 registered.
set -euo pipefail
V=${1:?mounted vendor root required}
P=/mnt/c/Users/Han/Project/OnePlus7Port
S="$P/tools/soundtrigger-compat/android.hardware.soundtrigger@2.1-impl.so"
test -f "$V/odm/lib/hw/audio.primary.msmnile.so"
test "$(sha256sum "$V/lib/hw/sound_trigger.primary.msmnile.so" | cut -d' ' -f1)" = cbb5c624b2f4b2a95e23e27760358cd947fa9f78f9d762cdacc0560f3df5e03f
if [ ! -L "$V/lib/hw/audio.primary.msmnile.so" ]; then
    test ! -e "$V/lib/hw/audio.primary.msmnile.so"
    ln -s ../../odm/lib/hw/audio.primary.msmnile.so "$V/lib/hw/audio.primary.msmnile.so"
fi
test "$(readlink "$V/lib/hw/audio.primary.msmnile.so")" = ../../odm/lib/hw/audio.primary.msmnile.so
setfattr -h -n security.selinux -v u:object_r:vendor_file:s0 "$V/lib/hw/audio.primary.msmnile.so"
cp "$S" "$V/lib/hw/android.hardware.soundtrigger@2.1-impl.so"
chmod 0644 "$V/lib/hw/android.hardware.soundtrigger@2.1-impl.so"
setfattr -n security.selinux -v u:object_r:vendor_file:s0 "$V/lib/hw/android.hardware.soundtrigger@2.1-impl.so"
# Do not let the service choose 2.3, which rejects native device API 1.0 and closes it.
if [ -f "$V/lib/hw/android.hardware.soundtrigger@2.3-impl.so" ]; then
    mv "$V/lib/hw/android.hardware.soundtrigger@2.3-impl.so" "$V/lib/hw/android.hardware.soundtrigger@2.3-impl.so.unused"
fi
python3 - "$V/etc/vintf/manifest.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = '<fqname>@2.3::ISoundTriggerHw/default</fqname>'
new = '<fqname>@2.1::ISoundTriggerHw/default</fqname>'
assert s.count(old) == 1 or (s.count(old) == 0 and s.count(new) == 1)
s = s.replace(old, new)
ET.fromstring(s)
# Rewrite the inode in place to preserve its SELinux label.
p.write_text(s)
PY
test -f "$V/lib/hw/audio.primary.msmnile.so"
test ! -e "$V/lib/hw/android.hardware.soundtrigger@2.3-impl.so"
echo 'SoundTrigger 2.1 adapter and real native HAL configured'
