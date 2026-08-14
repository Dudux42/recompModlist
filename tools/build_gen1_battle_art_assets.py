from __future__ import annotations

import argparse
import math
import re
import shutil
import urllib.request
from collections import Counter, defaultdict, deque
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image


MICRO_HOLE_MAX = 3


def repair_gif_micro_holes(frame: Image.Image, key_rgb: tuple[int, int, int]) -> int:
    """Restore tiny enclosed pixels lost to a GIF transparency-index collision."""
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


SPECIES = [
    "bulbasaur","ivysaur","venusaur","charmander","charmeleon","charizard",
    "squirtle","wartortle","blastoise","caterpie","metapod","butterfree",
    "weedle","kakuna","beedrill","pidgey","pidgeotto","pidgeot","rattata",
    "raticate","spearow","fearow","ekans","arbok","pikachu","raichu",
    "sandshrew","sandslash","nidoran-f","nidorina","nidoqueen","nidoran-m",
    "nidorino","nidoking","clefairy","clefable","vulpix","ninetales",
    "jigglypuff","wigglytuff","zubat","golbat","oddish","gloom","vileplume",
    "paras","parasect","venonat","venomoth","diglett","dugtrio","meowth",
    "persian","psyduck","golduck","mankey","primeape","growlithe","arcanine",
    "poliwag","poliwhirl","poliwrath","abra","kadabra","alakazam","machop",
    "machoke","machamp","bellsprout","weepinbell","victreebel","tentacool",
    "tentacruel","geodude","graveler","golem","ponyta","rapidash","slowpoke",
    "slowbro","magnemite","magneton","farfetchd","doduo","dodrio","seel",
    "dewgong","grimer","muk","shellder","cloyster","gastly","haunter",
    "gengar","onix","drowzee","hypno","krabby","kingler","voltorb",
    "electrode","exeggcute","exeggutor","cubone","marowak","hitmonlee",
    "hitmonchan","lickitung","koffing","weezing","rhyhorn","rhydon","chansey",
    "tangela","kangaskhan","horsea","seadra","goldeen","seaking","staryu",
    "starmie","mr-mime","scyther","jynx","electabuzz","magmar","pinsir",
    "tauros","magikarp","gyarados","lapras","ditto","eevee","vaporeon",
    "jolteon","flareon","porygon","omanyte","omastar","kabuto","kabutops",
    "aerodactyl","snorlax","articuno","zapdos","moltres","dratini","dragonair",
    "dragonite","mewtwo","mew",
]


def image_pixels(image: Image.Image):
    getter = getattr(image, "get_flattened_data", None)
    return getter() if getter else image.getdata()


def parse_front_sizes(metadata: Path) -> dict[str, tuple[int, int]]:
    text = metadata.read_text(encoding="utf-8")
    pattern = re.compile(
        r"^\s*([A-Z0-9_]+)\s*=\s*\{\s*\n"
        r"\s*front\s*=\s*\{[^\n]*?width\s*=\s*(\d+),\s*height\s*=\s*(\d+),",
        re.MULTILINE,
    )
    return {name.lower().replace("_", "-"): (int(w), int(h))
            for name, w, h in pattern.findall(text)}


def parse_front_metadata(metadata: Path):
    text = metadata.read_text(encoding="utf-8")
    blocks = re.finditer(
        r"^\s*([A-Z0-9_]+)\s*=\s*\{\s*\n"
        r"\s*front\s*=\s*\{([^\n]+)\}", text, re.MULTILINE)
    parsed = {}
    for match in blocks:
        slug = match.group(1).lower().replace("_", "-")
        body = match.group(2)
        numbers = {}
        for key in ("width", "height", "columns", "frames"):
            found = re.search(rf"\b{key}\s*=\s*(\d+)", body)
            if not found:
                raise SystemExit(f"missing {key} for {slug}")
            numbers[key] = int(found.group(1))
        durations = re.search(r"\bdurations\s*=\s*\{([^}]*)\}", body)
        if not durations:
            raise SystemExit(f"missing durations for {slug}")
        numbers["durations"] = [int(value) for value in durations.group(1).split(",")]
        if len(numbers["durations"]) != numbers["frames"]:
            raise SystemExit(f"duration/frame mismatch for {slug}")
        parsed[slug] = numbers
    return parsed


def write_animation_metadata(destination: Path, definitions):
    lines = ["-- Generated by tools/build_gen1_battle_art_assets.py.", "return {"]
    for dex, slug in enumerate(SPECIES, 1):
        item = definitions[slug]
        durations = ",".join(str(value) for value in item["durations"])
        shiny = item.get("shiny")
        shiny_text = ""
        if shiny:
            shiny_durations = ",".join(str(value) for value in shiny["durations"])
            shiny_text = (
                f", shiny = {{ width = {shiny['width']}, height = {shiny['height']}, "
                f"columns = {shiny['columns']}, frames = {shiny['frames']}, "
                f"durations = {{{shiny_durations}}} }}")
        lines.append(
            f"  [{dex}] = {{ width = {item['width']}, height = {item['height']}, "
            f"columns = {item['columns']}, frames = {item['frames']}, "
            f"durations = {{{durations}}}{shiny_text} }},")
    lines.append(
        "  hgss = { columns = 2, frames = 2, "
        "durations = {500,500} },")
    lines.append(
        "  platinum = { columns = 2, frames = 2, "
        "durations = {500,500} },")
    lines.append(
        "  emerald = { columns = 2, frames = 2, "
        "durations = {500,500} },")
    lines.extend(["}", ""])
    (destination / "animation_metadata.lua").write_text(
        "\n".join(lines), encoding="utf-8", newline="\n")


def download_gen1_sets(destination: Path):
    base = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/"
            "sprites/pokemon/versions/generation-i")
    sets = {
        "gen1RedBlue": "red-blue",
        "gen1Yellow": "yellow",
    }
    mask_cache = destination.parent / ".audit" / "battle_art_transparency"
    mask_cache.mkdir(parents=True, exist_ok=True)
    jobs = []
    for output_set, remote_set in sets.items():
        for dex in range(1, 152):
            output = destination / f"pokemon_static_{output_set}_front_{dex:03d}.png"
            if not output.exists():
                jobs.append((f"{base}/{remote_set}/{dex}.png", output))
            mask = mask_cache / f"{output_set}_{dex:03d}.png"
            if not mask.exists():
                jobs.append((f"{base}/{remote_set}/transparent/{dex}.png", mask))

    def fetch(job):
        url, output = job
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                data = response.read()
            output.write_bytes(data)
        except Exception as exc:
            raise RuntimeError(f"failed to download {url}: {exc}") from exc

    with ThreadPoolExecutor(max_workers=12) as pool:
        list(pool.map(fetch, jobs))

    # The compact colored Gen 1 PNGs preserve the cartridge background color.
    # Their 96x96 transparent companions provide exact binary sprite masks,
    # including holes fully enclosed by outlines. Transfer that mask onto the
    # compact canvas so legitimate white body pixels remain opaque.
    for output_set in sets:
        for dex in range(1, 152):
            path = destination / f"pokemon_static_{output_set}_front_{dex:03d}.png"
            image = Image.open(path).convert("RGBA")
            target_box = image.getchannel("A").getbbox()
            mask_image = Image.open(
                mask_cache / f"{output_set}_{dex:03d}.png").convert("RGBA")
            source_alpha = mask_image.getchannel("A")
            source_box = source_alpha.getbbox()
            if not (target_box and source_box):
                raise SystemExit(f"empty Gen 1 sprite or mask at Dex {dex:03d}")
            target_size = (target_box[2] - target_box[0], target_box[3] - target_box[1])
            source_size = (source_box[2] - source_box[0], source_box[3] - source_box[1])
            if target_size != source_size:
                raise SystemExit(
                    f"Gen 1 mask size mismatch {output_set} {dex:03d}: "
                    f"compact={target_size} mask={source_size}")
            alpha = Image.new("L", image.size, 0)
            alpha.paste(source_alpha.crop(source_box), (target_box[0], target_box[1]))
            image.putalpha(alpha)
            image.save(path, optimize=True)


def build_gen5_from_gifs(destination: Path):
    base = ("https://raw.githubusercontent.com/PokeAPI/sprites/master/"
            "sprites/pokemon/versions/generation-v/black-white/animated")
    cache = destination.parent / ".audit" / "gen5_animated_gifs"
    cache.mkdir(parents=True, exist_ok=True)
    jobs = []
    for dex in range(1, 152):
        for shiny in (False, True):
            suffix = "_shiny" if shiny else ""
            output = cache / f"{dex:03d}{suffix}.gif"
            if not output.exists():
                remote = f"shiny/{dex}.gif" if shiny else f"{dex}.gif"
                jobs.append((f"{base}/{remote}", output))

    def fetch(job):
        url, output = job
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                data = response.read()
            output.write_bytes(data)
        except Exception as exc:
            raise RuntimeError(f"failed to download {url}: {exc}") from exc

    with ThreadPoolExecutor(max_workers=12) as pool:
        list(pool.map(fetch, jobs))

    definitions = {}
    total_frames = 0
    repaired_pixels = 0
    for dex, slug in enumerate(SPECIES, 1):
        variants = {}
        for shiny in (False, True):
            suffix = "_shiny" if shiny else ""
            source = Image.open(cache / f"{dex:03d}{suffix}.gif")
            width, height = source.size
            transparency = source.info.get("transparency")
            palette = source.getpalette()
            if not (isinstance(transparency, int) and palette):
                raise SystemExit(f"GIF lacks indexed transparency: Dex {dex:03d}{suffix}")
            key_rgb = tuple(palette[transparency * 3:transparency * 3 + 3])
            frames, durations = [], []
            for frame_index in range(source.n_frames):
                source.seek(frame_index)
                frame = source.convert("RGBA").copy()
                repaired_pixels += repair_gif_micro_holes(frame, key_rgb)
                alpha = frame.getchannel("A")
                if alpha.getbbox() is None or alpha.getextrema()[0] != 0:
                    raise SystemExit(
                        f"GIF frame lacks transparent foreground separation: "
                        f"Dex {dex:03d}{suffix} frame {frame_index + 1}")
                if any(alpha.getpixel(point) != 0 for point in
                       ((0, 0), (width - 1, 0), (0, height - 1),
                        (width - 1, height - 1))):
                    raise SystemExit(
                        f"GIF frame has opaque canvas corner: Dex {dex:03d}"
                        f"{suffix} frame {frame_index + 1}")
                frames.append(frame)
                durations.append(max(1, int(source.info.get("duration") or 100)))
            variants[shiny] = (width, height, frames, durations)

        normal = variants[False]
        width, height, normal_frames, durations = normal
        normal_columns = min(16, len(normal_frames))
        for is_shiny, (variant_width, variant_height, frames, variant_durations) in variants.items():
            columns = min(16, len(frames))
            rows = math.ceil(len(frames) / columns)
            atlas = Image.new(
                "RGBA", (columns * variant_width, rows * variant_height),
                (0, 0, 0, 0))
            for index, frame in enumerate(frames):
                atlas.alpha_composite(
                    frame, ((index % columns) * variant_width,
                            (index // columns) * variant_height))
            suffix = "_shiny" if is_shiny else ""
            atlas.save(
                destination / f"pokemon_animated_gen5_front_{dex:03d}{suffix}.png",
                optimize=True)
            frames[0].save(
                destination / f"pokemon_static_gen5_front_{dex:03d}{suffix}.png",
                optimize=True)
        definitions[slug] = {
            "width": width,
            "height": height,
            "columns": normal_columns,
            "frames": len(normal_frames),
            "durations": durations,
        }
        shiny_width, shiny_height, shiny_frames, shiny_durations = variants[True]
        if (shiny_width, shiny_height, len(shiny_frames), shiny_durations) != \
                (width, height, len(normal_frames), durations):
            definitions[slug]["shiny"] = {
                "width": shiny_width,
                "height": shiny_height,
                "columns": min(16, len(shiny_frames)),
                "frames": len(shiny_frames),
                "durations": shiny_durations,
            }
        total_frames += len(normal_frames) + len(shiny_frames)
    write_animation_metadata(destination, definitions)
    print(f"built_gen5_gifs=302 species=151 decoded_frames={total_frames} "
          f"repaired_micro_hole_pixels={repaired_pixels}")


def palette_map(normal_sheet: Image.Image, shiny_sheet: Image.Image):
    votes: dict[tuple[int, int, int], Counter] = defaultdict(Counter)
    for normal, shiny in zip(image_pixels(normal_sheet), image_pixels(shiny_sheet)):
        votes[normal[:3]][shiny[:3]] += 1
    mapping = {normal: choices.most_common(1)[0][0] for normal, choices in votes.items()}
    ambiguous = sum(sum(choices.values()) - choices.most_common(1)[0][1]
                    for choices in votes.values())
    samples = sum(sum(choices.values()) for choices in votes.values())
    return mapping, ambiguous, samples


def recolor(image: Image.Image, mapping):
    source = image.convert("RGBA")
    pixels = []
    mapped = 0
    opaque = 0
    distances = []
    nearest_cache = {}
    palette = list(mapping)
    for pixel in image_pixels(source):
        source_rgb = pixel[:3]
        if pixel[3]:
            opaque += 1
            if source_rgb in mapping:
                mapped += 1
                nearest = source_rgb
                distance = 0.0
            else:
                nearest, distance = nearest_cache.get(source_rgb, (None, None))
                if nearest is None:
                    nearest = min(palette, key=lambda color: sum(
                        (color[channel] - source_rgb[channel]) ** 2
                        for channel in range(3)))
                    distance = math.sqrt(sum((nearest[channel] - source_rgb[channel]) ** 2
                                             for channel in range(3)))
                    nearest_cache[source_rgb] = (nearest, distance)
            distances.append(distance)
        else:
            nearest = source_rgb
        replacement = mapping.get(nearest, source_rgb)
        pixels.append((replacement[0], replacement[1], replacement[2], pixel[3]))
    output = Image.new("RGBA", source.size)
    output.putdata(pixels)
    return output, mapped, opaque, distances


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--download-gen1", action="store_true")
    parser.add_argument("--gen5-gifs", action="store_true")
    args = parser.parse_args()

    workspace = args.workspace.resolve()
    sheets = workspace / "pokemon_white2_front_spritesheets" / "gen1"
    destination = workspace / "gen1_battle_art_replacer"
    if args.gen5_gifs:
        build_gen5_from_gifs(destination)
        if args.download_gen1:
            download_gen1_sets(destination)
        return 0
    if not args.reference:
        parser.error("--reference is required unless --gen5-gifs is selected")
    reference = args.reference.resolve()
    metadata = reference / "data" / "animated_battle_sprites_gen5.lua"
    atlases = reference / "assets" / "battle" / "front-animated" / "gen5"
    definitions = parse_front_metadata(metadata)
    if len(definitions) != 151:
        raise SystemExit(f"expected 151 Gen 5 front definitions, found {len(definitions)}")
    write_animation_metadata(destination, definitions)
    if args.download_gen1:
        download_gen1_sets(destination)

    total_mapped = total_opaque = 0
    all_distances = []
    ambiguous_samples = palette_samples = 0
    species_coverage = []
    dimensions = Counter()
    for dex, slug in enumerate(SPECIES, 1):
        item = definitions[slug]
        width, height = item["width"], item["height"]
        atlas = Image.open(atlases / f"{slug}.png").convert("RGBA")
        if atlas.width < width or atlas.height < height:
            raise SystemExit(f"atlas too small for {slug}: {atlas.size} vs {(width, height)}")
        neutral = atlas.crop((0, 0, width, height))
        dimensions[neutral.size] += 1
        normal_out = destination / f"pokemon_static_gen5_front_{dex:03d}.png"
        neutral.save(normal_out, optimize=True)

        animated_out = destination / f"pokemon_animated_gen5_front_{dex:03d}.png"
        shutil.copyfile(atlases / f"{slug}.png", animated_out)

        normal_sheet = Image.open(sheets / "regular" / f"{dex:03d}.png").convert("RGBA")
        shiny_sheet = Image.open(sheets / "shiny" / f"{dex:03d}.png").convert("RGBA")
        mapping, ambiguous, samples = palette_map(normal_sheet, shiny_sheet)
        shiny, mapped, opaque, distances = recolor(neutral, mapping)
        shiny.save(destination / f"pokemon_static_gen5_front_{dex:03d}_shiny.png",
                   optimize=True)
        shiny_atlas, _, _, _ = recolor(atlas, mapping)
        shiny_atlas.save(
            destination / f"pokemon_animated_gen5_front_{dex:03d}_shiny.png",
            optimize=True)
        total_mapped += mapped
        total_opaque += opaque
        all_distances.extend(distances)
        ambiguous_samples += ambiguous
        palette_samples += samples
        species_coverage.append((100.0 * mapped / max(1, opaque), dex, slug))

    coverage = 100.0 * total_mapped / max(1, total_opaque)
    print(f"built_gen5=604 species=151 palette_coverage={coverage:.4f}%")
    if args.download_gen1:
        print("built_gen1=302 sets=red-blue,yellow options=red,blue,yellow")
    print(f"frame_dimensions={len(dimensions)} min={min(dimensions)} max={max(dimensions)}")
    print("lowest_species_coverage=" + ", ".join(
        f"{dex:03d}:{slug}:{pct:.2f}%" for pct, dex, slug
        in sorted(species_coverage)[:10]))
    ordered = sorted(all_distances)
    mean_distance = sum(ordered) / max(1, len(ordered))
    p95_distance = ordered[min(len(ordered) - 1, int(len(ordered) * 0.95))]
    print(f"palette_distance_mean={mean_distance:.3f} p95={p95_distance:.3f} "
          f"max={max(ordered):.3f}")
    ambiguity = 100.0 * ambiguous_samples / max(1, palette_samples)
    print(f"palette_ambiguity={ambiguity:.6f}%")
    if p95_distance > 32.0:
        raise SystemExit("palette distance p95 exceeds 32; refusing uncertain shiny art")
    if ambiguity > 0.01:
        raise SystemExit("palette mapping ambiguity exceeds 0.01%; refusing shiny art")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
