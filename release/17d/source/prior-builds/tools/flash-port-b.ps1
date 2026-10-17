# Phase B: flash ColorOS 17 system on the LineageOS 24 base to slot B (out-b\ from tools/build-port-b.sh).
# vbmeta_b / dtbo_b stay LineageOS's (vbmeta flags=3). Slot A untouched. Run with the phone in fastboot.
$ErrorActionPreference = 'Stop'
$O = 'C:\Users\Han\Project\OnePlus7Port\out-b'

function Run($fbArgs) {
    Write-Host "> fastboot $fbArgs"
    & fastboot @fbArgs
    if ($LASTEXITCODE -ne 0) { throw "fastboot $fbArgs failed" }
}

if (-not (fastboot devices)) { throw 'no device in fastboot mode' }
if ((fastboot getvar current-slot 2>&1 | Out-String) -notmatch 'current-slot: b') { throw 'expected current slot b' }

Run @('flash', 'boot_b',   "$O\boot.img")     # LineageOS boot + erofs /system line in first-stage fstab
Run @('flash', 'vendor_b', "$O\vendor.img")   # LineageOS vendor + erofs /system line in /etc/fstab.qcom
Run @('flash', 'system_b', "$O\system.img")   # ColorOS 17 EROFS
Run @('reboot', 'recovery')
# Then in Lineage Recovery: Factory reset -> Format data / factory reset -> Reboot system now.
# Back to plain LineageOS: flash LineageOS24\payload\system.img to system_b (the patched boot/vendor accept ext4 too).
