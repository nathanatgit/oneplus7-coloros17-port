# OnePlus 7 Pro — ColorOS 17 port

ColorOS 17 (PLK110 donor GSI) running on the OnePlus 7 Pro (`guacamole`, SM8150) on top of a LineageOS 24 kernel and vendor, with selected stock H.40 pieces (camera, odm HALs). Slot A stays stock H.40; the port lives on slot B.

Current release: **17k** (local test release, not production). 17k is a no-wipe upgrade for a phone that already runs the port; 17d was the last full-install release.
**Download (17k-r2 ZIPs and images, Quark share):** <https://pan.quark.cn/s/3dfce1464625?pwd=5VTb> — extraction code `5VTb`. Check each file against `release/17k/RELEASE-SHA256SUMS.txt` before flashing.

| Start here | |
| --- | --- |
| [release/17k/README.md](release/17k/README.md) | What the release contains and how to install it |
| [release/17k/docs/README.md](release/17k/docs/README.md) | Documentation index: architecture, fixes and patches, discoveries, merge principles, open items |
| [release/17k/FACTS.md](release/17k/FACTS.md) | Hashes and verified facts of the shipped images |
| [release/17k/BUILD_SOURCES.md](release/17k/BUILD_SOURCES.md) | Build inputs and how to rebuild |
| [release/17d/source/history/](release/17d/source/history/) | Original working handoffs and test notes, 2026-10-14 to 2026-10-17 |

Binary images and release ZIPs are not stored in Git. The 17k installers keep userdata (upgrade only); a first install on a fresh phone follows the 17d flow, which wipes userdata. Read the release README first.
