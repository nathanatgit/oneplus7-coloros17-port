# Flash the ColorOS 17 port test build to slot B. Slot A keeps stock H.40 untouched.
# Run with the phone in fastboot (adb reboot bootloader). DESTRUCTIVE: wipes userdata + metadata.
$ErrorActionPreference = 'Stop'
$P = 'C:\Users\Han\Project\OnePlus7Port'
$S = "$P\StockRom\H40-images"

function Run($fbArgs) {
    Write-Host "> fastboot $fbArgs"
    & fastboot @fbArgs
    if ($LASTEXITCODE -ne 0) { throw "fastboot $fbArgs failed" }
}

if (-not (fastboot devices)) { throw 'no device in fastboot mode' }
if ((fastboot getvar current-slot 2>&1 | Out-String) -notmatch 'current-slot: a') { throw 'expected current slot a' }

# Slot B firmware (abl, modem, dsp, dtbo, odm, ...) already equals stock H.40 (verified from backup).
Run @('flash', 'boot_b', "$S\boot.img")       # stock H.40 kernel; ramdisk unused (legacy SAR, skip_initramfs)
Run @('flash', 'vendor_b', "$S\vendor.img")   # stock H.40 vendor (slot B held an older one)
# Hashtree disabled -> bootloader uses system footer's root=PARTUUID cmdline. Verification stays ON
# so the chained system footer's cmdline descriptors are still applied (unlocked: key mismatch tolerated).
Run @('--disable-verity', 'flash', 'vbmeta_b', "$S\vbmeta.img")
Run @('flash', 'system_b', "$P\out\system.img")
Run @('--set-active=b')
Run @('-w')                                    # userdata + metadata: Android 17 cannot use ColorOS 12 data
Run @('reboot')

# Rollback: fastboot --set-active=a ; fastboot -w ; reboot. Then, for full stock, restore
# /data/reserve/reserve.img (= StockRom\H40-images\reserve.img) as root, since -w removes it.
