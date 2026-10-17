cd /mnt/c/Users/Han/Project/OnePlus7Port
python3 -I - <<'PY'
p='tools/build-port-b.sh'; s=open(p).read()
def rep(a,b):
    global s
    assert a in s, a[:60]; s=s.replace(a,b)
rep("# and needs the H.40 com.vendor.nfc library. It talks to the HIDL secure_element HALs installed into the odm below (eSE1).",
    "# and needs the H.40 com.vendor.nfc library. It reaches the SIM1/SIM2 secure_element HALs of the LOS vendor; the eSE (stock\n# android.hardware.secure_elementnq330 HAL) is NOT shipped: the LOS24 kernel has no /dev/p73 driver (tools/live/odm-services/install.list).")
rep('# Oplus odm services missing from the LOS24 odm (stock H.40; handoff-2026-10-17 §9b, build 17): charger HAL (Battery Health,\n# "getIChargerService fail"), cryptoeng HAL (Find My Device RPMB channel), secure_element HAL for the eSE (Wallet through OMAPI).',
    '# Oplus odm services missing from the LOS24 odm (stock H.40; handoff-2026-10-17 §9b, build 17b): charger HAL (Battery Health,\n# "getIChargerService fail") and cryptoeng HAL (Find My Device RPMB channel). The stock binaries need two symbols the LOS24 libbase /\n# libjsoncpp export differently; their rc LD_PRELOADs libportcompat.so (tools/live/odm-services/compat). Build 17 without it: CANNOT LINK.')
open(p,'w').write(s)
PY
bash -n tools/build-port-b.sh && echo ok
