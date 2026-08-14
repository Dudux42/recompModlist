from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "gen1_widescreen_ui" / "assets" / "fonts" / "pixelify_sans" / "PixelifySans-VariableFont_wght.ttf"
OUT = ROOT / "visual_audits" / "gen1_quality_of_life_alpha4_catch_hud.png"

img = Image.new("RGB", (640, 360), (54, 92, 55))
d = ImageDraw.Draw(img)
for y in range(0, 360, 16):
    d.line((0, y, 640, y), fill=(45, 76, 47), width=1)
for x in range(0, 640, 16):
    d.line((x, 0, x, 360), fill=(45, 76, 47), width=1)

ink = (14, 17, 18)
paper = (246, 246, 237)
shadow = (5, 6, 8)
red = (230, 26, 26)
small = ImageFont.truetype(str(FONT), 12)
tiny = ImageFont.truetype(str(FONT), 10)


def panel(x, y, w, h):
    d.rectangle((x + 4, y + 5, x + w + 3, y + h + 4), fill=shadow)
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=ink)
    d.rectangle((x + 2, y + 2, x + w - 3, y + h - 3), fill=paper)
    d.rectangle((x + 6, y + 6, x + w - 7, y + 7), fill=ink)
    d.rectangle((x + 6, y + h - 8, x + w - 7, y + h - 7), fill=ink)


panel(12, 10, 190, 52)
name = "SANDSHREW"
d.text((25, 19), name, font=small, fill=ink)
name_width = d.textlength(name, font=small)

ball = [
    "..KKKK..", ".KRRRRK.", "KRRRRRRK", "KKKWWKKK",
    "KWWWWWWK", ".KWWWWK.", "..KKKK..",
]
colors = {"K": ink, "R": red, "W": paper}
bx, by = int(25 + name_width + 5), 21
for py, row in enumerate(ball):
    for px, value in enumerate(row):
        if value in colors:
            d.point((bx + px, by + py), fill=colors[value])

level = "Lv.13"
d.text((189 - d.textlength(level, font=small), 19), level, font=small, fill=ink)
d.text((25, 39), "HP", font=tiny, fill=(64, 69, 69))
d.rounded_rectangle((62, 42, 189, 47), radius=3, fill=(36, 42, 39))
d.rounded_rectangle((64, 44, 184, 45), radius=1, fill=(41, 184, 75))

panel(12, 60, 190, 30)
d.text((21, 69), "P 36%    G 64%    U 56%", font=tiny, fill=ink)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.resize((1280, 720), Image.Resampling.NEAREST).save(OUT)
print(OUT)
