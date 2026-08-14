#!/usr/bin/env python3
"""Read-only Nintendo DS filesystem/SDAT inventory for a user-supplied ROM."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


def u16(data: bytes, off: int) -> int:
    return struct.unpack_from("<H", data, off)[0]


def u32(data: bytes, off: int) -> int:
    return struct.unpack_from("<I", data, off)[0]


def nds_files(data: bytes) -> list[dict]:
    fnt_off, fnt_size = u32(data, 0x40), u32(data, 0x44)
    fat_off, fat_size = u32(data, 0x48), u32(data, 0x4C)
    fnt = data[fnt_off : fnt_off + fnt_size]
    file_count = fat_size // 8
    fat = [(u32(data, fat_off + i * 8), u32(data, fat_off + i * 8 + 4))
           for i in range(file_count)]
    dir_count = u16(fnt, 6)
    dirs = []
    for i in range(dir_count):
        off = i * 8
        dirs.append((u32(fnt, off), u16(fnt, off + 4), u16(fnt, off + 6)))

    out: list[dict] = []
    seen: set[int] = set()

    def walk(dir_id: int, prefix: str) -> None:
        idx = dir_id - 0xF000
        if idx < 0 or idx >= len(dirs) or dir_id in seen:
            return
        seen.add(dir_id)
        pos, file_id, _parent = dirs[idx]
        while pos < len(fnt):
            marker = fnt[pos]
            pos += 1
            if marker == 0:
                break
            is_dir = bool(marker & 0x80)
            length = marker & 0x7F
            name = fnt[pos : pos + length].decode("ascii", "replace")
            pos += length
            if is_dir:
                child = u16(fnt, pos)
                pos += 2
                walk(child, prefix + name + "/")
            else:
                if file_id < len(fat):
                    start, end = fat[file_id]
                    out.append({
                        "id": file_id,
                        "path": prefix + name,
                        "offset": start,
                        "size": end - start,
                    })
                file_id += 1

    walk(0xF000, "")
    out.sort(key=lambda item: item["id"])
    return out


def sdat_symbols(blob: bytes) -> dict[str, list[str | None]]:
    if blob[:4] != b"SDAT":
        raise ValueError("not an SDAT file")
    # Standard SDAT header stores block offsets from byte 0x10 onward.
    block_count = u16(blob, 0x0E)
    blocks = [(u32(blob, 0x10 + i * 8), u32(blob, 0x14 + i * 8))
              for i in range(block_count)]
    symb_off = next((off for off, _size in blocks if blob[off:off + 4] == b"SYMB"), 0)
    if not symb_off:
        return {}
    base = symb_off
    labels = ["sequence", "sequence_archive", "bank", "wave_archive",
              "player", "group", "stream_player", "stream"]
    result: dict[str, list[str | None]] = {}
    for i, label in enumerate(labels):
        rel = u32(blob, base + 8 + i * 4)
        if not rel:
            result[label] = []
            continue
        table = base + rel
        count = u32(blob, table)
        names: list[str | None] = []
        for j in range(count):
            name_rel = u32(blob, table + 4 + j * 4)
            if not name_rel:
                names.append(None)
                continue
            start = base + name_rel
            end = blob.find(b"\0", start)
            names.append(blob[start:end].decode("ascii", "replace"))
        result[label] = names
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rom", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    data = args.rom.read_bytes()
    files = nds_files(data)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "filesystem.json").write_text(
        json.dumps(files, indent=2), encoding="utf-8")
    (args.out / "filesystem.txt").write_text(
        "\n".join(f"{x['id']:5d} {x['offset']:10d} {x['size']:10d} {x['path']}"
                  for x in files) + "\n", encoding="utf-8")

    sdats = []
    for item in files:
        start = item["offset"]
        blob = data[start : start + item["size"]]
        if blob[:4] == b"SDAT":
            target = args.out / f"file_{item['id']:05d}.sdat"
            target.write_bytes(blob)
            symbols = sdat_symbols(blob)
            (args.out / f"file_{item['id']:05d}_symbols.json").write_text(
                json.dumps(symbols, indent=2), encoding="utf-8")
            sdats.append({"file": item, "output": target.name,
                          "symbols": {k: len(v) for k, v in symbols.items()}})
    print(json.dumps({"rom_bytes": len(data), "files": len(files), "sdats": sdats},
                     indent=2))


if __name__ == "__main__":
    main()
