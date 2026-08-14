#!/usr/bin/env python3
"""Build 32x192 HGSS/PokeMMO sheets for Dramatic Shape billboards.

Wilds of Kanto has to reduce its source 32x32 follow-sprite tiles to 16x16
for Gen1Recomp's native SpriteRenderer.  Dramatic Shape still presents that
16x16 texture on a comparatively large 3D card.  These sheets preserve the
same six frames, pivot, and apparent size at twice the texture resolution.
They are used only by the 3D compatibility patch; world geometry remains a
16x16 card and the native renderer continues using Wilds' original sheets.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
MOD_ROOT = HERE.parent
DEFAULT_WILDS = Path.home() / "AppData/Roaming/pokemon-love2d/mods/overworld_wild_spawns"
OUT_DIR = MOD_ROOT / "assets/hgss_runtime_hd"
FRAME_SPECS = (
    ("idle", "down"),
    ("idle", "up"),
    ("idle", "left"),
    ("walk", "down"),
    ("walk", "up"),
    ("walk", "left"),
)
CARD = 32


def visible_bounds(image: Image.Image):
    return image.getchannel("A").getbbox()


def crop_tile(source: Image.Image, col: int, row: int, tw: int, th: int):
    return source.crop((col * tw, row * th, (col + 1) * tw, (row + 1) * th)).convert("RGBA")


def content_key(tile: Image.Image) -> bytes:
    bbox = visible_bounds(tile)
    return b"" if bbox is None else tile.crop(bbox).tobytes()


def source_tiles(source: Image.Image, layout: dict, tw: int, th: int):
    directions = layout.get("directions") or {"down": 0, "left": 1, "right": 2, "up": 3}
    idle_col = int(layout.get("idleColumn", 0))
    walk_cols = [int(value) for value in (layout.get("walkColumns") or [0, 1, 2, 3])]
    result = []
    for animation, direction in FRAME_SPECS:
        row = int(directions[direction])
        col = idle_col
        if animation == "walk":
            idle_key = content_key(crop_tile(source, idle_col, row, tw, th))
            for candidate in walk_cols:
                if candidate != idle_col and content_key(crop_tile(source, candidate, row, tw, th)) != idle_key:
                    col = candidate
                    break
        result.append(crop_tile(source, col, row, tw, th))
    return result


def build_sheet(source_path: Path, layout: dict, tw: int, th: int, runtime_scale: float):
    source = Image.open(source_path).convert("RGBA")
    tiles = source_tiles(source, layout, tw, th)
    boxes = [visible_bounds(tile) for tile in tiles]
    visible = [box for box in boxes if box]
    sheet = Image.new("RGBA", (CARD, CARD * 6), (0, 0, 0, 0))
    if not visible:
        return sheet

    left = min(box[0] for box in visible)
    top = min(box[1] for box in visible)
    right = max(box[2] for box in visible)
    bottom = max(box[3] for box in visible)
    scale = max(0.01, float(runtime_scale) * 2.0)
    union_w = max(1, min(CARD, round((right - left) * scale)))
    union_h = max(1, min(CARD, round((bottom - top) * scale)))
    origin_x = (CARD - union_w) // 2
    origin_y = CARD - union_h

    for index, (tile, box) in enumerate(zip(tiles, boxes)):
        if box is None:
            continue
        fl, ft, fr, fb = box
        width = max(1, min(CARD, round((fr - fl) * scale)))
        height = max(1, min(CARD, round((fb - ft) * scale)))
        pixels = tile.crop(box).resize((width, height), Image.Resampling.NEAREST)
        x = origin_x + round((fl - left) * scale)
        y = origin_y + round((ft - top) * scale)
        x = max(0, min(CARD - width, x))
        y = max(0, min(CARD - height, y))
        sheet.alpha_composite(pixels, (x, index * CARD + y))
    return sheet


def main() -> int:
    wilds = DEFAULT_WILDS
    mapping_path = wilds / "assets/enhanced_overworld/followsprites_mapping/followsprites_mapping.json"
    manifest_path = wilds / "assets/generated/followsprites_runtime/manifest.json"
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    layout = mapping["layout"]
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    written = 0
    for key, runtime in manifest.get("sheets", {}).items():
        species_id = int(runtime.get("speciesId", 0))
        if not 1 <= species_id <= 151:
            continue
        source_rel = runtime.get("source")
        if not source_rel:
            continue
        source_path = wilds / source_rel
        if not source_path.is_file():
            continue
        variant = "shiny" if runtime.get("variant") == "shiny" else "normal"
        output = OUT_DIR / f"{species_id:03d}-{variant}.png"
        sheet = build_sheet(
            source_path,
            layout,
            int(runtime.get("tileWidth") or 32),
            int(runtime.get("tileHeight") or 32),
            float(runtime.get("scale") or 1.0),
        )
        sheet.save(output, optimize=True)
        written += 1

    print(f"wrote {written} HD runtime sheets to {OUT_DIR}")
    return 0 if written else 1


if __name__ == "__main__":
    raise SystemExit(main())
