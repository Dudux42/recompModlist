"""Focused layout audit for the unified QOL battle overlays.

This deliberately renders only geometry owned by the mod over a schematic
battle HUD.  The final launcher/in-game pass remains authoritative.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "visual_audits" / "gen1_quality_of_life_alpha2_battle_overlays.png"
SCALE = 3

BALLS = {
    "gen2": [".KKKK.", "KK.KKK", "KKKKKK", "K....K", "K....K", ".KKKK."],
    "red": [
        "..KKKK..", ".KRRRRK.", "KRRRRRRK", "KKKWWKKK",
        "KWWWWWWK", ".KWWWWK.", "..KKKK..",
    ],
    "grey": [
        "..KKKK..", ".KGGGGK.", "KGGGGGGK", "KKKWWKKK",
        "KWWWWWWK", ".KWWWWK.", "..KKKK..",
    ],
}
COLORS = {"K": "#101018", "R": "#db2942", "G": "#777982", "W": "#f8f8f0"}


def rect(draw, box, fill, width=1):
    draw.rectangle(tuple(value * SCALE for value in box), fill=fill, width=width * SCALE)


def text(draw, xy, value, fill="#101018"):
    draw.text((xy[0] * SCALE, xy[1] * SCALE), value, fill=fill, font=FONT)


def ball(draw, rows, x, y, pixel=1):
    for py, row in enumerate(rows):
        for px, char in enumerate(row):
            if char in COLORS:
                rect(draw, (x + px * pixel, y + py * pixel,
                            x + (px + 1) * pixel - 1, y + (py + 1) * pixel - 1),
                     COLORS[char])


def panel(draw, left, top, width, height, title, mode, marker, wide=False, voxel=False):
    x0, y0 = left, top
    rect(draw, (x0, y0, x0 + width - 1, y0 + height - 1), "#d9e3dc")
    rect(draw, (x0 + 4, y0 + 17, x0 + width - 5, y0 + height - 5), "#f6f4df")
    text(draw, (x0 + 5, y0 + 3), title, "#f6f4df")
    text(draw, (x0 + 8, y0 + 24), "NIDORAN FEMALE  L18")
    text(draw, (x0 + 8, y0 + 38), "HP")
    rect(draw, (x0 + 27, y0 + 39, x0 + (115 if wide else 88), y0 + 42), "#101018")
    rect(draw, (x0 + 28, y0 + 40, x0 + (93 if wide else 72), y0 + 41), "#66a84d")
    ball(draw, BALLS[marker], x0 + (143 if wide else 126), y0 + 23, 1 if not voxel else 2)
    text(draw, (x0 + 8, y0 + 55), "P12 G23 U30")
    text(draw, (x0 + width - 88, y0 + height - 31), "PIKACHU  L21")
    if voxel:
        rect(draw, (x0 + width - 122, y0 + 50, x0 + width - 20, y0 + height - 40), "#c4c5cf")
        text(draw, (x0 + width - 110, y0 + 68), "SNAPPED HUD")
        text(draw, (x0 + width - 109, y0 + 79), "CANVAS")


OUTPUT.parent.mkdir(parents=True, exist_ok=True)
image = Image.new("RGB", (1512, 1020), "#262b35")
draw = ImageDraw.Draw(image)
FONT = ImageFont.load_default(size=21)
panel(draw, 8, 8, 160, 144, "CLASSIC / GEN2", "classic", "gen2")
panel(draw, 176, 8, 320, 144, "WIDE / RED", "wide", "red", wide=True)
panel(draw, 8, 160, 320, 180, "VOXEL SNAP / GREY", "voxel", "grey", wide=True, voxel=True)
text(draw, (337, 171), "AUDIT NOTES", "#f6f4df")
text(draw, (337, 190), "- marker remains beside enemy name", "#f6f4df")
text(draw, (337, 204), "- odds stay clear of art and HP", "#f6f4df")
text(draw, (337, 218), "- no EXP-bar ownership in this mod", "#f6f4df")
text(draw, (337, 232), "- voxel additions use snapped canvas", "#f6f4df")
text(draw, (337, 255), "Schematic layout audit; in-game rendering", "#bfc8d5")
text(draw, (337, 269), "with real fonts/palettes is still required.", "#bfc8d5")
image.save(OUTPUT)
print(OUTPUT)
