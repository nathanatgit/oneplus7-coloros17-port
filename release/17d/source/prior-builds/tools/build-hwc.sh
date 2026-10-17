#!/bin/bash
# Standalone build of android.hardware.graphics.composer@2.4-service (AOSP default) for the OnePlus7Port.
W=/root/hwc; cd $W
NDK=$W/android-ndk-r27c; TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64; SR=$TC/sysroot
S=$W/src; C=$S/hardware/interfaces/graphics/composer
SRC=${1:-$C/2.4/default/service.cpp}; OUT=${2:-$W/out/composer-service}
mkdir -p $(dirname $OUT)
INC="${OVERLAY:+-I$W/overlay}"
for v in 2.1 2.2 2.3 2.4; do for u in hal passthrough command-buffer resources; do [ -d $C/$v/utils/$u/include ] && INC="$INC -I$C/$v/utils/$u/include"; done; done
INC="$INC -I$C/2.1/utils/hwc2on1adapter/include -I$C/2.1/utils/hwc2onfbadapter/include"
INC="$INC -I$W/gen -I$S/system/libhidl/base/include -I$S/system/libhidl/transport/include -I$S/system/libfmq/include -I$S/system/libfmq/base"
INC="$INC -I$S/system/libbase/include -I$S/system/core/libutils/include -I$S/system/core/libutils/binder/include -I$S/system/core/libcutils/include -I$S/system/core/libsystem/include"
INC="$INC -I$S/system/core/libsync/include -I$S/system/logging/liblog/include -I$S/hardware/libhardware/include -I$S/frameworks/native/libs/binder/include -I$S/system/libhwbinder/include"
LIBS=$(for f in devlib/*.so; do echo -n " $f"; done)
$TC/bin/clang++ --target=aarch64-linux-android34 --sysroot=$SR -nostdinc++ -isystem $W/cxx/v1 \
  -std=c++20 -O2 -fno-rtti -fno-exceptions -fPIE -pie -D__ANDROID_VNDK__ -D__ANDROID_VENDOR__ -DLOG_TAG=\"android.hardware.graphics.composer@2.4-service\" \
  -Wno-deprecated-declarations -Wno-unused-parameter \
  $INC "$SRC" -o "$OUT" -nostdlib++ $LIBS -Wl,--as-needed -Wl,--allow-shlib-undefined -Wl,-z,max-page-size=4096 2>&1 | grep -E "error|undefined" | head -${3:-25}
[ -f "$OUT" ] && $TC/bin/llvm-strip "$OUT" && ls -l "$OUT"
