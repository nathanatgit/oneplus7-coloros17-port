#!/usr/bin/env bash
# Build the LOS 4.14 sm8150 kernel with the eSE (p73) driver. Run in WSL; sources in ~/ese/kernel, clang in ~/ese/clang.
set -e
export LD_LIBRARY_PATH=~/ese/shim
export PATH=~/ese/clang/bin:$PATH
K=~/ese/kernel; O=~/ese/out
cd $K
echo -n "-g0521dc291cf1" > .scmversion   # keep vermagic identical to the stock LOS build (no -dirty)
mkdir -p $O
cp /mnt/c/Users/Han/Project/OnePlus7Port/research/ese-p73/phone.config $O/.config
echo "CONFIG_NFC_P73_ESE=y" >> $O/.config
M="O=$O ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- HOSTCC=gcc HOSTCXX=g++"
make $M olddefconfig
grep -E "NFC_P73|NFC_NQ|SPI_SPIDEV|LOCALVERSION" $O/.config
make $M -j16 Image.gz 2>&1 | tail -n 400
echo BUILD_DONE
