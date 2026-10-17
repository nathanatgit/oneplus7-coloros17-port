# Wait for adb on each boot of the port and record logcat (all buffers) + kernel log until the device drops.
# Usage: capture-boot.ps1 <log dir> [max boots]
param([string]$Dir = 'C:\Users\Han\Project\OnePlus7Port\logs\phaseB-build1', [int]$MaxBoots = 4)
New-Item -ItemType Directory -Force $Dir | Out-Null
for ($n = 1; $n -le $MaxBoots; $n++) {
    adb wait-for-device
    $stamp = Get-Date -Format 'HHmmss'
    Write-Host "boot ${n}: adb up at $stamp"
    $lc = Start-Process adb -ArgumentList 'logcat', '-b', 'all', '-v', 'threadtime' -RedirectStandardOutput "$Dir\boot$n-$stamp-logcat.txt" -NoNewWindow -PassThru
    $km = Start-Process adb -ArgumentList 'shell', 'dmesg -w 2>/dev/null || cat /proc/kmsg' -RedirectStandardOutput "$Dir\boot$n-$stamp-kmsg.txt" -NoNewWindow -PassThru
    while ((adb get-state 2>$null) -eq 'device') {
        if ((adb shell getprop sys.boot_completed 2>$null) -match '1') { Write-Host "boot ${n}: boot_completed"; Start-Sleep 20; break }
        Start-Sleep 3
    }
    Stop-Process $lc.Id, $km.Id -ErrorAction SilentlyContinue
    adb shell 'getprop sys.boot.reason; getprop sys.boot_completed; uname -r; getprop ro.build.display.id' 2>$null | Out-File "$Dir\boot$n-$stamp-props.txt"
    if ((Get-Content "$Dir\boot$n-$stamp-props.txt" -ErrorAction SilentlyContinue) -match '^1$') { break }
}
