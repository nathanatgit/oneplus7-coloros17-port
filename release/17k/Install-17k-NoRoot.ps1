# OnePlus 7 Pro ColorOS 17 port, 17k-r2 NoRoot UPGRADE installer (Windows PowerShell).
# Default = UPGRADE of an installed port (17d or later) on the ACTIVE slot, KEEPING ALL USER DATA: it flashes vendor, system and
# boot of the active slot only and replaces /data/port/my_stock.img (the previous one is kept as my_stock-prev.img).
# After the images are flashed it asks whether to wipe /data; only the exact word WIPE does (clean install, `fastboot -w`);
# Enter, anything else, or no input (piped/non-interactive) keeps the data.
#   .\Install-17k.ps1                  install (asks the WIPE question after flashing)
#   .\Install-17k.ps1 -DryRun          check images, phone, slot, root and free space; change nothing
#   .\Install-17k.ps1 -Wipe            scripted: wipe /data without asking (clean install)
#   .\Install-17k.ps1 -NoWipe          scripted: keep /data without asking
#   .\Install-17k.ps1 -ConfirmDevice   scripted: accept a fastboot product other than msmnile without asking
# Start with the phone booted into the current port with USB debugging authorized (preferred), or in fastboot (bootloader) mode.
param([switch]$DryRun, [switch]$Wipe, [switch]$NoWipe, [switch]$ConfirmDevice)
$ErrorActionPreference = 'Stop'
if ($Wipe -and $NoWipe) { throw '-Wipe and -NoWipe cannot be combined.' }
$script:Variant = 'noroot'   # noroot | magisk
$script:Wiped = $false
# FASTBOOT / ADB environment variables override the program (like the .sh installer); default = the ones on PATH.
if ($env:FASTBOOT) { $script:Fastboot = $env:FASTBOOT } else { $script:Fastboot = (Get-Command fastboot.exe -ErrorAction Stop).Source }
if ($env:ADB) { $script:Adb = $env:ADB } else { $script:Adb = (Get-Command adb.exe -ErrorAction Stop).Source }
$script:Root = $PSScriptRoot
$script:Serial = $null
$script:SuMode = 'none'
$MyStockSha = '135022d0d5816296a365cb39e920a73c0eabc32ff4f5be18dfa70c86d203c189'
[long]$MyStockSize = 6917992448
$img = Join-Path $script:Root 'images'
$SystemImg = Join-Path $img 'system.img'
$BootstrapImg = Join-Path $img 'bootstrap-system.img'
$VendorImg = Join-Path $img 'vendor.img'
$MyStockImg = Join-Path $img 'my_stock.img'
$MagiskApk = Join-Path $img 'Magisk-v31.0.apk'
if ($script:Variant -eq 'magisk') { $BootImg = Join-Path $img 'boot-magisk31-17d.img' } else { $BootImg = Join-Path $img 'boot-ese-final.img' }

# Windows PowerShell 5.1 turns a native program's stderr into errors that 'Stop' makes fatal (fastboot prints everything on
# stderr), so every adb/fastboot call goes through Run-Native with 'Continue' and plain strings.
function Run-Native([string]$Exe, [string[]]$NativeArgs) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    # $null | : empty stdin, so adb/fastboot never read input meant for Read-Host
    try { $out = @($null | & $Exe @NativeArgs 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $old }
    return [pscustomobject]@{ Out = $out; Code = $code }
}
function Invoke-Fastboot([string[]]$FastbootArgs) {
    Write-Host ("> fastboot " + ($FastbootArgs -join ' '))
    $r = Run-Native $script:Fastboot (@('-s', $script:Serial) + $FastbootArgs)
    $r.Out | ForEach-Object { Write-Host $_ }
    if ($r.Code -ne 0) { throw "fastboot failed: $($FastbootArgs -join ' ')" }
    return ($r.Out -join "`n")
}
function Invoke-Adb([string[]]$AdbArgs) {
    Write-Host ("> adb " + ($AdbArgs -join ' '))
    $r = Run-Native $script:Adb (@('-s', $script:Serial) + $AdbArgs)
    $r.Out | ForEach-Object { Write-Host $_ }
    if ($r.Code -ne 0) { throw "adb failed: $($AdbArgs -join ' ')" }
    return ($r.Out -join "`n")
}
function Get-AdbOut([string[]]$AdbArgs) {   # quiet, never throws; returns trimmed output (stdout and stderr)
    $r = Run-Native $script:Adb (@('-s', $script:Serial) + $AdbArgs)
    return (($r.Out -join "`n").Trim())
}
function Test-Adb([string[]]$AdbArgs) {   # quiet; true when the command exits 0
    return ((Run-Native $script:Adb (@('-s', $script:Serial) + $AdbArgs)).Code -eq 0)
}
function Invoke-Root([string]$Cmd) {   # run as root on the phone; throws on a non-zero exit
    if ($script:SuMode -eq 'adbd') { return Invoke-Adb @('shell', $Cmd) }
    return Invoke-Adb @('shell', "su -c '$Cmd'")   # one string: adb joins its args
}
function Test-Root([string]$Cmd) {
    if ($script:SuMode -eq 'adbd') { return (Test-Adb @('shell', $Cmd)) }
    return (Test-Adb @('shell', "su -c '$Cmd'"))
}
function Wait-ForAdb([int]$Seconds = 400) {
    for ($i = 0; $i -lt $Seconds; $i += 2) {
        if ((Get-AdbOut @('get-state')) -eq 'device') { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}
function Wait-ForBoot([int]$Seconds = 400) {
    for ($i = 0; $i -lt $Seconds; $i += 3) {
        if ((Get-AdbOut @('shell', 'getprop', 'sys.boot_completed')) -eq '1') { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}
function Wait-ForFastboot([int]$Seconds = 180) {
    for ($i = 0; $i -lt $Seconds; $i += 2) {
        $rows = @((Run-Native $script:Fastboot @('devices')).Out | Where-Object { $_ -match ('^' + [regex]::Escape($script:Serial) + '\s+fastboot') })
        if ($rows.Count -eq 1) { return }
        Start-Sleep -Seconds 2
    }
    throw 'Timed out waiting for the phone in fastboot.'
}
function Get-CurrentSlot {
    $s = Invoke-Fastboot @('getvar', 'current-slot')
    if ($s -notmatch 'current-slot:\s*([ab])') { throw "Cannot parse current slot: $s" }
    return $Matches[1]
}
function Check-Image([string]$Path, [string]$ExpectedHash) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing package image: $Path" }
    Write-Host "Checking $Path ..."
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedHash.ToLowerInvariant()) { throw "SHA-256 mismatch: $Path ($actual)" }
}
function Find-Root {   # sets $script:SuMode = adbd | su | none
    $script:SuMode = 'none'
    if ((Get-AdbOut @('shell', 'id')) -match 'uid=0\(root\)') { $script:SuMode = 'adbd'; return }
    if (-not $DryRun -and (Get-AdbOut @('shell', 'getprop', 'ro.debuggable')) -eq '1') {
        [void](Test-Adb @('root'))
        Start-Sleep -Seconds 3
        [void](Wait-ForAdb 60)
        if ((Get-AdbOut @('shell', 'id')) -match 'uid=0\(root\)') { $script:SuMode = 'adbd'; return }
    }
    if ((Get-AdbOut @('shell', 'command -v su')) -match '/su$') {
        Write-Host 'If Magisk asks to allow root for the ADB shell, approve it on the phone.'
        if ((Get-AdbOut @('shell', 'su', '-c', 'id')) -match 'uid=0\(root\)') { $script:SuMode = 'su' }
    }
}
function Get-FreeKiB {
    $line = (Get-AdbOut @('shell', $(if ($script:SuMode -eq 'adbd') { 'df -k /data/port | tail -n 1' } else { "su -c 'df -k /data/port | tail -n 1'" })))
    $f = ($line -split '\s+')[3]
    if ($f -notmatch '^\d+$') { throw "Could not read free space on /data: $line" }
    return [long]$f
}
# Copies my_stock.img to /data/port/my_stock.img.new, verifies it on the phone, then swaps it in (old -> my_stock-prev.img).
function Stage-MyStock {
    if ($script:Wiped) {
        # /data was just wiped: it is empty, create the directory exactly like the 17d clean install did (init normally makes it too)
        for ($i = 0; $i -lt 90; $i += 2) { if (Test-Root 'test -d /data/port') { break }; Start-Sleep -Seconds 2 }
        [void](Test-Root 'mkdir -p /data/port; chown 0:0 /data/port; chmod 0750 /data/port; mkdir -p /data/local/tmp')
    } elseif (-not (Test-Root 'test -f /data/port/my_stock.img')) {
        throw 'No /data/port/my_stock.img on this phone: this is not an installed port. Rerun and answer WIPE for a clean install (README.md), or copy images\my_stock.img to /data/port by hand.'
    }
    $free = Get-FreeKiB
    if ($script:SuMode -eq 'su') { $need = [long]($MyStockSize * 2 / 1024) + 1048576 } else { $need = [long]($MyStockSize / 1024) + 1048576 }
    if ($free -le $need) { throw "Not enough free space on /data: $free KiB free, $need KiB needed." }
    Invoke-Root 'rm -f /data/port/my_stock.img.new' | Out-Null
    if ($script:SuMode -eq 'adbd') {
        Invoke-Adb @('push', $MyStockImg, '/data/port/my_stock.img.new') | Out-Null
    } else {
        Invoke-Adb @('shell', 'rm -f /data/local/tmp/my_stock.img.new') | Out-Null
        Invoke-Adb @('push', $MyStockImg, '/data/local/tmp/my_stock.img.new') | Out-Null
        Invoke-Root 'mv -f /data/local/tmp/my_stock.img.new /data/port/my_stock.img.new' | Out-Null
    }
    Write-Host 'Verifying my_stock.img on the phone ...'
    $got = ((Invoke-Root 'sha256sum /data/port/my_stock.img.new') -split '\s+')[0].ToLowerInvariant()
    if ($got -ne $MyStockSha) { Invoke-Root 'rm -f /data/port/my_stock.img.new' | Out-Null; throw "my_stock.img on the phone has SHA-256 $got; removed, nothing swapped." }
    Invoke-Root 'cd /data/port && rm -f my_stock-prev.img && { test ! -f my_stock.img || mv my_stock.img my_stock-prev.img; } && mv my_stock.img.new my_stock.img && chown 0:0 my_stock.img && chmod 0644 my_stock.img && chcon u:object_r:system_file:s0 my_stock.img && sync' | Out-Null
    if ($script:Wiped) { Write-Host 'my_stock.img staged on the freshly wiped /data.' } else { Write-Host 'my_stock.img staged; the previous image is /data/port/my_stock-prev.img.' }
}


# ---------- 17k-r2: Magisk variant: let OPPO Health run (best effort, never fails the install) ----------
# OPPO Health (com.heytap.health) shows a "risk notice" and closes when it can see root: Magisk puts `su` in /product/bin, which is
# first on every app's PATH. Magisk's DenyList hides Magisk from the listed apps only, but it must be ENFORCED: adding the app is
# not enough, `magisk --denylist enable` is needed (it also saves the setting in Magisk's database, so it survives reboots and
# later upgrades). Needs root for the ADB shell (MagiskSU); without it this step is skipped.
function Invoke-HealthDenyList {
    if ($script:Variant -ne 'magisk') { return }
    try {
        Find-Root
        if ($script:SuMode -eq 'none') {
            Write-Host 'No root for the ADB shell: skipped the Magisk DenyList step for OPPO Health. Later: adb shell su -c "magisk --denylist enable; magisk --denylist add com.heytap.health"'
            return
        }
        [void](Test-Root 'magisk --denylist enable')
        [void](Test-Root 'magisk --denylist add com.heytap.health')
        if (Test-Root 'magisk --denylist status') {
            Write-Host 'Magisk DenyList is enforced and lists com.heytap.health (hides Magisk from the OPPO Health root check).'
        } else {
            Write-Host 'Could not confirm the Magisk DenyList; if OPPO Health reports a rooted device, run: adb shell su -c "magisk --denylist enable; magisk --denylist add com.heytap.health"'
        }
    } catch { Write-Host "Skipped the Magisk DenyList step: $_" }
}

# ---------- 17k-r2: network-restriction guard (best effort, never fails the install) ----------
# The first 17k upgrade left Settings.Global restricted_networking_mode = 1 on the author's phone: every normal app had no
# network (Wi-Fi and cellular), adb shell still worked. The writer is UNKNOWN. The image now ships a boot-time guard
# (port_netguard); this installer step additionally clears the value once through adb after the final flash.
function Invoke-NetGuard {
    try {
        Start-Sleep -Seconds 20   # let a reboot that was just requested take the phone down before we look for adb
        Write-Host 'Waiting for Android to finish booting to check the network restriction setting (best effort) ...'
        if ((Wait-ForAdb 400) -and (Wait-ForBoot 400)) {
            $v = Get-AdbOut @('shell', 'settings', 'get', 'global', 'restricted_networking_mode')
            if ($v -eq '1') {
                [void](Get-AdbOut @('shell', 'settings', 'put', 'global', 'restricted_networking_mode', '0'))
                $v2 = Get-AdbOut @('shell', 'settings', 'get', 'global', 'restricted_networking_mode')
                Write-Host "restricted_networking_mode was 1 (apps would have had no network); set to 0, now reads '$v2'."
            } else {
                Write-Host "restricted_networking_mode reads '$v': nothing to do."
            }
        } else {
            Write-Host 'ADB did not come up; if apps have no network after boot, run: adb shell settings put global restricted_networking_mode 0'
        }
    } catch { Write-Host "Network restriction check skipped: $($_.Exception.Message)" }
}
Check-Image (Join-Path $script:Root 'images/bootstrap-system.img') 'e64a10ca29f384a877b223f255150dd8bb3616321f3b51e9b6f9c5ec43dc5726'
Check-Image (Join-Path $script:Root 'images/system.img') '0b24fcb2d323f406deba2ed4c46a8edb38c4532bde0b44b026c0a9e8373af3b9'
Check-Image (Join-Path $script:Root 'images/vendor.img') 'e61b3b199ae48f3518119d489aced6425fec0f8bb086f8537f50e382be731f3c'
Check-Image (Join-Path $script:Root 'images/my_stock.img') '135022d0d5816296a365cb39e920a73c0eabc32ff4f5be18dfa70c86d203c189'
Check-Image (Join-Path $script:Root 'images/boot-ese-final.img') 'a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91'

# ---------- find the phone ----------
$adbRows = @((Run-Native $script:Adb @('devices')).Out | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice\s*$' })
$fbRows = @((Run-Native $script:Fastboot @('devices')).Out | Where-Object { $_ -match '\sfastboot\s*$' })
if (($adbRows.Count + $fbRows.Count) -ne 1) { throw "Connect exactly one phone (Android with USB debugging authorized, or fastboot); found $($adbRows.Count) adb + $($fbRows.Count) fastboot." }
if ($adbRows.Count -eq 1) { $mode = 'adb'; $script:Serial = ($adbRows[0] -split '\s+')[0] } else { $mode = 'fastboot'; $script:Serial = ($fbRows[0] -split '\s+')[0] }

# ---------- phase 0: running Android ----------
$staged = $false; $slot = $null
if ($mode -eq 'adb') {
    $code = Get-AdbOut @('shell', 'getprop', 'ro.boot.project_codename')
    if ($code -ne 'guacamole') { throw "Expected a OnePlus 7 Pro (ro.boot.project_codename guacamole), got '$code'." }
    if (-not (Test-Adb @('shell', 'test -f /system/etc/init/00-port-mystock.rc'))) { throw 'The running system is not this ColorOS port (no 00-port-mystock.rc). Start the phone in fastboot mode and rerun this installer, answering WIPE for a clean install (README.md).' }
    $slot = (Get-AdbOut @('shell', 'getprop', 'ro.boot.slot_suffix')).TrimStart('_')
    if ($slot -notin @('a', 'b')) { throw "Cannot read the active slot: '$slot'." }
    Write-Host "Device $($script:Serial): guacamole, running the port on slot $slot."
    Find-Root
    Write-Host "Root for staging on the running system: $script:SuMode"
    if ($DryRun -and $script:SuMode -ne 'none') {
        if (Test-Root 'test -f /data/port/my_stock.img') { Write-Host 'Found /data/port/my_stock.img (upgrade).' } else { Write-Host 'WARNING: no /data/port/my_stock.img: not an installed port, the real run would stop.' }
        Write-Host "Free space on /data: $(Get-FreeKiB) KiB (my_stock.img is $([long]($MyStockSize / 1024)) KiB)."
    }
}

if ($mode -eq 'fastboot') {
    Write-Host "Device $($script:Serial): bootloader (fastboot) mode."
    Write-Host 'Nothing can be staged through adb from here, so my_stock.img is copied after the first boot (see below) once the images are flashed.'
}

# Reads one line from the console; empty string on EOF, redirected/closed stdin or any error (= the safe default answer).
function Read-Answer([string]$Prompt) {
    Write-Host -NoNewline $Prompt
    try { $a = [Console]::In.ReadLine() } catch { $a = $null }
    Write-Host ''
    if ($null -eq $a) { return '' }
    return $a.Trim("`r", "`n")
}

# ---------- fastboot product check ----------
# msmnile = the OnePlus 7 Pro (GM1910 / guacamole) board name. In bootloader mode anything else needs a typed "yes".
function Test-Product {
    $out = Invoke-Fastboot @('getvar', 'product')
    if ($out -notmatch '(?m)^\s*(\(bootloader\)\s*)?product:\s*(\S+)') { throw "Cannot parse the fastboot product: $out" }
    $prod = $Matches[2]
    if ($prod -eq 'msmnile') { Write-Host 'fastboot product: msmnile (OnePlus 7 Pro).'; return }
    if ($mode -eq 'adb' -and $prod -eq 'guacamole') { return }   # already verified over adb (project_codename guacamole)
    Write-Host "WARNING: fastboot reports product '$prod', expected 'msmnile' (OnePlus 7 Pro GM1910 / guacamole)."
    Write-Host 'Flashing this port onto another model can leave the phone unbootable.'
    if ($mode -eq 'adb') { throw "The phone was verified as guacamole over adb but fastboot reports '$prod'. Stopped before flashing; the phone is in fastboot (run: fastboot reboot)." }
    if ($DryRun) { Write-Host 'DRY RUN: the real run would ask you to type yes to continue.'; return }
    if ($ConfirmDevice) { Write-Host '-ConfirmDevice given: continuing.'; return }
    Write-Host 'Make sure this is a OnePlus 7 Pro (GM1910 / guacamole) before continuing.'
    $ans = Read-Answer 'Type yes to continue; anything else aborts and nothing is written: '
    if ($ans -cne 'yes') { throw 'Aborted: product not confirmed; nothing was written.' }
}

# ---------- wipe question (asked after the images are flashed, before the final reboot) ----------
function Get-WipeAnswer {
    if ($Wipe) { Write-Host '-Wipe given: /data will be erased.'; return $true }
    if ($NoWipe) { Write-Host '-NoWipe given: /data is kept.'; return $false }
    Write-Host 'Wipe user data? Default is No: upgrade keeps your data. Type WIPE to erase /data.'
    $ans = Read-Answer '> '
    return ($ans -ceq 'WIPE')   # case sensitive; Enter, EOF or anything else keeps the data
}

# After a wipe the phone must not be left without my_stock.img: say exactly how to finish by hand.
function Stop-Staging([string]$Message) {
    if ($script:Wiped) {
        Write-Host 'IMPORTANT: /data was wiped and my_stock.img is NOT on the phone yet, so the port will not start properly. Finish by hand (needs adb root or MagiskSU):'
        Write-Host '  adb shell "mkdir -p /data/port; chown 0:0 /data/port; chmod 0750 /data/port"'
        Write-Host '  adb push images\my_stock.img /data/local/tmp/my_stock.img   (then as root: cp it to /data/port/my_stock.img; chown 0:0; chmod 0644; chcon u:object_r:system_file:s0; sync)'
    }
    throw $Message
}

if ($DryRun) {
    Write-Host 'DRY RUN: image hashes and the phone verified; nothing was written, nothing rebooted, no data changed.'
    if ($mode -eq 'fastboot') {
        Test-Product
        Write-Host "Active slot: $(Get-CurrentSlot)"
    }
    if ($Wipe) {
        Write-Host "Would: wipe /data (clean install, -Wipe given). Variant $($script:Variant): flash the images, wipe userdata and metadata, boot, copy my_stock.img onto the fresh /data (see README.md), reboot. my_stock.img is NOT pushed before the wipe."
    } elseif ($mode -eq 'fastboot') {
        Write-Host 'Would: flash vendor_X, system_X, boot_X of the active slot, then ask "Wipe user data?" (default No; only the word WIPE wipes). No wipe: boot, copy my_stock.img after the first boot (NoRoot: via the temporary bootstrap system; Magisk: via MagiskSU), reboot. WIPE: wipe userdata, same copy onto the fresh /data.'
    } elseif ($script:SuMode -ne 'none') {
        Write-Host "Would: copy my_stock.img to /data/port (keeping the old one as my_stock-prev.img), reboot to fastboot, flash vendor_X, system_X, boot_X ($(Split-Path -Leaf $BootImg)) of the active slot, then ask `"Wipe user data?`" (default No, only the word WIPE wipes; -NoWipe skips the question), reboot."
    } elseif ($script:Variant -eq 'noroot') {
        Write-Host 'Would: reboot to fastboot, flash vendor_X + the 17k bootstrap system (adb root) + boot_X, then ask "Wipe user data?" (default No), boot, copy my_stock.img to /data/port, reboot to fastboot, flash the final system_X, reboot.'
    } else {
        Write-Host 'Would: reboot to fastboot, flash vendor_X, system_X and the Magisk boot_X, then ask "Wipe user data?" (default No), boot, install Magisk if missing, copy my_stock.img with MagiskSU, reboot.'
    }
    Write-Host 'Without the word WIPE (or -Wipe) nothing is erased.'
    exit 0
}

if ($Wipe) {
    Write-Host 'WIPE requested (-Wipe): /data will be erased after the images are flashed. Back up first.'
} else {
    Write-Host 'Default is an UPGRADE that keeps your data (apps, accounts, settings, files). You will be asked about a wipe after the images are flashed.'
    Write-Host 'Back up first anyway: a failed flash can still leave the phone unbootable.'
}

if ($mode -eq 'adb') {
    # With -Wipe the staged copy would be erased with /data, so it is skipped; the copy happens after the wipe instead.
    if ($script:SuMode -ne 'none' -and -not $Wipe) { Stage-MyStock; $staged = $true }
    Invoke-Adb @('reboot', 'bootloader') | Out-Null
    Write-Host 'Waiting for fastboot ...'
    Wait-ForFastboot
}

# ---------- phase 1: fastboot ----------
Test-Product
$unlocked = Invoke-Fastboot @('getvar', 'unlocked')
if ($unlocked -notmatch 'unlocked:\s*yes') { throw 'Bootloader is not reported unlocked.' }
$fslot = Get-CurrentSlot
if ($slot -and $slot -ne $fslot) { throw "Active slot changed ($slot -> $fslot); stopped before flashing." }
$slot = $fslot
Write-Host "Flashing slot $slot only (the other slot is not touched)."

# NoRoot with nothing staged (and every wipe): the 17k development system (adb root) boots once so my_stock.img can be copied,
# then the final system is flashed. Magisk copies with MagiskSU on the final system instead.
if ($script:Variant -eq 'noroot' -and -not $staged) { $firstSystem = $BootstrapImg } else { $firstSystem = $SystemImg }
Invoke-Fastboot @('flash', "vendor_$slot", $VendorImg) | Out-Null
Invoke-Fastboot @('flash', "system_$slot", $firstSystem) | Out-Null
Invoke-Fastboot @('flash', "boot_$slot", $BootImg) | Out-Null

$script:Wiped = $false
if (Get-WipeAnswer) {
    if ($staged) {
        Write-Host 'The my_stock.img copied to /data/port before the reboot is erased by the wipe; it is copied again onto the fresh /data after the first boot.'
        $staged = $false
        if ($script:Variant -eq 'noroot' -and $firstSystem -ne $BootstrapImg) {
            Write-Host 'Reflashing the temporary bootstrap system so my_stock.img can be copied onto the fresh /data.'
            $firstSystem = $BootstrapImg
            Invoke-Fastboot @('flash', "system_$slot", $BootstrapImg) | Out-Null
        }
    }
    Write-Host 'Wiping userdata and metadata ...'
    Invoke-Fastboot @('-w') | Out-Null
    $script:Wiped = $true
    Write-Host 'After the reboot the phone starts like a new phone. Keep it connected; the installer copies my_stock.img to /data/port once Android (or the bootstrap) is up.'
    if ($script:Variant -eq 'magisk') {
        Write-Host 'Magisk variant: on the fresh phone enable USB debugging (Settings > About phone > tap Build number 7x > Developer options > USB debugging), authorize this computer, and approve the Magisk root request for the ADB shell when it appears.'
    }
} else {
    Write-Host 'Keeping /data (no wipe).'
}
Invoke-Fastboot @('reboot') | Out-Null
$waitBoot = 400; if ($script:Wiped) { $waitBoot = 900 }

if ($script:Variant -eq 'noroot' -and -not $staged) {
    Write-Host 'Waiting for the temporary 17k bootstrap system (adb root) ...'
    if (-not (Wait-ForAdb $waitBoot)) { Stop-Staging 'Timed out waiting for the bootstrap system. The phone runs the bootstrap; rerun this installer.' }
    [void](Wait-ForBoot $waitBoot)
    [void](Test-Adb @('root'))
    Start-Sleep -Seconds 3
    [void](Wait-ForAdb 60)
    Find-Root
    if ($script:SuMode -ne 'adbd') { Stop-Staging 'Bootstrap adb root is unavailable; the final system was not flashed. Rerun this installer.' }
    Stage-MyStock; $staged = $true
    Invoke-Adb @('reboot', 'bootloader') | Out-Null
    try { Wait-ForFastboot } catch { Stop-Staging $_.Exception.Message }
    if ((Get-CurrentSlot) -ne $slot) { throw 'Active slot changed during staging; stopped before the final flash.' }
    Invoke-Fastboot @('flash', "system_$slot", $SystemImg) | Out-Null
    Invoke-Fastboot @('reboot') | Out-Null
}

if (-not $staged) {
    # Magisk variant without staging (fastboot start, no root on the old system, or after a wipe): stage with MagiskSU on the new system, then reboot once more.
    Write-Host 'Unlock the phone and approve this computer for USB debugging if asked. Waiting for Android ...'
    if (-not (Wait-ForAdb $waitBoot)) { Stop-Staging 'Timed out waiting for authorized ADB. Finish my_stock staging by hand (README.md).' }
    if (-not (Wait-ForBoot $waitBoot)) { Stop-Staging 'Android did not report boot completed. Finish my_stock staging by hand (README.md).' }
    if ((Get-AdbOut @('shell', 'pm', 'path', 'com.topjohnwu.magisk')) -notmatch 'package:') { Invoke-Adb @('install', '-r', $MagiskApk) | Out-Null }
    Find-Root
    if ($script:SuMode -ne 'su') { Stop-Staging 'MagiskSU root was not granted. Approve it in Magisk, then rerun this installer.' }
    Stage-MyStock; $staged = $true
    Invoke-Adb @('reboot') | Out-Null
} elseif ($script:Variant -eq 'magisk') {
    Write-Host 'Waiting for Android to install the Magisk app if it is missing (unlock the phone and approve USB debugging if asked) ...'
    if ((Wait-ForAdb 400) -and (Wait-ForBoot 400)) {
        if ((Get-AdbOut @('shell', 'pm', 'path', 'com.topjohnwu.magisk')) -notmatch 'package:') {
            try { Invoke-Adb @('install', '-r', $MagiskApk) | Out-Null } catch { Write-Host 'Could not install Magisk; install images\Magisk-v31.0.apk by hand.' }
        }
    } else { Write-Host 'ADB did not come up; if the Magisk app is missing, install images\Magisk-v31.0.apk by hand.' }
}

Invoke-NetGuard
Invoke-HealthDenyList
if ($script:Wiped) {
    Write-Host '17k-r2 CLEAN INSTALL flashed; /data was wiped and my_stock.img copied. The first boot can take several minutes; finish the setup wizard.'
} else {
    Write-Host '17k-r2 upgrade flashed; user data kept. If the phone is still starting, the first boot can take a few minutes.'
}
Write-Host 'After it has booted, once (see README.md):'
Write-Host '  adb shell pm uninstall-system-updates com.oplus.camera   # only if pm path com.oplus.camera shows /data/app'
Write-Host '  seed the wallpaper keeper as root: echo com.heytap.colorfulengine/.wallpaper.service.ColorfulWallpaperService > /data/port/wp/wallpaper-component'
Write-Host '  do NOT run tools/live/camera-donor17/restore-live.sh any more.'
