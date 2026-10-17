#!/usr/bin/env bash
set -euo pipefail
P="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
W=/root/port17d-rootless
T="$W/tree"
O="$P/release/17d/images/system.img"
python3 -I - "$T/system/build.prop" <<'PY'
import sys
p=sys.argv[1]; d=open(p).read()
old='\nro.adb.secure=0\n'; new='\nro.adb.secure=1\n'
assert d.count(old)+d.count(new)==1, 'expected exactly one ro.adb.secure entry'
open(p,'w').write(d.replace(old,new))
PY
rm -f "$T/product/etc/security/adb_keys"
mkfs.erofs -zlz4hc,12 -E legacy-compress -b4096 --mount-point=/ "$W/system.img" "$T" > "$W/mkfs-system-rootless.log"
python3 -I "$P/tools/avb/avbtool.py" add_hashtree_footer --image "$W/system.img" --partition_name system --partition_size 3640655872 --hash_algorithm sha256 --do_not_generate_fec --algorithm SHA256_RSA4096 --key "$P/tools/avb/port_key.pem"
dd if="$W/system.img" of="$O" bs=16M oflag=direct status=none
PF=/root/port17d-rootless-preflight
mkdir -p "$PF"
ln -sf "$O" "$PF/system.img"
ln -sf "$P/out-plk-build17d/vendor.img" "$PF/vendor.img"
ln -sf "$P/out-plk-build17d/boot.img" "$PF/boot.img"
env PROD_PROPS=1 OUT="$PF" bash "$P/tools/preflight-b.sh" 2>&1 | tee "$P/release/17d/logs/preflight-rootless-final.txt"
sha256sum "$O" | tee "$P/release/17d/logs/system-rootless-sha256.txt"
