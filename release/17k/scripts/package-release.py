"""17k-r2 release packager: copies the images into release/17k/images, renders the installers from scripts/templates,
writes the per-package SHA256SUMS, builds the two ZIPs, CRC-tests them and writes RELEASE-SHA256SUMS.txt.
Run from the repository root:  uv run python -I release/17k/scripts/package-release.py [--no-zip] [--no-copy]
"""
from __future__ import annotations
import hashlib
import pathlib
import re
import shutil
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
REL = ROOT / "release" / "17k"
TPL = REL / "scripts" / "templates"
OUT = ROOT / "out-plk-build17k-r2"
R17D = ROOT / "release" / "17k" / "images"  # kept 17d boot images + Magisk, carried through 17j (copied once from release/17j/images)
R17J = ROOT / "release" / "17j" / "images"
PROD_SYSTEM_SHA = "0b24fcb2d323f406deba2ed4c46a8edb38c4532bde0b44b026c0a9e8373af3b9"  # production system of the 17j-r2 rebuild (B18 saver fix), reused unchanged
CHUNK = 4 * 1024 * 1024

# published name -> source file. Boot images and Magisk are 17d's (the 17k build's boot.img has the same ramdisk/cmdline
# but the plain LineageOS kernel; boot-ese-final.img is the eSE-kernel build of it, see logs/boot-compare.txt).
SOURCES = {
    "images/bootstrap-system.img": OUT / "system.img",          # 17k development system (adb root): no-root staging only
    "images/system.img": R17J / "system.img",                   # 17j-r2 production-property system (B18 saver fix), reused byte-for-byte
    "images/vendor.img": OUT / "vendor.img",
    "images/my_stock.img": R17J / "my_stock.img",               # byte-identical to out-plk-build17k-r2/my_stock.img (source tree gone: never rebuild)
    "images/boot-ese-final.img": R17D / "boot-ese-final.img",
    "images/boot-magisk31-17d.img": R17D / "boot-magisk31-17d.img",
    "images/Magisk-v31.0.apk": R17D / "Magisk-v31.0.apk",
}
KNOWN = {  # fixed inputs carried from 17d
    "images/boot-ese-final.img": "a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91",
    "images/boot-magisk31-17d.img": "b073b02da7c29f00f54e510fb4e6a7304d49c5c5df89f684f81d69fa90d4e155",
    "images/Magisk-v31.0.apk": "2c8a488b9a5293e578e95ae4f07e3c57aba4feec4a52ca4dd852a2692d6dd4e8",
}
PACKAGES = {
    "no-root": ("noroot", "NoRoot", "OnePlus7Pro-17k-r2-NoRoot.zip",
                ["images/bootstrap-system.img", "images/system.img", "images/vendor.img", "images/my_stock.img", "images/boot-ese-final.img"]),
    "magisk": ("magisk", "Magisk 31", "OnePlus7Pro-17k-r2-Magisk31.zip",
               ["images/system.img", "images/vendor.img", "images/my_stock.img", "images/boot-magisk31-17d.img", "images/Magisk-v31.0.apk"]),
}


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(CHUNK), b""):
            h.update(block)
    return h.hexdigest()


def build_sums() -> dict[str, str]:
    sums = {}
    built = {}
    for line in (OUT / "SHA256SUMS").read_text().split("\n"):
        if line.strip():
            h, n = line.split()
            built[n.lstrip("*")] = h
    prod = PROD_SYSTEM_SHA
    for name, src in SOURCES.items():
        print(f"hashing {src}", flush=True)
        sums[name] = sha256(src)
    want = {"images/bootstrap-system.img": built["system.img"], "images/vendor.img": built["vendor.img"],
            "images/my_stock.img": built["my_stock.img"], "images/system.img": prod, **KNOWN}
    for name, h in want.items():
        if sums[name] != h:
            raise RuntimeError(f"SHA-256 mismatch {name}: {sums[name]} != {h}")
    return sums


def render(template: str, variant: str, vname: str, images: list[str], sums: dict[str, str], ps: bool) -> str:
    s = (TPL / template).read_text(encoding="utf-8")
    if ps:
        checks = "\n".join(f"Check-Image (Join-Path $script:Root '{n}') '{sums[n]}'" for n in images)
    else:
        checks = "\n".join(f"check_image {n} {sums[n]}" for n in images)
    size = SOURCES["images/my_stock.img"].stat().st_size
    out = (s.replace("@VARIANT@", variant).replace("@VARIANT_NAME@", vname).replace("@CHECK_IMAGES@", checks)
           .replace("@SHA_MY_STOCK@", sums["images/my_stock.img"]).replace("@SIZE_MY_STOCK@", str(size)))
    if any(t in out for t in ("@VARIANT", "@SHA_", "@SIZE_", "@CHECK_")):
        raise RuntimeError("unfilled placeholder in " + template)
    code = "\n".join(l for l in out.split("\n") if not l.lstrip().startswith("#"))
    for pat in (r"fastboot\S*\s[^\n]*\s-w\b", r"\bF\s+-w\b", r"'-w'", r"\bWIPE\b", r"\berase\b", r"\bformat\b"):
        if re.search(pat, code):
            raise RuntimeError(f"installer {template} contains a wipe/format/erase command ({pat})")
    return out


def bat(ps1: str) -> str:
    return ("@echo off\r\nsetlocal\r\nwhere powershell.exe >nul 2>nul || (echo PowerShell was not found. & exit /b 1)\r\n"
            f"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%~dp0{ps1}\" %*\r\nexit /b %errorlevel%\r\n")


def write(path: pathlib.Path, text: str, crlf: bool = False) -> None:
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n" if crlf else "\n").encode("utf-8"))


def make_zip(output: pathlib.Path, pkg: pathlib.Path, images: list[str]) -> None:
    if output.exists():
        output.unlink()
    items = [(REL / n, n) for n in images]
    items += [(pkg / f, f) for f in ("README.md", "Install-17k.ps1", "Install-17k.sh", "Install-17k.bat", "SHA256SUMS")]
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as zf:
        for src, arc in items:
            print(f"Adding {arc} ({src.stat().st_size} bytes)", flush=True)
            if arc == "Install-17k.sh":
                zi = zipfile.ZipInfo.from_file(src, arc); zi.external_attr = (0o100755 << 16); zi.compress_type = zipfile.ZIP_DEFLATED
                zf.writestr(zi, src.read_bytes())
            else:
                zf.write(src, arc)
    print(f"Created {output.name}: {output.stat().st_size} bytes; testing CRCs", flush=True)
    with zipfile.ZipFile(output) as zf:
        bad = zf.testzip()
        if bad:
            raise RuntimeError(f"bad ZIP entry {bad}")
        if set(zf.namelist()) != {a for _, a in items}:
            raise RuntimeError("ZIP entry list mismatch")
    print(f"ZIP integrity PASS: {output.name}", flush=True)


def main() -> None:
    if "--no-copy" not in sys.argv:
        for name, src in SOURCES.items():
            dst = REL / name
            if dst.resolve() == src.resolve():
                continue
            if dst.exists() and dst.stat().st_size == src.stat().st_size and sha256(dst) == sha256(src):
                continue
            print(f"copy {src} -> {dst}", flush=True)
            shutil.copyfile(src, dst)
    sums = build_sums()
    for name in SOURCES:
        if sha256(REL / name) != sums[name]:
            raise RuntimeError(f"release copy {name} differs from its source")
    for pdir, (variant, vname, zname, images) in PACKAGES.items():
        pkg = REL / "packages" / pdir
        write(pkg / "Install-17k.sh", render("Install-17k.sh.in", variant, vname, images, sums, False))
        write(pkg / "Install-17k.ps1", render("Install-17k.ps1.in", variant, vname, images, sums, True), crlf=True)
        write(pkg / "Install-17k.bat", bat("Install-17k.ps1"), crlf=True)
        write(pkg / "SHA256SUMS", "".join(f"{sums[n]}  {n}\n" for n in images))
        tag = "NoRoot" if variant == "noroot" else "Magisk"
        shutil.copyfile(pkg / "Install-17k.sh", REL / f"Install-17k-{tag}.sh")
        shutil.copyfile(pkg / "Install-17k.ps1", REL / f"Install-17k-{tag}.ps1")
        write(REL / f"Install-17k-{tag}.bat", bat(f"Install-17k-{tag}.ps1"), crlf=True)
        shutil.copyfile(pkg / "README.md", REL / f"README-{tag}.md")
    write(REL / "images" / "SHA256SUMS", "".join(f"{sums[n]}  {n}\n" for n in SOURCES))
    if "--no-zip" in sys.argv:
        return
    lines = []
    for pdir, (variant, vname, zname, images) in PACKAGES.items():
        z = REL / zname
        make_zip(z, REL / "packages" / pdir, images)
        lines.append(f"{sha256(z)}  {zname}")
    write(REL / "RELEASE-SHA256SUMS.txt", "\n".join(lines) + "\n")
    print((REL / "RELEASE-SHA256SUMS.txt").read_text())


if __name__ == "__main__":
    main()
