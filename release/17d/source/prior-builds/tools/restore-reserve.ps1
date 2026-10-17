# Restore stock /data/reserve/reserve.img on slot A, using the temporary adbfix boot image (nothing is flashed).
# Phone must be in fastboot mode on slot A.
$ErrorActionPreference = 'Stop'
$env:MSYS_NO_PATHCONV = '1'
$P = 'C:\Users\Han\Project\OnePlus7Port'
$scratch = "$P\tools\magisk"

function RunRoot([string]$script, [int]$timeoutSec = 120) {
    # Push a script, trigger the init hook, wait for it to finish, print its log.
    $f = "$scratch\run.sh"
    [IO.File]::WriteAllText($f, $script.Replace("`r`n", "`n"))
    adb push $f /data/local/tmp/run.sh | Out-Null
    adb shell 'rm -f /data/local/tmp/run.log; setprop debug.adbfix.run 1'
    $t0 = Get-Date
    do { Start-Sleep 1; $busy = (adb shell getprop debug.adbfix.run).Trim() -eq '1' }
    while ($busy -and ((Get-Date) - $t0).TotalSeconds -lt $timeoutSec)
    adb shell cat /data/local/tmp/run.log
}

if ((fastboot getvar current-slot 2>&1 | Out-String) -notmatch 'current-slot: a') { throw 'expected fastboot on slot a' }
fastboot boot "$scratch\boot-H40-magisk-adbfix.img"
Write-Host 'waiting for adb...'
adb wait-for-device

Write-Host '== why it loops (crash buffer + boot reason), then stop the framework'
RunRoot @'
getprop sys.boot.reason; getprop ro.boot.bootreason
logcat -d -b crash | tail -40
ls -la /data/reserve 2>&1
stop
echo framework-stopped
'@

Write-Host '== pushing reserve.img (4.5 GB)'
adb push "$P\StockRom\H40-images\reserve.img" /data/local/tmp/reserve.img

Write-Host '== moving into place'
RunRoot @'
set -e
mkdir -p /data/reserve
chown system:system /data/reserve
chmod 0771 /data/reserve
mv /data/local/tmp/reserve.img /data/reserve/reserve.img
chown root:root /data/reserve/reserve.img
chmod 0644 /data/reserve/reserve.img
restorecon -R /data/reserve
ls -laZ /data/reserve
sha256sum /data/reserve/reserve.img
sync
'@ 900
Write-Host 'expected sha256 c439d98f5630e1957af5ef088c229ceeaedb607790887d016c01746389b45176'
