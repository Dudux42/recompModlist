from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

from build_hgss_battle_art_assets import (
    BACK_MATTE as HGSS_BACK_MATTE,
    FRAME_H as HGSS_FRAME_H,
    FRAME_W as HGSS_FRAME_W,
    FRONT_FRAME_X as HGSS_FRONT_FRAME_X,
    NORMAL_Y as HGSS_NORMAL_Y,
    SHINY_Y as HGSS_SHINY_Y,
    panel_box as hgss_panel_box,
    panel_starts as hgss_panel_starts,
    trim_shared_frames as hgss_trim_shared_frames,
    transparent_front as hgss_transparent_front,
)
from build_frlg_battle_art_assets import (
    source_cell as frlg_source_cell,
    transparent_front as frlg_transparent_front,
    trim_pair as frlg_trim_pair,
)
from build_emerald_battle_art_assets import (
    source_cell as emerald_source_cell,
    transparent_front as emerald_transparent_front,
    trim_shared_frames as emerald_trim_shared_frames,
)


MICRO_HOLE_MAX = 3


def repair_gif_micro_holes(frame: Image.Image, key_rgb: tuple[int, int, int]) -> int:
    alpha = frame.getchannel("A")
    width, height = frame.size
    pixels = alpha.load()
    outside: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        point = (x, y)
        if point not in outside and pixels[x, y] == 0:
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

    visited = set(outside)
    repaired = 0
    rgba = frame.load()
    for y in range(height):
        for x in range(width):
            if pixels[x, y] != 0 or (x, y) in visited:
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
                            and pixels[nx, ny] == 0 and (nx, ny) not in visited):
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) <= MICRO_HOLE_MAX:
                for px, py in component:
                    rgba[px, py] = (*key_rgb, 255)
                repaired += len(component)
    return repaired


def add_file(archive: zipfile.ZipFile, source: Path, name: str) -> None:
    info = zipfile.ZipInfo(name)
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, source.read_bytes())


def audit_assets(source: Path, audit_path: Path, hgss_sheet: Path | None = None,
                 frlg_sheet: Path | None = None,
                 emerald_normal_sheet: Path | None = None,
                 emerald_shiny_sheet: Path | None = None) -> None:
    normal_files = sorted(source.glob("pokemon_static_gen5_front_[0-9][0-9][0-9].png"))
    shiny_files = sorted(source.glob("pokemon_static_gen5_front_[0-9][0-9][0-9]_shiny.png"))
    animated_files = sorted(source.glob("pokemon_animated_gen5_front_[0-9][0-9][0-9].png"))
    animated_shiny_files = sorted(source.glob("pokemon_animated_gen5_front_[0-9][0-9][0-9]_shiny.png"))
    hgss_normal_files = sorted(source.glob("pokemon_static_gen4HGSS_front_[0-9][0-9][0-9].png"))
    hgss_shiny_files = sorted(source.glob("pokemon_static_gen4HGSS_front_[0-9][0-9][0-9]_shiny.png"))
    hgss_animated_files = sorted(source.glob("pokemon_animated_gen4HGSS_front_[0-9][0-9][0-9].png"))
    hgss_animated_shiny_files = sorted(source.glob("pokemon_animated_gen4HGSS_front_[0-9][0-9][0-9]_shiny.png"))
    frlg_normal_files = sorted(source.glob("pokemon_static_gen3FRLG_front_[0-9][0-9][0-9].png"))
    frlg_shiny_files = sorted(source.glob("pokemon_static_gen3FRLG_front_[0-9][0-9][0-9]_shiny.png"))
    emerald_normal_files = sorted(source.glob("pokemon_static_gen3Emerald_front_[0-9][0-9][0-9].png"))
    emerald_shiny_files = sorted(source.glob("pokemon_static_gen3Emerald_front_[0-9][0-9][0-9]_shiny.png"))
    emerald_animated_files = sorted(source.glob("pokemon_animated_gen3Emerald_front_[0-9][0-9][0-9].png"))
    emerald_animated_shiny_files = sorted(source.glob("pokemon_animated_gen3Emerald_front_[0-9][0-9][0-9]_shiny.png"))
    platinum_sets = [sorted(source.glob(pattern)) for pattern in (
        "pokemon_static_gen4Platinum_front_[0-9][0-9][0-9].png",
        "pokemon_static_gen4Platinum_front_[0-9][0-9][0-9]_shiny.png",
        "pokemon_animated_gen4Platinum_front_[0-9][0-9][0-9].png",
        "pokemon_animated_gen4Platinum_front_[0-9][0-9][0-9]_shiny.png",
    )]
    crystal_sets = [sorted(source.glob(pattern)) for pattern in (
        "pokemon_static_gen2Crystal_front_[0-9][0-9][0-9].png",
        "pokemon_static_gen2Crystal_front_[0-9][0-9][0-9]_shiny.png",
        "pokemon_animated_gen2Crystal_front_[0-9][0-9][0-9].png",
        "pokemon_animated_gen2Crystal_front_[0-9][0-9][0-9]_shiny.png",
    )]
    red_blue_files = sorted(source.glob("pokemon_static_gen1RedBlue_front_[0-9][0-9][0-9].png"))
    yellow_files = sorted(source.glob("pokemon_static_gen1Yellow_front_[0-9][0-9][0-9].png"))
    if len(normal_files) != 151 or len(shiny_files) != 151:
        raise SystemExit(f"expected 151+151 PNGs, found {len(normal_files)}+{len(shiny_files)}")
    counts = (len(animated_files), len(animated_shiny_files),
              len(red_blue_files), len(yellow_files))
    if counts != (151, 151, 151, 151):
        raise SystemExit(f"animated/cartridge asset count mismatch: {counts}")
    hgss_counts = (len(hgss_normal_files), len(hgss_shiny_files),
                   len(hgss_animated_files), len(hgss_animated_shiny_files))
    if hgss_counts != (151, 151, 151, 151):
        raise SystemExit(f"HGSS asset count mismatch: {hgss_counts}")
    if (len(frlg_normal_files), len(frlg_shiny_files)) != (151, 151):
        raise SystemExit("FRLG asset count mismatch")
    emerald_counts = (len(emerald_normal_files), len(emerald_shiny_files),
                      len(emerald_animated_files),
                      len(emerald_animated_shiny_files))
    if emerald_counts != (151, 151, 151, 151):
        raise SystemExit(f"Emerald asset count mismatch: {emerald_counts}")
    if tuple(map(len, platinum_sets)) != (151, 151, 151, 151):
        raise SystemExit(f"Platinum asset count mismatch: {tuple(map(len, platinum_sets))}")
    if tuple(map(len, crystal_sets)) != (151, 151, 151, 151):
        raise SystemExit(f"Crystal asset count mismatch: {tuple(map(len, crystal_sets))}")
    for set_name, groups in (("Platinum", platinum_sets), ("Crystal", crystal_sets)):
        for dex in range(151):
            still, shiny_still, atlas, shiny_atlas = (
                Image.open(group[dex]).convert("RGBA") for group in groups)
            if any(image.getbbox() is None for image in
                   (still, shiny_still, atlas, shiny_atlas)):
                raise SystemExit(f"empty {set_name} asset at Dex {dex + 1:03d}")
            for label, image in (("normal", still), ("shiny", shiny_still)):
                if image.getchannel("A").getextrema()[0] != 0:
                    raise SystemExit(
                        f"{set_name} {label} lacks transparency at Dex {dex + 1:03d}")
                if any(image.getpixel(point)[3] != 0 for point in
                       ((0, 0), (image.width - 1, 0),
                        (0, image.height - 1), (image.width - 1, image.height - 1))):
                    raise SystemExit(
                        f"{set_name} {label} has opaque corner at Dex {dex + 1:03d}")
            if set_name == "Platinum" and (
                    atlas.size != (still.width * 2, still.height)
                    or shiny_atlas.size != (shiny_still.width * 2,
                                            shiny_still.height)):
                raise SystemExit(f"Platinum atlas dimensions mismatch at Dex {dex + 1:03d}")
    redundant_gender = [path.name for path in source.glob("pokemon_*_front_*.png")
                        if "female" in path.name.lower()
                        or "gender" in path.name.lower()]
    if redundant_gender:
        raise SystemExit(f"redundant gender assets found: {redundant_gender[:5]}")
    if not hgss_sheet:
        raise SystemExit("--hgss-sheet is required to audit HGSS source extraction")
    hgss_source = Image.open(hgss_sheet).convert("RGB")
    hgss_starts = hgss_panel_starts(hgss_source)
    if not frlg_sheet:
        raise SystemExit("--frlg-sheet is required to audit FRLG source extraction")
    frlg_source = Image.open(frlg_sheet).convert("RGB")
    if not emerald_normal_sheet or not emerald_shiny_sheet:
        raise SystemExit("both Emerald source sheets are required for audit")
    emerald_sources = (
        Image.open(emerald_normal_sheet).convert("RGB"),
        Image.open(emerald_shiny_sheet).convert("RGB"),
    )

    pairs = []
    dimensions = set()
    metadata_text = (source / "animation_metadata.lua").read_text(encoding="utf-8")
    metadata_rows = re.findall(
        r"\[(\d+)\] = \{ width = (\d+), height = (\d+), columns = (\d+), "
        r"frames = (\d+), durations = \{([^}]*)\}", metadata_text)
    if len(metadata_rows) != 151:
        raise SystemExit(f"expected 151 animation metadata rows, found {len(metadata_rows)}")
    mask_cache = source.parent / ".audit" / "battle_art_transparency"
    gif_cache = source.parent / ".audit" / "gen5_animated_gifs"
    metadata_lines = {
        int(match.group(1)): match.group(0)
        for line in metadata_text.splitlines()
        if (match := re.match(r"\s*\[(\d+)\].*", line))
    }
    audited_frames = 0
    repaired_pixels = 0
    audited_hgss_frames = 0
    audited_frlg_fronts = 0
    audited_emerald_frames = 0
    for dex, paths in enumerate(zip(normal_files, shiny_files, animated_files,
                                     animated_shiny_files, red_blue_files,
                                     yellow_files), 1):
        normal_path, shiny_path, animated_path, animated_shiny_path, red_blue_path, yellow_path = paths
        if f"_{dex:03d}.png" not in normal_path.name:
            raise SystemExit(f"normal mapping gap at Dex {dex:03d}: {normal_path.name}")
        if f"_{dex:03d}_shiny.png" not in shiny_path.name:
            raise SystemExit(f"shiny mapping gap at Dex {dex:03d}: {shiny_path.name}")
        normal = Image.open(normal_path).convert("RGBA")
        shiny = Image.open(shiny_path).convert("RGBA")
        if normal.getbbox() is None or shiny.getbbox() is None:
            raise SystemExit(f"empty sprite at Dex {dex:03d}")
        if normal.getchannel("A").getextrema()[0] != 0 \
                or shiny.getchannel("A").getextrema()[0] != 0:
            raise SystemExit(f"sprite lacks transparent background at Dex {dex:03d}")
        for label, image in (("normal", normal), ("shiny", shiny)):
            if any(image.getpixel(point)[3] != 0 for point in
                   ((0, 0), (image.width - 1, 0), (0, image.height - 1),
                    (image.width - 1, image.height - 1))):
                raise SystemExit(
                    f"Gen 5 {label} still has an opaque canvas corner at Dex {dex:03d}")
        if hashlib.sha256(normal.tobytes()).digest() == hashlib.sha256(shiny.tobytes()).digest():
            raise SystemExit(f"normal/shiny pair is identical at Dex {dex:03d}")
        dimensions.add(normal.size)
        animated = Image.open(animated_path).convert("RGBA")
        animated_shiny = Image.open(animated_shiny_path).convert("RGBA")
        red_blue = Image.open(red_blue_path).convert("RGBA")
        yellow = Image.open(yellow_path).convert("RGBA")
        if any(image.getbbox() is None for image in (animated, animated_shiny,
                                                      red_blue, yellow)):
            raise SystemExit(f"empty animation/cartridge sprite at Dex {dex:03d}")
        if red_blue.getchannel("A").getextrema()[0] != 0 \
                or yellow.getchannel("A").getextrema()[0] != 0:
            raise SystemExit(f"cartridge sprite lacks transparent background at Dex {dex:03d}")
        for set_name, image in (("gen1RedBlue", red_blue), ("gen1Yellow", yellow)):
            reference = Image.open(mask_cache / f"{set_name}_{dex:03d}.png").convert("RGBA")
            reference_alpha = reference.getchannel("A")
            reference_box = reference_alpha.getbbox()
            actual_alpha = image.getchannel("A")
            actual_box = actual_alpha.getbbox()
            if not (reference_box and actual_box):
                raise SystemExit(f"empty cartridge alpha mask at Dex {dex:03d}")
            expected = reference_alpha.crop(reference_box)
            actual = actual_alpha.crop(actual_box)
            if expected.size != actual.size or expected.tobytes() != actual.tobytes():
                raise SystemExit(f"cartridge alpha mask mismatch {set_name} Dex {dex:03d}")

        row = metadata_rows[dex - 1]
        row_dex, width, height, columns, frame_count, durations = row
        width, height, columns, frame_count = map(
            int, (width, height, columns, frame_count))
        if int(row_dex) != dex or len(durations.split(",")) != frame_count:
            raise SystemExit(f"animation metadata mismatch at Dex {dex:03d}")
        normal_contract = (width, height, columns, frame_count,
                           list(map(int, durations.split(","))))
        for label, atlas, still, suffix in (
                ("normal", animated, normal, ""),
                ("shiny", animated_shiny, shiny, "_shiny")):
            reference = Image.open(gif_cache / f"{dex:03d}{suffix}.gif")
            transparency = reference.info.get("transparency")
            palette = reference.getpalette()
            if not (isinstance(transparency, int) and palette):
                raise SystemExit(f"GIF lacks indexed transparency at Dex {dex:03d}{suffix}")
            key_rgb = tuple(palette[transparency * 3:transparency * 3 + 3])
            ref_width, ref_height = reference.size
            ref_count = reference.n_frames
            ref_columns = min(16, ref_count)
            ref_durations = []
            if atlas.size != (ref_columns * ref_width,
                              ((ref_count + ref_columns - 1) // ref_columns) * ref_height):
                raise SystemExit(f"{label} atlas dimensions mismatch at Dex {dex:03d}")
            first_frame = None
            for frame in range(ref_count):
                reference.seek(frame)
                expected = reference.convert("RGBA").copy()
                repaired_pixels += repair_gif_micro_holes(expected, key_rgb)
                ref_durations.append(max(1, int(reference.info.get("duration") or 100)))
                x = (frame % ref_columns) * ref_width
                y = (frame // ref_columns) * ref_height
                actual = atlas.crop((x, y, x + ref_width, y + ref_height))
                normalized = Image.new("RGBA", expected.size, (0, 0, 0, 0))
                normalized.alpha_composite(expected)
                if normalized.tobytes() != actual.tobytes():
                    raise SystemExit(
                        f"{label} GIF/atlas pixel or alpha mismatch at "
                        f"Dex {dex:03d} frame {frame + 1}")
                if frame == 0: first_frame = expected
                audited_frames += 1
            if first_frame is None or first_frame.size != still.size \
                    or first_frame.tobytes() != still.tobytes():
                raise SystemExit(f"{label} neutral still mismatch at Dex {dex:03d}")
            contract = (ref_width, ref_height, ref_columns, ref_count, ref_durations)
            if label == "normal" and contract != normal_contract:
                raise SystemExit(f"normal metadata/GIF mismatch at Dex {dex:03d}")
            if label == "shiny" and contract != normal_contract:
                line = metadata_lines.get(dex, "")
                match = re.search(
                    r"shiny = \{ width = (\d+), height = (\d+), columns = (\d+), "
                    r"frames = (\d+), durations = \{([^}]*)\}", line)
                if not match:
                    raise SystemExit(f"missing shiny metadata override at Dex {dex:03d}")
                override = (int(match.group(1)), int(match.group(2)),
                            int(match.group(3)), int(match.group(4)),
                            list(map(int, match.group(5).split(","))))
                if override != contract:
                    raise SystemExit(f"shiny metadata/GIF mismatch at Dex {dex:03d}")
        if hashlib.sha256(animated.tobytes()).digest() == hashlib.sha256(animated_shiny.tobytes()).digest():
            raise SystemExit(f"animated normal/shiny pair is identical at Dex {dex:03d}")

        x0, y0, _, _ = hgss_panel_box(hgss_starts, dex - 1)
        hgss_expected = []
        for label, row_y in (("normal", HGSS_NORMAL_Y),
                             ("shiny", HGSS_SHINY_Y)):
            for frame_x in HGSS_FRONT_FRAME_X:
                source_x0, source_y0 = x0, y0
                matte = (147, 187, 236)
                if dex == 140:
                    source_x0, source_y0 = hgss_starts[151]
                    if label == "shiny":
                        matte = HGSS_BACK_MATTE
                cell = hgss_source.crop((source_x0 + frame_x, source_y0 + row_y,
                                         source_x0 + frame_x + HGSS_FRAME_W,
                                         source_y0 + row_y + HGSS_FRAME_H))
                expected, _ = hgss_transparent_front(cell, matte)
                hgss_expected.append(expected)
        hgss_expected = hgss_trim_shared_frames(hgss_expected)
        expected_frame_size = hgss_expected[0].size
        for label, still_path, atlas_path, expected_offset in (
                ("normal", hgss_normal_files[dex - 1],
                 hgss_animated_files[dex - 1], 0),
                ("shiny", hgss_shiny_files[dex - 1],
                 hgss_animated_shiny_files[dex - 1], 2)):
            if f"_{dex:03d}" not in still_path.name or f"_{dex:03d}" not in atlas_path.name:
                raise SystemExit(f"HGSS {label} mapping gap at Dex {dex:03d}")
            still = Image.open(still_path).convert("RGBA")
            atlas = Image.open(atlas_path).convert("RGBA")
            frame_w, frame_h = expected_frame_size
            if still.size != expected_frame_size \
                    or atlas.size != (frame_w * 2, frame_h):
                raise SystemExit(f"HGSS {label} dimensions mismatch at Dex {dex:03d}")
            for frame_index in range(2):
                expected = hgss_expected[expected_offset + frame_index]
                actual = atlas.crop((frame_index * frame_w, 0,
                                     (frame_index + 1) * frame_w, frame_h))
                if actual.tobytes() != expected.tobytes():
                    raise SystemExit(
                        f"HGSS {label} source/front mismatch at Dex {dex:03d} "
                        f"frame {frame_index + 1}")
                if frame_index == 0 and still.tobytes() != expected.tobytes():
                    raise SystemExit(f"HGSS {label} neutral still mismatch at Dex {dex:03d}")
                audited_hgss_frames += 1

        expected_frlg = frlg_trim_pair([
            frlg_transparent_front(frlg_source_cell(frlg_source, dex, shiny))[0]
            for shiny in (False, True)
        ])
        actual_frlg = []
        for is_frlg_shiny, expected, path in zip(
                (False, True), expected_frlg,
                (frlg_normal_files[dex - 1], frlg_shiny_files[dex - 1])):
            if (f"_{dex:03d}_shiny.png" if is_frlg_shiny else f"_{dex:03d}.png") \
                    not in path.name:
                raise SystemExit(f"FRLG mapping gap at Dex {dex:03d}")
            actual = Image.open(path).convert("RGBA")
            if actual.size != expected.size or actual.tobytes() != expected.tobytes():
                raise SystemExit(f"FRLG source/front mismatch at Dex {dex:03d}")
            if any(actual.getpixel(point)[3] != 0 for point in
                   ((0, 0), (actual.width - 1, 0), (0, actual.height - 1),
                    (actual.width - 1, actual.height - 1))):
                raise SystemExit(f"FRLG opaque trimmed corner at Dex {dex:03d}")
            actual_frlg.append(actual)
            audited_frlg_fronts += 1

        emerald_expected = emerald_trim_shared_frames([
            emerald_transparent_front(
                emerald_source_cell(sheet, dex, frame_index))[0]
            for sheet in emerald_sources for frame_index in range(2)
        ])
        emerald_frame_size = emerald_expected[0].size
        for label, still_path, atlas_path, expected_offset in (
                ("normal", emerald_normal_files[dex - 1],
                 emerald_animated_files[dex - 1], 0),
                ("shiny", emerald_shiny_files[dex - 1],
                 emerald_animated_shiny_files[dex - 1], 2)):
            if f"_{dex:03d}" not in still_path.name \
                    or f"_{dex:03d}" not in atlas_path.name:
                raise SystemExit(f"Emerald {label} mapping gap at Dex {dex:03d}")
            still = Image.open(still_path).convert("RGBA")
            atlas = Image.open(atlas_path).convert("RGBA")
            frame_w, frame_h = emerald_frame_size
            if still.size != emerald_frame_size \
                    or atlas.size != (frame_w * 2, frame_h):
                raise SystemExit(f"Emerald {label} dimensions mismatch at Dex {dex:03d}")
            for frame_index in range(2):
                expected = emerald_expected[expected_offset + frame_index]
                actual = atlas.crop((frame_index * frame_w, 0,
                                     (frame_index + 1) * frame_w, frame_h))
                if actual.tobytes() != expected.tobytes():
                    raise SystemExit(
                        f"Emerald {label} source/front mismatch at Dex {dex:03d} "
                        f"frame {frame_index + 1}")
                if frame_index == 0 and still.tobytes() != expected.tobytes():
                    raise SystemExit(
                        f"Emerald {label} neutral still mismatch at Dex {dex:03d}")
                audited_emerald_frames += 1
        pairs.append((red_blue, yellow, actual_frlg[0], actual_frlg[1],
                      normal, shiny))

    columns, cell_w, cell_h = 8, 380, 132
    rows = (len(pairs) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), (28, 32, 42, 255))
    draw = ImageDraw.Draw(sheet)
    for index, images in enumerate(pairs):
        col, row = index % columns, index // columns
        x, y = col * cell_w, row * cell_h
        draw.text((x + 4, y + 3),
                  f"{index + 1:03d} R/B Y FRLG FRLGS G5 G5S",
                  fill=(235, 239, 248, 255))
        max_w, max_h = 58, 100
        for side, image in enumerate(images):
            scale = max(1, min(max_w // image.width, max_h // image.height))
            shown = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
            px = x + 4 + side * 62 + (58 - shown.width) // 2
            py = y + 22 + (104 - shown.height) // 2
            sheet.alpha_composite(shown, (px, py))
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(audit_path, optimize=True)
    if not re.search(
            r"hgss\s*=\s*\{\s*columns\s*=\s*2,\s*frames\s*=\s*2,\s*durations\s*=\s*"
            r"\{500,500\}\s*\}", metadata_text):
        raise SystemExit("missing or malformed HGSS animation metadata")
    if not re.search(
            r"platinum\s*=\s*\{\s*columns\s*=\s*2,\s*frames\s*=\s*2,\s*durations\s*=\s*"
            r"\{500,500\}\s*\}", metadata_text):
        raise SystemExit("missing or malformed Platinum animation metadata")
    crystal_metadata = (source / "crystal_animation_metadata.lua").read_text(
        encoding="utf-8")
    if len(re.findall(r"^\s*\[\d+\]\s*=", crystal_metadata, re.MULTILINE)) != 151:
        raise SystemExit("Crystal animation metadata does not contain 151 species")
    if not re.search(r"durations\s*=\s*\{\d", crystal_metadata):
        raise SystemExit("Crystal animation metadata lacks authored durations")
    if not re.search(
            r"emerald\s*=\s*\{\s*columns\s*=\s*2,\s*frames\s*=\s*2,\s*durations\s*=\s*"
            r"\{500,500\}\s*\}", metadata_text):
        raise SystemExit("missing or malformed Emerald animation metadata")
    print(f"asset_audit=ok species=151 pngs=3624 animation_frames={audited_frames} "
          f"hgss_front_frames={audited_hgss_frames} "
          f"frlg_fronts={audited_frlg_fronts} gender_variants=0 "
          f"emerald_front_frames={audited_emerald_frames} "
          f"repaired_micro_hole_pixels={repaired_pixels} exact_gen1_masks=302 "
          f"dimensions={len(dimensions)} contact_sheet={audit_path}")


def package_flat(source: Path, release: Path, asset_glob: str | None = None) -> None:
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8-sig"))
    required = [source / "manifest.json", source / manifest["entry"],
                source / "README.md", source / "ASSET_PROVENANCE.md",
                source / "animation_metadata.lua",
                source / "crystal_animation_metadata.lua"]
    files = list(required)
    if asset_glob:
        files.extend(sorted(source.glob(asset_glob)))
    if len({path.name for path in files}) != len(files):
        raise SystemExit("flat package would contain duplicate basenames")
    release.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(release, "w") as archive:
        for path in files:
            add_file(archive, path, path.name)
    with zipfile.ZipFile(release) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any("/" in name or "\\" in name for name in names):
            raise SystemExit("release is not a unique flat ZIP")
        if "manifest.json" not in names or manifest["entry"] not in names:
            raise SystemExit("release is missing its root manifest/entry")
    expected_version = manifest["version"]
    if expected_version not in release.name:
        raise SystemExit("ZIP filename does not match manifest version")
    print(f"package=ok entries={len(files)} release={release}")


def package_widescreen(root: Path) -> None:
    source = root / "gen1_widescreen_ui"
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8-sig"))
    release = root / "Releases" / f"gen1_widescreen_ui_v{manifest['version']}.zip"
    files = [
        (source / "manifest.json", "manifest.json"),
        (source / "main.lua", "main.lua"),
        (source / "README.md", "README.md"),
        (source / "assets" / "party_icons.png", "party_icons.png"),
        (source / "assets" / "fonts" / "pixelify_sans" /
         "PixelifySans-VariableFont_wght.ttf", "PixelifySans-VariableFont_wght.ttf"),
        (source / "assets" / "fonts" / "pixelify_sans" / "OFL.txt", "OFL.txt"),
    ]
    with zipfile.ZipFile(release, "w") as archive:
        for path, name in files:
            add_file(archive, path, name)
    with zipfile.ZipFile(release) as archive:
        names = archive.namelist()
        if len(names) != 6 or len(names) != len(set(names)):
            raise SystemExit("Widescreen package does not contain six unique entries")
        if any("/" in name or "\\" in name for name in names):
            raise SystemExit("Widescreen package is not flat")
    print(f"package=ok entries=6 release={release}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--hgss-sheet", type=Path)
    parser.add_argument("--frlg-sheet", type=Path)
    parser.add_argument("--emerald-normal-sheet", type=Path)
    parser.add_argument("--emerald-shiny-sheet", type=Path)
    args = parser.parse_args()
    root = args.workspace.resolve()
    battle = root / "gen1_battle_art_replacer"
    battle_manifest = json.loads(
        (battle / "manifest.json").read_text(encoding="utf-8-sig"))
    audit_assets(battle, root / "visual_audits" / "gen1_battle_art_all_fronts.png",
                 args.hgss_sheet, args.frlg_sheet,
                 args.emerald_normal_sheet, args.emerald_shiny_sheet)
    package_flat(
        battle,
        root / "Releases" /
        f"gen1_battle_art_replacer_v{battle_manifest['version']}.zip",
        "pokemon_*_front_*.png",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
