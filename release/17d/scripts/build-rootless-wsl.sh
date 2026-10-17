#!/usr/bin/env bash
set -euo pipefail
P="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
O="$P/release/17d/images/rootless"
mkdir -p "$O" /root/port17d-rootless
env PROD_PROPS=1 GSI="$P/ColorOS17-PLK110/system.img" W=/root/port17d-rootless OUT="$O" GSI_MNT=/mnt/plk FBE_MODE=standard bash "$P/tools/build-port-b.sh" 2>&1 | tee "$P/release/17d/logs/build-rootless.txt"
env PROD_PROPS=1 OUT="$O" bash "$P/tools/preflight-b.sh" 2>&1 | tee "$P/release/17d/logs/preflight-rootless.txt"
