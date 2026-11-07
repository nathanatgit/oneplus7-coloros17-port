# Build sources

**17k-r3 (2026-11-07):** only the vendor was rebuilt again: `scripts/build-17k-r3-vendor.sh` copies the rebuilt r2 vendor (`out-plk-build17k-r2/vendor-r2-final.img`, `e61b3b19...`) and installs `port-offlinecam-stub.rc` from `tools/live/odm-services/install.list` (0644 `vendor_configs_file`) -> vendor `3805ab33c05fd2843e66daee449532df8f67ccd659de598dd448dc04f4f198a7`. `scripts/build-17k-r3-assemble.sh` assembles `out-plk-build17k-r3/` (system / my_stock / boot reused byte-for-byte), runs the preflight (dev + prod) and the vendor diff vs r2. `package-release.py` writes the images, installers and ZIPs.

**17k-r2 rebuilt (2026-11-07):** `scripts/build-17k-r2-vendor.sh` now also installs `port-slider-hold.dex`, `port-sliderdex.sh`, `port-sliderdex.rc` (install.list) and writes the two audio policy XMLs from `tools/live/audio-policy-1input/` into the existing inodes (`cat >`, labels kept) after checking the vendor's files equal the `.orig` ones; result `vendor.img` `e61b3b199ae48f3518119d489aced6425fec0f8bb086f8537f50e382be731f3c`. `scripts/build-17k-r2-assemble.sh` additionally diffs against the previous r2 vendor. system / boot / my_stock unchanged.

**17k-r2 (2026-11-06, first build):** only the vendor was rebuilt again: `scripts/build-17k-r2-vendor.sh` copies the FIRST 17k vendor (`out-plk-build17k/vendor.img`, `d7e9a440...`), installs `port-netguard.sh` / `.rc` from `tools/live/odm-services/install.list` (0755 `vendor_file`, 0644 `vendor_configs_file`), fsck, dd to `out-plk-build17k-r2/vendor.img` (3a70f811...). `scripts/build-17k-r2-assemble.sh` assembles `out-plk-build17k-r2/` (system `e64a10ca` / boot / my_stock `135022d0` copied byte-for-byte), runs the development and production preflight and the vendor diff (`logs/preflight-17k-r2-*.txt`, `logs/vendor-17k-vs-17k-r2-diff.txt`). `scripts/package-release.py` now reads `out-plk-build17k-r2` and writes `OnePlus7Pro-17k-r2-*.zip`. The installer templates gained the `net_guard` / `Invoke-NetGuard` step. my_stock was NOT rebuilt (source gone).

The text below describes the first 17k build, which r2 builds on.

17k reuses the finished 17j-r2 system images and my_stock and rebuilds only the vendor image:

- `system.img` (production) / `bootstrap-system.img` (development): the 17j-r2 rebuild of 2026-11-05 (`release/17j/scripts/build-17j-r2-wsl.sh` + `finalize-production-system-r2-wsl.sh`), reused byte-for-byte.
- `my_stock.img`: reused byte-for-byte from 17j-r2. **It cannot be rebuilt**: its source (`stock-app-source/extracted/my_stock.img`) no longer exists, and a fresh `build-port-b.sh` run would silently drop about 504 stock app files. Keep this file.
- `vendor.img`: `scripts/build-17k-vendor.sh` copies the 17j-r2 vendor (`d8f45456...`), mounts it read-write and installs the four B20/B21 odm files exactly as `tools/build-port-b.sh` does from `tools/live/odm-services/install.list` (modes 0755/0644, labels vendor_file / vendor_configs_file), fsck, dd. Log `logs/build-vendor.txt`. (`tools/build-port-b.sh` itself installs the same four files in a full build; B20/B21 are in install.list/SHA256SUMS.)
- `scripts/build-17k-assemble.sh`: assembles `out-plk-build17k/`, runs `tools/preflight-b.sh` for the development pair and the production pair (`PROD_PROPS=1`), diffs the vendor against 17j-r2 (`logs/preflight-17k-*.txt`, `logs/vendor-17j-vs-17k-diff.txt`).
- `scripts/package-release.py` (`uv run python -I`): copies images, renders installers from `scripts/templates/`, writes SHA256SUMS, builds and CRC-tests the ZIPs, writes `RELEASE-SHA256SUMS.txt`.
- preflight additions for 17k (in `tools/preflight-b.sh`): section "B20+B21" (presence, sha, modes, labels, no CRLF, rc content of port-chglimit / port-bmslevel).

Inputs for a from-scratch rebuild: `ColorOS17-PLK110/`, `LineageOS24/`, `StockRom/H40-images/`, `tools/live/**`, the AVB key `tools/avb/port_key.pem`, and a my_stock source (gone; use `images/my_stock.img`). See [images/README.md](images/README.md).
