"""Build an in-place ZIP/Dex patch for the SM8150 camera preview stream flag.

The patch changes only the boolean argument passed for
OPNormalCamcorder.IncludeVideoStreamInPreview from true (v4) to false (v5).
It preserves every APK entry's offset and size, including aligned native libs.
"""
from __future__ import annotations

import hashlib
import pathlib
import struct
import sys
import zipfile
import zlib


def uleb(data: bytes | bytearray, pos: int) -> tuple[int, int]:
    value = shift = 0
    while True:
        byte = data[pos]
        pos += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, pos
        shift += 7


def dex_strings(dex: bytes | bytearray) -> list[str]:
    count, offset = struct.unpack_from("<II", dex, 56)
    result = []
    for i in range(count):
        item, = struct.unpack_from("<I", dex, offset + i * 4)
        _, p = uleb(dex, item)
        end = dex.index(0, p)
        result.append(bytes(dex[p:end]).decode("utf-8", errors="replace"))
    return result


def find_flag_argument(dex: bytearray) -> int:
    strings = dex_strings(dex)
    try:
        target_string = strings.index("OPNormalCamcorder.IncludeVideoStreamInPreview")
    except ValueError as exc:
        raise RuntimeError("Target feature string is absent") from exc

    type_count, type_offset = struct.unpack_from("<II", dex, 64)
    type_strings = [strings[struct.unpack_from("<I", dex, type_offset + 4 * i)[0]] for i in range(type_count)]
    method_count, method_offset = struct.unpack_from("<II", dex, 88)
    method_ids = [struct.unpack_from("<HHI", dex, method_offset + 8 * i) for i in range(method_count)]
    class_count, class_offset = struct.unpack_from("<II", dex, 96)

    target_class = "Lcom/oneplus/camera/features/SM8150FeaturesKt;"
    for i in range(class_count):
        class_def = class_offset + 32 * i
        class_idx = struct.unpack_from("<I", dex, class_def)[0]
        if type_strings[class_idx] != target_class:
            continue
        class_data = struct.unpack_from("<I", dex, class_def + 24)[0]
        static_fields, p = uleb(dex, class_data)
        instance_fields, p = uleb(dex, p)
        direct_methods, p = uleb(dex, p)
        virtual_methods, p = uleb(dex, p)
        for _ in range(static_fields + instance_fields):
            _, p = uleb(dex, p)
            _, p = uleb(dex, p)
        # Read method lists with their per-list delta accumulators.
        q = class_data
        for _ in range(4):
            _, q = uleb(dex, q)
        for _ in range(static_fields + instance_fields):
            _, q = uleb(dex, q)
            _, q = uleb(dex, q)
        for method_total in (direct_methods, virtual_methods):
            method_idx = 0
            for _ in range(method_total):
                diff, q = uleb(dex, q)
                method_idx += diff
                _, q = uleb(dex, q)
                code_offset, q = uleb(dex, q)
                _, _, name_idx = method_ids[method_idx]
                if strings[name_idx] == "initializeSM8150Features":
                    if not code_offset:
                        raise RuntimeError("Feature initializer has no code")
                    code = code_offset
                    registers, ins, outs, tries = struct.unpack_from("<HHHH", dex, code)
                    insns_size = struct.unpack_from("<I", dex, code + 12)[0]
                    insns_start = code + 16
                    insns = bytes(dex[insns_start:insns_start + 2 * insns_size])
                    found = []
                    for pos in range(0, len(insns) - 9, 2):
                        const_word, string_idx = struct.unpack_from("<HH", insns, pos)
                        invoke_word = struct.unpack_from("<H", insns, pos + 4)[0]
                        if const_word == 0x031A and string_idx == target_string and (invoke_word & 0x00FF) == 0x006E and (invoke_word >> 12) == 3:
                            invoke_method, = struct.unpack_from("<H", insns, pos + 6)
                            registers_word, = struct.unpack_from("<H", insns, pos + 8)
                            owner_idx, _, invoke_name_idx = method_ids[invoke_method]
                            if (type_strings[owner_idx] == "Lcom/oneplus/camera/features/FeatureInitializer;"
                                    and strings[invoke_name_idx] == "set"
                                    and registers_word == 0x0430):
                                found.append(insns_start + pos + 8)
                    if len(found) != 1:
                        raise RuntimeError(f"Expected one target setter call, found {len(found)}")
                    if registers != 8 or ins > registers or tries != 0:
                        raise RuntimeError("Unexpected initializer code-item layout")
                    return found[0]
        break
    raise RuntimeError("SM8150 initializer method was not found")


def patch(src: pathlib.Path, dst: pathlib.Path) -> None:
    raw = bytearray(src.read_bytes())
    with zipfile.ZipFile(src) as archive:
        info = archive.getinfo("classes.dex")
        if info.compress_type != zipfile.ZIP_STORED or info.file_size != info.compress_size:
            raise RuntimeError("classes.dex must be stored for offset-preserving patching")
        local = info.header_offset
        name_len, extra_len = struct.unpack_from("<HH", raw, local + 26)
        data_offset = local + 30 + name_len + extra_len
        dex = bytearray(raw[data_offset:data_offset + info.file_size])
        if len(dex) != info.file_size:
            raise RuntimeError("classes.dex payload is truncated")

        arg_offset = find_flag_argument(dex)
        old, = struct.unpack_from("<H", dex, arg_offset)
        if old != 0x0430:
            raise RuntimeError(f"Unexpected flag argument word 0x{old:04x}")
        struct.pack_into("<H", dex, arg_offset, 0x0530)
        dex[12:32] = hashlib.sha1(dex[32:]).digest()
        struct.pack_into("<I", dex, 8, zlib.adler32(dex[12:]) & 0xFFFFFFFF)
        crc = zlib.crc32(dex) & 0xFFFFFFFF
        raw[data_offset:data_offset + len(dex)] = dex
        struct.pack_into("<I", raw, local + 14, crc)

        cursor = archive.start_dir
        found_central = 0
        while cursor + 46 <= len(raw) and raw[cursor:cursor + 4] == b"PK\x01\x02":
            name_size, extra_size, comment_size = struct.unpack_from("<HHH", raw, cursor + 28)
            entry_name = bytes(raw[cursor + 46:cursor + 46 + name_size]).decode("utf-8")
            if entry_name == "classes.dex":
                struct.pack_into("<I", raw, cursor + 16, crc)
                found_central += 1
            cursor += 46 + name_size + extra_size + comment_size
        if found_central != 1:
            raise RuntimeError(f"Expected one central directory record, found {found_central}")

    dst.write_bytes(raw)
    with zipfile.ZipFile(src) as source, zipfile.ZipFile(dst) as result:
        if result.testzip() is not None:
            raise RuntimeError("ZIP CRC validation failed")
        patched = result.read("classes.dex")
        if hashlib.sha1(patched[32:]).digest() != patched[12:32]:
            raise RuntimeError("DEX SHA-1 validation failed")
        checksum, = struct.unpack_from("<I", patched, 8)
        if checksum != (zlib.adler32(patched[12:]) & 0xFFFFFFFF):
            raise RuntimeError("DEX Adler-32 validation failed")
        bad_libs = []
        for item in result.infolist():
            if item.filename.endswith(".so"):
                # Native libraries are stored with ZIP alignment extras; all
                # offsets must remain exactly as in the source archive.
                source_info = source.getinfo(item.filename)
                if source_info.header_offset != item.header_offset:
                    bad_libs.append(item.filename)
        if bad_libs:
            raise RuntimeError(f"Native library offsets changed: {bad_libs[:3]}")
    print(f"patched={dst} bytes={dst.stat().st_size} sha256={hashlib.sha256(dst.read_bytes()).hexdigest()} dex_offset={arg_offset}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch_include_video_preview.py input.apk output.apk")
    patch(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
