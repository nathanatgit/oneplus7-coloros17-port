"""Patch the stock camera to omit its preview-frame callback reader.

This narrow diagnostic patch changes the first instruction in
OPNormalCamcorderImpl.onSelectPreviewFrameCallbackSize into a DEX goto to the
method's existing OperationResult.NONE return path. The target APK's DEX
layout is checked before editing; DEX digests and the ZIP CRC are then rebuilt
without changing ZIP entry offsets.
"""
from __future__ import annotations

import hashlib
import pathlib
import struct
import sys
import zipfile
import zlib


DEX_OFFSET = 0x88FAC0
EXPECTED_INSN = bytes.fromhex("1a00 33a5")
PATCHED_INSN = bytes.fromhex("28 42 00 00")  # goto +0x42, nop -> sget NONE; return


def patch(source_path: pathlib.Path, output_path: pathlib.Path) -> None:
    raw = bytearray(source_path.read_bytes())
    with zipfile.ZipFile(source_path) as source:
        info = source.getinfo("classes.dex")
        if info.compress_type != zipfile.ZIP_STORED or info.file_size != info.compress_size:
            raise RuntimeError("classes.dex must be stored for offset-preserving patching")
        local_header = info.header_offset
        name_len, extra_len = struct.unpack_from("<HH", raw, local_header + 26)
        dex_offset = local_header + 30 + name_len + extra_len
        dex = bytearray(raw[dex_offset:dex_offset + info.file_size])
        if len(dex) != info.file_size:
            raise RuntimeError("classes.dex payload is truncated")
        if dex[DEX_OFFSET:DEX_OFFSET + len(EXPECTED_INSN)] != EXPECTED_INSN:
            raise RuntimeError("DEX method offset or original instruction differs from inspected APK")

        dex[DEX_OFFSET:DEX_OFFSET + len(PATCHED_INSN)] = PATCHED_INSN
        dex[12:32] = hashlib.sha1(dex[32:]).digest()
        struct.pack_into("<I", dex, 8, zlib.adler32(dex[12:]) & 0xFFFFFFFF)
        crc = zlib.crc32(dex) & 0xFFFFFFFF
        raw[dex_offset:dex_offset + len(dex)] = dex
        struct.pack_into("<I", raw, local_header + 14, crc)

        cursor = source.start_dir
        central_records = 0
        while cursor + 46 <= len(raw) and raw[cursor:cursor + 4] == b"PK\x01\x02":
            name_size, extra_size, comment_size = struct.unpack_from("<HHH", raw, cursor + 28)
            entry_name = bytes(raw[cursor + 46:cursor + 46 + name_size]).decode("utf-8")
            if entry_name == "classes.dex":
                struct.pack_into("<I", raw, cursor + 16, crc)
                central_records += 1
            cursor += 46 + name_size + extra_size + comment_size
        if central_records != 1:
            raise RuntimeError(f"Expected one central directory record, found {central_records}")

    output_path.write_bytes(raw)
    with zipfile.ZipFile(source_path) as source, zipfile.ZipFile(output_path) as output:
        if output.testzip() is not None:
            raise RuntimeError("ZIP CRC validation failed")
        patched_dex = output.read("classes.dex")
        if hashlib.sha1(patched_dex[32:]).digest() != patched_dex[12:32]:
            raise RuntimeError("DEX SHA-1 validation failed")
        checksum, = struct.unpack_from("<I", patched_dex, 8)
        if checksum != (zlib.adler32(patched_dex[12:]) & 0xFFFFFFFF):
            raise RuntimeError("DEX Adler-32 validation failed")
        changed_offsets = [
            entry.filename
            for entry in output.infolist()
            if entry.filename.endswith(".so")
            and source.getinfo(entry.filename).header_offset != entry.header_offset
        ]
        if changed_offsets:
            raise RuntimeError(f"Native library offsets changed: {changed_offsets[:3]}")
    print(
        f"patched={output_path} size={output_path.stat().st_size} "
        f"sha256={hashlib.sha256(output_path.read_bytes()).hexdigest()} "
        f"dex_sha256={hashlib.sha256(patched_dex).hexdigest()}"
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch_disable_preview_callback.py input.apk output.apk")
    patch(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
