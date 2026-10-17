# Cumulative source archive for the first 17d release

This first release is a cumulative snapshot of the OnePlus 7 Pro port work through build 17d. It is cut off before later 17e changes. The main reproducer sources remain in `../` (`build-port-b.sh`, `preflight-b.sh`, boot/eSE tooling, and the kernel patch). `tools/` and `research/` here preserve prior build helpers, one-off diagnostics, patch scripts, and patch files that were developed across earlier builds but were not in the original narrow source snapshot. `../history/` carries the sanitized build and fix handoffs.

## Scope

- Includes project shell, Python, PowerShell, batch, C/C++/header, patch, init-RC, and small text/config sources from `tools/` and `research/`.
- Includes the historical build helper scripts and the research patch files; reference patches are preserved as references and are not asserted to be shipped/applied.
- Does not include donor ROMs, extracted/decompiled donor APK trees, generated system/vendor/boot images, compiled APK/SO/DEX/JAR outputs, external tool binaries, or signing/private keys. Shipped behavior is represented by the release images; source recreation still requires the documented donor inputs and toolchains.
- Binary inputs and generated outputs are intentionally outside this source archive. Their provenance and SHA-256 checks are recorded in the build notes where available.

See `SOURCE_ARCHIVE_FILES.txt` for the exact included file list and `SOURCE_ARCHIVE_SHA256SUMS.txt` for integrity checks.


