#!/bin/bash
# Rebuild oplus-port-stubs.hold.dex (all port.* classes, B24) and the fake-path test dex. Needs java + apktool_3.0.3.jar.
set -e; cd "$(dirname "$0")"
JAVA="${JAVA:-/c/Program Files/Android/Android Studio1/jbr/bin/java}"; AJ=../../camera-helper/apktool_3.0.3.jar
"$JAVA" -cp $AJ build/Build.java smali oplus-port-stubs.hold.dex
rm -rf build/smali-test; cp -r smali build/smali-test
sed -i 's#/proc/tristatekey/tri_state#/data/local/tmp/slider-hold/fake_state#' build/smali-test/*.smali
uv run python -I build/mk_test.py
"$JAVA" -cp $AJ build/Build.java build/smali-test build/test.dex
sha256sum oplus-port-stubs.hold.dex
