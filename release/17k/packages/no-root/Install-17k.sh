#!/usr/bin/env bash
# OnePlus 7 Pro ColorOS 17 port, 17k NoRoot UPGRADE installer (Linux/macOS).
# Upgrades an installed port (17d or later) on the ACTIVE slot and KEEPS ALL USER DATA: it never wipes userdata or
# metadata (no `fastboot -w`, no format). It flashes vendor, system and boot of the active slot only and replaces
# /data/port/my_stock.img (the previous one is kept as /data/port/my_stock-prev.img).
#   bash ./Install-17k.sh            install
#   bash ./Install-17k.sh --dry-run  check images, phone, slot, root and free space; change nothing
# Start with the phone booted into the current port with USB debugging authorized (preferred), or in fastboot mode.
set -euo pipefail
# Git Bash on Windows: stop MSYS from rewriting phone paths such as /data/port/... into C:/Program Files/Git/data/port/...
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

VARIANT=noroot   # noroot | magisk
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"
FASTBOOT=${FASTBOOT:-fastboot}
ADB=${ADB:-adb}
DRY=0; [[ "${1:-}" == --dry-run ]] && DRY=1
command -v "$FASTBOOT" >/dev/null 2>&1 || die 'fastboot is not on PATH.'
command -v "$ADB" >/dev/null 2>&1 || die 'adb is not on PATH.'

MYSTOCK_SHA=135022d0d5816296a365cb39e920a73c0eabc32ff4f5be18dfa70c86d203c189
MYSTOCK_SIZE=6917992448
SYSTEM_IMG=images/system.img
BOOTSTRAP_IMG=images/bootstrap-system.img
VENDOR_IMG=images/vendor.img
if [[ $VARIANT == magisk ]]; then BOOT_IMG=images/boot-magisk31-17d.img; else BOOT_IMG=images/boot-ese-final.img; fi

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print tolower($1)}'
  else die 'Install sha256sum (Linux) or shasum (macOS) first.'; fi
}
check_image() {
  local path=$1 expected=$2 actual
  [[ -f "$path" ]] || die "Missing image: $path"
  say "Checking $path ..."
  actual=$(sha256 "$path")
  [[ "$actual" == "$expected" ]] || die "SHA-256 mismatch for $path: $actual"
}
check_image images/bootstrap-system.img e64a10ca29f384a877b223f255150dd8bb3616321f3b51e9b6f9c5ec43dc5726
check_image images/system.img 0b24fcb2d323f406deba2ed4c46a8edb38c4532bde0b44b026c0a9e8373af3b9
check_image images/vendor.img d7e9a440d5a0fb6cbb7f3de6d3b04639488a262bcaaac4a6c072776da5fbe874
check_image images/my_stock.img 135022d0d5816296a365cb39e920a73c0eabc32ff4f5be18dfa70c86d203c189
check_image images/boot-ese-final.img a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91

# ---------- find the phone ----------
SERIAL=; MODE=
ADB_LIST=$("$ADB" devices </dev/null | awk 'NR > 1 && $2 == "device" {print $1}')
FB_LIST=$("$FASTBOOT" devices </dev/null | awk '$2 == "fastboot" {print $1}')
NA=$(printf '%s\n' "$ADB_LIST" | awk 'NF {n++} END {print n+0}')
NF_=$(printf '%s\n' "$FB_LIST" | awk 'NF {n++} END {print n+0}')
[[ $((NA + NF_)) == 1 ]] || die "Connect exactly one phone (Android with USB debugging authorized, or fastboot); found $NA adb + $NF_ fastboot."
if [[ $NA == 1 ]]; then SERIAL=$ADB_LIST; MODE=adb; else SERIAL=$FB_LIST; MODE=fastboot; fi
# </dev/null: adb/fastboot must not eat the installer's stdin (piped answers to the confirmation prompt)
A() { "$ADB" -s "$SERIAL" "$@" </dev/null; }
F() { "$FASTBOOT" -s "$SERIAL" "$@" </dev/null; }

wait_adb() {   # $1 = seconds
  local i
  for ((i = 0; i < $1; i += 2)); do [[ "$(A get-state 2>/dev/null || true)" == device ]] && return 0; sleep 2; done
  return 1
}
wait_boot() {
  local i
  for ((i = 0; i < $1; i += 3)); do [[ "$(A shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]] && return 0; sleep 3; done
  return 1
}
wait_fastboot() {
  local i
  for ((i = 0; i < 180; i += 2)); do
    "$FASTBOOT" devices </dev/null | awk -v s="$SERIAL" '$1 == s && $2 == "fastboot" {f=1} END {exit !f}' && return 0; sleep 2
  done
  return 1
}

# ---------- root on the running Android (only for staging my_stock.img) ----------
ROOT=none
detect_root() {   # sets ROOT = adbd | su | none; never prompts for anything but Magisk's own dialog
  ROOT=none
  if [[ "$(A shell id 2>/dev/null)" == *'uid=0(root)'* ]]; then ROOT=adbd; return; fi
  if [[ $DRY == 0 && "$(A shell getprop ro.debuggable 2>/dev/null | tr -d '\r')" == 1 ]]; then
    A root >/dev/null 2>&1 || true; sleep 3; wait_adb 60 || true
    if [[ "$(A shell id 2>/dev/null)" == *'uid=0(root)'* ]]; then ROOT=adbd; return; fi
  fi
  if [[ "$(A shell 'command -v su' 2>/dev/null | tr -d '\r')" == */su ]]; then
    say 'If Magisk asks to allow root for the ADB shell, approve it on the phone.'
    if [[ "$(A shell su -c id 2>/dev/null)" == *'uid=0(root)'* ]]; then ROOT=su; fi
  fi
}
R() {   # run a command as root on the phone
  if [[ $ROOT == adbd ]]; then A shell "$1"; else A shell "su -c '$1'"; fi   # one string: adb joins its args
}

# Copies images/my_stock.img to /data/port/my_stock.img.new, verifies it on the phone, then swaps it in
# (old one -> my_stock-prev.img). The running system keeps using the old inode until it reboots.
stage_mystock() {
  local free need
  R 'test -f /data/port/my_stock.img' || die 'No /data/port/my_stock.img on this phone: this is not an installed port. Use the clean install in README.md.'
  free=$(R 'df -k /data/port | tail -n 1' | awk '{print $4}')
  if [[ $ROOT == su ]]; then need=$((MYSTOCK_SIZE * 2 / 1024 + 1048576)); else need=$((MYSTOCK_SIZE / 1024 + 1048576)); fi
  [[ "$free" =~ ^[0-9]+$ ]] || die "Could not read free space on /data: $free"
  (( free > need )) || die "Not enough free space on /data: ${free} KiB free, ${need} KiB needed."
  R 'rm -f /data/port/my_stock.img.new'
  if [[ $ROOT == adbd ]]; then
    A push images/my_stock.img /data/port/my_stock.img.new
  else
    A shell 'rm -f /data/local/tmp/my_stock.img.new'
    A push images/my_stock.img /data/local/tmp/my_stock.img.new
    R 'mv -f /data/local/tmp/my_stock.img.new /data/port/my_stock.img.new'
  fi
  say 'Verifying my_stock.img on the phone ...'
  local got
  got=$(R 'sha256sum /data/port/my_stock.img.new' | awk '{print tolower($1)}')
  [[ "$got" == "$MYSTOCK_SHA" ]] || { R 'rm -f /data/port/my_stock.img.new'; die "my_stock.img on the phone has SHA-256 $got; removed, nothing swapped."; }
  R 'cd /data/port && rm -f my_stock-prev.img && mv my_stock.img my_stock-prev.img && mv my_stock.img.new my_stock.img && chown 0:0 my_stock.img && chmod 0644 my_stock.img && chcon u:object_r:system_file:s0 my_stock.img && sync' \
    || die 'Swapping my_stock.img failed; check /data/port by hand (README.md, rollback).'
  say 'my_stock.img staged; the previous image is /data/port/my_stock-prev.img.'
}

# ---------- phase 0: running Android ----------
STAGED=0; SLOT=
if [[ $MODE == adb ]]; then
  CODE=$(A shell getprop ro.boot.project_codename | tr -d '\r')
  [[ "$CODE" == guacamole ]] || die "Expected a OnePlus 7 Pro (ro.boot.project_codename guacamole), got '$CODE'."
  A shell 'test -f /system/etc/init/00-port-mystock.rc' || die 'The running system is not this ColorOS port (no 00-port-mystock.rc). Use the clean install in README.md.'
  SLOT=$(A shell getprop ro.boot.slot_suffix | tr -d '\r'); SLOT=${SLOT#_}
  [[ "$SLOT" == a || "$SLOT" == b ]] || die "Cannot read the active slot: '$SLOT'."
  say "Device $SERIAL: guacamole, running the port on slot $SLOT."
  detect_root
  say "Root for staging on the running system: $ROOT"
  if [[ $DRY == 1 ]]; then
    if [[ $ROOT != none ]]; then
      R 'test -f /data/port/my_stock.img' && say 'Found /data/port/my_stock.img (upgrade).' || say 'WARNING: no /data/port/my_stock.img: not an installed port, the real run would stop.'
      say "Free space on /data: $(R 'df -k /data/port | tail -n 1' | awk '{print $4}') KiB (my_stock.img is $((MYSTOCK_SIZE / 1024)) KiB)."
    fi
  fi
fi

if [[ $DRY == 1 ]]; then
  say 'DRY RUN: image hashes and the phone verified; nothing was written, nothing rebooted, no data changed.'
  if [[ $MODE == fastboot ]]; then
    PRODUCT=$(F getvar product 2>&1 || true); SI=$(F getvar current-slot 2>&1 || true)
    say "fastboot: $(printf '%s\n' "$PRODUCT" | grep -o 'product:.*' | head -n1); $(printf '%s\n' "$SI" | grep -o 'current-slot:.*' | head -n1)"
  fi
  if [[ $ROOT != none ]]; then
    say "Would: copy my_stock.img to /data/port (keeping the old one as my_stock-prev.img), reboot to fastboot, flash vendor_X, system_X, boot_X ($BOOT_IMG) of the active slot, reboot. No wipe."
  elif [[ $VARIANT == noroot ]]; then
    say 'Would: reboot to fastboot, flash vendor_X + the 17k bootstrap system (adb root) + boot_X of the active slot, boot it, copy my_stock.img to /data/port, reboot to fastboot, flash the final system_X, reboot. No wipe.'
  else
    say 'Would: reboot to fastboot, flash vendor_X, system_X and the Magisk boot_X of the active slot, boot, install Magisk if missing, copy my_stock.img with MagiskSU, reboot. No wipe.'
  fi
  exit 0
fi

say 'This UPGRADES the port on the active slot and keeps your data (apps, accounts, settings, files).'
say 'It does not wipe anything, but back up first anyway: a failed flash can still leave the phone unbootable.'
read -r -p 'Confirm the phone is a OnePlus 7 Pro running this port; type GM1910 or PLK110: ' MODEL
[[ "$MODEL" == GM1910 || "$MODEL" == PLK110 ]] || die 'Model confirmation did not match; nothing was changed.'

if [[ $MODE == adb ]]; then
  if [[ $ROOT != none ]]; then stage_mystock; STAGED=1; fi
  A reboot bootloader
  say 'Waiting for fastboot ...'
  wait_fastboot || die 'Timed out waiting for fastboot.'
fi

# ---------- phase 1: fastboot ----------
PRODUCT=$(F getvar product 2>&1) || die "Could not read fastboot product: $PRODUCT"
printf '%s\n' "$PRODUCT" | grep -Eq 'product:[[:space:]]*(guacamole|msmnile)([[:space:]]|$)' || die "Expected fastboot product guacamole or msmnile (OnePlus 7 Pro bootloaders report either): $PRODUCT"
UNLOCKED=$(F getvar unlocked 2>&1) || die "Could not read bootloader state: $UNLOCKED"
printf '%s\n' "$UNLOCKED" | grep -Eqi 'unlocked:[[:space:]]*yes' || die 'Bootloader is not reported unlocked.'
SI=$(F getvar current-slot 2>&1) || die "Could not read the active slot: $SI"
FSLOT=$(printf '%s\n' "$SI" | sed -nE 's/.*current-slot:[[:space:]]*([ab]).*/\1/p' | head -n 1)
[[ "$FSLOT" == a || "$FSLOT" == b ]] || die "Cannot parse the active slot: $SI"
[[ -z "$SLOT" || "$SLOT" == "$FSLOT" ]] || die "Active slot changed ($SLOT -> $FSLOT); stopped before flashing."
SLOT=$FSLOT
say "Flashing slot $SLOT only (the other slot is not touched). No wipe."

if [[ $STAGED == 1 || $VARIANT == magisk ]]; then
  F flash "vendor_$SLOT" "$VENDOR_IMG"
  F flash "system_$SLOT" "$SYSTEM_IMG"
  F flash "boot_$SLOT" "$BOOT_IMG"
  F reboot
else
  # no-root, nothing staged: the 17k development system (adb root) boots once so my_stock.img can be copied, then the final system
  F flash "vendor_$SLOT" "$VENDOR_IMG"
  F flash "system_$SLOT" "$BOOTSTRAP_IMG"
  F flash "boot_$SLOT" "$BOOT_IMG"
  F reboot
  say 'Waiting for the temporary 17k bootstrap system (adb root) ...'
  wait_adb 400 || die 'Timed out waiting for the bootstrap system. The phone runs the bootstrap; rerun this installer.'
  wait_boot 400 || true
  A root >/dev/null 2>&1 || true; sleep 3; wait_adb 60 || true
  detect_root
  [[ $ROOT == adbd ]] || die 'Bootstrap adb root is unavailable; the final system was not flashed. Rerun this installer.'
  stage_mystock; STAGED=1
  A reboot bootloader
  wait_fastboot || die 'Timed out waiting for fastboot.'
  SI=$(F getvar current-slot 2>&1); FSLOT=$(printf '%s\n' "$SI" | sed -nE 's/.*current-slot:[[:space:]]*([ab]).*/\1/p' | head -n 1)
  [[ "$FSLOT" == "$SLOT" ]] || die 'Active slot changed during staging; stopped before the final flash.'
  F flash "system_$SLOT" "$SYSTEM_IMG"
  F reboot
fi

if [[ $STAGED == 0 ]]; then
  # Magisk variant without root on the old system: stage with MagiskSU on the new system, then reboot once more.
  say 'Unlock the phone and approve this computer for USB debugging if asked. Waiting for Android ...'
  wait_adb 400 || die 'Timed out waiting for authorized ADB. Finish my_stock staging by hand (README.md).'
  wait_boot 400 || die 'Android did not report boot completed. Finish my_stock staging by hand (README.md).'
  A shell pm path com.topjohnwu.magisk 2>/dev/null | grep -q package: || A install -r images/Magisk-v31.0.apk
  detect_root
  [[ $ROOT == su ]] || die 'MagiskSU root was not granted. Approve it in Magisk, then rerun this installer.'
  stage_mystock; STAGED=1
  A reboot
elif [[ $VARIANT == magisk ]]; then
  # my_stock was staged on the old system; make sure the Magisk app is present on the new one (best effort).
  say 'Waiting for Android to install the Magisk app if it is missing (unlock the phone and approve USB debugging if asked) ...'
  if wait_adb 400 && wait_boot 400; then
    A shell pm path com.topjohnwu.magisk 2>/dev/null | grep -q package: || A install -r images/Magisk-v31.0.apk || say 'Could not install Magisk; install images/Magisk-v31.0.apk by hand.'
  else
    say 'ADB did not come up; if the Magisk app is missing, install images/Magisk-v31.0.apk by hand.'
  fi
fi

say '17k upgrade flashed; user data kept. The phone is rebooting (first boot can take a few minutes).'
say 'After it has booted, once (see README.md):'
say '  adb shell pm uninstall-system-updates com.oplus.camera   # only if pm path com.oplus.camera shows /data/app'
say '  seed the wallpaper keeper as root: echo com.heytap.colorfulengine/.wallpaper.service.ColorfulWallpaperService > /data/port/wp/wallpaper-component'
say '  do NOT run tools/live/camera-donor17/restore-live.sh any more.'
