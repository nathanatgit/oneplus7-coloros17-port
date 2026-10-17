#!/bin/sh
# Run in WSL: builds libportcompat.so (no libc dependency, so the glibc cross toolchain is fine).
cd "$(dirname "$0")" && aarch64-linux-gnu-gcc -shared -nostdlib -Wl,-soname,libportcompat.so -Wl,-z,max-page-size=4096 -Wl,--hash-style=gnu -Wl,-z,norelro -o libportcompat.so portcompat.S && sha256sum libportcompat.so
