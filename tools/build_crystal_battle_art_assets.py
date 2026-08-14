#!/usr/bin/env python3
"""Build audited Crystal front animations using the supplied sheet and GIFs."""

from __future__ import annotations

import argparse
from collections import deque
import concurrent.futures
import math
import time
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw


SHEET_SIZE = (3883, 3407)
PANEL_COLUMNS = 6
SPECIES_PER_COLUMN = 26
PANEL_STEP_X = 651
PANEL_STEP_Y = 131
HEADER_H = 18
SHINY_Y = 75
CELL_STEP = 57
CELL_SIZE = 56
MAX_FRONT_CELLS = 10
BACK_CELL = 10
RED_MATTE = (255, 64, 64)
TRIM_PADDING = 1
BASE_URL = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/"
    "pokemon/versions/generation-ii/crystal/animated")


def panel_origin(dex: int) -> tuple[int, int]:
    index = dex - 1
    return ((index // SPECIES_PER_COLUMN) * PANEL_STEP_X,
            (index % SPECIES_PER_COLUMN) * PANEL_STEP_Y)


def source_cell(sheet: Image.Image, dex: int, shiny: bool,
                frame: int) -> Image.Image:
    x0, y0 = panel_origin(dex)
    x = x0 + 1 + frame * CELL_STEP
    y = y0 + (SHINY_Y if shiny else HEADER_H)
    return sheet.crop((x, y, x + CELL_SIZE, y + CELL_SIZE))


def source_frame_count(sheet: Image.Image, dex: int, shiny: bool) -> int:
    count = 0
    for frame in range(MAX_FRONT_CELLS):
        cell = source_cell(sheet, dex, shiny, frame).convert("RGB")
        if all(pixel == RED_MATTE for pixel in cell.getdata()):
            break
        count += 1
    if count < 2:
        raise SystemExit(f"Crystal front sequence too short at Dex {dex:03d}")
    return count


def download_gif(cache: Path, dex: int, shiny: bool) -> Path:
    suffix = "_shiny" if shiny else ""
    target = cache / f"{dex:03d}{suffix}.gif"
    if target.exists():
        return target
    cache.mkdir(parents=True, exist_ok=True)
    branch = "shiny/" if shiny else ""
    url = f"{BASE_URL}/{branch}{dex}.gif"
    request = urllib.request.Request(url, headers={"User-Agent": "gen1-battle-art-builder"})
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                target.write_bytes(response.read())
            return target
        except Exception as error:
            last_error = error
            if attempt < 2:
                time.sleep(1 + attempt)
    raise last_error
    return target


def prefetch_gifs(cache: Path) -> None:
    jobs = [(dex, shiny) for dex in range(1, 152) for shiny in (False, True)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=24) as executor:
        futures = [executor.submit(download_gif, cache, dex, shiny)
                   for dex, shiny in jobs]
        for future in concurrent.futures.as_completed(futures):
            future.result()


def trim_shared_frames(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise SystemExit("empty Crystal animation frame")
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


def decode_gif(path: Path) -> tuple[list[Image.Image], list[int]]:
    source = Image.open(path)
    if source.size != (CELL_SIZE, CELL_SIZE):
        raise SystemExit(f"unexpected Crystal GIF dimensions: {path} {source.size}")
    frames, durations = [], []
    for index in range(source.n_frames):
        source.seek(index)
        frames.append(source.convert("RGBA").copy())
        durations.append(max(1, int(source.info.get("duration") or 100)))
    return frames, durations


def colored_points(image: Image.Image, gif: bool = False) -> set[tuple[int, int]]:
    points = set()
    for y in range(CELL_SIZE):
        for x in range(CELL_SIZE):
            pixel = image.getpixel((x, y))
            if gif:
                if pixel[3] and pixel[:3] not in ((248, 248, 248),
                                                  (255, 255, 255)):
                    points.add((x, y))
            elif pixel not in (RED_MATTE, (255, 255, 255)):
                points.add((x, y))
    return points


def sheet_colored_frames(sheet: Image.Image, dex: int,
                         shiny: bool) -> list[tuple[Image.Image,
                                                   set[tuple[int, int]],
                                                   set[tuple[int, int]]]]:
    result = []
    for index in range(source_frame_count(sheet, dex, shiny)):
        source = source_cell(sheet, dex, shiny, index).convert("RGB")
        result.append((source, colored_points(source), {
            (x, y) for y in range(CELL_SIZE) for x in range(CELL_SIZE)
            if source.getpixel((x, y)) == RED_MATTE
        }))
    return result


def reconstruct_sheet_frame(candidates, gif_frame: Image.Image, dex: int,
                            shiny: bool, frame_index: int) \
        -> tuple[Image.Image, int]:
    """Map a timed GIF frame to a sheet pose, keeping sheet RGB and GIF alpha."""
    gif_points = colored_points(gif_frame, gif=True)
    gif_left = min(x for x, _ in gif_points)
    gif_top = min(y for _, y in gif_points)
    match = None
    def search(radius: int) -> None:
        nonlocal match
        for source_index, (source, source_points, red_points) in enumerate(candidates):
            source_left = min(x for x, _ in source_points)
            source_top = min(y for _, y in source_points)
            base_dx, base_dy = source_left - gif_left, source_top - gif_top
            for dx in range(base_dx - radius, base_dx + radius + 1):
                for dy in range(base_dy - radius, base_dy + radius + 1):
                    shifted = {(x + dx, y + dy) for x, y in gif_points}
                    outside = {point for point in shifted
                               if not (0 <= point[0] < CELL_SIZE
                                       and 0 <= point[1] < CELL_SIZE)}
                    gif_extra = shifted - source_points
                    gif_extra_red = outside | (gif_extra & red_points)
                    source_extra = source_points - shifted
                    score = (len(gif_extra_red) * 1000 + len(source_extra)
                             + len(gif_extra))
                    if match is None or score < match[0]:
                        match = (score, source_index, source, dx, dy,
                                 gif_extra_red, source_extra)
    search(0)
    if not match:
        raise SystemExit(
            f"Crystal GIF pose not found in supplied sheet Dex {dex:03d} "
            f"{'shiny' if shiny else 'normal'} frame {frame_index + 1}; "
            f"best={match and (len(match[5]), len(match[6]))}")

    _, source_index, source, dx, dy, _, source_extra = match
    if match[5]:
        # Some repository GIFs use a different drawing from the supplied
        # Crystal sheet. In that case, derive transparency from the selected
        # sheet pose itself instead of applying a provably incompatible mask.
        exterior = set()
        queue = deque()
        for x in range(CELL_SIZE):
            queue.extend(((x, 0), (x, CELL_SIZE - 1)))
        for y in range(CELL_SIZE):
            queue.extend(((0, y), (CELL_SIZE - 1, y)))
        while queue:
            point = queue.popleft()
            if point in exterior:
                continue
            x, y = point
            if source.getpixel(point) not in (RED_MATTE, (255, 255, 255)):
                continue
            exterior.add(point)
            if x: queue.append((x - 1, y))
            if x + 1 < CELL_SIZE: queue.append((x + 1, y))
            if y: queue.append((x, y - 1))
            if y + 1 < CELL_SIZE: queue.append((x, y + 1))
        out = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
        for y in range(CELL_SIZE):
            for x in range(CELL_SIZE):
                if (x, y) not in exterior:
                    out.putpixel((x, y), (*source.getpixel((x, y)), 255))
        if any(out.getpixel((x, y))[3] and source.getpixel((x, y)) == RED_MATTE
               for y in range(CELL_SIZE) for x in range(CELL_SIZE)):
            raise SystemExit(f"Crystal matte fallback failed Dex {dex:03d}")
        return out, source_index

    out = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    for y in range(CELL_SIZE):
        for x in range(CELL_SIZE):
            if gif_frame.getpixel((x, y))[3] == 0:
                continue
            sx, sy = x + dx, y + dy
            if not (0 <= sx < CELL_SIZE and 0 <= sy < CELL_SIZE):
                raise SystemExit(f"Crystal shifted alpha escaped its cell Dex {dex:03d}")
            out.putpixel((sx, sy), (*source.getpixel((sx, sy)), 255))
    # A few GIFs clip colored pixels at the edge of their 56px canvas. The
    # supplied sheet retains them, so restore only those proven colored source
    # pixels after the pose match; arbitrary white background is never filled.
    for sx, sy in source_extra:
        out.putpixel((sx, sy), (*source.getpixel((sx, sy)), 255))
    if colored_points(out, gif=True) != candidates[source_index][1]:
        raise SystemExit(f"Crystal reconstructed RGB mismatch Dex {dex:03d}")
    return out, source_index


def metadata_line(dex: int, normal: dict, shiny: dict) -> str:
    def descriptor(value: dict) -> str:
        durations = ",".join(str(item) for item in value["durations"])
        return (f"width = {value['width']}, height = {value['height']}, "
                f"columns = {value['columns']}, frames = {value['frames']}, "
                f"durations = {{{durations}}}")
    shiny_text = ""
    if shiny != normal:
        shiny_text = f", shiny = {{ {descriptor(shiny)} }}"
    return f"  [{dex}] = {{ {descriptor(normal)}{shiny_text} }},"


def build_assets(sheet: Image.Image, cache: Path, destination: Path,
                 audit_path: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    prefetch_gifs(cache)
    contact = Image.new("RGBA", (8 * 328, 19 * 348), (28, 32, 42, 255))
    draw = ImageDraw.Draw(contact)
    definitions = []
    decoded = 0
    for dex in range(1, 152):
        raw_variants = []
        variant_durations = []
        for shiny in (False, True):
            candidates = sheet_colored_frames(sheet, dex, shiny)
            gif_frames, durations = decode_gif(download_gif(cache, dex, shiny))
            frames, matched = [], set()
            for index, gif_frame in enumerate(gif_frames):
                frame, source_index = reconstruct_sheet_frame(
                    candidates, gif_frame, dex, shiny, index)
                frames.append(frame)
                matched.add(source_index)
            # Composite sheets sometimes include additional presentation poses
            # which are not part of Crystal's authored battle GIF sequence.
            # Do not invent timing for those unused cells: only poses selected
            # by an actual timed GIF frame are emitted.
            raw_variants.append(frames)
            variant_durations.append(durations)
            decoded += len(frames)

        all_frames = trim_shared_frames(raw_variants[0] + raw_variants[1])
        normal_count = len(raw_variants[0])
        variants = (all_frames[:normal_count], all_frames[normal_count:])
        descriptors = []
        for shiny, frames, durations in zip(
                (False, True), variants, variant_durations):
            frame_w, frame_h = frames[0].size
            columns = min(MAX_FRONT_CELLS, len(frames))
            rows = math.ceil(len(frames) / columns)
            atlas = Image.new("RGBA", (frame_w * columns, frame_h * rows),
                              (0, 0, 0, 0))
            for index, frame in enumerate(frames):
                atlas.alpha_composite(
                    frame, ((index % columns) * frame_w,
                            (index // columns) * frame_h))
            suffix = "_shiny" if shiny else ""
            atlas.save(destination /
                       f"pokemon_animated_gen2Crystal_front_{dex:03d}{suffix}.png",
                       optimize=True)
            frames[0].save(destination /
                           f"pokemon_static_gen2Crystal_front_{dex:03d}{suffix}.png",
                           optimize=True)
            descriptors.append({"width": frame_w, "height": frame_h,
                                "columns": columns, "frames": len(frames),
                                "durations": durations})
        definitions.append(metadata_line(dex, descriptors[0], descriptors[1]))

        index = dex - 1
        col, row = index % 8, index // 8
        ox, oy = col * 328, row * 348
        draw.text((ox + 4, oy + 3),
                  f"{dex:03d} N1 N-LAST S1 S-LAST",
                  fill=(235, 239, 248, 255))
        shown_frames = (variants[0][0], variants[0][-1],
                        variants[1][0], variants[1][-1])
        for frame_index, frame in enumerate(shown_frames):
            shown = frame.resize((frame.width * 2, frame.height * 2),
                                 Image.Resampling.NEAREST)
            px = ox + 4 + (frame_index % 2) * 162 + (156 - shown.width) // 2
            py = oy + 24 + (frame_index // 2) * 162 + (156 - shown.height) // 2
            contact.alpha_composite(shown, (px, py))

    (destination / "crystal_animation_metadata.lua").write_text(
        "return {\n" + "\n".join(definitions) + "\n}\n",
        encoding="utf-8", newline="\n")
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    contact.save(audit_path, optimize=True)
    print(f"built_crystal_pngs=604 species=151 decoded_frames={decoded} "
          f"contact={audit_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()
    sheet = Image.open(args.sheet).convert("RGB")
    if sheet.size != SHEET_SIZE:
        raise SystemExit(f"unexpected Crystal sheet dimensions: {sheet.size}")
    if args.build:
        build_assets(sheet,
                     args.workspace / ".audit" / "crystal_animated_gifs",
                     args.workspace / "gen1_battle_art_replacer",
                     args.workspace / "visual_audits" /
                     "crystal_battle_art_all_fronts.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
