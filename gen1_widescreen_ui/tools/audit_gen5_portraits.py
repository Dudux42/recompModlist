"""Audit final-frame Gen 5 Battle Art bounds and fitted UI size."""

import io
import re
import sys
import zipfile

from PIL import Image


archive_path, data_path = sys.argv[1], sys.argv[2]
text = open(data_path, encoding="utf-8").read()
pattern = re.compile(
    r"^\s*([A-Z0-9_]+)\s*=\s*\{\s*\n"
    r"\s*front\s*=\s*\{\s*image\s*=\s*\"([^\"]+)\""
    r"\s*,\s*width\s*=\s*(\d+)\s*,\s*height\s*=\s*(\d+)"
    r"\s*,\s*columns\s*=\s*(\d+)\s*,\s*frames\s*=\s*(\d+)",
    re.MULTILINE,
)

rows = []
with zipfile.ZipFile(archive_path) as archive:
    for match in pattern.finditer(text):
        species, path, width, height, columns, frames = match.groups()
        width, height, columns, frames = map(int, (width, height, columns, frames))
        sheet = Image.open(io.BytesIO(archive.read(path))).convert("RGBA")
        index = frames - 1
        x, y = (index % columns) * width, (index // columns) * height
        cell = sheet.crop((x, y, x + width, y + height))
        bbox = cell.getchannel("A").getbbox()
        if not bbox:
            continue
        opaque_w, opaque_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        scale = min(56 / opaque_w, 66 / opaque_h)
        shown_w, shown_h = opaque_w * scale, opaque_h * scale
        aspect = max(opaque_w / opaque_h, opaque_h / opaque_w)
        rows.append((shown_h, -aspect, species, opaque_w, opaque_h, shown_w))

rows.sort()
limit = int(sys.argv[3]) if len(sys.argv) > 3 else 25
for shown_h, neg_aspect, species, opaque_w, opaque_h, shown_w in rows[:limit]:
    print(
        f"{species:12} bounds={opaque_w:2}x{opaque_h:2} "
        f"shown={shown_w:4.1f}x{shown_h:4.1f} aspect={-neg_aspect:.2f}"
    )
