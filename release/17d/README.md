# OnePlus 7 Pro ColorOS 17 port — 17d test release

First local test release for the OnePlus 7 Pro PLK110 / GM1910 family (`guacamole`, Snapdragon 855 / `msmnile`). It contains two standalone fastboot bundles:

- `OnePlus7Pro-17d-NoRoot.zip`
- `OnePlus7Pro-17d-Magisk31.zip`

Each ZIP contains the 17d system and vendor images, the required `my_stock.img`, its boot image, an installer, and checksums. The no-root bundle also carries a temporary 17d debug bootstrap, used only to install `my_stock.img` after formatting data; the installer replaces it with the secure production-property system before finishing. The rooted bundle stages that file through MagiskSU instead.

## Install

Extract the ZIP, connect one phone in fastboot mode, and run the included installer: Windows can use `Install-17d.bat` or `Install-17d.ps1`; Linux and macOS can use `bash ./Install-17d.sh`. Each installer checks the fastboot product `guacamole`, detects the current active slot, and flashes only that slot; it does not hard-code B or change the active slot. It leaves the other slot untouched.

The clean data wipe is required on every device. Back up the phone first: the installer erases userdata and metadata, including apps, accounts, keys, and personal files. It asks for the device model and requires typing `WIPE` before it writes anything. It installs the 17d system, vendor, and boot images directly; no separate LineageOS, GSI, or other base ROM flash is required. These are host-assisted fastboot bundles; they are not `fastboot update` archives.

Requirements: unlocked bootloader, current Android platform-tools (`adb` and `fastboot`) on `PATH`, a OnePlus 7 Pro PLK110/GM1910, and matching H.40 firmware. This test package does not replace bootloader or radio firmware. It requires fastboot product `guacamole`; do not use it on a different phone.

The root package uses Magisk v31.0, an official pre-release chosen for Android 17/API 37 compatibility. On its first boot, approve the ADB shell root request in Magisk when prompted so the installer can place `my_stock.img` in userdata.

## Release evidence and limits

See [FACTS.md](FACTS.md), [BUILD_SOURCES.md](BUILD_SOURCES.md), and [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md). The Magisk-patched boot image passed a temporary `fastboot boot` test: Android boot completed, `magiskd` ran, and `su -c id` returned UID 0. The boot partition was not flashed during that test. The no-root system image passed the 17d preflight and differs from the original 17d system only in `system/build.prop`; it has not been clean-flashed or live-boot-tested.

The build/source image share and extraction details are in [`images/README.md`](images/README.md). Binary images and generated ZIPs are excluded from Git; this folder is for source, build notes, and scripts.

This is a local test release, not a production or public release. The package install flow has not been run end-to-end on a wiped second device.

The cumulative developer tools and patches from builds 1–17 are preserved under source/prior-builds/; see BUILD_SOURCES.md for scope and exclusions.
