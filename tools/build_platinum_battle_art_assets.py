#!/usr/bin/env python3
"""Extract front-only Platinum Gen 1 battle art from the supplied sheet."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

from build_hgss_battle_art_assets import (
    BACK_MATTE,
    FRAME_H,
    FRAME_W,
    FRONT_FRAME_X,
    FRONT_MATTE,
    NORMAL_Y,
    SHINY_Y,
    transparent_front,
    trim_shared_frames,
)


SHEET_SIZE = (3241, 3511)
PANEL_W = 324
PANEL_H = 195
TITLE_WHITE_MIN = 220


def panel_starts(sheet: Image.Image) -> list[tuple[int, int]]:
    starts = []
    for row in range(sheet.height // PANEL_H):
        for col in range(sheet.width // PANEL_W):
            x0, y0 = col * PANEL_W, row * PANEL_H
            white = sum(
                1
                for y in range(y0 + 1, y0 + 17)
                for x in range(x0 + 1, min(x0 + 120, sheet.width))
                if min(sheet.getpixel((x, y))[:3]) >= TITLE_WHITE_MIN
            )
            if white > 15:
                starts.append((x0, y0))
    if len(starts) != 151:
        raise SystemExit(f"expected exactly 151 Platinum panels, found {len(starts)}")
    return starts


def panel_box(starts: list[tuple[int, int]], index: int) -> tuple[int, int, int, int]:
    x0, y0 = starts[index]
    if index + 1 < len(starts) and starts[index + 1][1] == y0:
        x1 = starts[index + 1][0]
    else:
        x1 = min(x0 + PANEL_W, 3240)
    return x0, y0, x1, y0 + PANEL_H


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
        frames = []
        for row_y in (NORMAL_Y, SHINY_Y):
            for frame_x in FRONT_FRAME_X:
                cell = sheet.crop((x0 + frame_x, y0 + row_y,
                                   x0 + frame_x + FRAME_W,
                                   y0 + row_y + FRAME_H))
                matte_counts = {
                    matte: sum(1 for pixel in cell.getdata() if pixel == matte)
                    for matte in (FRONT_MATTE, BACK_MATTE)
                }
                matte = max(matte_counts, key=matte_counts.get)
                frame, keyed = transparent_front(cell, matte)
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
                       f"pokemon_animated_gen4Platinum_front_{dex:03d}{suffix}.png",
                       optimize=True)
            pair[0].save(destination /
                         f"pokemon_static_gen4Platinum_front_{dex:03d}{suffix}.png",
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
    print(f"built_platinum_pngs=604 species=151 frames=604 "
          f"keyed_pixels={keyed_pixels} panel_widths={dict(sorted(widths.items()))} "
          f"contact={audit_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()
    sheet = Image.open(args.sheet).convert("RGB")
    if sheet.size != SHEET_SIZE:
        raise SystemExit(f"unexpected Platinum sheet dimensions: {sheet.size}")
    starts = panel_starts(sheet)
    if args.build:
        build_assets(sheet, starts, args.workspace / "gen1_battle_art_replacer",
                     args.workspace / "visual_audits" /
                     "platinum_battle_art_all_fronts.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
