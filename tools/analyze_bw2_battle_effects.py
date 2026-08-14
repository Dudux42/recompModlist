#!/usr/bin/env python3
"""Inventory B2W2 battle-effect script references to particle SPA files."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("effects", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    rows = []
    for path in sorted(args.effects.glob("[0-9][0-9][0-9][0-9].bin")):
        data = path.read_bytes()
        refs = []
        for pos in range(0, len(data) - 3, 2):
            opcode = struct.unpack_from("<H", data, pos)[0]
            if opcode in (6, 7):
                refs.append({"offset": pos, "opcode": opcode,
                             "spa": struct.unpack_from("<H", data, pos + 2)[0]})
        rows.append({"effect_index": int(path.stem), "size": len(data),
                     "refs": refs})
    args.out.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    for row in rows:
        spas = ",".join(str(x["spa"]) for x in row["refs"])
        print(f"{row['effect_index']:3d} {row['size']:5d} {spas}")


if __name__ == "__main__":
    main()
