# 17k release facts

## Target and behaviour

- Target: OnePlus 7 Pro GM1910 / PLK110 (`guacamole`; the bootloader reports fastboot product `msmnile` on the author's phone), ColorOS 17 PLK110 donor on the LineageOS 24 vendor and kernel.
- Build 17k = 17j-r2 (system/my_stock/boot unchanged, incl. the B18 wallpaper-saver fix) + B20 charging-limit enforcer + B21 real-gauge level in the vendor image ([docs/CHANGELOG-17k.md](docs/CHANGELOG-17k.md)).
- Installers: upgrade only, no data wipe (no `fastboot -w`, no format/erase, no WIPE prompt; the packager refuses to render one). They flash only the active slot's `vendor`, `system`, `boot` and replace `/data/port/my_stock.img` after verifying its SHA-256 (old one kept as `my_stock-prev.img`).
- Final system (both bundles): production properties (`ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`), no builder ADB key. `bootstrap-system.img` (NoRoot bundle only) = the development build with adb root.

## Image hashes

| Image | SHA-256 | Size (bytes) | Source / role |
|---|---|---|---|
| `system.img` | `0b24fcb2d323f406deba2ed4c46a8edb38c4532bde0b44b026c0a9e8373af3b9` | 3,640,655,872 | 17j-r2 production system (unchanged); both bundles |
| `bootstrap-system.img` | `e64a10ca29f384a877b223f255150dd8bb3616321f3b51e9b6f9c5ec43dc5726` | 3,640,655,872 | 17j-r2 development system (adb root) = `out-plk-build17k/system.img` |
| `vendor.img` | `d7e9a440d5a0fb6cbb7f3de6d3b04639488a262bcaaac4a6c072776da5fbe874` | 1,073,741,824 | 17j-r2 vendor (`d8f45456...`) + 4 odm files B20/B21 |
| `my_stock.img` | `135022d0d5816296a365cb39e920a73c0eabc32ff4f5be18dfa70c86d203c189` | 6,917,992,448 | 17j-r2 my_stock, byte-identical; NOT rebuildable (source gone) |
| `boot-ese-final.img` | `a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91` | 100,663,296 | 17d eSE-kernel boot |
| `boot-magisk31-17d.img` | `b073b02da7c29f00f54e510fb4e6a7304d49c5c5df89f684f81d69fa90d4e155` | 100,663,296 | Magisk v31.0 patch of it |
| `Magisk-v31.0.apk` | `2c8a488b9a5293e578e95ae4f07e3c57aba4feec4a52ca4dd852a2692d6dd4e8` | 11,248,935 | Magisk |

B20/B21 files (sources `tools/live/odm-services/port/...`): `bin/port-chglimit.sh` `ac6aa905f3cf632af216a26989275a947370653541c3ce761bf5308783e1fd69` (uses `/sys/class/oplus_chg/battery/mmi_charging_enable` when present, else `power_supply/battery/`), `etc/init/port-chglimit.rc` `72d396c8...943a`, `bin/port-bmslevel.sh` `6344969d...094e`, `etc/init/port-bmslevel.rc` `74ce260a...316b`. Installed to `/vendor/odm/bin` 0755 `vendor_file` and `/vendor/odm/etc/init` 0644 `vendor_configs_file`; rc `seclabel u:r:su:s0`.

## Verification

- `tools/preflight-b.sh` development set (system `e64a10ca`, vendor `d7e9a440`, boot, my_stock): **PREFLIGHT PASS** (`logs/preflight-17k-development.txt`), includes the new "B20+B21" section.
- `PROD_PROPS=1 tools/preflight-b.sh` production system `0b24fcb2` + 17k vendor/boot/my_stock: **PREFLIGHT PASS** (`logs/preflight-17k-production.txt`).
- Vendor file-level diff vs 17j-r2 vendor: only the four B20/B21 odm files (`logs/vendor-17j-vs-17k-diff.txt`).
- Live (2026-11-04, 17j-r2 phone, scripts started by hand): B20 hold/release at a lowered limit, B21 gauge tracking; chglimit with the node fallback started on the phone 2026-11-06 and left mmi untouched (below limit).

## Not verified

- 17k was flashed once and booted on the author's phone (2026-11-06; TEST-STATUS.md): `port_chglimit` / `port_bmslevel` start from /odm at boot and the gauge matches. The real 85 % crossing and the B18 saver across reboots are still untested; only the Magisk `.sh` installer has been run. Idle drain (~150 mA screen-off) is not fixed. B19 experiments are not included.
- The oplus_chg node path fallback in port-chglimit.sh is untested on a kernel that has that path (the port's kernel does not).
