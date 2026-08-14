"""Schematic integer-scale audit of the alpha 3 HM menu flow."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "visual_audits" / "gen1_quality_of_life_alpha3_hm_flow.png"
S = 3
FONT = ImageFont.load_default(size=18)


def box(draw, x, y, w, h, fill="#f7f4df", outline="#171820", width=2):
    draw.rectangle((x*S, y*S, (x+w)*S, (y+h)*S), fill=fill,
                   outline=outline, width=width*S)


def text(draw, x, y, value, color="#171820"):
    draw.text((x*S, y*S), value, fill=color, font=FONT)


def panel(draw, ox, title):
    box(draw, ox, 0, 160, 144, fill="#d9e3dc", outline="#d9e3dc", width=1)
    text(draw, ox+5, 4, title, "#171820")


OUTPUT.parent.mkdir(parents=True, exist_ok=True)
image = Image.new("RGB", (1458, 432), "#252b35")
draw = ImageDraw.Draw(image)

panel(draw, 0, "START MENU")
box(draw, 75, 18, 78, 117)
for i, label in enumerate(["POKEMON", "HMs", "ITEM", "RED", "SAVE", "OPTION"]):
    y = 29 + i*17
    text(draw, 88, y, label)
    if label == "HMs": text(draw, 79, y, ">")

panel(draw, 164, "OBTAINED HMS")
box(draw, 225, 18, 92, 117)
for i, label in enumerate(["CUT", "FLY", "SURF", "STRENGTH", "FLASH", "CANCEL"]):
    y = 29 + i*17
    text(draw, 242, y, label)
    if label == "FLY": text(draw, 231, y, ">")

panel(draw, 328, "CONFIRMATION")
box(draw, 336, 18, 144, 96, fill="#c9d8c8")
text(draw, 365, 51, "TOWN MAP / VISITED CITY")
box(draw, 336, 112, 144, 30)
text(draw, 346, 120, "Use FLY?")
box(draw, 429, 66, 43, 43)
text(draw, 442, 75, "YES")
text(draw, 442, 92, "NO")
text(draw, 433, 75, ">")

image.save(OUTPUT)
print(OUTPUT)
