# Build sources

This release folder carries the exact 17d builder/preflight scripts and the eSE kernel sources needed to inspect or reproduce the image set. The ZIP installers are standalone and do not read these source files at install time.

The production-property system image was rebuilt with `PROD_PROPS=1`, then finalized and preflighted with:

```text
PROD_PROPS=1 GSI=ColorOS17-PLK110/system.img W=/root/port17d-rootless OUT=release/17d/images/rootless GSI_MNT=/mnt/plk FBE_MODE=standard tools/build-port-b.sh
PROD_PROPS=1 OUT=release/17d/images/rootless tools/preflight-b.sh
release/17d/scripts/finalize-production-system-wsl.sh
```

The shipped `images/system.img` has `ro.secure=1`, `ro.debuggable=0`, `ro.adb.secure=1`, and no builder ADB key. Filesystem comparison confirmed the intended `system/build.prop` difference only. The shipped vendor and `my_stock` images are copied from the original preflighted 17d build.

Reproduction still requires the repository donor inputs (`ColorOS17-PLK110`, `LineageOS24`, `stock-app-source`, `StockRom/H40-images`) and the external WSL kernel/toolchain tree described by `tools/ese-build-kernel.sh`. Large donor and kernel source archives are not duplicated in this release directory. The user-provided Quark share and its extraction code are recorded in [`images/README.md`](images/README.md); the referenced files have not been independently inventoried here. Verify each file against the expected SHA-256 before using it.

The checked-in release source is intended to contain scripts, documentation, logs, and checksums only. `release/17d/.gitignore` excludes local image files and generated ZIPs. The current build helpers are WSL/local-input workflows, not a ready-to-run hosted Actions pipeline: a future workflow needs a runner with the required build toolchain and a secure way to provide the donor inputs. Do not place the Quark extraction code in workflow logs or other public workflow output.

Included snapshot files:

- `source/tools/build-port-b.sh`
- `source/tools/preflight-b.sh`
- `source/tools/make-mystock-merged.sh`
- `source/tools/ese-build-kernel.sh`
- `source/tools/bootimg_v2.py`
- `source/tools/live/ese-kernel/BAKING.md`
- `source/tools/live/ese-kernel/vendor-odm.SHA256SUMS`
- `source/research/ese-p73/port/los-nfc-p73.patch`
- `source/research/ese-p73/port/p73.c`
- `source/research/ese-p73/phone.config`

The release-only WSL build helper and comparison helper are in `scripts/`.
