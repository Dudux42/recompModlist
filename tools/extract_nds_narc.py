#!/usr/bin/env python3
"""Extract one NitroFS file and, when applicable, its NARC members."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

from inspect_white2_rom import nds_files


def u16(data: bytes, off: int) -> int:
    return struct.unpack_from("<H", data, off)[0]


def u32(data: bytes, off: int) -> int:
    return struct.unpack_from("<I", data, off)[0]


def narc_members(blob: bytes) -> list[bytes]:
    if blob[:4] != b"NARC":
        raise ValueError("selected NitroFS file is not a NARC archive")
    pos = u16(blob, 0x0C)
    fat_entries = None
    image = None
    while pos + 8 <= len(blob):
        magic = blob[pos:pos + 4]
        size = u32(blob, pos + 4)
        if size < 8 or pos + size > len(blob):
            raise ValueError(f"malformed NARC block at {pos:#x}")
        if magic in (b"BTAF", b"FATB"):
            count = u16(blob, pos + 8)
            fat_entries = [(u32(blob, pos + 12 + i * 8),
                            u32(blob, pos + 16 + i * 8))
                           for i in range(count)]
        elif magic in (b"GMIF", b"FIMG"):
            image = blob[pos + 8:pos + size]
        pos += size
    if fat_entries is None or image is None:
        raise ValueError("NARC is missing FAT or image block")
    return [image[start:end] for start, end in fat_entries]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rom", type=Path)
    parser.add_argument("nitro_path")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    found = next((item for item in nds_files(rom)
                  if item["path"] == args.nitro_path), None)
    if not found:
        raise SystemExit(f"NitroFS path not found: {args.nitro_path}")
    blob = rom[found["offset"]:found["offset"] + found["size"]]
    args.out.mkdir(parents=True, exist_ok=True)
    raw_name = args.nitro_path.replace("/", "_") + ".narc"
    (args.out / raw_name).write_bytes(blob)
    members = narc_members(blob)
    inventory = []
    for index, member in enumerate(members):
        name = f"{index:04d}.bin"
        (args.out / name).write_bytes(member)
        inventory.append({"index": index, "size": len(member),
                          "magic": member[:4].hex(), "file": name})
    (args.out / "inventory.json").write_text(
        json.dumps(inventory, indent=2), encoding="utf-8")
    print(json.dumps({"nitro": found, "members": len(members)}, indent=2))


if __name__ == "__main__":
    main()
