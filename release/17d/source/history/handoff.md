# OnePlus 7 Pro ROM<LOCAL_WSL_PATH> handoff

Updated: 2026-10-14, Asia/Shanghai.

## Current state and scope

The connected device is a **OnePlus 7 Pro GM1910**, codename `guacamole` / Android device property `OnePlus7Pro`. The user sometimes calls it a OnePlus 7; do not select `guacamoleb` packages on that basis.

User originally wanted a useful home-LAN role, selected a media center, prefers VLC, and wants **phone storage -> TV**. Their TV already has VLC. The conversation then explored Google Play installation, Play Integrity, bootloader relocking, KernelSU, and newer ColorOS ports. User specifically requested testing **ColorOS 17**, not an AOSP Android 17 GSI.

Latest live verification before writing this document:

- ADB serial: `<DEVICE_SERIAL>`; Android is running; `sys.boot_completed=1`.
- Firmware: `GM1910_11_H.40`, ColorOS 12.1 / Android 12, SDK 31.
- Fingerprint: `OnePlus/OnePlus7Pro_CH/OnePlus7Pro:12/SKQ1.211113.001/P.202303230244:user/release-keys`.
- Security patch: `2022-12-05`.
- Kernel previously verified: `4.14.180-perf+`, built March 23, 2023.
- Bootloader remains **unlocked** (`ro.boot.flash.locked=0`). Earlier fastboot checks: `unlocked=yes`, verity enabled, critical partitions locked, active slot `a`.
- Verified Boot previously reported `orange`; SELinux enforcing.
- Snapdragon SM8150 platform, approximately 8 GB RAM and 202 GB free storage at initial inspection.
- Wi-Fi IPv4: `<LOCAL_IP>/24`; this address may change.
- **No root has been achieved. No boot/system/vendor/DTBO/vbmeta partition was flashed. No wipe or repartition was performed.**

Authorization in this conversation covered ADB access, app installation, root investigation/attempt, bootloader reboots, and evaluating a ColorOS 17 test. It does not establish approval to delete personal data or repartition storage. Prepare a concrete image, rollback plan, and description of consequences before asking for any required destructive-action approval. Do not infer permission to publish or message ROM maintainers.

## Completed app/media work

Installed and verified:

- VLC `3.7.1`, package `org.videolan.vlc`.
- Primitive FTPd `8.2`, package `org.primftpd`.
- KernelSU Manager `v3.3.1`, package `me.weishu.kernelsu`, versionCode `32680`.

Created `/sdcard/Movies` for media. The user had not selected a media folder or copied a collection yet. Primitive FTPd has **not** been configured or tested against the TV. No FTP server credentials, shared-folder permissions, or running-service state have been established. Proposed setup: share a dedicated media directory on the phone and have VLC on the TV browse/play it over LAN. Root is unnecessary for this.

Local APKs:

- `<LOCAL_WINDOWS_PATH>`
- `<LOCAL_WINDOWS_PATH>`
- `<LOCAL_WINDOWS_PATH>`

Their downloaded hashes were checked against VideoLAN/GitHub release metadata before installation.

## Google Play: unfinished

The phone contains enabled `com.google.android.gms` and `com.google.android.gsf`. However, `com.android.vending` is a **headless updater stub**, not the full Store:

- Stub path: `/my_bigball/priv-app/GooglePlayServicesUpdater/GooglePlayServicesUpdater.apk`.
- Stub version: `22.7.52-23 [2] [PR] 371265832`.
- No launcher activity; launching the Store failed to resolve.
- Play services version observed: `22.21.16 (190400-454906765)`.
- Services Framework version: `12-7567768`.

A full Google-signed Play Store update remains to be installed. APKMirror/APKPure automated downloads were blocked by browser verification; Uptodown returned 404 in the local browser/HTTP environment. No full Store APK was installed, no Google login was performed, and no Play Integrity verdict was measured. Do not equate an installed manager, stock-looking properties, or Play Protect certification with a verified Play Integrity result.

## Bootloader relock: failed without changing state

User manually ran:

```powershell
fastboot oem lock
```

Response:

```text
FAILED (remote: 'Device cannot be unlocked for technical reason.')
fastboot: error: Command failed
```

Subsequent read-only fastboot checks confirmed the bootloader was still unlocked. A OnePlus 7 Pro issue report documents the same error on lock and unlock operations after Android 12 updates. This supports a firmware limitation as the likely explanation; it is not a proven diagnosis or a verified fix for this phone.

Reference: https://gitlab.com/LineageOS/issues/android/-/issues/6017

Do not try miscellaneous lock/unlock or critical-partition commands. Returning to Android 11 is a reported workaround for related unlock failures, but no GM1910 rollback package or downgrade procedure has been validated here. Relocking wipes data and requires appropriate stock signed firmware. Installing the KernelSU Manager APK alone did not alter the boot image. The Developer-options OEM-unlocking switch is permission to unlock, not the actual relock action.

## Exact stock firmware and extracted recovery images

User-supplied source ZIP:

`<LOCAL_WINDOWS_PATH>`

Size: `4,634,620,018` bytes.

Inspected OTA metadata matches the running device:

- `ota-id=GM1910_11.H.40_4400_202303231745`
- `version_name=GM1910_11_H.40`
- `pre-device=OnePlus7Pro`
- `product_name=OnePlus7Pro_CH`
- Exact matching post-build fingerprint and incremental `P.202303230244`.
- Android 12, ColorOS V12.1, security patch `2022-12-05`.

Used checksum-verified `ssut/payload-dumper-go` 2.1.0 to extract only `boot,dtbo,vbmeta`. The extractor completed successfully with its operation/final-image verification enabled. This establishes payload consistency, not an independent verification of the entire OTA package's vendor signature or provenance.

Extractor:

`<LOCAL_WINDOWS_PATH>`

Recovery-image directory:

`<LOCAL_WINDOWS_PATH>`

| File | Bytes | SHA-256 |
|---|---:|---|
| boot.img | 100663296 | 991CF738F5A6DC874C6261FA073C89182E61935A9493DC27347699C4D0A68792 |
| dtbo.img | 25165824 | 2F6015B1F9FA9DAFD5E7FBC61A297559741C6D33BB42CB2CCD7E6DBE0526C90C |
| vbmeta.img | 8192 | 2FC73B21A4BADEC67F7D8A603B86AEF4A789630D270C0D8C1A3F84C39281E693 |

`system`, `vendor`, and other full recovery partitions have NOT yet been extracted. The original full ZIP remains available. No personal-data backup, persist/calibration backup, or tested end-to-end restoration procedure has been completed. These extracted images are not backups read from the phone's live partitions.

Stock boot uses Android boot-header version 2 and 4096-byte pages. Kernel size observed: `40142864` bytes; ramdisk size: `21057538` bytes.

## KernelSU compatibility investigation

Current official Manager displays **Unsupported**, with the explanation that current KernelSU supports GKI kernels. Official KernelSU dropped official non-GKI support starting with v1.0; archived integration documentation identifies v0.9.5 as the last officially supported non-GKI version.

Sources:

- https://kernelsu.org/guide/installation.html
- https://kernelsu.org/guide/how-to-integrate-for-non-gki.html

Jailbreak mode is a real late-load feature, not a universal root switch. No compatible jailbreak prerequisite or exploit has been verified for the stock enforcing H.40/4.14 kernel. No SELinux change or exploit was attempted.

Community candidate downloaded and inspected:

`<LOCAL_WINDOWS_PATH>`

SHA-256: `87F5CB0EE7B25B050693938DCB239B131D89F795C98ABC23A64DA520D8C69B4B`.

Release: https://github.com/snowwolf725/android_kernel_oneplus_sm8150/releases/tag/11872

Maintainer targets OnePlus 7/7 Pro/7T/7T Pro and **OOS12**, not explicitly ColorOS H.40. The package contains a raw kernel `Image` and AnyKernel3 installer, not a ready-to-boot boot.img. Installer checks device name, reads the active boot image, repacks/flashes it, and sets `patch_vbmeta_flag=auto`. Do not run it as a harmless inspection operation.

Build source branch: `oneplus/OOS_SM8150_12.0`; workflow relates to OnePlus `sm8150_s_12.1_op7pro` source. Candidate version:

`4.14.180_SnowWolf725-perf+`, built May 31, 2024.

Compared embedded candidate IKCONFIG with `/proc/config.gz` from the phone. Found **45 differences**, including KPROBES/debug options, OPPO-to-OPLUS vendor option changes, and DNS-hook differences. This is compatibility evidence to investigate, not proof of bootability or proof of incompatibility.

Audit files:

- `<LOCAL_WINDOWS_PATH>`
- `<LOCAL_WINDOWS_PATH>`
- `<LOCAL_WINDOWS_PATH>`
- `<LOCAL_WINDOWS_PATH>`
- `<LOCAL_WINDOWS_PATH>`

No candidate boot image was repacked, temporarily booted, or flashed. Current Manager v3.3.1 may not be the manager appropriate for this older kernel build; verify required manager compatibility before any trial.

## Treble and partition findings

Live properties:

- `ro.treble.enabled=true`
- `ro.vndk.version=30`
- `ro.vendor.build.version.sdk=30`
- `ro.product.first_api_level=28`
- `ro.build.ab_update=true`
- ARM64 with 32-bit ARM compatibility.
- Vendor VINTF manifest `target-level=5`, kernel target-level 5.
- No `/dev/block/bootdevice/by-name/super`.
- `system_a -> /dev/block/sda13`; `system_b -> /dev/block/sda14`.
- No `android.software.dynamic_system` feature was returned; `service check gsiservice` reported service not found. A working DSU path is **not** established.
- Reading `/proc/partitions` and relevant sysfs block sizes through unrooted ADB was denied. Read sizes through fastboot instead.

Fastboot independently reported:

```text
partition-size:system_a: 0xD9000000
partition-size:system_b: 0xD9000000
```

Each system partition is **3,640,655,872 bytes = 3.390625 GiB**. This is actual partition capacity; the earlier `df` output of approximately 3.2 GB describes the mounted filesystem.

This is a static A/B layout. Do not apply generic dynamic-partition instructions such as deleting product logical partitions or resizing super. Treble does not make another model's stock ColorOS firmware interchangeable.

## ColorOS 14/16/17 findings

### ColorOS 14

Primary maintainer evidence exists for an H.40-based ColorOS 14 port on the OnePlus 7 Pro: an unofficial ColorOS-focused TWRP project reports physical owner-data decryption testing. This does **not** establish complete ROM functionality, a vetted release download, or a verified installation procedure.

Source: https://github.com/KAI-Miru/android_device_oneplus_guacamole

The recovery project preserves stock H.40 boot components. Do not confuse this recovery repository with the ROM release itself. No recovery image from it was downloaded or tested here.

### ColorOS 16

No device-specific GM1910/guacamole ColorOS 16 package was verified. Known projects/releases found target the OnePlus 8/9 families, including an 8T release, and must not be flashed onto this phone.

- https://github.com/toraidl/coloros_port
- https://optool.daxiaamu.com/op8tcoloros16

### ColorOS 17: direct test blocked by measured image size

Found a generic experimental Axis GSI, not a validated guacamole-specific port:

https://sourceforge.net/projects/axisgsiupdates/files/coloros/ColorOS-17-PLG110-1789230151842-18092026-AxisGSI.zip/download

Project lists archive SHA-256:

`13919439e823d0df07cd644c15bf875d537fe2d2d139d62dbba19f29d1345552`

**The full archive was NOT downloaded, and that full-archive hash was NOT independently checked.** Only HTTP Range samples of its head and tail were retrieved to inspect ZIP metadata and the decompressed filesystem superblock.

Verified sample-derived findings:

- Archive Content-Length: `3435589433` bytes.
- ZIP contains one `system.img`, deflated, using ZIP64 length metadata.
- Expanded `system.img`: **6851592192 bytes = 6.38104248046875 GiB**.
- Format: **raw ext4**, not Android sparse.
- Ext4 block size: 4096 bytes; block count: 1672752.
- Allocated filesystem space from the superblock: **6637981696 bytes = 6.182102203369141 GiB**.
- Phone system-partition capacity: **3.390625 GiB**.
- Therefore it cannot be directly flashed; removing free space alone cannot make it fit.

Audit directory:

`<LOCAL_WINDOWS_PATH>`

Files include `image-preflight.json`, `zip-entries.json`, `zip-head.bin`, `zip-tail.bin`, and `zip-tail-headers.txt`. Image contents, security, VINTF compatibility, and bootability were not audited beyond the sampled metadata/superblock. Do not present the measured allocated size as a guaranteed minimum after rebuilding/removing content.

The phone was rebooted to fastboot for size checks, then returned to Android. Verified `sys.boot_completed=1` and H.40 afterward. No direct install was attempted because the size preflight failed.

## Suggested next actions

Choose the user's current priority before taking dependent firmware actions:

1. **Working home media center:** configure Primitive FTPd with a dedicated media folder, then test listing, playback, seeking, and screen-off availability from VLC on the TV. This needs no ROM replacement/root.
2. **Learn ROM work:** establish complete recovery/data backups, then select a correctly sized ARM64 GSI and verify old-vendor compatibility. A nearby Android 12/12L baseline followed by Android 14 was suggested; the user preferred investigating ColorOS 17 directly.
3. **ColorOS 14:** locate the actual guacamole/H.40 port maintainer release and audit bugs, file hashes, required firmware, installation, and rollback. Existing recovery evidence is only a lead.
4. **ColorOS 17:** it would require substantial image rebuilding/slimming or a separately designed storage-layout change, plus old-vendor adaptation. Do not repartition as a quick workaround. No viable fitting package is prepared.
5. **KernelSU:** determine whether the OOS12 community kernel can safely be repacked with this exact H.40 boot layout and whether vendor/kernel interfaces remain compatible. Prefer an established compatible build or controlled temporary-boot test with recovery prepared. Do not treat the installed Manager as achieved root.
6. **Google Play:** obtain a compatible full Google-signed Store installer, verify its signature through an update over the stock package, launch it, and let the user perform Google authentication. Still unfinished.

## Operational notes

- Working shell is PowerShell. Use literal here-strings for Python/JSON/script content and literal filesystem paths.
- ADB is installed through WinGet platform-tools. Early sandboxed ADB checks falsely showed no device; elevated tool execution successfully reached it. Recheck actual connectivity rather than assuming the phone disconnected.
- `fastboot` may wait indefinitely without a device; check `fastboot devices` before issuing queries.
- No partition commands should be chosen solely from the model label or a generic GSI guide. Keep the GM1910/H.40/static-A/B specifics explicit.
- No credentials, tokens, or Google-account information are stored in this handoff.

