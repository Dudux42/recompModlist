#!/usr/bin/env python3
"""Extract audited front-facing HGSS Gen 1 battle art from the supplied sheet."""

from __future__ import annotations

import argparse
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageDraw


SHEET_CELL_W = 324
SHEET_CELL_H = 195
HEADER_H = 34
PANEL_DIVIDER_Y = 114
TITLE_WHITE_MIN = 220
FRONT_MATTE = (147, 187, 236)
BACK_MATTE = (84, 165, 75)
FRAME_W = 80
FRAME_H = 80
FRONT_FRAME_X = (1, 82)
NORMAL_Y = 34
SHINY_Y = 115
MICRO_HOLE_MAX = 3
TRIM_PADDING = 1


def panel_starts(sheet: Image.Image) -> list[tuple[int, int]]:
    starts = []
    for row in range(sheet.height // SHEET_CELL_H):
        for col in range(sheet.width // SHEET_CELL_W):
            x0, y0 = col * SHEET_CELL_W, row * SHEET_CELL_H
            white = sum(
                1
                for y in range(y0 + 1, y0 + 17)
                for x in range(x0 + 1, min(x0 + 120, sheet.width))
                if min(sheet.getpixel((x, y))[:3]) >= TITLE_WHITE_MIN
            )
            if white > 15:
                starts.append((x0, y0))
    if len(starts) < 152:
        raise SystemExit(f"expected at least 151 labeled panels, found {len(starts)}")
    return starts


def panel_box(starts: list[tuple[int, int]], index: int) -> tuple[int, int, int, int]:
    x0, y0 = starts[index]
    if index + 1 < len(starts) and starts[index + 1][1] == y0:
        x1 = starts[index + 1][0]
    else:
        x1 = 3240
    return x0, y0, x1, y0 + SHEET_CELL_H


def transparent_front(cell: Image.Image, matte: tuple[int, int, int] = FRONT_MATTE) \
        -> tuple[Image.Image, int]:
    """Key the blue front matte while retaining enclosed palette collisions."""
    rgba = cell.convert("RGBA")
    rgb = cell.convert("RGB")
    width, height = cell.size
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

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)
    neighbors = ((-1, 0), (1, 0), (0, -1), (0, 1))
    while queue:
        x, y = queue.popleft()
        for dx, dy in neighbors:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                push(nx, ny)

    # Enclosed matte components up to three pixels are palette collisions in
    # the drawing. Larger enclosed components are authored openings.
    visited = set(outside)
    preserve = set()
    for y in range(height):
        for x in range(width):
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
                    if (0 <= nx < width and 0 <= ny < height
                            and is_matte(nx, ny) and (nx, ny) not in visited):
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) <= MICRO_HOLE_MAX:
                preserve.update(component)

    pixels = rgba.load()
    keyed = 0
    for y in range(height):
        for x in range(width):
            if is_matte(x, y) and (x, y) not in preserve:
                pixels[x, y] = (0, 0, 0, 0)
                keyed += 1
    return rgba, keyed


def trim_shared_frames(frames: list[Image.Image], padding: int = TRIM_PADDING) \
        -> list[Image.Image]:
    """Trim one shared silhouette box without disturbing frame alignment."""
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise SystemExit("cannot trim an empty HGSS front frame")
    left = min(box[0] for box in boxes if box)
    top = min(box[1] for box in boxes if box)
    right = max(box[2] for box in boxes if box)
    bottom = max(box[3] for box in boxes if box)
    width, height = right - left + padding * 2, bottom - top + padding * 2
    trimmed = []
    for frame in frames:
        out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        out.alpha_composite(frame.crop((left, top, right, bottom)),
                            (padding, padding))
        trimmed.append(out)
    return trimmed


def build_assets(sheet: Image.Image, starts: list[tuple[int, int]],
                 destination: Path, audit_path: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    contact = Image.new("RGBA", (8 * 328, 19 * 348), (28, 32, 42, 255))
    draw = ImageDraw.Draw(contact)
    widths = Counter()
    keyed_pixels = 0
    for dex in range(1, 152):
        x0, y0, x1, _ = panel_box(starts, dex - 1)
        widths[x1 - x0] += 1
        variants = []
        keyed_variants = []
        for shiny, row_y in ((False, NORMAL_Y), (True, SHINY_Y)):
            source_x0, source_y0 = x0, y0
            matte = FRONT_MATTE
            if dex == 140:
                # The sheet supplies a labeled correction panel after Dex 151.
                # It contains only Kabuto's two normal and two shiny fronts;
                # its shiny row deliberately uses the green matte.
                source_x0, source_y0 = starts[151]
                matte = BACK_MATTE if shiny else FRONT_MATTE
            frames = []
            for frame_x in FRONT_FRAME_X:
                cell = sheet.crop((source_x0 + frame_x, source_y0 + row_y,
                                   source_x0 + frame_x + FRAME_W,
                                   source_y0 + row_y + FRAME_H))
                frame, keyed = transparent_front(cell, matte)
                keyed_pixels += keyed
                if frame.getchannel("A").getbbox() is None:
                    raise SystemExit(f"empty HGSS front: Dex {dex:03d}")
                if any(frame.getpixel(point)[3] != 0 for point in
                       ((0, 0), (FRAME_W - 1, 0), (0, FRAME_H - 1),
                        (FRAME_W - 1, FRAME_H - 1))):
                    raise SystemExit(f"opaque HGSS canvas corner: Dex {dex:03d}")
                frames.append(frame)
            keyed_variants.extend(frames)

        # The 80x80 sheet cells contain generous authored margins. Keeping
        # those margins made UI consumers fit the empty canvas rather than the
        # Pokemon. One shared crop across normal/shiny and both poses preserves
        # exact animation alignment while removing only unused outer padding.
        variants = trim_shared_frames(keyed_variants)
        frame_w, frame_h = variants[0].size
        for shiny, offset in ((False, 0), (True, 2)):
            frames = variants[offset:offset + 2]
            suffix = "_shiny" if shiny else ""
            atlas = Image.new("RGBA", (frame_w * 2, frame_h), (0, 0, 0, 0))
            atlas.alpha_composite(frames[0], (0, 0))
            atlas.alpha_composite(frames[1], (frame_w, 0))
            atlas.save(destination / f"pokemon_animated_gen4HGSS_front_{dex:03d}{suffix}.png",
                       optimize=True)
            frames[0].save(destination / f"pokemon_static_gen4HGSS_front_{dex:03d}{suffix}.png",
                           optimize=True)

        index = dex - 1
        col, row = index % 8, index // 8
        ox, oy = col * 328, row * 348
        draw.text((ox + 4, oy + 3), f"{dex:03d} N1 N2 S1 S2", fill=(235, 239, 248, 255))
        for frame_index, frame in enumerate(variants):
            shown = frame.resize((160, 160), Image.Resampling.NEAREST)
            px = ox + 4 + (frame_index % 2) * 162
            py = oy + 24 + (frame_index // 2) * 162
            contact.alpha_composite(shown, (px, py))

    audit_path.parent.mkdir(parents=True, exist_ok=True)
    contact.save(audit_path, optimize=True)
    print(f"built_hgss_pngs=604 species=151 frames=604 keyed_pixels={keyed_pixels} "
          f"panel_widths={dict(sorted(widths.items()))} contact={audit_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--audit-panels", default="1,3,19,25,27,123,151")
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()

    sheet = Image.open(args.sheet).convert("RGB")
    if sheet.size != (3241, 3511):
        raise SystemExit(f"unexpected HGSS sheet dimensions: {sheet.size}")
    starts = panel_starts(sheet)
    audit_dir = args.workspace / "visual_audits" / "hgss_source_panels"
    audit_dir.mkdir(parents=True, exist_ok=True)
    requested = [int(value) for value in args.audit_panels.split(",")]
    for dex in requested:
        box = panel_box(starts, dex - 1)
        crop = sheet.crop(box)
        crop.resize((crop.width * 3, crop.height * 3),
                    Image.Resampling.NEAREST).save(audit_dir / f"{dex:03d}.png")
        print(f"panel dex={dex:03d} box={box} size={crop.size}")
    fixed_x, fixed_y = starts[151]
    fixed = sheet.crop((fixed_x, fixed_y, fixed_x + SHEET_CELL_W,
                        fixed_y + SHEET_CELL_H))
    fixed.resize((fixed.width * 3, fixed.height * 3),
                 Image.Resampling.NEAREST).save(audit_dir / "fixed_kabuto.png")
    print(f"panels=151 extra_labeled_panels_ignored={max(0, len(starts) - 151)}")
    if args.build:
        build_assets(sheet, starts, args.workspace / "gen1_battle_art_replacer",
                     args.workspace / "visual_audits" / "hgss_battle_art_all_fronts.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
