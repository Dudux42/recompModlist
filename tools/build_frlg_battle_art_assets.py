#!/usr/bin/env python3
"""Extract only normal/shiny Gen 1 front sprites from the supplied FRLG sheet."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


SHEET_SIZE = (1971, 1836)
PANEL_W = 130
PANEL_H = 165
GRID_X = 10
GRID_Y = 10
HEADER_H = 35
FRAME_SIZE = 64
NORMAL_X = 1
SHINY_X = 66
FRONT_Y = 36
MICRO_HOLE_MAX = 3
TRIM_PADDING = 1


def source_cell(sheet: Image.Image, dex: int, shiny: bool) -> Image.Image:
    index = dex - 1
    panel_x = GRID_X + (index % 15) * PANEL_W
    panel_y = GRID_Y + (index // 15) * PANEL_H
    x = panel_x + (SHINY_X if shiny else NORMAL_X)
    y = panel_y + FRONT_Y
    return sheet.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE))


def transparent_front(cell: Image.Image) -> tuple[Image.Image, int]:
    """Remove the cell's flat matte while retaining tiny palette collisions."""
    rgb = cell.convert("RGB")
    corners = [rgb.getpixel(point) for point in
               ((0, 0), (FRAME_SIZE - 1, 0), (0, FRAME_SIZE - 1),
                (FRAME_SIZE - 1, FRAME_SIZE - 1))]
    if len(set(corners)) != 1:
        raise SystemExit(f"FRLG front cell has inconsistent matte corners: {corners}")
    matte = corners[0]
    rgba = rgb.convert("RGBA")
    source = rgb.load()
    outside: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def is_matte(x: int, y: int) -> bool:
        return source[x, y] == matte

    def push(x: int, y: int) -> None:
        point = (x, y)
        if point not in outside and is_matte(x, y):
            outside.add(point)
            queue.append(point)

    for x in range(FRAME_SIZE):
        push(x, 0)
        push(x, FRAME_SIZE - 1)
    for y in range(FRAME_SIZE):
        push(0, y)
        push(FRAME_SIZE - 1, y)
    neighbors = ((-1, 0), (1, 0), (0, -1), (0, 1))
    while queue:
        x, y = queue.popleft()
        for dx, dy in neighbors:
            nx, ny = x + dx, y + dy
            if 0 <= nx < FRAME_SIZE and 0 <= ny < FRAME_SIZE:
                push(nx, ny)

    visited = set(outside)
    preserve = set()
    for y in range(FRAME_SIZE):
        for x in range(FRAME_SIZE):
            if not is_matte(x, y) or (x, y) in visited:
                continue
            component = []
            visited.add((x, y))
            queue.append((x, y))
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for dx, dy in neighbors:
                    nx, ny = px + dx, py + dy
                    if (0 <= nx < FRAME_SIZE and 0 <= ny < FRAME_SIZE
                            and is_matte(nx, ny) and (nx, ny) not in visited):
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) <= MICRO_HOLE_MAX:
                preserve.update(component)

    pixels = rgba.load()
    keyed = 0
    for y in range(FRAME_SIZE):
        for x in range(FRAME_SIZE):
            if is_matte(x, y) and (x, y) not in preserve:
                pixels[x, y] = (0, 0, 0, 0)
                keyed += 1
    return rgba, keyed


def trim_pair(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise SystemExit("empty FRLG front sprite")
    left = min(box[0] for box in boxes if box)
    top = min(box[1] for box in boxes if box)
    right = max(box[2] for box in boxes if box)
    bottom = max(box[3] for box in boxes if box)
    size = (right - left + TRIM_PADDING * 2,
            bottom - top + TRIM_PADDING * 2)
    result = []
    for frame in frames:
        out = Image.new("RGBA", size, (0, 0, 0, 0))
        out.alpha_composite(frame.crop((left, top, right, bottom)),
                            (TRIM_PADDING, TRIM_PADDING))
        result.append(out)
    return result


def build_assets(sheet: Image.Image, destination: Path, audit_path: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    contact = Image.new("RGBA", (8 * 260, 19 * 144), (28, 32, 42, 255))
    draw = ImageDraw.Draw(contact)
    keyed_pixels = 0
    for dex in range(1, 152):
        frames = []
        for shiny in (False, True):
            frame, keyed = transparent_front(source_cell(sheet, dex, shiny))
            keyed_pixels += keyed
            frames.append(frame)
        frames = trim_pair(frames)
        for shiny, frame in zip((False, True), frames):
            suffix = "_shiny" if shiny else ""
            frame.save(destination /
                       f"pokemon_static_gen3FRLG_front_{dex:03d}{suffix}.png",
                       optimize=True)

        index = dex - 1
        col, row = index % 8, index // 8
        ox, oy = col * 260, row * 144
        draw.text((ox + 4, oy + 3), f"{dex:03d} NORMAL / SHINY",
                  fill=(235, 239, 248, 255))
        for frame_index, frame in enumerate(frames):
            scale = min(2, max(1, 112 // max(frame.size)))
            shown = frame.resize((frame.width * scale, frame.height * scale),
                                 Image.Resampling.NEAREST)
            px = ox + frame_index * 128 + (124 - shown.width) // 2
            py = oy + 24 + (116 - shown.height) // 2
            contact.alpha_composite(shown, (px, py))

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    contact.save(audit_path, optimize=True)
    print(f"built_frlg_pngs=302 species=151 keyed_pixels={keyed_pixels} "
          f"contact={audit_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()
    sheet = Image.open(args.sheet).convert("RGB")
    if sheet.size != SHEET_SIZE:
        raise SystemExit(f"unexpected FRLG sheet dimensions: {sheet.size}")
    if args.build:
        build_assets(sheet, args.workspace / "gen1_battle_art_replacer",
                     args.workspace / "visual_audits" /
                     "frlg_battle_art_all_fronts.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
