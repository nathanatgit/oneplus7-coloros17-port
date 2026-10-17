export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
P=/mnt/c/Users/Han/Project/OnePlus7Port
export GSI=$P/ColorOS17-PLK110/system.img W=/root/plk OUT=$P/out-plk-build17c GSI_MNT=/mnt/plk FBE_MODE=standard
rm -rf $OUT; bash $P/tools/build-port-b.sh > $P/logs/plk-build17c/build.txt 2>&1
echo "build exit $?" >> $P/logs/plk-build17c/build.txt
OUT=$OUT bash $P/tools/preflight-b.sh > $P/logs/plk-build17c/preflight.txt 2>&1
echo "preflight exit $?" >> $P/logs/plk-build17c/preflight.txt
