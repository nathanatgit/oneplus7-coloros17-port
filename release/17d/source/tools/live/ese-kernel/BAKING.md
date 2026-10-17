# Baking the eSE (SE HAL) stack into the vendor image (build 17d)

Source tree: `vendor-odm/` here = exact copy of what is live on vendor_b (pulled 2026-10-17, hashes in `vendor-odm.SHA256SUMS`).
All targets are under `/vendor/odm/` (`/odm` is a symlink to it). Owner for everything: root:root.

| Target (under /vendor/odm) | Mode | SELinux label | Notes |
| --- | --- | --- | --- |
| `bin/hw/android.hardware.secure_elementnq330@1.1-service` | 0755 | `u:object_r:hal_secure_element_default_exec:s0` | stock H.40 binary (= `tools/live/odm-services/stock/...`) |
| `lib64/ese_spi_nxp_nq330.so`, `ese_client.so`, `ls_client.so` | 0644 | `u:object_r:vendor_file:s0` | stock NXP libs |
| `lib64/vendor.nxpnq330.nxpese@1.0.so`, `vendor.nxp.nxpnfc@1.0.so`, `vendor.nxp.eventprocessor@1.0.so` | 0644 | `vendor_file` | HIDL stubs/clients (INxpEse / INxpEseEvtProcessor are served by the HAL binary itself, no extra files) |
| `lib64/android.hardware.nfc@1.0.so`, `android.hardware.nfc@1.1.so` | 0644 | `vendor_file` | |
| `lib64/libchrome.so`, `lib64/libevent.so` | 0644 | `vendor_file` | libevent from H.40 system/lib64 (vendor namespace cannot see /system/lib64) |
| `lib64/libport_shim_trim.so` | 0644 | `vendor_file` | android::base::Trim shim, source `tools/live/odm-shim/` (already part of the charger/cryptoeng bake) |
| `etc/libese-nxp.conf` | 0644 | `u:object_r:vendor_configs_file:s0` | identical to stock |
| `etc/init/android.hardware.secure_elementnq330@1.1-service.rc` | 0644 | `vendor_configs_file` | `setenv LD_PRELOAD /odm/lib64/libport_shim_trim.so`, `oneshot`, post-fs-data: mkdir /data/vendor/secure_element 0777, chmod 0660 + chown secure_element /dev/p73, `setprop vendor.nfc_se.config_ready true` |
| `etc/vintf/manifest/manifest_port_secure_element.xml` | 0644 | `vendor_configs_file` | eSE1 @1.1 + `vendor.nxpnq330.nxpese@1.0::INxpEse/default` + `vendor.nxp.eventprocessor@1.0::INxpEseEvtProcessor/default` (without the last two the HAL aborts at registration) |

Notes
- Most of the libs were already in the odm partition from build 17 (see `install.list` in `tools/live/odm-services`); only the binary, rc and vintf fragment were dropped in 17b. Check `lib64/*` against `vendor-odm.SHA256SUMS` rather than assuming.
- Also needed: `com.android.se` must be enabled/unhidden (live fix: `pm unhide com.android.se; pm enable com.android.se`; it is persistent LOS24 `SecureElement.apk` in system_ext/app) and the `android.se.omapi` AIDL declaration in `manifest_oplus_charger.xml` (already in 17b).
- Kernel side: `out-ese/boot-ese-final.img` (kernel `CONFIG_NFC_P73_ESE=y` + nq-nci eSE power pin quirk TLMM49). Without that kernel `/dev/p73` is missing and the HAL (oneshot) just exits once per boot.
- Known limitation: each eSE open waits ~10 s (5 x 2 s `omapi_status` retries) because the NFC HAL does not serve the HIDL ioctl interface.
