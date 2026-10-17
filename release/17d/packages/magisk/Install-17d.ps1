param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$script:Fastboot = (Get-Command fastboot.exe -ErrorAction Stop).Source
$script:Adb = (Get-Command adb.exe -ErrorAction Stop).Source
$script:Root = $PSScriptRoot
$script:Serial = $null
$script:Slot = $null

function Invoke-Fastboot([string[]]$FastbootArgs) {
    Write-Host ("> fastboot " + ($FastbootArgs -join ' '))
    $lines = & $script:Fastboot @FastbootArgs 2>&1
    $code = $LASTEXITCODE
    $lines | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { throw "fastboot failed: $($FastbootArgs -join ' ')" }
    return ($lines -join "`n")
}
function Invoke-Adb([string[]]$AdbArgs) {
    Write-Host ("> adb " + ($AdbArgs -join ' '))
    $lines = & $script:Adb -s $script:Serial @AdbArgs 2>&1
    $code = $LASTEXITCODE
    $lines | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { throw "adb failed: $($AdbArgs -join ' ')" }
    return ($lines -join "`n")
}
function Get-CurrentSlot {
    $s = Invoke-Fastboot @('-s', $script:Serial, 'getvar', 'current-slot')
    if ($s -notmatch 'current-slot:\s*([ab])') { throw "Cannot parse current slot: $s" }
    return $Matches[1]
}
function Wait-ForAdb([int]$Seconds = 300) {
    for ($i = 0; $i -lt $Seconds; $i += 2) {
        $s = & $script:Adb -s $script:Serial get-state 2>$null
        if (($s | Out-String).Trim() -eq 'device') { return }
        Start-Sleep -Seconds 2
    }
    throw 'Timed out waiting for Android ADB.'
}
function Wait-ForFastboot([int]$Seconds = 180) {
    for ($i = 0; $i -lt $Seconds; $i += 2) {
        $rows = @(& $script:Fastboot devices 2>$null | Where-Object { $_ -match '\sfastboot\s*$' })
        if (($rows | Where-Object { $_ -match ('^' + [regex]::Escape($script:Serial) + '\s') }).Count -eq 1) { return }
        Start-Sleep -Seconds 2
    }
    throw 'Timed out waiting for the phone in fastboot.'
}
function Check-Image([string]$RelativePath, [string]$ExpectedHash) {
    $path = Join-Path $script:Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package image: $RelativePath" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedHash.ToLowerInvariant()) { throw "SHA-256 mismatch: $RelativePath ($actual)" }
}

$expected = @{
    'images/system.img' = 'd56f80b4ea9d39338e954127bdefb1e56d4eab77ff8b4498f79ac0124db390d2'
    'images/vendor.img' = 'b55bc1810bd49aebae3c34f56e8e098e440f98ce4f5c6a215a16f1f3bfa729f6'
    'images/my_stock.img' = 'fac842d6d7ca732c1d5dd7f356cfae1991ee9433f88e89b6e3370a1336811760'
    'images/boot-magisk31-17d.img' = 'b073b02da7c29f00f54e510fb4e6a7304d49c5c5df89f684f81d69fa90d4e155'
    'images/Magisk-v31.0.apk' = '2c8a488b9a5293e578e95ae4f07e3c57aba4feec4a52ca4dd852a2692d6dd4e8'
}
foreach ($item in $expected.GetEnumerator()) { Check-Image $item.Key $item.Value }

$fbDevices = @(& $script:Fastboot devices | Where-Object { $_ -match '\sfastboot\s*$' })
if ($fbDevices.Count -ne 1) { throw "Connect exactly one phone in fastboot mode; found $($fbDevices.Count)." }
$script:Serial = $fbDevices[0].Split()[0]
$product = Invoke-Fastboot @('-s', $script:Serial, 'getvar', 'product')
if ($product -notmatch 'product:\s*guacamole\b') { throw "Expected fastboot product guacamole; got: $product" }
$unlocked = Invoke-Fastboot @('-s', $script:Serial, 'getvar', 'unlocked')
if ($unlocked -notmatch 'unlocked:\s*yes') { throw 'Bootloader is not reported unlocked.' }
$script:Slot = Get-CurrentSlot
Write-Host "Detected product guacamole, serial $script:Serial, active slot $script:Slot. Only slot $script:Slot will be flashed."

if ($DryRun) {
    Write-Host 'DRY RUN: validated image hashes and fastboot device; no partitions or user data were changed.'
    Write-Host "Would flash 17d system, vendor, and Magisk boot to slot $script:Slot; wipe userdata/metadata; boot, install Magisk v31.0, grant the staging shell root in Magisk, copy my_stock.img to userdata, and reboot."
    exit 0
}

$model = Read-Host 'Confirm this is a OnePlus 7 Pro PLK110 or GM1910; type PLK110 or GM1910'
if ($model -notin @('PLK110','GM1910')) { throw 'Target model confirmation did not match.' }
$wipe = Read-Host 'This will erase userdata and metadata. Type WIPE to continue'
if ($wipe -cne 'WIPE') { throw 'Install cancelled before any writes.' }

$img = Join-Path $script:Root 'images'
Invoke-Fastboot @('-s', $script:Serial, 'flash', "system_$script:Slot", (Join-Path $img 'system.img')) | Out-Null
Invoke-Fastboot @('-s', $script:Serial, 'flash', "vendor_$script:Slot", (Join-Path $img 'vendor.img')) | Out-Null
Invoke-Fastboot @('-s', $script:Serial, 'flash', "boot_$script:Slot", (Join-Path $img 'boot-magisk31-17d.img')) | Out-Null
Invoke-Fastboot @('-s', $script:Serial, '-w') | Out-Null
Invoke-Fastboot @('-s', $script:Serial, 'reboot') | Out-Null
Wait-ForAdb
$booted = $false
for ($i = 0; $i -lt 240; $i += 3) {
    $state = & $script:Adb -s $script:Serial shell getprop sys.boot_completed 2>$null
    if (($state | Out-String).Trim() -eq '1') { $booted = $true; break }
    Start-Sleep -Seconds 3
}
if (-not $booted) { throw 'Android did not report boot completed; stop and inspect the phone before continuing.' }
Invoke-Adb @('install', '-r', (Join-Path $img 'Magisk-v31.0.apk')) | Out-Null
Write-Host 'If Magisk asks to allow root for the ADB shell, approve it on the phone. The installer now requests su for the image copy.'
$identity = Invoke-Adb @('shell', 'su', '-c', 'id')
if ($identity -notmatch 'uid=0\(root\)') { throw 'MagiskSU root was not granted. Approve the shell request in Magisk, then rerun the image-copy steps described in README.md.' }
Invoke-Adb @('shell', 'mkdir -p /data/port; chown 0:0 /data/port; chmod 0750 /data/port; mkdir -p /data/local/tmp') | Out-Null
Invoke-Adb @('push', (Join-Path $img 'my_stock.img'), '/data/local/tmp/my_stock.img') | Out-Null
Invoke-Adb @('shell', 'su', '-c', 'cp /data/local/tmp/my_stock.img /data/port/my_stock.img && chown 0:0 /data/port/my_stock.img && chmod 0644 /data/port/my_stock.img && chcon u:object_r:system_file:s0 /data/port/my_stock.img && sync && rm -f /data/local/tmp/my_stock.img') | Out-Null
Invoke-Adb @('reboot') | Out-Null
Write-Host '17d Magisk install complete. The phone is rebooting; allow several minutes for the first boot.'
