# Build sources

17k reuses the finished 17j-r2 system images and my_stock and rebuilds only the vendor image:

- `system.img` (production) / `bootstrap-system.img` (development): the 17j-r2 rebuild of 2026-11-05 (`release/17j/scripts/build-17j-r2-wsl.sh` + `finalize-production-system-r2-wsl.sh`), reused byte-for-byte.
- `my_stock.img`: reused byte-for-byte from 17j-r2. **It cannot be rebuilt**: its source (`stock-app-source/extracted/my_stock.img`) no longer exists, and a fresh `build-port-b.sh` run would silently drop about 504 stock app files. Keep this file.
- `vendor.img`: `scripts/build-17k-vendor.sh` copies the 17j-r2 vendor (`d8f45456...`), mounts it read-write and installs the four B20/B21 odm files exactly as `tools/build-port-b.sh` does from `tools/live/odm-services/install.list` (modes 0755/0644, labels vendor_file / vendor_configs_file), fsck, dd. Log `logs/build-vendor.txt`. (`tools/build-port-b.sh` itself installs the same four files in a full build; B20/B21 are in install.list/SHA256SUMS.)
- `scripts/build-17k-assemble.sh`: assembles `out-plk-build17k/`, runs `tools/preflight-b.sh` for the development pair and the production pair (`PROD_PROPS=1`), diffs the vendor against 17j-r2 (`logs/preflight-17k-*.txt`, `logs/vendor-17j-vs-17k-diff.txt`).
- `scripts/package-release.py` (`uv run python -I`): copies images, renders installers from `scripts/templates/`, writes SHA256SUMS, builds and CRC-tests the ZIPs, writes `RELEASE-SHA256SUMS.txt`.
- preflight additions for 17k (in `tools/preflight-b.sh`): section "B20+B21" (presence, sha, modes, labels, no CRLF, rc content of port-chglimit / port-bmslevel).

Inputs for a from-scratch rebuild: `ColorOS17-PLK110/`, `LineageOS24/`, `StockRom/H40-images/`, `tools/live/**`, the AVB key `tools/avb/port_key.pem`, and a my_stock source (gone; use `images/my_stock.img`). See [images/README.md](images/README.md).
