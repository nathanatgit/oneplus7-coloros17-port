#!/usr/bin/env bash
# PowerShell installer tests with stub adb/fastboot (.cmd wrappers calling stub.sh). Never touches a real phone.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REL=/c/Users/Han/Project/OnePlus7Port/release/17k
W=$HERE/workps; rm -rf "$W"; mkdir -p "$W/bin" "$W/img"
BASH_WIN='C:\Program Files\Git\bin\bash.exe'
HERE_WIN=$(cygpath -w "$HERE")
for n in adb fastboot; do printf '@echo off\r\n"%s" "%s\\stub.sh" %s %%*\r\n' "$BASH_WIN" "$HERE_WIN" "$n" > "$W/bin/$n.cmd"; done
export ADB=$(cygpath -w "$W/bin/adb.cmd") FASTBOOT=$(cygpath -w "$W/bin/fastboot.cmd")
for f in system.img bootstrap-system.img vendor.img my_stock.img boot-ese-final.img boot-magisk31-17d.img Magisk-v31.0.apk; do echo "fake $f" > "$W/img/$f"; done
MYSHA=$(sha256sum "$W/img/my_stock.img" | awk '{print $1}')
PASS=0; FAIL=0; RESULTS=()
ok() { PASS=$((PASS+1)); RESULTS+=("PASS  $1"); }
bad() { FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1  -- $2"); }
mk_case() {
  C=$W/c-$1; rm -rf "$C"; mkdir -p "$C/images" "$C/state"; cp "$W"/img/* "$C/images/"
  local tag=Magisk; [[ $2 == noroot ]] && tag=NoRoot
  cp "$REL/Install-17k-$tag.ps1" "$C/Install.ps1"
  for f in $(grep -o "images/[A-Za-z0-9_.-]*'" "$C/Install.ps1" | tr -d "'" | sort -u); do
    h=$(sha256sum "$C/$f" | awk '{print $1}')
    sed -i -E "s#(Check-Image \(Join-Path \\\$script:Root '$f'\) )'[0-9a-f]{64}'#\1'$h'#" "$C/Install.ps1"
  done
  sed -i -E "s/^\\\$MyStockSha = '.*'/\$MyStockSha = '$MYSHA'/; s/^\[long\]\\\$MyStockSize = .*/[long]\$MyStockSize = 1024/" "$C/Install.ps1"
  export STUB_STATE=$(cygpath -w "$C/state")
  s=$C/state
  printf android > $s/mode; printf SER0001 > $s/serial; printf msmnile > $s/product; printf a > $s/slot; printf guacamole > $s/codename
  printf 1 > $s/portsys; printf 1 > $s/has_mystock; printf 0 > $s/wiped; printf old > $s/sys; printf old > $s/boot; printf 0 > $s/magisk_app; printf "${ROOTMODE:-adbd}" > $s/rootmode
}
run_case() {
  local sin=$1; shift
  local args="$*"
  ( cd "$C" && case $sin in EOF) pwsh -NoProfile -Command "function Start-Sleep {}; & ./Install.ps1 $args" </dev/null ;; *) printf "${sin#text:}" | pwsh -NoProfile -Command "function Start-Sleep {}; & ./Install.ps1 $args" ;; esac ) > "$C/out.txt" 2>&1
  RC=$?; LOG=$C/state/cmd.log
}
st() { cat "$C/state/$1"; }
expect() { local n=$1; shift; if "$@"; then ok "$n"; else bad "$n" "$(echo "$*" | cut -c1-90)"; fi; }
nowipe() { expect "$1: exit 0" test $RC -eq 0; expect "$1: no -w" bash -c "! grep -qE 'fastboot -w' '$LOG'"; expect "$1: my_stock present" test "$(st has_mystock)" = 1; expect "$1: final system" test "$(st sys)" = final; expect "$1: no unhandled" test ! -s $C/state/unhandled.log; }
wipe() { expect "$1: exit 0" test $RC -eq 0; expect "$1: one -w" test "$(grep -cE 'fastboot -w' "$LOG")" = 1; expect "$1: wiped" test "$(st wiped)" = 1; expect "$1: my_stock re-provided after wipe (pre-wipe copy erased and redone)" bash -c "tail -n1 '$C/state/events.log' | grep -q 'SWAP wiped=1'"; expect "$1: mkdir after wipe" grep -q 'MKDIR wiped=1' "$C/state/events.log"; expect "$1: final system" test "$(st sys)" = final; expect "$1: no unhandled" test ! -s $C/state/unhandled.log; }
for V in noroot magisk; do
  RM=adbd; [[ $V == magisk ]] && RM=su
  ROOTMODE=$RM mk_case $V-android-enter $V; run_case 'text:\n'; nowipe "PS $V android Enter"
  expect "PS $V android Enter: question asked, no model prompt" bash -c "grep -q 'Type WIPE to erase /data' '$C/out.txt' && ! grep -q 'GM1910 or PLK110' '$C/out.txt'"
  ROOTMODE=$RM mk_case $V-android-eof $V; run_case EOF; nowipe "PS $V android EOF"
  ROOTMODE=$RM mk_case $V-android-lower $V; run_case 'text:wipe\n'; nowipe "PS $V android lowercase wipe"
  ROOTMODE=$RM mk_case $V-android-WIPE $V; run_case 'text:WIPE\n'; wipe "PS $V android WIPE"
  ROOTMODE=$RM mk_case $V-android-Wipeflag $V; run_case EOF -Wipe; wipe "PS $V android -Wipe"
  ROOTMODE=$RM mk_case $V-fb-msmnile $V; printf fastboot > $C/state/mode; run_case 'text:\n'; nowipe "PS $V fastboot msmnile"
  ROOTMODE=$RM mk_case $V-fb-WIPE $V; printf fastboot > $C/state/mode; run_case 'text:WIPE\n'; wipe "PS $V fastboot WIPE"
  ROOTMODE=$RM mk_case $V-fb-wrong-no $V; printf fastboot > $C/state/mode; printf sdm845 > $C/state/product; run_case 'text:no\n'
  expect "PS $V wrong product no: aborts, nothing written" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|fastboot -w|reboot' '$LOG' && grep -q \"expected 'msmnile'\" '$C/out.txt'"
  ROOTMODE=$RM mk_case $V-fb-wrong-eof $V; printf fastboot > $C/state/mode; printf sdm845 > $C/state/product; run_case EOF
  expect "PS $V wrong product EOF: aborts, nothing written" bash -c "[[ $RC -ne 0 ]] && ! grep -qE 'flash|fastboot -w|reboot' '$LOG'"
  ROOTMODE=$RM mk_case $V-fb-wrong-yes $V; printf fastboot > $C/state/mode; printf sdm845 > $C/state/product; run_case 'text:yes\n\n'; nowipe "PS $V wrong product yes + Enter"
  ROOTMODE=$RM mk_case $V-dry $V; printf fastboot > $C/state/mode; run_case EOF -DryRun
  expect "PS $V dry-run fastboot: nothing written" bash -c "[[ $RC -eq 0 ]] && ! grep -qE 'flash|fastboot -w|reboot|push' '$LOG'"
  ROOTMODE=$RM mk_case $V-dry-a $V; run_case EOF -DryRun
  expect "PS $V dry-run android: nothing written" bash -c "[[ $RC -eq 0 ]] && ! grep -qE 'flash|fastboot -w|reboot|push' '$LOG'"
done
echo; printf '%s\n' "${RESULTS[@]}"; echo; echo "TOTAL PASS=$PASS FAIL=$FAIL"; [[ $FAIL -eq 0 ]]
