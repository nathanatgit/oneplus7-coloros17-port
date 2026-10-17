cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/build-port-b.sh'; s=open(p).read()
i=s.index('unzip -p "$BS/OVoiceManagerService-sva-c17sig.apk" classes.dex | grep -aq svaOpaque'); j=s.index('\n',i)
s=s[:i]+'''[ "$(unzip -p "$BS/OVoiceManagerService-sva-c17sig.apk" 'classes*.dex' | grep -ac svaOpaque)" -ge 1 ] || { echo "breeno apk lacks svaOpaque"; exit 1; }   # grep -c reads all (grep -q + pipefail = SIGPIPE)'''+s[j:]
open(p,'w').write(s)
PY
bash -n tools/build-port-b.sh && echo ok
