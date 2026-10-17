. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
m $P/LineageOS24/payload/system.img /mnt/i-ls
for sym in _ZN7android4base4TrimERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE _ZN4Json5ValueaSES0_; do echo "## $sym"
 for f in $(find /mnt/i-hv/lib64 /mnt/i-sys/system/lib64 /mnt/i-lv/lib64 /mnt/i-s16/system/lib64 /mnt/i-ls/system/lib64 -maxdepth 2 -name 'libbase.so' -o -maxdepth 2 -name 'libjsoncpp.so' 2>/dev/null); do
  nm -D --defined-only $f 2>/dev/null | grep -q " $sym\$" && echo "DEFINES $f"; done; done
echo; which clang gcc aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ clang++ 2>&1 | head
ls /usr/lib/gcc-cross 2>/dev/null; ls ~/ndk* /opt 2>/dev/null | head
nm -D --defined-only /mnt/i-lv/lib64/libbase.so | grep Trim
nm -D --defined-only /mnt/i-lv/lib64/libjsoncpp.so | grep 'Json5ValueaS'
