# ColorOS 17 → OnePlus 7 Pro (GM1910 / guacamole) port log

**Current camera work:** [camera-handoff-2026-10-16.md](camera-handoff-2026-10-16.md), [camera-facts-2026-10-16.md](camera-facts-2026-10-16.md), and [camera-port-2026-10-16.md](camera-port-2026-10-16.md). Earlier sections are historical; use [handoff-2026-10-16.md](handoff-2026-10-16.md) for build 13 state.
Background and earlier device state: [handoff.md](handoff.md). Facts below were measured on 2026-10-14; the
"Current device state" section right below is from mid-session and superseded by the handoff.

## Current device state (end of 2026-10-14 session)

- **Active slot: A, stock H.40, fully working** (boot completed; `/mnt/vendor/my_reserve` and my_stock/heytap/
  bigball/preload loop-mounted; USB debugging on, this PC authorized). `persist.sys.disable_rescue=true` is still
  set from the recovery aid (harmless; clear later as root).
- **Slot B:** stock H.40 boot + vendor, `vbmeta_b` flashed with `--disable-verity`, port test build 1 system.
  Bootloops (see "Test build 1 result"). Slot B firmware otherwise equals stock H.40.
- Bootloader unlocked; nothing outside `boot_b`, `vendor_b`, `vbmeta_b`, `system_b`, userdata, metadata was written.
- Magisk app 30.7 was installed on the old (wiped) data; reinstall when root is needed again.

## Slot A recovery incident (what fastboot wipes do to stock)

After `fastboot -w` (formatted F2FS) and `fastboot format:ext4 userdata`, stock slot A also bootlooped
(boot animation shown, reboot every ~45 s; crash buffer showed `init` subprocesses aborting with SIGABRT).
Two things were missing: `/data/reserve/reserve.img` (fastboot wipes delete it) and a userdata filesystem made
the way stock expects. Fix that worked:

1. Temp-booted `tools/magisk/boot-H40-magisk-adbfix.img` (built by `tools/make-adbfix-boot.sh`; Magisk boot +
   overlay.d rc: adb on, this PC's key authorized, rescue disabled, and an init hook that runs
   `/data/local/tmp/run.sh` as root in `u:r:magisk:s0` when `debug.adbfix.run=1` — needed because the Magisk
   app was wiped, so `su` has no grant UI). `tools/restore-reserve.ps1` restored `reserve.img` (hash verified,
   restorecon → `apk_data_file`).
2. Still looped; the user then ran **Wipe data in stock ColorOS recovery** → booted fine, and that wipe
   **kept `/data/reserve`** (by design).

Lessons: **never use `fastboot -w` / `fastboot format` for slot A**; wipe from stock recovery instead. If
`/data/reserve` is lost, restore it first (step 1), then wipe in recovery. `tools/bootimg_v2.py` repacks a v2 boot
ramdisk (dtb_size is at header offset 1648); verified by section-exact round trip.

## Rollback

- Slot A: `fastboot --set-active=a`, then wipe data **from stock recovery** (see incident above).
- Full stock content: as root, copy `StockRom/H40-images/reserve.img` to `/data/reserve/reserve.img`
  (byte-identical to what stock had; SHA-256 `c439d98f…45176`).
- Any partition: `Backup-2026-10-14/partitions/<name>.img` (113 images, `SHA256SUMS`), or stock images in
  `StockRom/H40-images/` (24 images from the exact H.40 OTA).

## Stock H.40 layout

| Image | Size | FS | Notes |
|---|---:|---|---|
| system | 3.39 GiB (0xD9000000, partition-sized) | ext4, 40,035 free 4K blocks | system-as-root; holds `/system/euclid/*.img` |
| vendor | 1.0 GiB | ext4, ~179 MiB free | VNDK 30; `/etc/fstab.qcom` drives the `my_*` mounts below |
| odm | 80 MB | ext4 | |
| reserve | 4.27 GiB | ext4, ~13 MiB free | **a file on userdata, `/data/reserve/reserve.img`**, not a partition |

How OnePlus fit ColorOS 12.1 onto a 3.39 GiB system partition (vendor `fstab.qcom`, confirmed live):

- `/system/euclid/` (in system): my_product 557 MiB, odm 333 MiB, my_region, my_carrier, my_company, my_engineering
- `/vendor/euclid/`: my_manifest
- `/data/reserve/reserve.img` → loop-mounted `latemount` at `/mnt/vendor/my_reserve`, containing
  my_stock 2.12 GiB, my_heytap 1.28 GiB, my_bigball 868 MiB, my_preload
- Each `my_*` image is loop-mounted ro and bind-mounted over `/my_*` (tmpfs placeholders until then).
- Total stock ColorOS footprint ≈ 8 GB.

## Kernel (4.14.180-perf+, H.40)

- `CONFIG_EROFS_FS=y`, `EROFS_FS_ZIP=y` (LZ4), `CLUSTER_PAGE_LIMIT=1` (old OPLUS backport). **Verified** to read
  images from `mkfs.erofs 1.7.1 -zlz4hc,12 -E legacy-compress -b4096` (see test below).
- BPF syscall/JIT/cgroup-bpf present; no userfaultfd (ART falls back).
- Cmdline carries OPLUS "Phoenix" boot watchdog (`phx_rus_conf.kernel_time=240 android_time=250
  recovery_method=2`): reboots when Android does not finish booting and drops to recovery after repeated failures.
- LineageOS ships Android 17 (24.0) for guacamole on this kernel family, so 4.14 is not inherently fatal.

## Boot chain (legacy system-as-root) — the current blocker

- Live `/proc/cmdline`: `skip_initramfs ... root=/dev/dm-0 dm="1 vroot ... verity ..."`. The kernel mounts system
  as `/` itself and runs `/init` from it; the boot ramdisk is **not used** for normal boot.
- First-stage vendor/odm mounts come from the device-tree fstab (`/proc/device-tree/firmware/android/fstab`:
  vendor + odm only, ext4, `avb` on vendor). The DT fstab takes precedence over ramdisk fstabs in first-stage init.
- Top-level vbmeta (`tools/vbmeta_dump.py`) chains `system` (rollback loc 2) and `vendor` (loc 5), hashes boot
  and dtbo, holds odm's hashtree. The system partition's own AVB footer carries two kernel cmdline descriptors:
  flags=1 `dm=` verity root (hashtree enabled), flags=2 `root=PARTUUID=$(ANDROID_SYSTEM_PARTUUID)` (hashtree
  disabled). `avbtool add_hashtree_footer --setup_as_rootfs_from_kernel` reproduces both.
- **Android 12 init (stock) still has the legacy-SAR path** (`/dev/root`, "First stage mount skipped …" strings).
  **The Android 17 GSI init has none of it**; it only knows two-stage init (`/first_stage_ramdisk/fstab.`).
  GSI `/system/bin/init` is dynamically linked (interpreter `/system/bin/bootstrap/linker64`), so it cannot be
  dropped into a ramdisk as first-stage init.
- Stock H.40 boot ramdisk = recovery-as-boot ramdisk: `/init -> /system/bin/init` (Android 12, dynamically linked
  against the ramdisk's own linker), `/system/bin/recovery` present, `first_stage_ramdisk/fstab.qcom` present,
  root `fstab.qcom` has `/` ext4. Its init contains `/first_stage_ramdisk`, `android,fstab`, `first_stage_mount`,
  `selinux_setup`; the literal `force_normal_boot` string was **not** found (to investigate: how it decides
  normal boot vs recovery when `/system/bin/recovery` exists).

## Device backup

`Backup-2026-10-14/partitions/`: 113 raw partitions dumped as root (Magisk 30.7 via temporary `fastboot boot`
of `tools/magisk/boot-H40-magisk30.7.img`, nothing flashed), hash-checked phone-side and PC-side (`SHA256SUMS`).
Includes all device-unique data: persist, modemst1/2, fsg, fsc, mdm1m9kefs*, oem_*nvbk, param, devinfo, op1,
op2, keystore, secdata. Excluded at the user's request: userdata (no personal-data backup) and vendor_a/b.
`boot_a` was byte-identical to stock H.40 `boot.img` (Magisk changed nothing).

## ColorOS 17 Axis GSI inventory

`ColorOS17-GSI/…AxisGSI.zip`: SHA-256 matches the project's published `13919439…1345552`.

- Android 17, SDK 37. Fingerprint `alps/sys_mssi_64_cn_armv82/...` → MediaTek system-image donor, ARMv8.2
  target (SM8150 OK). Contains phh/TrebleDroid files (`/system/phh`). No adb keys shipped
  (`/adb_keys -> /product/etc/security/adb_keys`, target absent).
- ext4, 6.2 GiB used; ColorOS `my_*` trees at the image root, same layout as stock H.40.
- By tree: system_ext ~1.93 GiB, my_stock ~1.54 GiB, system ~1.50 GiB, my_product ~1.10 GiB, product ~0.15 GiB.
  Listing: `ColorOS17-GSI/system-filelist.txt`.
- my_stock = apps only (Contacts, InCallUI, Mms, OppoGallery2, Screenshot, Wallpapers, OHome, SecurityGuard, …).

## Fitting: solved

- `mkfs.erofs` 1.7.1 `-zlz4hc,12 -E legacy-compress -b4096 --mount-point=/`: full GSI 4,488,155,136 B (no fit);
  **without my_stock contents 3,396,952,064 B — fits the 3,640,655,872 B system partition.**
- Verified on the phone: loop-mounted that image under stock H.40 (rooted; needed
  `magiskpolicy --live "allow kernel shell_data_file file { read open getattr }"`), all 10,222 file SHA-256s
  identical to the source; SELinux labels preserved.
- my_stock goes to `/data/reserve/reserve.img` (ext4 holding `/reserve/my_stock.img`, 1.84 GB), the slot the
  stock vendor fstab already mounts `latemount`.

## Test build 1 (`tools/build-port.sh` → `out/`, flashed with `tools/flash-slot-b.ps1`)

- `out/system.img` (SHA-256 `f4a30a6c…a136`): EROFS of the GSI, my_stock emptied (mount point kept), AVB hashtree
  footer signed with self-made `tools/avb/port_key.pem`. Test-only change: adb on at boot
  (`persist.sys.usb.config=adb`), authentication kept, only this PC's key pre-authorized in
  `/product/etc/security/adb_keys` (label `adb_keys_file`). (Disabling adb auth was refused by the permission
  classifier; key pre-authorization is the replacement.) Remove for daily use.
- `out/reserve.img` (SHA-256 `08ca409a…a2d1`): not yet installed.

### Result: bootloop

- OnePlus logo only, never the ColorOS boot animation, ~15 s per cycle; no adb at any point. After several
  cycles it entered recovery on its own (Phoenix watchdog / init reboot-to-recovery).
- Separate issue found: `fastboot -w` formatted userdata as **F2FS** while the fstab expects ext4 (no
  `formattable` flag) → fixed with `fastboot format:ext4 userdata`. Bootloop persisted after that.
- **Diagnosis:** Android 17 init cannot run as the legacy-SAR kernel-launched `/init`; it dies in first stage
  before adbd. Evidence:
  - static: A12 init has the `/dev/root` legacy-SAR path, A17 init does not (see Boot chain).
  - bootloader log (`logs/oplogs/recovery/last_uboot_log`, from OPLUS `oplusreserve/recovery/`): on slot B
    `vbmeta_b ... HASH_MISMATCH` (expected after `--disable-verity`, tolerated when unlocked), then ABL Phoenix
    `kernel err 3 times, will go to recovery` — the failures were counted as **kernel-level** (consistent with init
    dying → "Attempted to kill init" panic), not Android-level.
  - The failing boots' own kmsg was not preserved: `/sys/fs/pstore` was empty after a Vol Up+Power reset, and
    `oplusreserve/recovery/last_kmsg*` only hold recovery sessions.
- Useful log sources on this phone (root): `/mnt/vendor/oplusreserve/recovery/last_uboot_log*` (ABL + kernel log
  of the boot that entered recovery), `last_kmsg*`, `boot_log/`, `media/log/criticalLog/`. Copied to `logs/oplogs/`.
- Recovery-mode selection in the H.40 ramdisk init: every recovery kmsg shows `init first stage started!` then
  `First stage mount skipped (recovery mode)` — recovery mode is chosen because `/system/bin/recovery` exists in
  the ramdisk. A 2SI boot ramdisk for slot B must therefore either drop the recovery binary or pass
  `androidboot.force_normal_boot=1`.

## Reference: how LineageOS 24.0 (Android 17) boots this exact phone

Read from `LineageOS/android_device_oneplus_{sm8150-common,guacamole}` and `android_kernel_oneplus_sm8150`, branch
`lineage-24.0` (copies in the session scratchpad; re-fetch if needed):

| Topic | LineageOS | Stock H.40 |
|---|---|---|
| Boot model | `BOARD_USES_RECOVERY_AS_BOOT := true`, no system-root image → **2SI** from boot ramdisk | legacy SAR: kernel mounts system as `/` |
| Bootloader `skip_initramfs` | kernel `CONFIG_INITRAMFS_IGNORE_SKIP_FLAG=y` (`init/initramfs.c`): ramdisk always unpacked; `/proc/cmdline` shows `want_initramf` | honoured; ramdisk only for recovery |
| Normal vs recovery | kernel `CONFIG_PROC_CMDLINE_APPEND_ANDROID_FORCE_NORMAL_BOOT=y` (`fs/proc/cmdline.c`): appends `androidboot.force_normal_boot=1` when the bootloader sent `skip_initramfs` (normal boot only) | ramdisk init picks recovery because `/system/bin/recovery` exists |
| Both kernel options live in | `arch/arm64/configs/vendor/oplus_non_dynamic.config` | — |
| DT fstab | **deleted** in `arch/arm64/boot/dts/18821/sm8150.dtsi` (only the `android,vbmeta` node remains) | `firmware/android/fstab` with vendor + odm, which overrides ramdisk fstabs |
| First-stage fstab | `system /system ext4 ... wait,slotselect,avb,first_stage_mount`, same for vendor | none (`first_stage_ramdisk/fstab.qcom` is a vendor-fstab copy, no `first_stage_mount`) |
| vbmeta | `--set_hashtree_disabled_flag --set_verification_disabled_flag` | verity on |
| Ramdisk compression | LZ4 | gzip |
| Kernel | 4.14 with Lineage backports, EROFS on | 4.14.180 H.40 |

Not used from LineageOS: their kernel (its modules/vermagic would not match stock vendor's `.ko` files).

## Android 17 on a 4.14 kernel: the eBPF wall (researched 2026-10-14)

ColorOS 17 GSI = Android 17 (`ro.build.version.release=17`, SDK 37). Lessons from LineageOS 24 / AOSP sources:

- **AOSP `NetBpfLoad` hard-gates kernel versions** (strings present in the GSI's `com.android.tethering` APEX
  `bin/netbpfload`): `Android U requires kernel 4.14`, `Android V requires kernel 4.19`, `Android 25Q2 requires kernel
  5.4`, `Android 25Q4 requires kernel 5.10`, plus `Android V+ only supports LTS kernels`. The APEX rc declares
  `reboot_on_failure reboot,netbpfload-failed` → **with the stock 4.14.180 kernel, Android 17 reboots** even after
  the boot chain is fixed.
- The GSI has **no workaround**: no phh/TrebleDroid BPF knob (`persist.sys.phh.*` has none), and its
  `netbpfload` does not contain `kver_override`.
- **How LineageOS passes it on this phone:** (1) kernel `4.14.357-openela` with eBPF features backported
  "1:1" to 5.10 level (LineageOS requires this for 23.2/24.0); (2) a Connectivity patch
  "bpf: Allow overriding kernel version" reading **`ro.bpf.kver_override`** in `KernelUtils.h`; (3)
  `sm8150-common/product.prop`: `ro.bpf.kver_override=5.10.239` ("matches android12-5.10", tested with
  `netd_integration_test`). Also: "Enable UFFD GC — kernel has support for it now" (stock lacks userfaultfd),
  and `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS` disabled "until we fix kernel".
- So both halves are required: a kernel with the backports **and** a loader that can be told about them.
  Spoofing the version alone would make the loader try 5.x programs the stock kernel cannot run.

Consequence for the plan: the stock-kernel design below can at best get past first-stage init; expect the next
failure to be `reboot,netbpfload-failed`. A working Android 17 needs the LineageOS-style kernel. Options:

1. **ColorOS 17 system on a LineageOS 24 base** (their boot image/kernel, dtbo, vendor — already 2SI, eBPF-ready,
   Android-17 VINTF) + `ro.bpf.kver_override` + swap the GSI's `com.android.tethering` APEX for LineageOS's (which
   honours the override). This is the usual way OEM systems are ported to EOL devices: reuse a maintained custom-ROM
   base for kernel/vendor, port only the system side.
2. Keep stock H.40 kernel/vendor and also replace the kernel with LineageOS's — but stock vendor kernel modules
   (e.g. WLAN `.ko`) would not match the new kernel; effectively converges on option 1.
3. Build 2 as designed below purely as a learning step to validate the 2SI chain, expecting the eBPF reboot.

## Phase A: official LineageOS 24 on slot B — WORKS (2026-10-14)

Chosen route: **ColorOS 17 system on a LineageOS 24 base** (option 1 above). Phase A validates the base alone.

- Build: `LineageOS24/lineage-24.0-20261011-nightly-guacamole-signed.zip` + `boot/dtbo/vbmeta.img` from
  download.lineageos.org; all SHA-256s match the API (`LineageOS24/SHA256SUMS`). Payload extracted to `LineageOS24/payload/`.
- Payload firmware is from GM1911 **H.41** (`proprietary-firmware.txt`); byte-identical to our H.40 images except
  **abl**, which was deliberately not flashed (slot B kept H.40 abl — avoids any anti-rollback risk). Works with it.
- Not the wiki's sideload: an A/B sideload always writes the *other* slot and would have destroyed stock slot A.
  Instead `tools/flash-lineage-slot-b.ps1` flashed boot/dtbo/vbmeta/system/vendor to `_b`, set B active, then
  **Format data in Lineage Recovery** (no fastboot wipe).
- Result: boots to home screen; Wi-Fi, camera, fingerprint OK (no SIM to test radio). Verified over adb:
  kernel `4.14.357-openela-perf`; `/proc/cmdline` has `want_initramfs` + `androidboot.force_normal_boot=1`;
  `ro.bpf.kver_override=5.10.239`; Android 17 `CP2A.260605.016` (same base build as the ColorOS GSI);
  `ro.board.first_api_level=28`; system = `sda14` (system_b) ext4, vendor = `sde44` ext4; verifiedbootstate orange.
- Side effect: Format data removed stock's `/data/reserve/reserve.img`. To go back to slot A: restore it with the
  adbfix procedure, then wipe in stock recovery (see Slot A incident).

## Phase B build 1: ColorOS 17 system on the LineageOS base (`tools/build-port-b.sh` → `out-b/`)

- `system.img` (3,390,140,416 B data, partition-sized with AVB hashtree footer): GSI tree with my_stock emptied,
  adb on + this PC's key, `ro.bpf.kver_override=5.10.239` in `/system/build.prop` (LineageOS sets it in its own
  system's product props, so it disappears with their system), ColorOS `com.android.tethering.apex` replaced by
  LineageOS's `com.android.tethering.capex` (only LineageOS's NetBpfLoad reads the override). Neither policy gives
  `ro.bpf.kver_override` its own property context.
- `boot.img`: LineageOS boot; only the LZ4-legacy ramdisk changed — erofs `/system` line inserted before the ext4 one in
  `first_stage_ramdisk/system/etc/fstab.qcom` and `system/etc/recovery.fstab`. Kernel/dtb/recovery_dtbo/header verified
  identical; ramdisk file list identical; Lineage Recovery kept.
- `vendor.img`: LineageOS vendor with the same erofs line in `/etc/fstab.qcom` (edited in place; label
  `vendor_configs_file` kept; fsck clean). fs_mgr tries same-mount-point entries in order, so ext4 LineageOS
  system still boots with these boot/vendor images.
- Flash: `tools/flash-port-b.ps1` (boot_b, vendor_b, system_b), then Format data in Lineage Recovery.

### Build 1 result: init fatal → reboot to bootloader (SELinux)

- Symptom: after Format data, boot went straight back to fastboot = init's fatal-error reboot target.
- LineageOS kernel has no pstore; Lineage Recovery (Advanced → Enable ADB) gives a root shell. From it: the LineageOS
  kernel mounts our EROFS `system_b` fine → not a first-stage mount problem.
- Reproduced init's split-policy compile on the PC (`tools/sepolicy-compile-test.sh`, secilc **3.11 built from
  SELinuxProject source** — Ubuntu's secilc rejects Android's `nlmsg` allowx). Control LineageOS system+vendor: OK.
  ColorOS system + LineageOS vendor: `Re-declaration of type hal_oplus_sensor_aidl`.
- `tools/sepolicy-conflicts.py` found exactly 3 clashes: `hal_oplus_sensor_aidl`, `hal_oplus_touch_aidl` (ColorOS
  system_ext: attribute; LineageOS vendor: type = its HAL domains) and `vendor_camera_update_data_file` (type on both).
- Fix `tools/patch-vendor-sepolicy.py` (now part of build-port-b.sh): rename LineageOS's two types to `los_…`, drop the
  vendor's duplicate type declaration. Result compiles (1,944,281 B), 0 conflicts. Only `vendor_sepolicy.cil` changed.
  (A plain LineageOS system would still use the untouched precompiled policy, whose hash matches it.)
- Lesson: before flashing an OEM system onto another vendor, run the split-policy compile on the PC — it is the
  first thing second-stage init does.

### Build 1, second failure: still init-fatal → fastboot (~18 s cycle)

- With the SELinux fix, still back in fastboot 18 s after `fastboot reboot`. Ran the **ColorOS** `secilc` on the phone
  (Lineage Recovery root shell, chroot into the real `system_b`/`vendor_b`, `tools/ondevice-sepolicy-test.sh`): clean.
  Also compiles with each `plat_sepolicy_genfs_{202504,202604,202704}.cil` → SELinux is no longer the cause.
- Found and fixed a second fatal class: **property_contexts prefixes defined on both sides with different contexts**
  (`tools/propctx-conflicts.py`): `persist.vendor.bluetooth.` (ColorOS: MediaTek `system_mtk_bluetooth_prop`),
  `persist.vendor.side.fp.near.feature.support`, `vendor.oplus.video.dump.output`. Removed from ColorOS
  `system_ext_property_contexts` (build-port-b.sh). Other merged contexts (service, hwservice, keystore2, seapp) clean
  (`tools/ctx-conflicts.py`). All checks bundled in `tools/preflight-b.sh` → PASS.
- Flashed: **still back in fastboot after 18 s.** Cause unknown — needs a log.

### Debug logger attempt (`tools/build-debug-b.sh` → `out-b-debug/`) — CURRENT STATE OF THE PHONE

- LineageOS kernel has no pstore (no `/sys/fs/pstore`, mount fails), so logs die with the reboot. Debug boot: ramdisk
  `/init` replaced by a `#!/bb sh` wrapper (Magisk's static busybox) that mounts `metadata` `-o sync` and streams
  `/dev/kmsg` to `port-kmsg.txt` (rotating the previous one to `port-kmsg.prev.txt`), then execs the real init.
  Debug vendor adds `(typepermissive kernel)`.
- Flashed `boot_b`/`vendor_b` from `out-b-debug/`. Result: **black screen, USB shows `Qualcomm HS-USB Diagnostics 900E`
  = Qualcomm crash-dump mode (kernel panic)**, not EDL, not a brick. New behaviour vs the 18 s fastboot loop, so the
  wrapper itself most likely killed PID 1 (e.g. "No working init found" / "Attempted to kill init").
- Exit: hold Power + Vol Up ~15 s → keep Vol Up for fastboot.
- **Next session:** first `fastboot flash boot_b out-b/boot.img` (non-debug, known to reach init) so recovery works,
  boot Lineage Recovery (Advanced → Enable ADB), mount the metadata partition and look for `port-kmsg*.txt` — if the
  logger ran at all before the panic, it holds the log. Then fix the wrapper (suspects: interpreter `/bb` exec,
  pid-1 script semantics, `/dev` devtmpfs left mounted under init's tmpfs) and test it with the *LineageOS* system first,
  which is known to boot.
- Slot A: untouched stock H.40 (but `/data` is LineageOS-formatted; returning to A needs the reserve.img restore +
  stock-recovery wipe).

### Boot logger that works (`tools/port-logger.c`, `tools/build-debug-b.sh` → `out-b-debug/`)

- v1 (busybox `#!/bb sh` wrapper) crashed even LineageOS into 900E: the LineageOS kernel has **`CONFIG_DEVTMPFS` off**
  (and `CONFIG_PSTORE` off, `CONFIG_PANIC_TIMEOUT=-1`), and leftover mounts break first-stage `SwitchRoot()`
  (it MS_MOVEs every mount and `PLOG(FATAL)`s).
- v2: static aarch64 C program as ramdisk `/init`: mknod by sysfs major:minor, mount `metadata`, fork a child that
  batches `/dev/kmsg` into `<metadata>/port-kmsg.txt` (fdatasync per batch; rotated to `.prev` each boot), lazy-detach
  everything, exec the real init. Tested on plain LineageOS first (boots). Debug cmdline adds `printk.devkmsg=on`.
- Debug vendor adds `/vendor/etc/init/port-logcat.rc` (logcat -b all → `/metadata/port-logcat.txt`, domain
  `logpersist`) and `(typepermissive kernel)`, `(typepermissive logpersist)`.
- Read logs from Lineage Recovery (fastboot menu → Recovery mode → Advanced → Enable ADB; `fastboot reboot recovery`
  does not work on this ABL): mount `/dev/block/by-name/metadata`, pull `port-kmsg.prev.txt` / `port-logcat.txt`.

### Failures found with the logger (all PC-reproduced, all fixed in the build scripts)

1. `SELinux: capping policy version from 30 to 29 for legacy kernel (no xperms support)` — ColorOS init (phh patch)
   strips only `allowx` from plat/system_ext/vendor CIL; the 4 `auditallowx` + 3 `dontauditx` in plat and 1
   `dontauditx` in vendor `plat_pub_versioned.cil` fail `secilc -c 29` → init fatal. `androidboot.selinux_xperms_supported=1`
   is **ignored**. Fix: strip those logging-only rules (build-port-b.sh, patch-vendor-sepolicy.py). Preflight now
   emulates init's v29 compile.
2. `/data` never mounted (`Read-only file system` on every mkdir): metadata-encryption key in
   `/metadata/vold/metadata_encryption/key` was created under LineageOS; ColorOS keystore2 rejects it (error -38).
   Lineage Recovery's "Format data" does not remove it. Fix: `tools/reset-data-keys.sh` (rm `/metadata/vold`, zero
   first 64 MiB of userdata).
3. `enablefilecrypto_failed`: `vold: Failed to install fscrypt key to /data: Invalid argument`. LineageOS fstab
   `fileencryption=ice` = `FSCRYPT_MODE_PRIVATE` (AOSP libfscrypt), which needs the CAF ICE/wrapped-key patches that
   LineageOS's vold has and the MediaTek-built PLG110 vold lacks. Fix option `FBE_MODE=standard`
   (`aes-256-xts:aes-256-cts:v2`); kernel has FS_ENCRYPTION_INLINE_CRYPT + BLK_INLINE_ENCRYPTION_FALLBACK.
   Not yet booted with it.
- Also seen: ColorOS prop files override `ro.vendor.build.fingerprint`, `ro.bootimage.build.fingerprint`,
  `ro.vendor.build.ab_ota_partitions` (MediaTek partition list!) with donor values. **Never accept an OTA inside the
  port.** Gotcha: `sed -i` on an image file drops its SELinux xattr — always rewrite in place.

### Donor switch: PLG110 (MediaTek) → PLK110 (expected Qualcomm)

- PLG110 evidence of MediaTek: fingerprint `alps/sys_mssi_64_cn_armv82`, MTK partition list in props,
  `system_mtk_bluetooth_prop`, vold without CAF patches. The same Axis project has
  `ColorOS-17-PLK110-1789230075256-18092026-AxisGSI.zip` (same date). MD5s from the SourceForge RSS feed
  (`/projects/axisgsiupdates/rss?path=/coloros`): PLG110 `81136312952f3ac98ff259e12860f419` (matches our file),
  PLK110 `103e36d468a3304def0c0030c5870d8e`.
- Build tools made donor-independent: `GSI`/`W`/`OUT`/`GSI_MNT`/`FBE_MODE` env for build-port-b.sh; SELinux and
  property_contexts conflicts now computed (`patch-vendor-sepolicy.py <vendor> <system>`, `drop-propctx-conflicts.py`).

## Test build 2 design (superseded by the LineageOS-base route; kept as reference)

Goal: reproduce LineageOS's 2SI boot with the **stock H.40 kernel and vendor**, changing only what is needed.

### Boot path, step by step

| # | Step | What we change | Evidence it works / risk |
|---|---|---|---|
| 1 | ABL loads `boot_b`, builds cmdline (adds `skip_initramfs`) | nothing | seen in `last_uboot_log` |
| 2 | Kernel decides on ramdisk | hex-patch kernel string `skip_initramfs` → `want_initramfs` (= Magisk LEGACYSAR patch, = effect of `INITRAMFS_IGNORE_SKIP_FLAG`) | the Magisk-patched stock boot booted fine twice with exactly this patch |
| 3 | `/init` (A12 first stage, ramdisk) chooses mode | remove `/system/bin/recovery` from the ramdisk → normal mode. (Cannot rely on `force_normal_boot`: string absent from this init.) Slot B loses its recovery; slot A's is unaffected | recovery-mode decision seen in every recovery kmsg; **risk:** exact A12 code path without the switch to `/first_stage_ramdisk` must be checked against AOSP 12 `first_stage_init.cpp` before building |
| 4 | First-stage fstab lookup | delete `firmware/android/fstab` node from every DTB in `boot_b` (`fdtput -r`); ramdisk `/fstab.qcom` and `/first_stage_ramdisk/fstab.qcom` get: `system /system erofs ro wait,slotselect,first_stage_mount`, `vendor /vendor ext4 ro,barrier=1,discard wait,slotselect,first_stage_mount`, `odm /odm ext4 ... first_stage_mount` (no `avb`) | mirrors LineageOS (DT fstab removed + ramdisk fstab) |
| 5 | Mount + switch root to `/system`, exec `/system/bin/init selinux_setup` | nothing | standard 2SI handoff; A12 first stage → newer system init is the normal GSI case. EROFS read verified on this kernel |
| 6 | A17 selinux_setup + second stage, `mount_all /vendor/etc/fstab.qcom` | edit `vendor_b` fstab: system line → `/system erofs ... first_stage_mount`; drop `/vendor/euclid/my_manifest.img` (would cover ColorOS 17's `/my_manifest` with 12's); reserve: `/data/reserve_cos17/reserve.img` with only my_stock (H.40's `/data/reserve` must not be mounted into ColorOS 17) | vendor edit needs vbmeta verification off (step 7) |
| 7 | vbmeta | `vbmeta_b` with both disable flags (LineageOS does the same) | avoids verifying the edited vendor; system footer cmdline no longer needed under 2SI |
| 8 | Android 17 userspace on 4.14 + VNDK-30 vendor | nothing yet | **largest unknown** — LineageOS proves the kernel family works, but with their backports |

### Destructive actions and their side effects (to approve separately)

- Flash `boot_b`, `vendor_b`, `vbmeta_b` (slot B only). Slot A untouched.
- `/data` is shared: the first boot of B upgrades/rewrites the current stock data. **Afterwards slot A needs a wipe from
  stock recovery** (which keeps `/data/reserve`). No `fastboot -w` / `fastboot format` at any point.
- `reserve_cos17` (my_stock) is installed only after B first boots; first boot runs without my_stock as before.

### To verify on the PC before building (each a gate)

1. **Done.** AOSP `android12-release` sources (`init/first_stage_init.cpp`, `init/first_stage_mount.cpp`,
   `fs_mgr/fs_mgr_fstab.cpp`):
   - Without `force_normal_boot` there is no switch to `/first_stage_ramdisk`; first stage runs from the ramdisk root.
   - `DoFirstStageMount` returns early only `if (IsRecoveryMode())` (= `/system/bin/recovery` exists).
   - `ReadFirstStageFstab`: DT fstab if present, else `ReadDefaultFstab` filtered to `first_stage_mount` entries.
     `ReadDefaultFstab` itself uses `/etc/recovery.fstab` when `/system/bin/recovery` exists, else `GetFstabPath()`:
     suffixes `fstab_suffix` (`default`), `hardware` (`qcom`), `hardware.platform` × prefixes `/odm/etc/fstab.`,
     `/vendor/etc/fstab.`, `/fstab.`, `/first_stage_ramdisk/fstab.` → our ramdisk **`/fstab.qcom`** is used.
   - `TrySwitchSystemAsRoot`: mounts the `/system` entry, `SwitchRoot("/system")`, then
     `execv("/system/bin/init", "selinux_setup")`.
   - Without a `/system` or `/` entry it falls back to `GetRootEntry` (the legacy `/dev/root` path).
2. DTB edit: split the 12 MB concatenated DTB section, delete the node in each, re-concatenate; confirm with `fdtdump`.
3. Ramdisk repack keeps every other file byte-identical; boot image round-trip as done for the adbfix image.

## Gotchas

- Git Bash rewrites `/data/...` args for adb; set `MSYS_NO_PATHCONV=1`.
- `adb exec-out` streaming of ≥100 MB partitions stalled; dd to `/data/local/tmp` then `adb pull`.
- WSL shuts down when idle and drops loop mounts; remount before reuse. Build scratch: `<LOCAL_WSL_PATH>` in WSL.
- Never write through absolute symlinks inside an extracted image tree from the host (e.g. `/adb_keys`).
- Button combos: Vol Up + Power → fastboot; Vol Down + Power → recovery.

### 2026-10-15 — Display fixed live (ColorOS UI renders)
- SoundTrigger 2.1 (stock H.40 adapter) fixed the watchdog hang: `sys.boot_completed=1`, root adb.
- Screen stuck on the OnePlus splash: composer@2.4 logged `failed to parse command 0x8000000` = QTI
  `IQtiComposerClient SET_LAYER_TYPE` (0x800<<16). ColorOS SF has CAF's QtiExtension; per
  `QtiSurfaceFlingerExtensionFactory.cpp` it is enabled when `ro.product.first_api_level < 34` (ours: 28) or
  `vendor.display.enable_display_extensions=1`. The LineageOS sm8150 composer is plain AOSP 2.4 (no IQtiComposer).
- Fix: `tools/patch-sf-qti-ext.py` repoints SF's single `ro.product.first_api_level` read to
  `ro.port.sf_first_api_level` (=36 in system build.prop) → QtiNullExtension. Global first_api_level left alone
  (bpfloader/VSR/keystore depend on it).
- Live test: bind-mounted patched SF + setprop → 0 parse errors, ColorOS boot animation, then SystemUI/launcher.
- Open: "Voltage error" charging notification (oplus charger stack vs LOS kernel), camera provider, my_stock apps,
  ~200 s reboot seen earlier (did not reproduce this session yet). OLED: blank backlight while stuck on splash.

### 2026-10-15 (later) — live session findings
See `handoff-2026-10-15.md` §1–2 for the full table. Short version:
- Live fixes (not yet in a flashed build): SF QTI patch, `libcamera_metadata` LLNDK, `/odm/vendor` link + wlan
  module reload (WiFi up), my_stock as `/data/port/my_stock.img` (Phone/Contacts/Mms/Gallery installed).
- Power key 5 s delay = Theia → `IOplusProject` AIDL lookup (missing on LOS vendor) on the input thread.
- Fingerprint enroll ANR = guide video on sw HEVC decoder failing (`0x43dd`), not the sensor.
- Pop-up camera: motor works via `/sys/class/motor/*`; LOS `OnePlusCameraHelper` needs repackaging (system uid).
- Alert slider: ColorOS reads it via `IOplusMisc` (missing); kernel side `/proc/tristatekey/tri_state`.
- Missing from donor: my_heytap/my_bigball (keyboard, stock camera, app market).

### 2026-10-15 (late) — codecs, charger warning, stock Oplus HALs
- Video: ColorOS build.prop `debug.stagefright.ccodec=1` drops all vendor C2 codecs except AVC (AOSP
  Codec2InfoBuilder option 1); LOS disables OMX → HEVC went to software and 10-bit failed (fingerprint guide video).
  `=4` fixes it live; build-port-b.sh now rewrites the line.
- Charger "voltage too high": AIDL `vendor.oplus.hardware.charger.ICharger` missing → notifycode=-1 → SystemUI bit 1
  (charger OV). OP7 Pro = Warp Charge 30 (VOOC), unlike the OnePlus 15 donor.
- Stock H.40 odm.img has HIDL @1.0 charger/misc/performance/oplus_project services; ColorOS 17 only falls back to
  HIDL for IOplusMisc. Others need AIDL shims. Details: handoff-2026-10-15.md §0.

### 2026-10-15 (build 9) — live fixes baked in and flashed
- Built `out-plk/` with SF QTI patch, `/odm/vendor` link, libcamera_metadata LLNDK, my_stock image + rc, ccodec=4.
  Preflight PASS. Flashed system_b only (boot/vendor unchanged on the phone); new my_stock.img pushed to /data/port.
- Clean boot: init's `mount erofs loop@… ` and `mkdir … encryption=None` work; my_stock apps installed; camera
  provider, WiFi (no manual insmod), HW codecs and display all OK without live tweaks. Fingerprint HAL no crash.
- From now on: each fix is validated live over root adb before it goes into the build script.

### 2026-10-15 (after build 9) — live tests: power key, fingerprint
Logs: `logs/plk-build9/`. Stub service: `tools/oplus-stubs/` (smali → dex, run with app_process as root).
- **Power key 5 s — fixed live.** Not Theia/Java: `system_ext/lib64/lib_inputflingerEx.so` `saupwkProcessKey` →
  `getStatbilityHalService` → `AServiceManager_getService("…stability.oplus_project.IOplusProject/default")` blocks
  5 s on InputReader for every key (stack: `ss-stack-powerkey.txt`, `pk-reader.txt`). A system-stability Java Binder
  with the right descriptor registered under that name → keys handled ~2 ms after release. LOS has no
  implementation (only matrix entry, change 505310).
- **Fingerprint enroll ANR — fixed live** by the same stub for `vendor.oplus.hardware.performance.IPerformance`
  (mediaserver `OplusVideoBoostUtils` waited 5 s per codec; MediaPlayer.reset queued behind it). ccodec=4 alone did not fix it.
- **Fingerprint finger-down — root cause, validated live:** LOS `fingerprint@2.3-service.oplus` wrapper owns
  `android@2.3/default` and drops the Goodix `onFingerprintCmd` (TOUCH_DOWN) callbacks; ColorOS 17 talks to
  `vendor.oplus…fingerprint@2.1` like stock H.40. `stop vendor.fps_hal_oplus; stop fps_hal; start fps_hal` → Goodix
  registers all names, gets TP touch-down via its kernel netlink (`notifyTouch Down`) and enroll runs, but captures
  fail `GF_ERROR_TOO_FAST` (no illumination). Stock H.40 = same Goodix HAL (`/odm/bin/hw/…fingerprint@2.1-service`).
- **Illumination:** SystemUI `OnScreenHighLightControl.hbmControl` → AIDL `vendor.oplus.hardware.displaypanelfeature.
  IDisplayPanelFeature.setDisplayPanelFeatureValue(22,[0|1])` (txn 2), HIDL @1.0 fallback; neither on LOS vendor →
  `NoSuchElementException`, UI stays dim. Stock H.40 odm has `vendor.oplus.hardware.displaypanelfeature@1.0-service`
  (SetDisplayPanelHBM / FPPress / DimlayHBM) + VINTF fragment + rc. Kernel `hbm` is toggled on enroll start/stop
  already (by the Goodix HAL). Sensor geometry agrees with LOS: centre (720,2728) r=137 = stock iconlocation 392 / iconsize 274.
- ⚠ **A generic stub for IDisplayPanelFeature crash-looped system_server** (`bad array lengths`: display thread reads
  an int[] from getDisplayPanelFeatureValue) → phone rebooted. Never register a generic stub for an interface whose
  getters return arrays; implement the real reply shape or use the stock HAL.
- Also noted: `persist.sys.phh.fod.bbk=true` (phh GSI vivo FOD hook) is set — check whether it interferes.

### 2026-10-15 (late) — fingerprint: full chain traced (stock H.40 + LOS kernel)
- Stock H.40 SystemUI (`OnScreenFingerprintControl.highlightControl`) = ColorOS 17: SF transact 0x4e25 +
  HIDL `displaypanelfeature@1.0 setDisplayPanelFeatureValue(22,[on])`. Stock service lives in **`system/euclid/odm.img`**
  (`/odm/bin/hw/vendor.oplus.hardware.displaypanelfeature@1.0-service`, writes `/sys/kernel/oplus_display/*` itself);
  its jump table: feature **22 = SetDisplayPanelDimlayHBM** (`dimlayer_hbm`), feature 12 = `hbm`.
- **onFingerprintCmd ABI mismatch:** H.40 Goodix HAL sends `vec<uint32>`, ColorOS 17's
  `IBiometricsFingerprintClientCallbackEx$Stub` (services.jar classes4.dex, txn 2) reads `vec<int8>` →
  `hw-Parcel: Buffer length 32 does not match expected size 8`, TOUCH_DOWN lost. **Fixed live**:
  `tools/live/fpcmd/services.jar` (readInt32Vector + narrow, logs `PortFpCmd`) bind-mounted over
  /system/framework/services.jar → `dispatchTouchDown`, pressed overlay shown.
- **Remaining blocker = UI ready:** Goodix HAL waits ~530 ms for the display's UI-ready, then
  `[Fpsys] UI timeout` → `captureImage GF_ERROR_TOO_FAST`. Forcing hbm/dimlayer_hbm does not help.
  LOS kernel `sde_crtc.c` (~5443): plane prop `PLANE_CUST` 1=fp icon, 2=pressed, 3=aod; a pressed plane sets
  `fingerprint_pressed` → HBM + `send_fingerprint_message(E_FP_EVENT_UI_READY)`. LOS sets PLANE_CUST via the SF UDFPS
  z-order magic (`hardware/oplus fingerprint/UdfpsExtension.cpp`: dim 0x41000005, pressed 0x41000033); stock via
  QTI composer SET_LAYER_TYPE. ColorOS 17 SF on the LOS composer does neither (QTI ext disabled for display).
  HBM node writes are applied at the next frame commit (screen brightened only after a touch redraw).
- Next: make ColorOS SF give `OnScreenFingerprintPressedIcon` z-order 0x41000033 (and the dim layer 0x41000005), e.g.
  patch its OplusOutputLayer / QTI layer-type path, or verify how LOS composer decodes the z-order first.
- **Composer check (path "stock composer + QTI ext") — not viable:** stock H.40 and LOS composers are both the
  generic `composer@2.4-service` + `hwcomposer.*.so`; neither has `IQtiComposerClient`/SET_LAYER_TYPE. LOS composer
  (`hardware/qcom-caf` sm8150, `-DFOD_ZPOS`): `HWCLayer::SetLayerZOrder` strips `0x20000000` → `fod_pressed`;
  `hw_device_drm` ORs it back into `PLANE_SET_ZORDER`; kernel `sde_plane` (zpos & 0x20000000) → `PLANE_CUST=2`.
  Stock ColorOS 12 SF does this itself (strings `--- FOD ON %#x`, `dumpZorder`). ColorOS 17 (PLK110) SF has no such
  code (it relies on the QTI ext). ⇒ The pressed bit must come from SurfaceFlinger (or a composer that parses
  SET_LAYER_TYPE, which needs an LOS display HAL source build). ColorOS 17 SF z-order call site: `0x2f9364`
  (`hwcLayer->setZOrder(w28)` via vtable +160, OutputLayer in x19).

### 2026-10-15 (night) — standalone composer build (SET_LAYER_TYPE)
- Full LOS tree impossible here (C: 72.5 GB free, WSL 7 GB RAM). Standalone build instead: `tools/build-hwc.sh`
  (WSL `<LOCAL_WSL_PATH>`): AOSP main tarballs (hardware/interfaces graphics, libhidl, libfmq, libbase, core libs, liblog,
  libhardware incl. include_all, binder headers), Ubuntu `hidl-gen` 10.0 for composer/common/mapper/hidl headers,
  NDK r27c clang with libc++ headers switched to `std::__1`, `-fno-rtti -fno-exceptions`, linked against LOS
  vendor/system libs (`<LOCAL_WSL_PATH>`). Unmodified service builds; all 183 imports resolve.
- `tools/hwc-port/patch-engine.py` → overlay `composer-hal/2.4/ComposerCommandEngine.h`: accepts QTI
  SET_LAYER_TYPE (0x800<<16), skips other ≥0x800<<16 commands, caches z per layer and ORs 0x20000000 when the layer's
  type == `persist.vendor.port.fod_pressed_type` (default -1 = log only). Build: `OVERLAY=1 build-hwc.sh '' out`.
  Binary `tools/live/hwc/composer-service-port` (sha 4a053d93…).
- **Live test**: bind-mounted it over `/vendor/bin/hw/android.hardware.graphics.composer@2.4-service` and the
  unpatched donor SF (`tools/live/hwc/surfaceflinger.orig`, QTI ext ON) over /system/bin/surfaceflinger, restarted
  composer + framework → display works, SET_LAYER_TYPE parsed (3 layers, type 0, at startup), no parse errors.
- **But SF sends no layer type for the FOD layers** during enroll. SF's FOD code first queries
  `displaypanelfeature` (`[FOD] getDisplayPanelFeatureValue fpType=0x%x`); that HAL is missing → FOD marking off.
  Next: provide displaypanelfeature (stock H.40 HIDL @1.0 service from euclid odm + VINTF fragment, or a correct
  AIDL impl incl. getDisplayPanelFeatureValue reply shape) and re-check which layer type SF sends for the pressed icon.

### 2026-10-15 (night) — FINGERPRINT ENROLL WORKS (live)
`dumpsys fingerprint` count 1; per press: `notify fingerpress on` → `gf_spi … UI ready` → `Acquired: 0`; 0 UI timeout,
0 TOO_FAST (log `logs/plk-build9/fp-fod.txt`). Live stack (all lost on reboot):
1. stubs `tools/oplus-stubs` (app_process): IOplusProject, IPerformance, **IDisplayPanelFeature** (wire-correct
   `PanelBinder`, self-test `port.PanelSelfTest`): get 211 (`fpType`) = `persist.vendor.port.dpf.211` = **2**;
   set 22 → dimlayer_hbm, 12 → hbm, **28 → notify_fppress** (stock `SetDisplayPanelFPPress`; kernel fp_mode +
   forced commit). 81 unsupported on stock too. fpType=1 made enroll hard to reach; 2 makes SF call 28 per press.
2. `stop vendor.fps_hal_oplus` + restart `fps_hal` (Goodix owns android@2.x + vendor.oplus@2.1 names, as on H.40).
3. `services.jar` onFingerprintCmd vec<uint32> patch (`tools/live/fpcmd/`).
4. source-built composer `tools/live/hwc/composer-service-port` (sha f3cff0f2…, `tools/build-hwc.sh`,
   `tools/hwc-port/patch-engine.py`): accepts QTI SET_LAYER_TYPE; layer with frame `persist.vendor.port.fod_rect`
   (default 583,2591,857,2865 = OnScreenFingerprintPressedIcon) gets z | 0x20000000. ColorOS SF (fpType 2) gives that
   layer z **0x41000033** (newer Oplus convention, no 0x20000000 bit) → 0x61000033. A rule "z has 0x41000000 prefix"
   could replace the rect rule.
5. unpatched donor SF (QTI ext on) `tools/live/hwc/surfaceflinger.orig` bind-mounted (build-9 image has the
   noqti SF + ro.port.sf_first_api_level=36 — must be reverted when baking).
Root causes = a chain of ColorOS-17 vs H.40/LOS mismatches (handoff §0d table).
Still to do: unlock/auth test, then bake 1–5 into build-port-b.sh / vendor (+ init rc for the stub service, SELinux).

### 2026-10-15 (late night) — unlock works; ablation; black lock screen
- Fingerprint **unlock works** with the live stack (user confirmed).
- Ablation: removing the `services.jar` patch → `readInt8Vector` IllegalArgumentException, UI timeout again →
  required. Blocking feature 22 (`dimlayer_hbm`) → lock screen dim but visible, unlock fails → required.
- LOS kernel `sde_crtc_onscreenfinger_atomic_check`: FOD handling (incl. `fingerprint_pressed` → UI ready) only
  runs while `oplus_dimlayer_hbm` (or `dimlayer_bl`) is set; it also enters panel HBM and adds its own
  brightness-compensating dim layer. ColorOS SystemUI's keyguard `OnScreenFingerprintDimLayer` dims on top →
  black lock screen. Details and next steps: handoff-2026-10-15.md §0e.

### 2026-10-15 (evening) — build 10: live fixes baked in
- Volume panel side: ColorOS SystemUI `FeatureOption.isOplusVolumeKeyInRight` = prop
  `persist.oplus.software.audio.right_volume_key` (donor `my_product/build.prop` = true). Live `setprop … false` +
  SystemUI restart → panel on the left (user confirmed). Build: `my_product/build.prop` line → false.
- SystemUI dim patch (`tools/patch-systemui-dim.py`, other session) drops the v2 signing block → a fresh package scan
  would reject SystemUI. `tools/transplant-apk-sigblock.py` puts the original block back (system-partition APKs are
  scanned without digest checks). Live: bind-mounted, `/data/system/package_cache` wiped, framework restarted →
  SystemUI scanned and running with the platform signature (`1f86190a`, same as `android`).
- Stub dex: fpType (211) defaults to 2 when `persist.vendor.port.dpf.211` is unset (self-test `ret=0 [2, 0, 0]`).
- build-port-b.sh now: stub dex + `00-port-oplus-stubs.rc` (post-fs-data, root, su seclabel); patched services.jar
  (odex/vdex/art removed); signed kernel-dim SystemUI (oat removed); volume prop; vendor composer = source-built;
  LOS `fingerprint@2.3-service.oplus.rc` removed (Goodix `fps_hal` owns the names). SF QTI patch and
  `ro.port.sf_first_api_level` dropped (donor SF unchanged). Each replaced donor file is sha-checked;
  preflight-b.sh checks the exact live-tested artifacts. Build-9 images kept in `out-plk-build9/`.
- Not in build 10: camera-motor helper (needs a permanent permission design; runtime CAMERA grants give no gid).
- **Build 10 flashed (system_b 300a29be…, vendor_b c42bea4f…; boot unchanged 614c…) and verified on a clean boot**:
  stubs from init, Goodix fps_hal owns all fingerprint names, no bind mounts, tested artifacts in place. User
  confirmed: lock screen visible, fingerprint unlock works, power key instant, volume panel on the left.
  Rollback: `out-plk-build9/` (system 2c994b52…, vendor 760b… = same script without composer/fingerprint changes;
  the previously flashed vendor 0cb3… image is not kept).

### 2026-10-15 (evening) — screen-off gestures (double tap to wake)
- Settings had it on (`double_wake_status=1`, `oplus_screen_off_gesture_state=1`) but `/proc/touchpanel/double_tap_enable`
  stayed 0: ColorOS 17 `ColorTouchNodeManagerService` writes touch nodes only through AIDL
  `vendor.oplus.hardware.touch.IOplusTouch/default` (V2, hash ef41c5fa…; no HIDL fallback). LOS vendor has only
  `vendor.lineage.touch.ITouchscreenGesture`; stock H.40 has HIDL `touch@1.0-service` (odm).
- nodeFlag = `com.oplus.touchnode.OplusTouchNodeManager` constants (1 DOUBLE_TAP_ENABLE … 22 TOUCH_OPTIMIZED_TIME) =
  index into the stock touch@1.0-service path table (`/proc/touchpanel/double_tap_enable`, `coordinate`, …).
- New `port.TouchBinder` in tools/oplus-stubs (txn 1–9, read/write/isSupported on that table). Live: after toggling
  the setting ColorOS reads flag 1 and writes flag 21 (`double_tap_enable_indep`) = 70; kernel sends `KEY_WAKEUP`;
  **user confirmed double tap wakes the screen**. Flag 194 (ColorOS 17 node, not in H.40) fails harmlessly.
  Drawn gestures (O/V/arrows) not tested yet. Added to the stub rc (build 11).

### 2026-10-16 — CUST_LEVEL_LIST, slider → action button, stock apps, H.40 camera (see handoff-2026-10-16.md)
- Root cause found: env `CUST_LEVEL_LIST` unset → ColorOS ignores all `/my_*/etc/extension` features (app-feature
  provider empty; Settings EXP mode → Special access closes). Export added to init.environ.rc in build-port-b.sh
  (build 12, untested).
- Slider: ColorOS 17 slider path needs feature `oplus.software.audio.alert_slider` (absent, OnePlus 15 has an action
  button). User chose action-button mapping: `port.SliderBridge` (grabs `oplus,tri-state-key`, reads
  /proc/tristatekey/tri_state, injects KEYCODE_ACTION_BUTTON_CLICK 780; down = 1 s hold → long press 782). Hint side:
  OplusGestureUI `sidekey_config.xml` `action_position_right_pixel` 620,790 (2376-px units). Live-confirmed.
- Screen-off gestures: IOplusTouch stub (build 11), double tap confirmed.
- Stock apps: donor package payload verified, my_stock merged (153 apps), 33 del-app apps + keyboards installed live.
- Camera: H.40 OnePlusCamera works for photo + lenses after permission grant, linearmotor patch, media profile
  variant `_vendor`; video still fails (vidhance EGL crash with ColorOS libEGL; then audio encoder creation fails).
- Stock PLK110 17.0.0.105 CN01 full OTA added (StockRom/836f…zip). Its init sets CUST_LEVEL_LIST in code; decoded
  order now in build-port-b.sh: /system:/system_ext:/vendor:/odm:/odm/cust:/my_preload:/my_stock:/my_region/global:
  /my_product:/my_region:/my_bigball:/my_carrier:/my_carrier/cust:/my_company:/my_engineering:/my_product/special.

### 2026-10-16 — build 12 crash loop: composer vs ColorOS 17 generic metadata
- Build 12 (CUST_LEVEL_LIST on) → white/black flicker every 5–10 s. Root cause: ColorOS 17 SF sends
  SET_LAYER_GENERIC_METADATA (composer 2.4 opcode 0x40e, length 19); the AOSP 2.4 engine rejects it without consuming
  → `endCommand()` LOG_FATAL "too little data read" → composer abort → SF/system_server restarts, SystemUI GPU page
  faults. Secondary: the OnePlus 15 default live video wallpaper (livepicker `Infiniti1VideoWallpaper`, HEVC
  1272x2776) failed buffer allocation in a loop — livepicker disabled on the phone (`pm disable-user`).
- Fix (patch-engine.py): accept/ignore generic metadata, and consume+log any under-read command instead of aborting.
  Composer `c8042313…` live-verified (full stack restart, 3 min: 0 presentOrValidate failures, 0 GPU faults,
  0 tombstones, 1 SystemUI start). In build-port-b.sh for build 13.

### 2026-10-16 — build 12 follow-ups: screen-off gestures, Flux theme editor
- Double tap wake broken on build 12: with CUST features on, AOD is active and SystemUI writes gesture mode 16
  (mask |0x10000 single tap, &~0x2 double tap) at screen off; the LOS driver then drops double taps. Stub
  (TouchBinder flag 21) now always ORs 0x2. O/V/single tap: LOS driver reports scancode 246+type, ColorOS only acts on
  KEYCODE_F4 + coordinate node → `tools/live/keylayout/touchpanel.kl` maps them to F4. Live-verified: single tap shows
  AOD, O and V actions, double tap wakes, double tap on home locks. Stub dex 2493fd12…, kl in build-port-b.sh.
- Flux theme edit crash: `com.oplus.wallpapers` OdinHeaderTools parses `getprop` with readLine(); stock
  getsuperlayoutsize.sh (CRLF) sets `ro.oplus.storage.super_size` to "\r" because GM1910 has no super partition →
  StringIndexOutOfBounds. Build 13 sets it to 4819255296 (system_b+vendor_b+odm_b) and drops supersize.rc. Not yet
  verified (ro prop, needs flash).
- Build 13 flashed 2026-10-16 (system_b 19a72261…, vendor_b 296de9db…; boot and /data/port/my_stock.img kept from
  build 12). Boot monitored 3 min: 0 FATAL/ANR/tombstones, 1 SystemUI + 1 system_server start, 0 presentOrValidate
  failures, 0 kgsl faults. super_size=4819255296, market name 一加 7 Pro / OnePlus 7 Pro, battery 4000, LUMO 0,
  touchpanel.kl active, stub 2493fd12…. Rollback: out-plk-build12/.


### 2026-10-16 (afternoon) — build 13 regressions: popup camera stays up, punch hole back
- Popup camera: the LOS helper is a user app (flags 0x0, UID 10190), so `persistent` is ignored; FastClear killed it
  (o-kill 2006 at 14:45:08 and 14:52:21) and the camera stayed up (position 0); retracted by adb.
  LOS = persistent system-UID priv-app helper; stock H.40 = MotorManagerService in system_server +
  HIDL motorcontrol@1.0 (odm). ColorOS 17 kept only the MotorManager client API (server and HAL client removed).
  Plan: init-started root `port.MotorBridge` in the stub dex (LOS helper logic). Details: handoff-2026-10-16.md §0.
- Punch hole: build 13 image (12:52) predates the overlay-drop block (script 15:01); will be in build 14.
- About page still shows donor "2 mAh" battery and "50W wireless" charging; to fix from H.40 values in build 14.
- Punch hole live test: dropping both display overlays → system_server crash loop "Invalid colorMode: 301" (the
  android overlay also holds config_availableColorModes). The visible hole is the oplus overlay's
  oplus_rc_cutout.png. Live: oplus overlay hidden via bind mount + fabricated empty cutout strings → insets 0, stable.
  build-port-b.sh now drops only the oplus overlay; the android overlay's cutout string still needs a static blank.
- Punch hole resolved (live, user-confirmed): dropping the oplus overlay exposed ColorOS 17's default top-left corner
  image with a baked-in hole. Now: H.40 odm oplus display overlay (18821, OP7 Pro corners, no cutout image) replaces
  the donor's; donor android overlay kept for colour modes with its cutout string emptied (tools/patch-cutout-overlay.py).
- About phone: "2 mAh" = GSI placeholder power profile (capacity 2.0, components 0.1); H.40 power_profile.xml
  (4065 mAh) into my_product/etc/power_profile. "50W wireless" = donor app features; 6 wireless lines removed (H.40
  has none). Both live-verified and in build-port-b.sh.
- Axis GSI rw-system.sh bind-mounts /system/axisgsi/vo over /vendor/overlay (and its group/passwd over vendor's):
  all LOS vendor RROs are hidden; OnePlus 15 vendor RROs apply instead. Not changed yet; see handoff-2026-10-16 §0.
- Flux theme editor: **user-verified working on build 13** (ro.oplus.storage.super_size=4819255296, supersize.rc
  dropped). Stays in build-port-b.sh.

### 2026-10-16 (evening) — build 14 flashed; SIM absent → round trip via stock H.40 → SIM works
- Build 14 (system_b 5d77ce14…) verified: no cutout, 4065 mAh, no wireless features. SIM: modem CARDSTATE_ABSENT, no
  ATR, firmware identical everywhere. Slot A reflashed with H.40 OS images + reserve restore + recovery wipe → H.40
  detects the SIM. Back on slot B with fresh /data → SIM PRESENT (PIN). Cause = reseat or stale /data state; not
  build 14. my_stock.img re-pushed. Details: handoff-2026-10-16.md §00.
- Pop-up camera fixed live: `port.MotorBridge` (tools/oplus-stubs/smali/port/MotorBridge.smali) = LOS CameraMotorService
  logic without a Context: ICameraServiceListener on media.camera, camera "1" NOT_AVAILABLE → up, PRESENT → down,
  100 ms debounce; lowers the camera at start if left up; exits on cameraserver death (init restarts). Runs from init
  as root (su), so FastClear can't kill it. User-verified 17:12 (up + down). In build-port-b.sh (service
  port_motor_bridge on boot_completed) + preflight; stub dex a77bd144… (only MotorBridge added vs 2493fd12…).
- Missing apps after the wipe: ColorOS installs /my_stock/del-app (33 apps) only on the FIRST boot, and my_stock.img
  was pushed after it. Installed live with `pm install -r -g` + Oplus/Baidu keyboards (stock-app-source/myproduct-apps),
  Oplus keyboard set default. After a future /data wipe: push my_stock.img and reboot BEFORE finishing setup, or
  repeat these installs.
- Light sensor (no lux, HWiNFO dead): LOS sensors HAL (android.hardware.sensors@2.1-service.oneplus_msmnile)
  AlsCorrection::init() connects to vendor.lineage.oplus_als IAreaCapture/default only if VINTF-declared; ColorOS
  lacks LOS's system_ext service → service=nullptr → every reading dropped ("Could not get area above sensor").
  Fix for build 15: LOS's 4 files (bin/hw service, -V1-ndk.so, rc + seclabel su, VINTF fragment) from LOS system
  (tools/live/als, sha-checked) + preflight. Live: binary links on ColorOS libgui, registers once declared, one
  getAreaBrightness call OK (rgb 0). HAL side can only be tested from boot (restarting the sensors HAL reboots).
- Lesson: restarting servicemanager (or the sensors HAL) on a freshly formatted /data in checkpoint mode reboots the
  phone (reboot,checkpoint_commit_failed after system_server pre-watchdog); GPS xtra-daemon tombstones are collateral.

### 2026-10-16 (late evening) — H.40 camera video: investigation in progress (NOT fixed)
- Build 15 (MotorBridge + LOS IAreaCapture light-sensor service) was started in the background; check
  logs/plk-build15/{build,preflight}.txt. Build 14 images moved to out-plk-build14/. Not flashed.
- GPS: user confirmed working (earlier no-fix was indoors).
- H.40 OnePlusCamera video: preview hangs in video mode and recording never starts because the app's
  CamcorderImpl.selectProfile() → Camcorder.Profile.getDefaultProfile() returns null ("initializingRecorder() -
  No profile"). Findings so far:
  1. ColorOS libmedia reads ro.media.xml_variant.profiles (plural); the build sets the singular ...profile (no effect).
     Live: setprop ro.media.xml_variant.profiles _vendor; also media.settings.xml honoured first.
  2. With media.settings.xml → vendor file, "quality N not found" errors stop, but the app still finds no profile.
  3. getDefaultProfile uses CamcorderProfile.get(quality) WITHOUT camera id (= default back camera) and OnePlus/
     high-speed quality ids: 6, 8, 2004 (0x7d4), 2005 (0x7d5), 3001 (0xbb9), chosen by height/capture rate.
     Next: read the rest of getDefaultProfile (smali in WSL <LOCAL_WSL_PATH>
     hardware/Camcorder$Profile$Companion.smali) to see which quality id it asks for at 1080p30 and why it's null;
     then add the missing ids to a port media_profiles file (tools/make-media-profiles-port.py already adds
     cameraId 4/5 copies of camera 0) and set ro.media.xml_variant.profiles / media.settings.xml in the build.
- Live state now (lost on reboot): media.settings.xml=/data/local/tmp/media_profiles_port.xml,
  ro.media.xml_variant.profiles=_vendor, Video.xml resolution 1080p (backup /data/local/tmp/Video.xml.bak).
- User wants a second camera: the ColorOS 17 camera (see camera-port-2026-10-16.md; black preview, live-only, lost
  in the wipes).

## Build 16 (2026-10-17): calls, SMS, audio and H.40 camera video fixes baked

Built into `out-plk-build16/` (not flashed at the time of writing; see `handoff-2026-10-17.md` §3 for the flash steps and §4 for the clean-boot checks). Preflight PASS.

- H.40 camera video: `vendor.vidhance.enabled=0` plus `tools/live/camera/OnePlusCamera-H40-v10.apk` (EIS bypass, no 960x540 preview-frame reader, 4K30 session type 0); 1080p30/4K30/1080p60 recordings verified. `h40-video-fixed-handoff-2026-10-17.md`.
- Audio HAL: the Breeno wake-word package is disabled at boot (`system/etc/init/01-port-audio-fix.rc`) and the odm `audio.primary.msmnile.so` ultrasound thread is patched out (sha asserts in `build-port-b.sh`).
- IMS / VoLTE: LOS24 `ims.apk` (HIDL ImsRadio) patched so `QtiImsExt` uses ColorOS's `QtiImsExtBase(Executor, Context)`, with ColorOS's signing block (`tools/transplant-apk-sigblock.py`), LOS jni libs, and the `ims-ext-common` library dependency on the HIDL java libs. Outgoing calls connect over VoLTE. `ims-volte-findings-2026-10-17.md`.
- Incoming SMS: `persist.vendor.radio.poweron_opt=0` (donor value 1 made qcrild buffer MT SMS awaiting an ACK ColorOS never sends).
- GPS: no change needed; real fix near a window (`gps-facts-2026-10-17.md`).

