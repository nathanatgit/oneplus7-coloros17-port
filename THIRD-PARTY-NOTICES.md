# Third-party notices

The original work in this repository (build scripts, installers, patches written for this port, documentation) is licensed under the Apache License 2.0, see `LICENSE`. The items below keep their own licenses. This list was written from file names and what is known about those projects; it is not a legal audit, and license files are not always present next to the copies.

## Projects this port is built on (not included in this repository)
| Project | Used for | License |
| --- | --- | --- |
| [LineageOS](https://lineageos.org/) (`android_kernel_oneplus_sm8150`, device trees, vendor, nightlies) | Kernel and vendor layer | Linux kernel: GPL-2.0; Android userspace and device trees: mostly Apache-2.0 |
| [Axis GSI](https://sourceforge.net/projects/axisgsiupdates/) (ColorOS 17 PLK110 GSI) | System donor | Contains OPPO ColorOS software, which remains OPPO's property; see the Axis GSI project's own terms |
| OnePlus 7 Pro H.40 and OPPO PLK110 stock firmware | Camera stack, HAL services, my_stock apps | Proprietary (OPPO / OnePlus). Not part of this repository; images are shared separately and are not licensed by this project |
| [Magisk](https://github.com/topjohnwu/Magisk) | Optional root (the APK is distributed with the release downloads, not in git) | GPL-3.0 |

## Third-party files that are in this repository
| Path (under `release/`) | What | License |
| --- | --- | --- |
| `17d/source/prior-builds/research/ese-p73/` (`p73.c`, `p73.h`, `port/los-nfc-p73.patch`) | NXP p73 eSE kernel driver and its patch for the LineageOS kernel | GPL-2.0-only (Linux kernel code); these files are NOT under Apache-2.0 |
| `*/source/**/avbtool.py` | Android Verified Boot tool, "Copyright 2016, The Android Open Source Project" | Apache-2.0 |
| `17d/source/prior-builds/tools/scrcpy/` | scrcpy launcher scripts (Genymobile) | Apache-2.0 |
| `17d/source/prior-builds/tools/live/rea-analysis/rizin-portable/` | Rizin headers (rizin.re) | LGPL-3.0 |
| `17d/source/prior-builds/tools/live/rea-analysis/jadx/` | jadx wrapper files (skylot/jadx) | Apache-2.0 |

If you are an owner of any file listed here or of anything in this repository that should not be redistributed, open an issue and it will be removed.
