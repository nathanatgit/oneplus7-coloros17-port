#!/usr/bin/env bash
# Stub adb/fastboot for installer tests. State lives in files under $STUB_STATE. NEVER talks to a real device.
# usage: stub.sh adb|fastboot args...
set -u
who=$1; shift
S=${STUB_STATE:?STUB_STATE not set}
g() { cat "$S/$1" 2>/dev/null || true; }
p() { printf '%s' "$2" > "$S/$1"; }
SERIAL=$(g serial)
if [[ ${1:-} == -s ]]; then shift 2; fi
echo "$who $*" >> "$S/cmd.log"
mode=$(g mode)

root_kind() {
  case $(g sys) in
    old) g rootmode ;;
    bootstrap) echo adbd ;;
    final) if [[ $(g boot) == magisk && $(g magisk_app) == 1 ]]; then echo su; else echo none; fi ;;
  esac
}

if [[ $who == fastboot ]]; then
  case ${1:-} in
    devices) [[ $mode == fastboot ]] && printf '%s\tfastboot\n' "$SERIAL"; exit 0 ;;
    getvar)
      [[ $mode == fastboot ]] || { echo '< waiting for any device >' >&2; exit 1; }
      case $2 in
        product) echo "product: $(g product)" >&2 ;;
        unlocked) echo "unlocked: yes" >&2 ;;
        current-slot) echo "current-slot: $(g slot)" >&2 ;;
        *) echo "$2: ?" >&2 ;;
      esac
      echo 'Finished. Total time: 0.002s' >&2; exit 0 ;;
    flash)
      [[ $mode == fastboot ]] || exit 1
      img=$(basename "$3")
      case $2 in
        system_*) if [[ $img == bootstrap-system.img ]]; then p sys bootstrap; else p sys final; fi ;;
        boot_*) if [[ $img == boot-magisk31-17d.img ]]; then p boot magisk; else p boot ese; fi ;;
        vendor_*) p vendor 1 ;;
      esac
      echo "Writing '$2'  OKAY" >&2; exit 0 ;;
    -w) [[ $mode == fastboot ]] || exit 1; p wiped 1; p has_mystock 0; p magisk_app 0; echo 'Erasing userdata OKAY' >&2; exit 0 ;;
    reboot) [[ $mode == fastboot ]] || exit 1; p mode android; echo 'Rebooting OKAY' >&2; exit 0 ;;
    *) echo "stub fastboot: unhandled $*" >> "$S/unhandled.log"; exit 0 ;;
  esac
fi

# ---- adb ----
case ${1:-} in
  devices) echo 'List of devices attached'; [[ $mode == android ]] && printf '%s\tdevice\n' "$SERIAL"
           [[ -f $S/extra_adb ]] && printf 'EXTRA123\tdevice\n'; exit 0 ;;
  get-state) [[ $mode == android ]] && { echo device; exit 0; }; echo 'error: no devices/emulators found' >&2; exit 1 ;;
esac
[[ $mode == android ]] || { echo 'error: no devices/emulators found' >&2; exit 1; }
case ${1:-} in
  root) echo 'restarting adbd as root'; exit 0 ;;
  reboot) if [[ ${2:-} == bootloader ]]; then p mode fastboot; else p mode android; fi; exit 0 ;;
  install) p magisk_app 1; echo Success; exit 0 ;;
  push) p staged_sha "$(sha256sum "$2" | awk '{print $1}' | tr -d '\\')"; echo "$2: 1 file pushed" >&2; echo "PUSH $3 wiped=$(g wiped)" >> "$S/events.log"; exit 0 ;;
  shell) shift ;;
  *) echo "stub adb: unhandled $*" >> "$S/unhandled.log"; exit 0 ;;
esac
cmd="$*"
kind=$(root_kind)
if [[ $cmd == "su -c id" ]]; then [[ $kind == su ]] && { echo 'uid=0(root) gid=0(root)'; exit 0; }; echo 'su: not found' ; exit 127; fi
inner=$cmd; viasu=0
if [[ $cmd == "su -c '"* ]]; then
  [[ $kind == su ]] || { echo 'su: inaccessible or not found'; exit 127; }
  inner=${cmd#"su -c '"}; inner=${inner%\'}; viasu=1
fi
rootok=0; [[ $kind == adbd || $viasu == 1 ]] && rootok=1
case $inner in
  id) if [[ $kind == adbd ]]; then echo 'uid=0(root) gid=0(root)'; else echo 'uid=2000(shell) gid=2000(shell)'; fi ;;
  "getprop ro.boot.project_codename") g codename; echo ;;
  "getprop ro.boot.slot_suffix") echo "_$(g slot)" ;;
  "getprop ro.debuggable") echo 0 ;;
  "getprop sys.boot_completed") echo 1 ;;
  "command -v su") if [[ $kind == su ]]; then echo /system/bin/su; else exit 1; fi ;;
  "test -f /system/etc/init/00-port-mystock.rc") [[ $(g portsys) == 1 ]] ;;
  "test -f /data/port/my_stock.img") [[ $rootok == 1 && $(g has_mystock) == 1 ]] ;;
  "test -d /data/port") [[ $rootok == 1 ]] ;;
  "df -k /data/port | tail -n 1") echo '/dev/block/dm-1 100000000 10000000 90000000 10% /data' ;;
  "sha256sum /data/port/my_stock.img.new") echo "$(g staged_sha)  /data/port/my_stock.img.new" ;;
  "pm path com.topjohnwu.magisk") if [[ $(g magisk_app) == 1 ]]; then echo package:/data/app/magisk/base.apk; else exit 1; fi ;;
  "settings get global restricted_networking_mode") echo 0 ;;
  "magisk --denylist"*) [[ $viasu == 1 ]] ;;
  "mkdir -p /data/port"*) [[ $rootok == 1 ]] && echo "MKDIR wiped=$(g wiped)" >> "$S/events.log" ;;
  "cd /data/port && "*"mv my_stock.img.new my_stock.img"*)
      if [[ $rootok == 1 ]]; then p has_mystock 1; echo "SWAP wiped=$(g wiped)" >> "$S/events.log"; else exit 1; fi ;;
  "rm -f "*|"mv -f "*) ;;
  *) echo "stub adb: unhandled shell: $inner" >> "$S/unhandled.log" ;;
esac
exit $?
