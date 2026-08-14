#!/usr/bin/env python3
"""Extract FRLG trainer fronts and Red/Leaf throw frames from the supplied sheet."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


EXPECTED_SIZE = (536, 1400)
MATTE = (255, 127, 39, 255)


def cell(col: int, row_y: int) -> tuple[int, int, int, int]:
    return 8 + col * 65, row_y, 64, 64


# The sheet's Kanto block follows FRLG's trainer-front table. Professor Oak
# is not present in the supplied regular-trainer grid and deliberately keeps
# his ROM portrait. Yellow Jessie/James also remain ROM-owned.
TRAINERS = {
    "youngster": cell(0, 242), "bug_catcher": cell(1, 242),
    "lass": cell(2, 242), "sailor": cell(3, 242),
    "camper": cell(4, 242), "picnicker": cell(5, 242),
    "pokemaniac": cell(6, 242), "super_nerd": cell(7, 242),
    "hiker": cell(0, 307), "biker": cell(1, 307),
    "burglar": cell(2, 307), "engineer": cell(3, 307),
    "fisherman": cell(4, 307), "swimmer_m": cell(5, 307),
    "beauty": cell(6, 307), "cue_ball": cell(7, 307),
    "gamer": cell(0, 372), "swimmer_f": cell(1, 372),
    "psychic_m": cell(2, 372), "rocker": cell(3, 372),
    "juggler": cell(4, 372), "tamer": cell(5, 372),
    "bird_keeper": cell(6, 372), "black_belt": cell(7, 372),
    "scientist": cell(1, 437), "rocket_grunt_m": cell(2, 437),
    "cooltrainer_m": cell(4, 437), "cooltrainer_f": cell(5, 437),
    "gentleman": cell(6, 437), "channeler": cell(7, 437),
    "rival_early": cell(0, 142), "rival_late": cell(1, 142),
    "champion_rival": cell(2, 142),
    "brock": cell(0, 667), "misty": cell(1, 667),
    "lt_surge": cell(2, 667), "erika": cell(3, 667),
    "koga": cell(4, 667), "blaine": cell(5, 667),
    "sabrina": cell(6, 667), "giovanni": cell(7, 667),
    "lorelei": cell(0, 767), "bruno": cell(1, 767),
    "agatha": cell(2, 767), "lance": cell(3, 767),
}


def crop(source: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    x, y, w, h = rect
    image = source.crop((x, y, x + w, y + h)).convert("RGBA")
    pixels = image.load()
    for py in range(h):
        for px in range(w):
            if pixels[px, py] == MATTE:
                pixels[px, py] = (0, 0, 0, 0)
    return image


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def build_audit(assets: dict[str, Image.Image], output: Path) -> None:
    canvas = Image.new("RGBA", (768, 640), (224, 224, 224, 255))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, 767, 31), fill=(35, 35, 55, 255))
    draw.text((12, 10), "FRLG ENEMY TRAINERS + PLAYER THROW FRAMES", fill="white")
    names = list(TRAINERS)
    for index, name in enumerate(names):
        col, row = index % 9, index // 9
        x, y = 12 + col * 84, 44 + row * 100
        canvas.alpha_composite(assets[name], (x + 10, y))
        draw.text((x, y + 66), name[:13], fill=(20, 20, 30, 255))
    base_y = 550
    for pack_index, pack in enumerate(("red", "leaf")):
        draw.text((12 + pack_index * 376, base_y), pack.upper(), fill=(20, 20, 30, 255))
        for frame in range(5):
            image = assets[f"{pack}_throw_{frame + 1}"]
            canvas.alpha_composite(image, (52 + pack_index * 376 + frame * 65, base_y - 4))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--audit", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    if source.size != EXPECTED_SIZE:
        raise SystemExit(f"unexpected source dimensions {source.size}; expected {EXPECTED_SIZE}")
    args.output.mkdir(parents=True, exist_ok=True)

    assets = {name: crop(source, rect) for name, rect in TRAINERS.items()}
    for pack, y in (("red", 968), ("leaf", 1033)):
        for frame in range(5):
            assets[f"{pack}_throw_{frame + 1}"] = crop(source, cell(frame, y))

    report = {
        "source": args.source.name,
        "source_dimensions": list(source.size),
        "source_sha256": sha256(args.source),
        "matte": list(MATTE),
        "outputs": {},
    }
    for name, image in assets.items():
        prefix = "frlg_trainer_" if name in TRAINERS else "frlg_"
        path = args.output / f"{prefix}{name}.png"
        image.save(path, optimize=False)
        report["outputs"][path.name] = {
            "dimensions": list(image.size), "sha256": sha256(path)
        }
    (args.output / "FRLG_TRAINER_EXTRACTION_REPORT.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    if args.audit:
        build_audit(assets, args.audit)


if __name__ == "__main__":
    main()
