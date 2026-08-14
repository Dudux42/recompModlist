#!/usr/bin/env python3
"""Extract normal/shiny Gen 1 front poses from the supplied Emerald sheets."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


SHEET_SIZE = (695, 2144)
GRID_STEP = 69
GRID_MARGIN = 5
GRID_COLUMNS = 10
FRAME_SIZE = 64
MATTE = (165, 235, 255)
MICRO_HOLE_MAX = 3
TRIM_PADDING = 1


def source_cell(sheet: Image.Image, dex: int, frame: int) -> Image.Image:
    index = (dex - 1) * 2 + frame
    x = GRID_MARGIN + (index % GRID_COLUMNS) * GRID_STEP
    y = GRID_MARGIN + (index // GRID_COLUMNS) * GRID_STEP
    return sheet.crop((x, y, x + FRAME_SIZE, y + FRAME_SIZE))


def transparent_front(cell: Image.Image) -> tuple[Image.Image, int]:
    rgb = cell.convert("RGB")
    corners = [rgb.getpixel(point) for point in
               ((0, 0), (FRAME_SIZE - 1, 0), (0, FRAME_SIZE - 1),
                (FRAME_SIZE - 1, FRAME_SIZE - 1))]
    if MATTE not in corners:
        # Large poses may touch one or more corners, but every source cell must
        # still expose its known cyan matte at the border.
        border_has_matte = any(
            rgb.getpixel((x, y)) == MATTE
            for x in range(FRAME_SIZE) for y in range(FRAME_SIZE)
            if x in (0, FRAME_SIZE - 1) or y in (0, FRAME_SIZE - 1))
        if not border_has_matte:
            raise SystemExit(f"Emerald cell has no border matte: {corners}")
    rgba = rgb.convert("RGBA")
    source = rgb.load()
    outside: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def is_matte(x: int, y: int) -> bool:
        return source[x, y] == MATTE

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


def trim_shared_frames(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise SystemExit("empty Emerald front frame")
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


def build_assets(normal_sheet: Image.Image, shiny_sheet: Image.Image,
                 destination: Path, audit_path: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    contact = Image.new("RGBA", (8 * 328, 19 * 348), (28, 32, 42, 255))
    draw = ImageDraw.Draw(contact)
    keyed_pixels = 0
    for dex in range(1, 152):
        frames = []
        for sheet in (normal_sheet, shiny_sheet):
            for frame_index in range(2):
                frame, keyed = transparent_front(
                    source_cell(sheet, dex, frame_index))
                frames.append(frame)
                keyed_pixels += keyed
        frames = trim_shared_frames(frames)
        frame_w, frame_h = frames[0].size
        for shiny, offset in ((False, 0), (True, 2)):
            pair = frames[offset:offset + 2]
            suffix = "_shiny" if shiny else ""
            atlas = Image.new("RGBA", (frame_w * 2, frame_h), (0, 0, 0, 0))
            atlas.alpha_composite(pair[0], (0, 0))
            atlas.alpha_composite(pair[1], (frame_w, 0))
            atlas.save(destination /
                       f"pokemon_animated_gen3Emerald_front_{dex:03d}{suffix}.png",
                       optimize=True)
            pair[0].save(destination /
                         f"pokemon_static_gen3Emerald_front_{dex:03d}{suffix}.png",
                         optimize=True)

        index = dex - 1
        col, row = index % 8, index // 8
        ox, oy = col * 328, row * 348
        draw.text((ox + 4, oy + 3), f"{dex:03d} N1 N2 S1 S2",
                  fill=(235, 239, 248, 255))
        for frame_index, frame in enumerate(frames):
            shown = frame.resize((frame.width * 2, frame.height * 2),
                                 Image.Resampling.NEAREST)
            px = ox + 4 + (frame_index % 2) * 162 + (156 - shown.width) // 2
            py = oy + 24 + (frame_index // 2) * 162 + (156 - shown.height) // 2
            contact.alpha_composite(shown, (px, py))

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    contact.save(audit_path, optimize=True)
    print(f"built_emerald_pngs=604 species=151 frames=604 "
          f"keyed_pixels={keyed_pixels} contact={audit_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--normal-sheet", type=Path, required=True)
    parser.add_argument("--shiny-sheet", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()
    normal = Image.open(args.normal_sheet).convert("RGB")
    shiny = Image.open(args.shiny_sheet).convert("RGB")
    if normal.size != SHEET_SIZE or shiny.size != SHEET_SIZE:
        raise SystemExit(
            f"unexpected Emerald sheet dimensions: {normal.size}, {shiny.size}")
    if args.build:
        build_assets(normal, shiny, args.workspace / "gen1_battle_art_replacer",
                     args.workspace / "visual_audits" /
                     "emerald_battle_art_all_fronts.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
