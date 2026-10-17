#!/usr/bin/env bash
set -euo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"
FASTBOOT=${FASTBOOT:-fastboot}
ADB=${ADB:-adb}
command -v "$FASTBOOT" >/dev/null 2>&1 || die 'fastboot is not on PATH.'
command -v "$ADB" >/dev/null 2>&1 || die 'adb is not on PATH.'

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print tolower($1)}'
  else die 'Install sha256sum (Linux) or shasum (macOS) first.'; fi
}
check_image() {
  local path=$1 expected=$2 actual
  [[ -f "$path" ]] || die "Missing image: $path"
  actual=$(sha256 "$path")
  [[ "$actual" == "$expected" ]] || die "SHA-256 mismatch for $path: $actual"
}
check_image images/bootstrap-system.img 2d2b4c07ceebcda8b61100467f768fa0dba4baf0440c53c82777e0ea094f18c8
check_image images/system.img d56f80b4ea9d39338e954127bdefb1e56d4eab77ff8b4498f79ac0124db390d2
check_image images/vendor.img b55bc1810bd49aebae3c34f56e8e098e440f98ce4f5c6a215a16f1f3bfa729f6
check_image images/my_stock.img fac842d6d7ca732c1d5dd7f356cfae1991ee9433f88e89b6e3370a1336811760
check_image images/boot-ese-final.img a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91

FB_LIST=$("$FASTBOOT" devices | awk '$2 == "fastboot" {print $1}')
COUNT=$(printf '%s\n' "$FB_LIST" | awk 'NF {n++} END {print n+0}')
[[ "$COUNT" == 1 ]] || die "Connect exactly one phone in fastboot mode; found $COUNT."
SERIAL=$(printf '%s\n' "$FB_LIST" | awk 'NF {print $1; exit}')
PRODUCT=$("$FASTBOOT" -s "$SERIAL" getvar product 2>&1) || die "Could not read fastboot product: $PRODUCT"
printf '%s\n' "$PRODUCT" | grep -Eq 'product:[[:space:]]*guacamole([[:space:]]|$)' || die "Expected fastboot product guacamole: $PRODUCT"
UNLOCKED=$("$FASTBOOT" -s "$SERIAL" getvar unlocked 2>&1) || die "Could not read bootloader state: $UNLOCKED"
printf '%s\n' "$UNLOCKED" | grep -Eqi 'unlocked:[[:space:]]*yes' || die 'Bootloader is not reported unlocked.'
SLOT_INFO=$("$FASTBOOT" -s "$SERIAL" getvar current-slot 2>&1) || die "Could not read active slot: $SLOT_INFO"
SLOT=$(printf '%s\n' "$SLOT_INFO" | sed -nE 's/.*current-slot:[[:space:]]*([ab]).*/\1/p' | head -n 1)
[[ "$SLOT" == a || "$SLOT" == b ]] || die "Cannot parse active slot: $SLOT_INFO"
printf 'Device %s: product guacamole, active slot %s. Only slot %s will be flashed.\n' "$SERIAL" "$SLOT" "$SLOT"

if [[ "${1:-}" == --dry-run ]]; then
  printf 'DRY RUN: hashes and fastboot device verified; no partitions or user data changed.\nWould flash bootstrap system/vendor/eSE boot to slot %s, wipe userdata/metadata, stage my_stock.img, then flash the production system and plain eSE boot.\n' "$SLOT"
  exit 0
fi

read -r -p 'Confirm the phone is OnePlus 7 Pro PLK110 or GM1910; type PLK110 or GM1910: ' MODEL
[[ "$MODEL" == PLK110 || "$MODEL" == GM1910 ]] || die 'Model confirmation did not match.'
printf 'This clean install erases userdata and metadata on this phone. Back up first.\n'
read -r -p 'Type WIPE to continue: ' WIPE
[[ "$WIPE" == WIPE ]] || die 'Install cancelled before any writes.'

"$FASTBOOT" -s "$SERIAL" flash "system_$SLOT" images/bootstrap-system.img
"$FASTBOOT" -s "$SERIAL" flash "vendor_$SLOT" images/vendor.img
"$FASTBOOT" -s "$SERIAL" flash "boot_$SLOT" images/boot-ese-final.img
"$FASTBOOT" -s "$SERIAL" -w
"$FASTBOOT" -s "$SERIAL" reboot

printf 'Waiting for the temporary bootstrap Android system...\n'
READY=0
for _ in $(seq 1 150); do
  if [[ "$("$ADB" -s "$SERIAL" get-state 2>/dev/null || true)" == device ]]; then READY=1; break; fi
  sleep 2
done
[[ "$READY" == 1 ]] || die 'Timed out waiting for bootstrap ADB.'
"$ADB" -s "$SERIAL" root
for _ in $(seq 1 60); do
  if [[ "$("$ADB" -s "$SERIAL" shell id 2>/dev/null || true)" == *'uid=0(root)'* ]]; then READY=1; break; fi
  sleep 2
done
[[ "$("$ADB" -s "$SERIAL" shell id)" == *'uid=0(root)'* ]] || die 'Bootstrap ADB root is unavailable; final system was not flashed.'

READY=0
for _ in $(seq 1 90); do
  if "$ADB" -s "$SERIAL" shell 'test -d /data/port && echo ready' 2>/dev/null | grep -q ready; then READY=1; break; fi
  sleep 2
done
[[ "$READY" == 1 ]] || die 'Timed out waiting for /data/port.'
"$ADB" -s "$SERIAL" push images/my_stock.img /data/port/my_stock.img
"$ADB" -s "$SERIAL" shell 'chown 0:0 /data/port/my_stock.img; chmod 0644 /data/port/my_stock.img; chcon u:object_r:system_file:s0 /data/port/my_stock.img; sync'
"$ADB" -s "$SERIAL" reboot bootloader

printf 'Waiting for fastboot...\n'
READY=0
for _ in $(seq 1 90); do
  if "$FASTBOOT" devices | awk -v s="$SERIAL" '$1 == s && $2 == "fastboot" {found=1} END {exit !found}'; then READY=1; break; fi
  sleep 2
done
[[ "$READY" == 1 ]] || die 'Timed out waiting for fastboot.'
SLOT_INFO=$("$FASTBOOT" -s "$SERIAL" getvar current-slot 2>&1)
SLOT_NOW=$(printf '%s\n' "$SLOT_INFO" | sed -nE 's/.*current-slot:[[:space:]]*([ab]).*/\1/p' | head -n 1)
[[ "$SLOT_NOW" == "$SLOT" ]] || die 'Active slot changed during staging; stopped before final flash.'
"$FASTBOOT" -s "$SERIAL" flash "system_$SLOT" images/system.img
"$FASTBOOT" -s "$SERIAL" flash "boot_$SLOT" images/boot-ese-final.img
"$FASTBOOT" -s "$SERIAL" reboot
printf '17d no-root install complete. Allow several minutes for first boot.\n'
