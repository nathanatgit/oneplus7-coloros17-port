# Phase A: install official LineageOS 24.0 (20261011 nightly, hashes in LineageOS24\SHA256SUMS) to slot B only.
# Equivalent to the wiki's sideload install, but writes slot B by hand so stock H.40 on slot A stays untouched.
# Firmware: slot B already has H.40 firmware; LineageOS's payload firmware (GM1911 H.41) is byte-identical except abl,
# which is deliberately NOT flashed (keep the bootloader slot A also uses). Run with the phone in fastboot, slot A active.
$ErrorActionPreference = 'Stop'
$L = 'C:\Users\Han\Project\OnePlus7Port\LineageOS24'

function Run($fbArgs) {
    Write-Host "> fastboot $fbArgs"
    & fastboot @fbArgs
    if ($LASTEXITCODE -ne 0) { throw "fastboot $fbArgs failed" }
}

if (-not (fastboot devices)) { throw 'no device in fastboot mode' }
if ((fastboot getvar current-slot 2>&1 | Out-String) -notmatch 'current-slot: a') { throw 'expected current slot a' }

Run @('flash', 'boot_b',   "$L\boot.img")             # kernel 4.14.357 + 2SI ramdisk incl. Lineage Recovery
Run @('flash', 'dtbo_b',   "$L\dtbo.img")
Run @('flash', 'vbmeta_b', "$L\vbmeta.img")           # flags=3: hashtree + verification disabled
Run @('flash', 'system_b', "$L\payload\system.img")
Run @('flash', 'vendor_b', "$L\payload\vendor.img")
Run @('--set-active=b')
Run @('reboot', 'recovery')
# Next, on the phone (Lineage Recovery): Factory reset -> Format data / factory reset -> back -> Reboot system now.
# Do NOT use fastboot -w (see PORTING.md, slot A incident).
