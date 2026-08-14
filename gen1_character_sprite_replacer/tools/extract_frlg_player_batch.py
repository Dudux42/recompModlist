#!/usr/bin/env python3
"""Extract the reviewed FRLG player batch from the user's 673x638 sheet."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


EXPECTED_SIZE = (673, 638)
BACKGROUND = {(255, 127, 39, 255), (34, 177, 76, 255)}

PACKS = {
    "frlg_red": {
        "walk_y": (42, 75, 108, 141),
        "front": (342, 225, 64, 64),
        "back": (8, 225, 64, 64),
        "main_menu": (601, 183, 64, 96),
    },
    "frlg_leaf": {
        "walk_y": (309, 342, 375, 408),
        "front": (342, 492, 64, 64),
        "back": (8, 492, 64, 64),
        "main_menu": (601, 448, 64, 96),
    },
}


def rgba_crop(source: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    x, y, w, h = rect
    image = source.crop((x, y, x + w, y + h)).convert("RGBA")
    pixels = image.load()
    for py in range(h):
        for px in range(w):
            if pixels[px, py] in BACKGROUND:
                pixels[px, py] = (0, 0, 0, 0)
    return image


def stack_frames(frames: list[Image.Image]) -> Image.Image:
    width = frames[0].width
    height = frames[0].height
    assert all(frame.size == (width, height) for frame in frames)
    sheet = Image.new("RGBA", (width, height * len(frames)), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (0, index * height))
    return sheet


def six_pose(source: Image.Image, ys: tuple[int, int, int], x0: int,
             x1: int, size: int) -> Image.Image:
    # Engine order: stand down/up/left, walk down/up/left. Right mirrors left.
    frames = [rgba_crop(source, (x0, y, size, 32)) for y in ys]
    frames += [rgba_crop(source, (x1, y, size, 32)) for y in ys]
    return stack_frames(frames)


def twelve_pose(source: Image.Image, ys: tuple[int, int, int, int],
                stand_x: int, step_a_x: int, step_b_x: int,
                size: int) -> Image.Image:
    # The source rows are down/up/left/right and its columns are
    # step A / neutral idle / step B. Store neutral first for the engine,
    # followed by both authored steps, preserving all four directions.
    frames = [rgba_crop(source, (x, y, size, 32))
              for x in (stand_x, step_a_x, step_b_x) for y in ys]
    return stack_frames(frames)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def checkerboard(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (238, 238, 238, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 8):
        for x in range(0, size[0], 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=(200, 200, 200, 255))
    return image


def build_audit(assets: dict[str, Image.Image], output: Path) -> None:
    canvas = checkerboard((960, 640))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, 959, 31), fill=(35, 35, 55, 255))
    draw.text((12, 10), "FRLG PLAYER BATCH - THREE-FRAME WALK AUDIT", fill="white")
    x_origins = {"frlg_red": 24, "frlg_leaf": 494}
    for pack, x0 in x_origins.items():
        draw.text((x0, 44), pack.upper(), fill=(20, 20, 30, 255))
        walk = assets[f"{pack}_walk"]
        bike = assets[f"{pack}_bike"]
        surf = assets[f"{pack}_surf"]
        for index in range(12):
            frame = walk.crop((0, index * 32, 16, index * 32 + 32)).resize((32, 64), Image.Resampling.NEAREST)
            canvas.alpha_composite(frame, (x0 + index * 38, 68))
            bframe = bike.crop((0, index * 32, 32, index * 32 + 32)).resize((64, 64), Image.Resampling.NEAREST)
            canvas.alpha_composite(bframe, (x0 + (index % 3) * 72, 148 + (index // 3) * 70))
        for index in range(6):
            sframe = surf.crop((0, index * 32, 32, index * 32 + 32)).resize((64, 64), Image.Resampling.NEAREST)
            canvas.alpha_composite(sframe, (x0 + 230 + (index % 2) * 68, 148 + (index // 2) * 70))
        canvas.alpha_composite(assets[f"{pack}_front"].resize((128, 128), Image.Resampling.NEAREST), (x0, 500))
        canvas.alpha_composite(assets[f"{pack}_back"].resize((128, 128), Image.Resampling.NEAREST), (x0 + 130, 500))
        canvas.alpha_composite(assets[f"{pack}_main_menu"], (x0 + 270, 510))
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

    assets: dict[str, Image.Image] = {}
    for pack, spec in PACKS.items():
        ys = spec["walk_y"]
        assets[f"{pack}_walk"] = twelve_pose(source, ys, 25, 8, 42, 16)
        assets[f"{pack}_bike"] = twelve_pose(source, ys, 161, 128, 194, 32)
        assets[f"{pack}_surf"] = six_pose(source, ys[:3], 377, 410, 32)
        assets[f"{pack}_front"] = rgba_crop(source, spec["front"])
        assets[f"{pack}_back"] = rgba_crop(source, spec["back"])
        assets[f"{pack}_main_menu"] = rgba_crop(source, spec["main_menu"])

    report = {
        "source": args.source.name,
        "source_dimensions": list(source.size),
        "source_sha256": sha256(args.source),
        "background_keys": [list(color) for color in sorted(BACKGROUND)],
        "outputs": {},
    }
    for name, image in assets.items():
        path = args.output / f"{name}.png"
        image.save(path, optimize=False)
        report["outputs"][path.name] = {
            "dimensions": list(image.size),
            "sha256": sha256(path),
        }
    (args.output / "FRLG_EXTRACTION_REPORT.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    if args.audit:
        build_audit(assets, args.audit)


if __name__ == "__main__":
    main()
