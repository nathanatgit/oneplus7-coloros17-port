#!/usr/bin/env python3
# ColorOS SF enables Qualcomm's QtiSurfaceFlingerExtension when ro.product.first_api_level < 34 (always true
# here: 28) or vendor.display.enable_display_extensions=1 (QtiSurfaceFlingerExtensionFactory.cpp). The
# extension sends QTI composer commands (SET_LAYER_TYPE 0x800...) that the LineageOS AOSP composer@2.4 rejects
# ("failed to parse command 0x8000000") -> validate fails -> nothing is presented.
# Point SF's only read of first_api_level at a port-owned prop instead (same length, patched in place so the
# file keeps its SELinux xattr); build.prop sets it to 36 so SF takes QtiNullExtension.
import sys
f = sys.argv[1]
a, b = b'ro.product.first_api_level\0', b'ro.port.sf_first_api_level\0'
d = open(f, 'rb').read()
if d.count(b) == 1 and d.count(a) == 0:
    print('surfaceflinger already patched'); sys.exit(0)
assert d.count(a) == 1, 'expected exactly one first_api_level string in surfaceflinger, found %d' % d.count(a)
with open(f, 'r+b') as fh:
    fh.seek(d.index(a)); fh.write(b)
print('surfaceflinger: QTI extension gated on ro.port.sf_first_api_level')
