from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "gen1_widescreen_ui" / "assets" / "fonts" / "pixelify_sans" / "PixelifySans-VariableFont_wght.ttf"
OUT = ROOT / "visual_audits" / "gen1_quality_of_life_alpha6_location_banner.png"

img = Image.new("RGB", (640, 360), (50, 89, 51))
d = ImageDraw.Draw(img)
for y in range(0, 360, 16):
    d.line((0, y, 640, y), fill=(42, 75, 44))
for x in range(0, 640, 16):
    d.line((x, 0, x, 360), fill=(42, 75, 44))

shadow = (5, 6, 8)
ink = (14, 17, 18)
paper = (246, 246, 237)
font = ImageFont.truetype(str(FONT), 16)
text = "ROUTE 4"
text_box = d.textbbox((0, 0), text, font=font)
text_w = text_box[2] - text_box[0]
text_h = text_box[3] - text_box[1]
w, h = max(180, text_w + 48), 48
x, y = (640 - w) // 2, 10

d.rectangle((x + 4, y + 5, x + w + 3, y + h + 4), fill=shadow)
d.rectangle((x, y, x + w - 1, y + h - 1), fill=ink)
d.rectangle((x + 2, y + 2, x + w - 3, y + h - 3), fill=paper)
d.rectangle((x + 6, y + 6, x + w - 7, y + 7), fill=ink)
d.rectangle((x + 6, y + h - 8, x + w - 7, y + h - 7), fill=ink)
d.text((x + (w - text_w) // 2, y + (h - text_h) // 2 - text_box[1]),
       text, font=font, fill=ink)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.resize((1280, 720), Image.Resampling.NEAREST).save(OUT)
print(OUT)
