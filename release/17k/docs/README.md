# 17j docs — what is in this build and why (17k-r2 adds B22 + B24/B25b + B26, 17k-r3 adds B27; see CHANGELOG-17k.md)

17j = the 17d release + everything built and verified on the author's phone since (17e–17i) + the 17j bake (donor camera, battery
drain fixes, H.40 props, identity, wallpaper keeper). Read in this order:

| File | What it is |
| --- | --- |
| [CHANGELOG-17k.md](CHANGELOG-17k.md) | Changes in 17k (older: CHANGELOG-17j-history.md); every change since 17d, per build, with its verification status |
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the pieces fit: LineageOS 24 base, ColorOS 17 donor, stock H.40 parts, partitions, boot chain (17d text + 17j notes at the end) |
| [FIXES-AND-PATCHES.md](FIXES-AND-PATCHES.md) | The 17d fix catalogue (symptom, root cause, patch, status); later fixes are in the changelog |
| [DISCOVERIES.md](DISCOVERIES.md) | Facts learned while porting (hardware, firmware, ColorOS internals, tooling quirks) |
| [PRINCIPLES.md](PRINCIPLES.md) | Rules for merging and patching so a new fix does not break the working build |
| [OPEN-ITEMS.md](OPEN-ITEMS.md) | Not in 17j, known issues, first-boot checks, rollback |

The authoritative per-item record (evidence, live test, revert) is `tools/live/BAKE-LIST.md` in the repository; this release carries
a snapshot in `../source/tools/live/BAKE-LIST.md`.
