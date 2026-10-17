set -e
cd "$(dirname "$0")"
for n in trim json; do
  aarch64-linux-gnu-gcc -shared -nostdlib -fPIC -Wl,-soname,libport_shim_$n.so -Wl,--hash-style=both -Wl,-z,max-page-size=4096 -o libport_shim_$n.so shim_$n.S
done
sha256sum libport_shim_*.so
