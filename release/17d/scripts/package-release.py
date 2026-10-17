from __future__ import annotations
import hashlib
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
REL = ROOT / "release" / "17d"
OUT_NOROOT = REL / "OnePlus7Pro-17d-NoRoot.zip"
OUT_MAGISK = REL / "OnePlus7Pro-17d-Magisk31.zip"
CHUNK = 1024 * 1024

IMAGES = {
    "images/bootstrap-system.img": (ROOT / "out-plk-build17d" / "system.img", "2d2b4c07ceebcda8b61100467f768fa0dba4baf0440c53c82777e0ea094f18c8"),
    "images/system.img": (REL / "images" / "system.img", "d56f80b4ea9d39338e954127bdefb1e56d4eab77ff8b4498f79ac0124db390d2"),
    "images/vendor.img": (ROOT / "out-plk-build17d" / "vendor.img", "b55bc1810bd49aebae3c34f56e8e098e440f98ce4f5c6a215a16f1f3bfa729f6"),
    "images/my_stock.img": (ROOT / "out-plk-build17d" / "my_stock.img", "fac842d6d7ca732c1d5dd7f356cfae1991ee9433f88e89b6e3370a1336811760"),
    "images/boot-ese-final.img": (ROOT / "out-ese" / "boot-ese-final.img", "a96c205d24598b824c9e119e48cd7b363151920b21ab351e971539511e3cbe91"),
    "images/boot-magisk31-17d.img": (REL / "images" / "boot-magisk31-17d.img", "b073b02da7c29f00f54e510fb4e6a7304d49c5c5df89f684f81d69fa90d4e155"),
    "images/Magisk-v31.0.apk": (REL / "images" / "Magisk-v31.0.apk", "2c8a488b9a5293e578e95ae4f07e3c57aba4feec4a52ca4dd852a2692d6dd4e8"),
}

def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(CHUNK), b""):
            h.update(block)
    return h.hexdigest()

def write_sums(path: pathlib.Path, names: list[str]) -> None:
    lines = [f"{IMAGES[name][1]}  {name}" for name in names]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")

def make_zip(output: pathlib.Path, package_dir: pathlib.Path, images: list[str], docs: list[tuple[pathlib.Path, str]]) -> None:
    if output.exists():
        output.unlink()
    write_sums(package_dir / "SHA256SUMS", images)
    items = [(IMAGES[name][0], name) for name in images]
    items += docs
    items.append((package_dir / "SHA256SUMS", "SHA256SUMS"))
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as zf:
        for source, arcname in items:
            if not source.is_file():
                raise FileNotFoundError(source)
            print(f"Adding {arcname} ({source.stat().st_size} bytes)", flush=True)
            zf.write(source, arcname, compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)
    print(f"Created {output.name}: {output.stat().st_size} bytes; checking ZIP CRCs", flush=True)
    with zipfile.ZipFile(output, "r") as zf:
        bad = zf.testzip()
        if bad:
            raise RuntimeError(f"Bad ZIP entry: {bad}")
        expected = set(images) | {arc for _, arc in docs} | {"SHA256SUMS"}
        actual = set(zf.namelist())
        if actual != expected:
            raise RuntimeError(f"ZIP entry list mismatch: missing={sorted(expected-actual)} extra={sorted(actual-expected)}")
    print(f"ZIP integrity PASS: {output.name}", flush=True)

for name, (source, expected) in IMAGES.items():
    actual = sha256(source)
    if actual != expected:
        raise RuntimeError(f"SHA-256 mismatch for {source}: {actual} != {expected}")
    print(f"SHA-256 PASS: {name}", flush=True)

noroot_images = ["images/bootstrap-system.img", "images/system.img", "images/vendor.img", "images/my_stock.img", "images/boot-ese-final.img"]
root_images = ["images/system.img", "images/vendor.img", "images/my_stock.img", "images/boot-magisk31-17d.img", "images/Magisk-v31.0.apk"]
if "--magisk-only" not in sys.argv:
    make_zip(OUT_NOROOT, REL / "packages" / "no-root", noroot_images, [
        (REL / "packages" / "no-root" / "README.md", "README.md"),
        (REL / "packages" / "no-root" / "Install-17d.ps1", "Install-17d.ps1"),
        (REL / "packages" / "no-root" / "Install-17d.sh", "Install-17d.sh"),
        (REL / "packages" / "no-root" / "Install-17d.bat", "Install-17d.bat"),
    ])
make_zip(OUT_MAGISK, REL / "packages" / "magisk", root_images, [
    (REL / "packages" / "magisk" / "README.md", "README.md"),
    (REL / "packages" / "magisk" / "Install-17d.ps1", "Install-17d.ps1"),
    (REL / "packages" / "magisk" / "Install-17d.sh", "Install-17d.sh"),
    (REL / "packages" / "magisk" / "Install-17d.bat", "Install-17d.bat"),
])

