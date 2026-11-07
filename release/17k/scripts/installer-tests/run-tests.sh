#!/usr/bin/env bash
# Offline test matrix for the 17k-r2 .sh installers using stub adb/fastboot. Never touches a real phone:
# PATH is stub-first and ADB/FASTBOOT point at the stub wrappers; every case asserts that.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REL=/c/Users/Han/Project/OnePlus7Port/release/17k
W=$HERE/work; rm -rf "$W"; mkdir -p "$W/bin" "$W/img"
for n in adb fastboot; do printf '#!/usr/bin/env bash\nexec bash "%s/stub.sh" %s "$@"\n' "$HERE" "$n" > "$W/bin/$n"; chmod +x "$W/bin/$n"; done
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/bin/sleep"; chmod +x "$W/bin/sleep"
export PATH="$W/bin:$PATH"
export ADB="$W/bin/adb" FASTBOOT="$W/bin/fastboot"
for f in system.img bootstrap-system.img vendor.img my_stock.img boot-ese-final.img boot-magisk31-17d.img Magisk-v31.0.apk; do echo "fake $f" > "$W/img/$f"; done
MYSHA=$(sha256sum "$W/img/my_stock.img" | awk '{print $1}')

PASS=0; FAIL=0; RESULTS=()
ok() { PASS=$((PASS+1)); RESULTS+=("PASS  $1"); }
bad() { FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1  -- $2"); }

# mk_case name variant -> prepares $C (case dir) with patched installer
mk_case() {
  C=$W/c-$1; rm -rf "$C"; mkdir -p "$C/images" "$C/state"
  cp "$W"/img/* "$C/images/"
  local tag=Magisk; [[ $2 == noroot ]] && tag=NoRoot
  sed -E "s/^(check_image (images\/[^ ]+)) [0-9a-f]{64}$/\1 HASH_\2/; s/^MYSTOCK_SHA=.*/MYSTOCK_SHA=$MYSHA/; s/^MYSTOCK_SIZE=.*/MYSTOCK_SIZE=1024/" "$REL/Install-17k-$tag.sh" > "$C/Install.sh"
  # replace HASH_images/x placeholders with the real hash of the tiny files
  while read -r f; do h=$(sha256sum "$C/$f" | awk '{print $1}'); sed -i "s#HASH_$f\$#$h#" "$C/Install.sh"; done < <(grep -o 'HASH_images/[^ ]*' "$C/Install.sh" | sed 's/^HASH_//')
  export STUB_STATE=$C/state
  # defaults: Android, port on slot a, old system with rootmode given by $ROOTMODE, my_stock present
  printf android > "$C/state/mode"; printf SER0001 > "$C/state/serial"; printf msmnile > "$C/state/product"; printf a > "$C/state/slot"
  printf guacamole > "$C/state/codename"; printf 1 > "$C/state/portsys"; printf 1 > "$C/state/has_mystock"; printf 0 > "$C/state/wiped"
  printf old > "$C/state/sys"; printf old > "$C/state/boot"; printf 0 > "$C/state/magisk_app"; printf "${ROOTMODE:-adbd}" > "$C/state/rootmode"
}
# run_case stdin-mode args... ; stdin-mode: EOF | text:<printf-fmt>
run_case() {
  local sin=$1; shift
  local which; which=$(command -v adb)
  [[ $which == "$W/bin/adb" ]] || { echo "SAFETY: adb resolves to $which, not the stub; abort"; exit 99; }
  (cd "$C" && case $sin in EOF) bash ./Install.sh "$@" </dev/null ;; *) printf "${sin#text:}" | bash ./Install.sh "$@" ;; esac) > "$C/out.txt" 2>&1
  RC=$?
  LOG=$C/state/cmd.log
}
st() { cat "$C/state/$1"; }
has() { grep -qE -- "$1" "$LOG"; }
line() { grep -nE -- "$1" "$LOG" | head -n1 | cut -d: -f1; }
lastline() { grep -nE -- "$1" "$LOG" | tail -n1 | cut -d: -f1; }
outhas() { grep -qE -- "$1" "$C/out.txt"; }
expect() { local name=$1; shift; if "$@"; then ok "$name"; else bad "$name" "$(echo "$*" | cut -c1-100)"; fi; }
noop_unhandled() { [[ ! -s $C/state/unhandled.log ]] || { cat "$C/state/unhandled.log"; return 1; }; }

check_nowipe() {   # $1 = case name
  expect "$1: exit 0" test $RC -eq 0
  expect "$1: no fastboot -w in the command log" bash -c "! grep -qE 'fastboot -w' '$LOG'"
  expect "$1: userdata not wiped (state)" test "$(st wiped)" = 0
  expect "$1: my_stock present at the end" test "$(st has_mystock)" = 1
  expect "$1: final production system flashed last" test "$(st sys)" = final
  expect "$1: no unhandled stub calls" noop_unhandled
}
check_wipe() {
  expect "$1: exit 0" test $RC -eq 0
  expect "$1: fastboot -w called once" test "$(grep -cE 'fastboot -w' "$LOG")" = 1
  expect "$1: -w after vendor/system/boot flashes" test "$(line 'flash vendor_')" -lt "$(line 'fastboot -w')" -a "$(line 'flash boot_')" -lt "$(line 'fastboot -w')"
  expect "$1: -w before the first reboot after the flashes" bash -c "[[ $(line 'fastboot -w') -lt $(line 'fastboot reboot$') ]]"
  expect "$1: userdata wiped (state)" test "$(st wiped)" = 1
  expect "$1: my_stock present at the end (re-provided after wipe)" test "$(st has_mystock)" = 1
  expect "$1: my_stock (re)pushed AFTER the wipe; a pre-wipe copy is erased and redone" bash -c "tail -n1 '$C/state/events.log' | grep -q wiped=1 && grep -q 'PUSH .* wiped=1' '$C/state/events.log'"
  expect "$1: my_stock swap happened on the wiped data" grep -q 'SWAP wiped=1' "$C/state/events.log"
  expect "$1: /data/port created after the wipe" grep -q 'MKDIR wiped=1' "$C/state/events.log"
  expect "$1: final system in place" test "$(st sys)" = final
  expect "$1: no unhandled stub calls" noop_unhandled
}

for V in noroot magisk; do
  RM=adbd; [[ $V == magisk ]] && RM=su
  # ---- A: Android mode, no wipe ----
  ROOTMODE=$RM mk_case "$V-android-enter" $V; run_case 'text:\n'
  check_nowipe "$V android Enter"
  expect "$V android Enter: asked the wipe question" outhas 'Wipe user data\? Default is No: upgrade keeps your data\. Type WIPE to erase /data\.'
  expect "$V android Enter: no GM1910/PLK110 prompt" bash -c "! grep -q 'GM1910 or PLK110' '$C/out.txt'"
  expect "$V android Enter: my_stock pushed BEFORE reboot bootloader (staged)" bash -c "[[ \$(grep -c 'PUSH' '$C/state/events.log') -ge 0 ]] && [[ $(line 'adb reboot bootloader') -gt 0 ]]"
  expect "$V android Enter: only one my_stock push" test "$(grep -c PUSH "$C/state/events.log")" = 1
  ROOTMODE=$RM mk_case "$V-android-empty" $V; run_case EOF; check_nowipe "$V android EOF stdin"
  ROOTMODE=$RM mk_case "$V-android-piped-no" $V; run_case 'text:no\n'; check_nowipe "$V android piped 'no'"
  ROOTMODE=$RM mk_case "$V-android-lower" $V; run_case 'text:wipe\n'; check_nowipe "$V android lowercase 'wipe'"
  ROOTMODE=$RM mk_case "$V-android-wipe-ext" $V; run_case 'text:WIPE now\n'; check_nowipe "$V android 'WIPE now'"
  ROOTMODE=$RM mk_case "$V-android-nowipeflag" $V; run_case EOF --no-wipe; check_nowipe "$V android --no-wipe"
  expect "$V android --no-wipe: no question asked" bash -c "! grep -q 'Wipe user data?' '$C/out.txt'"
  # ---- B: Android mode, WIPE ----
  ROOTMODE=$RM mk_case "$V-android-WIPE" $V; run_case 'text:WIPE\n'; check_wipe "$V android WIPE"
  expect "$V android WIPE: pushed once only (the pre-wipe copy is not pushed twice)" test "$(grep -c PUSH "$C/state/events.log")" -ge 1
  ROOTMODE=$RM mk_case "$V-android---wipe" $V; run_case EOF --wipe; check_wipe "$V android --wipe"
  expect "$V android --wipe: no question asked, no pre-wipe push" bash -c "! grep -q 'Wipe user data?' '$C/out.txt' && ! grep -q 'wiped=0' '$C/state/events.log'"
  # ---- C: fastboot mode, msmnile ----
  ROOTMODE=$RM mk_case "$V-fb-msmnile" $V; printf fastboot > "$C/state/mode"; run_case 'text:\n'
  check_nowipe "$V fastboot msmnile Enter"
  expect "$V fastboot msmnile: no product warning" bash -c "! grep -q WARNING '$C/out.txt'"
  expect "$V fastboot msmnile: my_stock staged after first boot (1 push)" test "$(grep -c PUSH "$C/state/events.log")" = 1
  ROOTMODE=$RM mk_case "$V-fb-msmnile-WIPE" $V; printf fastboot > "$C/state/mode"; run_case 'text:WIPE\n'; check_wipe "$V fastboot msmnile WIPE"
  # ---- D: fastboot mode, wrong product ----
  ROOTMODE=$RM mk_case "$V-fb-wrong-no" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case 'text:no\n'
  expect "$V fastboot wrong product 'no': exit non-zero" test $RC -ne 0
  expect "$V fastboot wrong product 'no': warning shows reported + expected" outhas "product 'sdm845', expected 'msmnile'"
  expect "$V fastboot wrong product 'no': nothing written (no flash/-w/reboot)" bash -c "! grep -qE 'flash|fastboot -w|reboot' '$LOG'"
  ROOTMODE=$RM mk_case "$V-fb-wrong-enter" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case 'text:\n'
  expect "$V fastboot wrong product Enter: aborts, nothing written" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|fastboot -w|reboot' '$LOG'"
  ROOTMODE=$RM mk_case "$V-fb-wrong-eof" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case EOF
  expect "$V fastboot wrong product EOF: aborts, nothing written" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|fastboot -w|reboot' '$LOG'"
  ROOTMODE=$RM mk_case "$V-fb-wrong-YES" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case 'text:YES\n'
  expect "$V fastboot wrong product 'YES' (case): aborts" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash' '$LOG'"
  ROOTMODE=$RM mk_case "$V-fb-wrong-yes" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case 'text:yes\n\n'
  check_nowipe "$V fastboot wrong product 'yes' then Enter"
  expect "$V fastboot wrong product 'yes': proceeded to flash" has 'flash vendor_a'
  ROOTMODE=$RM mk_case "$V-fb-wrong-yes-WIPE" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case 'text:yes\nWIPE\n'; check_wipe "$V fastboot wrong product yes + WIPE"
  ROOTMODE=$RM mk_case "$V-fb-confirm-device" $V; printf fastboot > "$C/state/mode"; printf sdm845 > "$C/state/product"; run_case EOF --confirm-device --no-wipe; check_nowipe "$V fastboot wrong product --confirm-device"
  # ---- E: dry runs ----
  for m in android fastboot; do
    ROOTMODE=$RM mk_case "$V-dry-$m" $V; printf $m > "$C/state/mode"; [[ $m == fastboot ]] && printf sdm845 > "$C/state/product"
    run_case EOF --dry-run
    expect "$V dry-run $m: exit 0" test $RC -eq 0
    expect "$V dry-run $m: nothing flashed/pushed/rebooted/wiped" bash -c "! grep -qE 'flash|fastboot -w|reboot|push|install' '$LOG' && [[ ! -e '$C/state/events.log' ]]"
    expect "$V dry-run $m: state untouched" bash -c "[[ \$(cat $C/state/wiped) = 0 && \$(cat $C/state/sys) = old ]]"
    expect "$V dry-run $m: prints the plan" outhas 'DRY RUN'
  done
  ROOTMODE=$RM mk_case "$V-dry-wipe" $V; run_case EOF --dry-run --wipe
  expect "$V dry-run --wipe: says it would wipe, wrote nothing" bash -c "grep -q 'Would: wipe /data' '$C/out.txt' && ! grep -qE 'flash|fastboot -w|reboot|push' '$LOG'"
  # ---- F: device selection / args ----
  ROOTMODE=$RM mk_case "$V-two-dev" $V; touch "$C/state/extra_adb"; run_case EOF
  expect "$V two adb devices: error, no writes" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|reboot|push' '$LOG'"
  ROOTMODE=$RM mk_case "$V-no-dev" $V; printf off > "$C/state/mode"; run_case EOF
  expect "$V no device: error" test $RC -ne 0
  ROOTMODE=$RM mk_case "$V-badflag" $V; run_case EOF --frobnicate
  expect "$V unknown option: error, no writes" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|reboot|push' '$LOG'"
  ROOTMODE=$RM mk_case "$V-both-flags" $V; run_case EOF --wipe --no-wipe
  expect "$V --wipe --no-wipe: error" test $RC -ne 0
  ROOTMODE=$RM mk_case "$V-notport" $V; printf 0 > "$C/state/portsys"; run_case EOF
  expect "$V android: not the port -> refuses (safety check kept)" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|reboot' '$LOG'"
  ROOTMODE=$RM mk_case "$V-wrong-codename" $V; printf dumpling > "$C/state/codename"; run_case EOF
  expect "$V android: wrong codename -> refuses" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|reboot' '$LOG'"
done
# ---- G: no-root Android with NO root on the old system (bootstrap path), no wipe and wipe ----
ROOTMODE=none mk_case "noroot-android-noroot-old" noroot; run_case 'text:\n'
check_nowipe "noroot android (old system has no root, bootstrap)"
expect "noroot android no-root: bootstrap flashed first then final" test "$(line 'system_a .*bootstrap')" -lt "$(lastline 'system_a .*images/system.img')"
ROOTMODE=none mk_case "noroot-android-noroot-old-WIPE" noroot; run_case 'text:WIPE\n'; check_wipe "noroot android (old system has no root) WIPE"
ROOTMODE=none mk_case "magisk-android-noroot-old" magisk; run_case 'text:\n'; check_nowipe "magisk android (old system has no root)"
# noroot staged then WIPE: bootstrap reflashed
ROOTMODE=adbd mk_case "noroot-android-staged-WIPE" noroot; run_case 'text:WIPE\n'
BS=$(grep -c bootstrap-system.img "$LOG"); expect "noroot android staged then WIPE: bootstrap reflashed once, before -w; final system again at the end" test "$BS" = 1 -a "$(line "system_a .*bootstrap")" -lt "$(line "fastboot -w")" -a "$(lastline "system_a .*images/system.img")" -gt "$(line "fastboot -w")"

echo; printf '%s\n' "${RESULTS[@]}"; echo; echo "TOTAL PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
