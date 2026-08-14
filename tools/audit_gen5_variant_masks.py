#!/usr/bin/env python3
"""Compare normal/shiny Gen 5 GIF alpha masks frame by frame."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


def frames(path: Path) -> list[Image.Image]:
    source = Image.open(path)
    result = []
    for index in range(source.n_frames):
        source.seek(index)
        result.append(source.convert("RGBA").getchannel("A").copy())
    return result


def rgba_frames(path: Path) -> list[Image.Image]:
    source = Image.open(path)
    result = []
    for index in range(source.n_frames):
        source.seek(index)
        result.append(source.convert("RGBA").copy())
    return result


def write_contacts(cache: Path, dex: int, output: Path) -> None:
    variants = [("NORMAL", rgba_frames(cache / f"{dex:03d}.gif")),
                ("SHINY", rgba_frames(cache / f"{dex:03d}_shiny.gif"))]
    columns, scale, label_height = 8, 4, 12
    width = max(frame.width for _, group in variants for frame in group)
    height = max(frame.height for _, group in variants for frame in group)
    cell_w, cell_h = width * scale + 8, height * scale + label_height + 8
    total_rows = sum((len(group) + columns - 1) // columns for _, group in variants)
    clean = Image.new("RGBA", (columns * cell_w, total_rows * cell_h),
                      (24, 74, 24, 255))
    marked = clean.copy()
    clean_draw, marked_draw = ImageDraw.Draw(clean), ImageDraw.Draw(marked)
    row_base = 0
    for label, group in variants:
        for index, frame in enumerate(group):
            row = row_base + index // columns
            col = index % columns
            x, y = col * cell_w + 4, row * cell_h + label_height + 4
            enlarged = frame.resize((frame.width * scale, frame.height * scale),
                                     Image.Resampling.NEAREST)
            clean.alpha_composite(enlarged, (x, y))
            marked.alpha_composite(enlarged, (x, y))
            text = f"{label[0]}{index + 1}"
            clean_draw.text((x, row * cell_h), text, fill=(255, 255, 255, 255))
            marked_draw.text((x, row * cell_h), text, fill=(255, 255, 255, 255))
            for component in enclosed_holes(frame.getchannel("A")):
                for px, py in component:
                    marked_draw.rectangle(
                        (x + px * scale, y + py * scale,
                         x + (px + 1) * scale - 1, y + (py + 1) * scale - 1),
                        fill=(255, 0, 255, 255))
        row_base += (len(group) + columns - 1) // columns
    output.parent.mkdir(parents=True, exist_ok=True)
    clean.save(output, optimize=True)
    marked_path = output.with_name(output.stem + "_holes" + output.suffix)
    marked.save(marked_path, optimize=True)
    print(f"contact={output} holes_contact={marked_path}")


def enclosed_holes(alpha: Image.Image) -> list[list[tuple[int, int]]]:
    """Return 8-connected transparent components unreachable from the border."""
    width, height = alpha.size
    opaque = alpha.load()
    outside: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        point = (x, y)
        if point not in outside and opaque[x, y] == 0:
            outside.add(point)
            queue.append(point)

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                       (x - 1, y),                   (x + 1, y),
                       (x - 1, y + 1), (x, y + 1), (x + 1, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                seed(nx, ny)

    holes = []
    visited = set(outside)
    for y in range(height):
        for x in range(width):
            if opaque[x, y] != 0 or (x, y) in visited:
                continue
            component = []
            visited.add((x, y))
            queue.append((x, y))
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for nx, ny in ((px - 1, py - 1), (px, py - 1), (px + 1, py - 1),
                               (px - 1, py),                       (px + 1, py),
                               (px - 1, py + 1), (px, py + 1), (px + 1, py + 1)):
                    if (0 <= nx < width and 0 <= ny < height
                            and opaque[nx, ny] == 0 and (nx, ny) not in visited):
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            holes.append(component)
    return holes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--report-holes", action="store_true")
    parser.add_argument("--contact-dex", type=int)
    parser.add_argument("--contact-output", type=Path)
    args = parser.parse_args()
    cache = args.workspace / ".audit" / "gen5_animated_gifs"
    if args.contact_dex:
        output = args.contact_output or (args.workspace / "visual_audits" /
                                         f"gen5_{args.contact_dex:03d}_all_frames.png")
        write_contacts(cache, args.contact_dex, output)

    mismatches = []
    incomparable = []
    missing_normal = missing_shiny = 0
    hole_rows = []
    for dex in range(1, 152):
        normal = frames(cache / f"{dex:03d}.gif")
        shiny = frames(cache / f"{dex:03d}_shiny.gif")
        if args.report_holes:
            for label, variant in (("normal", normal), ("shiny", shiny)):
                for index, alpha in enumerate(variant, 1):
                    holes = enclosed_holes(alpha)
                    small = sorted(len(component) for component in holes
                                   if len(component) <= 16)
                    if small:
                        hole_rows.append((dex, label, index, small))
        if len(normal) != len(shiny) or normal[0].size != shiny[0].size:
            incomparable.append((dex, normal[0].size, len(normal), shiny[0].size, len(shiny)))
            continue
        for index, (normal_alpha, shiny_alpha) in enumerate(zip(normal, shiny), 1):
            normal_only = ImageChops.subtract(normal_alpha, shiny_alpha)
            shiny_only = ImageChops.subtract(shiny_alpha, normal_alpha)
            normal_count = sum(value > 0 for value in normal_only.get_flattened_data())
            shiny_count = sum(value > 0 for value in shiny_only.get_flattened_data())
            if normal_count or shiny_count:
                mismatches.append((dex, index, normal_count, shiny_count,
                                   normal_only.getbbox(), shiny_only.getbbox()))
                missing_shiny += normal_count
                missing_normal += shiny_count

    print(f"comparable_species={151 - len(incomparable)} "
          f"incomparable_species={len(incomparable)} "
          f"mismatched_frames={len(mismatches)} "
          f"normal_only_pixels={missing_shiny} shiny_only_pixels={missing_normal}")
    for row in incomparable:
        print("INCOMPARABLE dex=%03d normal=%sx%s/%d shiny=%sx%s/%d" %
              (row[0], row[1][0], row[1][1], row[2],
               row[3][0], row[3][1], row[4]))
    for row in mismatches:
        print("MISMATCH dex=%03d frame=%d normal_only=%d shiny_only=%d "
              "normal_box=%s shiny_box=%s" % row)
    if args.report_holes:
        print(f"SMALL_HOLE_FRAMES count={len(hole_rows)}")
        for dex, label, index, sizes in hole_rows:
            print(f"HOLES dex={dex:03d} variant={label} frame={index} sizes={sizes}")
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
