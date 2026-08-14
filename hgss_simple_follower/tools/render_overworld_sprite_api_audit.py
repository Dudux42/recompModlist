"""Render a focused HGSS Overworld Sprite API normal/shiny/voxel audit."""

from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else (
    ROOT.parent / "visual_audits" / "hgss_simple_follower_alpha18_provider_api.png"
)
SAMPLES = [(1, "BULBASAUR"), (25, "PIKACHU"), (94, "GENGAR"), (151, "MEW")]
SCALE = 3
FRAME = 32


def font(size: int):
    candidates = [
        Path(r"C:\Windows\Fonts\consola.ttf"),
        Path(r"C:\Windows\Fonts\arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def load_sheet(kind: str, dex: int) -> Image.Image:
    directory = "runtime_followers" if kind == "normal" else "runtime_shiny"
    path = ROOT / "assets" / directory / f"{dex:03d}.png"
    image = Image.open(path).convert("RGBA")
    if image.size != (32, 192):
        raise ValueError(f"{path} is {image.size}, expected 32x192")
    return image


def frame_strip(sheet: Image.Image) -> Image.Image:
    strip = Image.new("RGBA", (FRAME * 6, FRAME), (0, 0, 0, 0))
    for index in range(6):
        cell = sheet.crop((0, index * FRAME, FRAME, (index + 1) * FRAME))
        strip.alpha_composite(cell, (index * FRAME, 0))
    return strip.resize((FRAME * 6 * SCALE, FRAME * SCALE), Image.Resampling.NEAREST)


def checker(draw: ImageDraw.ImageDraw, box, cell=12):
    x0, y0, x1, y1 = box
    for y in range(y0, y1, cell):
        for x in range(x0, x1, cell):
            color = (44, 50, 64) if ((x - x0) // cell + (y - y0) // cell) % 2 else (57, 64, 80)
            draw.rectangle((x, y, min(x + cell - 1, x1), min(y + cell - 1, y1)), fill=color)


title_font, label_font, small_font = font(24), font(16), font(13)
canvas = Image.new("RGB", (1420, 720), (24, 28, 38))
draw = ImageDraw.Draw(canvas)
draw.text((24, 18), "HGSS OVERWORLD SPRITE API v1 — ALPHA 18 VISUAL AUDIT", font=title_font,
          fill=(238, 242, 250))
draw.text((24, 52), "Six 32×32 frames • nearest-neighbor 3× • normal/shiny pairs • provider voxel seam",
          font=small_font, fill=(173, 184, 204))

row_y = 90
for dex, name in SAMPLES:
    draw.text((24, row_y + 38), f"#{dex:03d} {name}", font=label_font, fill=(238, 242, 250))
    for column, kind in enumerate(("normal", "shiny")):
        x = 185 + column * 595
        draw.text((x, row_y - 20), kind.upper(), font=small_font,
                  fill=(136, 211, 255) if kind == "normal" else (255, 213, 106))
        box = (x, row_y, x + FRAME * 6 * SCALE, row_y + FRAME * SCALE)
        checker(draw, box)
        strip = frame_strip(load_sheet(kind, dex))
        canvas.paste(strip, (x, row_y), strip)
        draw.rectangle(box, outline=(102, 116, 145), width=1)
        for frame_index in range(1, 6):
            fx = x + frame_index * FRAME * SCALE
            draw.line((fx, row_y, fx, row_y + FRAME * SCALE), fill=(83, 94, 118))
    row_y += 132

# Provider geometry panel: exact values used by both voxel seams.
panel = (24, 620, 1396, 696)
draw.rounded_rectangle(panel, radius=8, fill=(33, 38, 50), outline=(83, 95, 120), width=1)
draw.text((42, 632), "FLAT CARD", font=small_font, fill=(145, 220, 164))
draw.text((145, 632), "32×32 at (px−8, py−20), integer draw, one body", font=small_font,
          fill=(223, 229, 240))
draw.text((520, 632), "VOXEL CARD", font=small_font, fill=(145, 220, 164))
draw.text((630, 632), "X −8…24 • Y 0…32 • normalized 16×96 proxy UVs", font=small_font,
          fill=(223, 229, 240))
draw.text((1040, 632), "ANCHOR", font=small_font, fill=(145, 220, 164))
draw.text((1110, 632), "16×16 collision unchanged", font=small_font, fill=(223, 229, 240))
draw.line((42, 666, 1380, 666), fill=(74, 84, 105))
draw.text((42, 673), "Markers: hgssOverworldSprite=true; no hgssSimpleFollower tag; Dramatic Shape and Battle Art Voxel Fork share the same centered seam.",
          font=small_font, fill=(173, 184, 204))

OUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUT)
print(OUT)
