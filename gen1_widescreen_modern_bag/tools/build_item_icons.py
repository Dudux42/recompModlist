"""Build faithful 32x32 Bag icons from the user-supplied source strips.

Only border-connected matte pixels are removed. Every surviving source pixel
is cropped, optionally resized with nearest-neighbor sampling, and centered on
a transparent 32x32 canvas. Input hashes and cell counts are mandatory.
"""

from __future__ import annotations

import argparse
import hashlib
from collections import deque
from pathlib import Path

from PIL import Image


SHEETS = {
    "balls": ("codex-clipboard-91530dc9-0a66-48c9-ade0-ac846b591010.png", "4D00CF7C94EE0BC77513C6C879DDA41A93890A713A46D1FE9EF82A242ACE80C9", [
        "master_ball", "ultra_ball", "great_ball", "poke_ball", "safari_ball"]),
    "medicine": ("codex-clipboard-df66754d-f3db-47c6-8e41-7f9c28d4ee29.png", "5B09EA041DBE71FC8D04FCC2F663A06203A9DC1652641C50898B7B248A5FBF46", [
        "potion", "super_potion", "hyper_potion", "max_potion", "full_restore",
        "antidote", "burn_heal", "ice_heal", "awakening", "parlyz_heal",
        "full_heal", "revive", "max_revive"]),
    "drinks": ("codex-clipboard-051d275e-5bb0-4fc8-93fd-964d5f4e8ef5.png", "BE19E85D3CF6B9C99D8A35F798DD5306D13FA1DB657E33BF25A21413D6C7CEC4", [
        "fresh_water", "soda_pop", "lemonade"]),
    "vitamins": ("codex-clipboard-81b5dbc9-4fdd-4874-9f40-db07d2c020ef.png", "24ED4529C2C30516462857350BED360629F0EFF8F7DD1E2746C3903CA90A3826", [
        "hp_up", "protein", "iron", "calcium", None, "carbos", "pp_up", None]),
    "repels_stones": ("codex-clipboard-2a83d7f5-74a7-4fa9-ad2e-98e2f0e8b659.png", "7BD46EEEEBAC4CFCA06E97C8990187D4773EA7DAA23925E00DEF696C79760C7F", [
        "repel", "super_repel", "max_repel", "escape_rope", "leaf_stone",
        "fire_stone", "water_stone", "thunder_stone", "moon_stone"]),
    "poke_doll": ("codex-clipboard-7078fe8a-145a-4b59-ac8d-2719ffbfd24f.png", "8137906D3F9521E4667B9A97044FD7A2D4AD1EDDADC4E9EA661A1D4E17AA5CD1", ["poke_doll"]),
    "fossils": ("codex-clipboard-c959f0c1-29ce-4104-8a3b-2cc8502c6d30.png", "93DD98C76190302628ACB02933F9DFA2F1C8A46B3852A22488A89FE467E6477C", [
        "helix_fossil", "dome_fossil", "old_amber"]),
    "key_items_2": ("codex-clipboard-238f8f0e-1dfe-46c3-8674-d7cecda3e464.png", "42A279C105058E257D50F6270EC669157B43F43BA6E21CB29FCD5296473B204F", [
        "card_key", "poke_flute", "gold_teeth", "secret_key", "old_rod",
        "good_rod", "super_rod"]),
    "ss_ticket": ("codex-clipboard-72a4a31c-6764-483a-948b-28aa64b0fb0d.png", "5D1335EBD5ACE6B7E5F4B1D531A90551864EE511791DD98D4471416BDCB3C540", ["ss_ticket"]),
    "bike_voucher": ("codex-clipboard-ef6e8a06-f4de-42bd-ae5b-422a90677f4a.png", "22EB442DC73D343291C79FCE6D69275A6DAC84034F0C5956447F211B34FD2A59", ["bike_voucher"]),
    "parcel": ("codex-clipboard-ee7388ef-9501-4c5a-ad4f-ed595d2e8a94.png", "C5B96EF2294DE4DF9D3395B261DDFB939E4B844F78A81DA4D5EEB460FA8A2449", ["oaks_parcel"]),
    "tm": ("codex-clipboard-f48d8eaa-76a9-4bb0-9733-77baff11cd35.png", "72BD3216245F6A36B24FD15C09F53304C777E7283019400BD92037052E0E4872", ["tm"]),
    "hm": ("codex-clipboard-e0748ba2-05f2-4ce2-9d79-5015f52724ef.png", "5642A3F92033896C06C1A2DB565624CE5FED8407C31474B0A4FEE148EC39300D", ["hm"]),
    "key_items_1": ("codex-clipboard-75cb25f7-644d-46c9-85a0-60bc160e1aed.png", "A30D2FDE0AA43ECD20EFEF39883392185332B1FC216EC0966E98B467B17A7F53", [
        "bicycle", "itemfinder", "lift_key", "silph_scope", "coin_case"]),
    "pp": ("codex-clipboard-e0492580-1126-4a91-a38f-04129bc4bcc8.png", "B3F756074F9C56AF45B1635A4F9444319F75F13D8FE249AAFF4919D2207E3956", [
        "ether", "max_ether", "elixer", "max_elixer"]),
    "rare_candy": ("codex-clipboard-335fa5c0-2329-4a26-a60d-20876e18d5d3.png", "2A984EE7C677676B96DA27C9CE5E039FC2C132025F80D73713ACC252118F1C2D", ["rare_candy"]),
    "battle": ("codex-clipboard-3c224b35-c3b3-4f0f-beba-72e21dadba28.png", "FED9A914B8C97C6C68860A647D8CC836E0CD5C4B7623B2A752AD2E9B0E221E50", [
        "guard_spec", "dire_hit", "x_attack", "x_defend", "x_speed",
        "x_accuracy", "x_special"]),
    "exp_all": ("codex-clipboard-d3a93ba9-a287-4026-9e0f-819f173c4766.png", "80E4EABECF8AC4F801AF1F3C866D373A05CAD854B328E723340BC5337D2867CF", ["exp_all"]),
    "nugget": ("codex-clipboard-0186f465-1b1a-4bad-93ef-404efffe966f.png", "BB0AC683294E1BA8753E4722B764E3B37F853DD8828AFCE3A72940BB6822E82F", ["nugget"]),
    "town_map": ("codex-clipboard-511a30b2-7c10-45ce-a36a-f03a0f1388ca.png", "7D9D5295F62A0A29113C375E616A46ACC81989B1DE5248ECDD829E37F0036F69", ["town_map"]),
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def remove_border_matte(source: Image.Image) -> Image.Image:
    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    matte = {(255, 127, 39), (255, 255, 255)}
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.append((x, 0)); queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y)); queue.append((width - 1, y))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        r, g, b, a = pixels[x, y]
        if a == 0:
            pass
        elif (r, g, b) in matte:
            pixels[x, y] = (r, g, b, 0)
        else:
            continue
        if x: queue.append((x - 1, y))
        if x + 1 < width: queue.append((x + 1, y))
        if y: queue.append((x, y - 1))
        if y + 1 < height: queue.append((x, y + 1))
    # Orange is the exact sheet matte. Remove enclosed remnants too (such as
    # rope loops and disc holes) without touching neighboring shaded colors.
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) == (255, 127, 39):
                pixels[x, y] = (r, g, b, 0)
    return image


def occupied_runs(image: Image.Image) -> list[tuple[int, int]]:
    alpha = image.getchannel("A")
    occupied = [x for x in range(image.width)
                if alpha.crop((x, 0, x + 1, image.height)).getbbox()]
    runs: list[list[int]] = []
    for x in occupied:
        if not runs or x > runs[-1][1] + 1:
            runs.append([x, x])
        else:
            runs[-1][1] = x
    return [(start, end) for start, end in runs]


def normalize(cell: Image.Image) -> Image.Image:
    bbox = cell.getchannel("A").getbbox()
    if not bbox:
        raise ValueError("empty icon cell")
    icon = cell.crop(bbox)
    if icon.width > 30 or icon.height > 30:
        scale = min(30 / icon.width, 30 / icon.height)
        size = (max(1, round(icon.width * scale)), max(1, round(icon.height * scale)))
        icon = icon.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.alpha_composite(icon, ((32 - icon.width) // 2, (32 - icon.height) // 2))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for sheet, (filename, expected_hash, names) in SHEETS.items():
        path = args.source_dir / filename
        if not path.is_file():
            raise FileNotFoundError(f"{sheet}: missing {path}")
        actual = digest(path)
        if actual != expected_hash:
            raise ValueError(f"{sheet}: SHA256 {actual} != {expected_hash}")
        image = remove_border_matte(Image.open(path))
        runs = occupied_runs(image)
        if len(runs) != len(names):
            raise ValueError(f"{sheet}: found {len(runs)} cells, expected {len(names)}")
        for (start, end), name in zip(runs, names):
            if name is None:
                continue
            output = args.out_dir / f"bag_item_{name}.png"
            normalize(image.crop((start, 0, end + 1, image.height))).save(output)
            written.append(output)
    if len(written) != 72:
        raise ValueError(f"wrote {len(written)} icons, expected 72")
    print(f"Built {len(written)} faithful 32x32 RGBA icons in {args.out_dir}")


if __name__ == "__main__":
    main()
