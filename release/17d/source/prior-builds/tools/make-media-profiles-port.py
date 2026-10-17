#!/usr/bin/env python3
"""OnePlus7Port: camcorder profiles for the LineageOS camera HAL's logical camera IDs.

The LOS vendor media_profiles_vendor.xml (identical to stock H.40's) defines CamcorderProfiles only for camera IDs 0-3.
The LOS camera HAL also exposes logical IDs 4 (portrait) and 5 (rear SAT multi-camera); the H.40 OnePlus Camera
records video on ID 5 -> "initializingRecorder() - No profile" -> recording never starts.
This copies camera 0's (main sensor) <CamcorderProfiles> block as cameraId 4 and 5. Everything else is unchanged.

Usage: make-media-profiles-port.py <media_profiles_vendor.xml> <out.xml>
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
d = open(src).read()
blocks = re.findall(r'[ \t]*<CamcorderProfiles cameraId="(\d+)"[^>]*>.*?</CamcorderProfiles>\n', d, re.S)
ids = set(blocks)
assert ids == {'0', '1', '2', '3'}, 'unexpected camera ids %s (source changed?)' % sorted(ids)
m = re.search(r'([ \t]*<CamcorderProfiles cameraId="0"[^>]*>.*?</CamcorderProfiles>\n)', d, re.S)
cam0 = m.group(1)
extra = ''.join(cam0.replace('cameraId="0"', 'cameraId="%d"' % i, 1) for i in (4, 5))
last = list(re.finditer(r'[ \t]*<CamcorderProfiles cameraId="3"[^>]*>.*?</CamcorderProfiles>\n', d, re.S))[0]
out = d[:last.end()] + extra + d[last.end():]
open(dst, 'w').write(out)
print('camera ids now:', sorted(set(re.findall(r'<CamcorderProfiles cameraId="(\d+)"', out))))
