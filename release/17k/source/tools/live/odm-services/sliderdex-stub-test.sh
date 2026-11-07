#!/bin/bash
# Stub test of port/bin/port-sliderdex.sh under dash: paths redirected to a temp dir, mount/umount/log/getprop/stop/start stubbed.
# Run in WSL:  bash tools/live/odm-services/sliderdex-stub-test.sh
H=$(cd "$(dirname "$0")" && pwd); SCR=$H/port/bin/port-sliderdex.sh; DEX=$H/port/bin/port-slider-hold.dex
SHA=5ac5b643ae23bfb6bd078c7d7a341ea2ff54b2094fcf8987593595c22d609f54
W=$(mktemp -d); trap 'rm -rf $W' EXIT; fail=0
run() { # name, S-present(1/0), S-content(good/bad), mounts-has-D(0/1), mount-mode(ok/fail/noop), svc-state
  n=$1; T=$W/$n; mkdir -p $T/bin $T/fw; : > $T/calls; S=$T/hold.dex; D=$T/fw/oplus-port-stubs.dex
  echo stock > $D
  [ "$2" = 1 ] && { [ "$3" = good ] && cp $DEX $S || echo garbage > $S; }
  [ "$4" = 1 ] && echo "x $D ext4" > $T/mounts || : > $T/mounts
  for c in log stop start umount; do printf '#!/bin/sh\necho "%s $*" >> %s\n' $c $T/calls > $T/bin/$c; done
  printf '#!/bin/sh\necho "getprop $*" >> %s\necho %s\n' $T/calls "$6" > $T/bin/getprop
  case $5 in
    ok) printf '#!/bin/sh\necho "mount $*" >> %s\nshift; shift; cp "$1" "$2"\n' $T/calls > $T/bin/mount ;;
    fail) printf '#!/bin/sh\necho "mount $*" >> %s\nexit 1\n' $T/calls > $T/bin/mount ;;
    noop) printf '#!/bin/sh\necho "mount $*" >> %s\nexit 0\n' $T/calls > $T/bin/mount ;;
  esac
  chmod +x $T/bin/*
  sed -e "s#^D=.*#D=$D#" -e "s#^S=.*#S=$S#" -e "s#/proc/mounts#$T/mounts#" $SCR > $T/s.sh
  ( PATH=$T/bin:$PATH dash $T/s.sh ); echo "$n exit=$? D=$(head -c5 $D) calls: $(tr '\n' '|' < $T/calls | sed "s#$W/[a-z0-9_]*/##g")"
}
chk() { grep -q "$2" $W/$1/calls && r=ok || r=NO; echo "  [$r] $1 has '$2'"; [ $r = ok ] || fail=1; }
nochk() { grep -q "$2" $W/$1/calls && { echo "  [NO] $1 has '$2'"; fail=1; } || echo "  [ok] $1 lacks '$2'"; }
run t1_ok 1 good 0 ok stopped; chk t1_ok 'mount -o bind'; chk t1_ok 'hold dex bound'; nochk t1_ok 'stop port'
run t2_missing 0 good 0 ok stopped; chk t2_missing 'stock dex kept'; nochk t2_missing 'mount -o'
run t3_badsha 1 bad 0 ok stopped; chk t3_badsha 'unexpected sha'; nochk t3_badsha 'mount -o'
run t4_already 1 good 1 ok stopped; chk t4_already 'already mounted'; nochk t4_already 'mount -o'
run t5_mountfail 1 good 0 fail stopped; chk t5_mountfail 'bind mount failed'
run t6_noop_mismatch 1 good 0 noop stopped; chk t6_noop_mismatch 'umount'; chk t6_noop_mismatch 'verify failed'
run t7_running 1 good 0 ok running; chk t7_running 'stop port_slider_bridge'; chk t7_running 'start port_slider_bridge'
[ "$(sha256sum < $DEX | cut -d' ' -f1)" = $SHA ] || { echo "dex sha mismatch"; fail=1; }
[ $fail = 0 ] && echo "ALL PASS" || echo "FAILED"; exit $fail
