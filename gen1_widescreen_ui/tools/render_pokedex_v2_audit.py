"""Render deterministic layout audits for Widescreen Pokedex Provider API v2.

This mirrors the 640x360 presenter geometry in main.lua. It is a visual QA
fixture, not a second runtime renderer and is never packaged with the mod.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parent / "visual_audits" / "gen1_widescreen_ui_alpha14_pokedex_v2"
FONT = ROOT / "assets" / "fonts" / "pixelify_sans" / "PixelifySans-VariableFont_wght.ttf"

PAPER = (246, 246, 237)
PAPER2 = (224, 227, 214)
INK = (14, 17, 18)
SELECTED = (19, 26, 31)
SELECTED_TEXT = (255, 255, 245)
ACCENT = (209, 41, 28)
MUTED = (64, 69, 69)
GREEN = (31, 158, 69)
BLUE = (45, 132, 222)

F16 = ImageFont.truetype(str(FONT), 16)
F12 = ImageFont.truetype(str(FONT), 12)
F10 = ImageFont.truetype(str(FONT), 10)


def panel(draw, box):
    x, y, w, h = box
    draw.rectangle((x + 5, y + 5, x + w + 5, y + h + 5), fill=(10, 12, 13, 150))
    draw.rectangle((x, y, x + w, y + h), fill=PAPER, outline=INK, width=3)
    draw.line((x + 9, y + 10, x + w - 9, y + 10), fill=INK, width=2)
    draw.line((x + 9, y + h - 10, x + w - 9, y + h - 10), fill=INK, width=2)


def text(draw, xy, value, font=F12, fill=INK, anchor=None):
    draw.text(xy, str(value), font=font, fill=fill, anchor=anchor)


def header(draw, title, page=None):
    text(draw, (20, 14), title, F16)
    draw.rectangle((184, 30, 454, 32), fill=ACCENT)
    if page:
        text(draw, (620, 17), page, F12, MUTED, "ra")


def badge(draw, x, y, label, color):
    draw.rounded_rectangle((x, y, x + 82, y + 20), 10, fill=color, outline=INK, width=1)
    text(draw, (x + 41, y + 10), label, F10, (255, 255, 250), "mm")


def portrait(draw, x, y, hidden=False):
    if hidden:
        text(draw, (x + 62, y + 60), "?", F16, MUTED, "mm")
        return
    # Pixel-art-shaped audit stand-in; runtime art still comes from Battle Art.
    draw.rectangle((x + 36, y + 18, x + 86, y + 75), fill=(240, 207, 47), outline=INK, width=3)
    draw.polygon(((x + 40, y + 20), (x + 48, y), (x + 58, y + 22)), fill=(240, 207, 47), outline=INK)
    draw.polygon(((x + 65, y + 22), (x + 80, y + 3), (x + 83, y + 30)), fill=(240, 207, 47), outline=INK)
    draw.rectangle((x + 46, y + 40, x + 52, y + 46), fill=INK)
    draw.rectangle((x + 70, y + 40, x + 76, y + 46), fill=INK)
    draw.rectangle((x + 31, y + 73, x + 49, y + 101), fill=(180, 135, 33), outline=INK)
    draw.rectangle((x + 76, y + 73, x + 94, y + 101), fill=(180, 135, 33), outline=INK)


def base_main(kind="owned", submenu=False, long_entry=False):
    im = Image.new("RGB", (640, 360), PAPER)
    d = ImageDraw.Draw(im)
    header(d, "POKEDEX")
    panel(d, (20, 52, 260, 266))
    panel(d, (292, 52, 328, 266))
    names = ["BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER", "CHARMELEON", "CHARIZARD", "SQUIRTLE", "WARTORTLE"]
    for i, name in enumerate(names):
        y = 62 + i * 29
        selected = i == 0
        d.rectangle((29, y, 271, y + 26), fill=SELECTED if selected else PAPER2)
        if selected:
            d.rectangle((29, y, 34, y + 26), fill=ACCENT)
        shown = "?????" if kind == "unseen" and i == 0 else name
        text(d, (42, y + 5), f"{i + 1:03d}  {shown}", F12, SELECTED_TEXT if selected else INK)
        if i in (0, 1) and kind != "unseen":
            d.ellipse((251, y + 7, 261, y + 17), outline=SELECTED_TEXT if selected else INK)
    hidden = kind == "unseen"
    name = "?????" if hidden else "BULBASAUR"
    text(d, (309, 67), name, F16)
    text(d, (310, 95), "No. 001", F12, MUTED)
    portrait(d, 477, 65, hidden)
    if hidden:
        text(d, (310, 165), "NO DATA RECORDED", F12, MUTED)
    else:
        text(d, (310, 122), "SEED POKEMON", F12)
        text(d, (310, 146), "HT  0.7 m", F12)
        text(d, (310, 168), "WT  6.9 kg", F12)
        entry = ("A strange seed was planted on its back at birth. The plant sprouts and grows with this POKEMON. "
                 "This deliberately long fixture verifies rendered-width wrapping and clipping.") if long_entry else (
                 "A strange seed was planted on its back at birth.")
        words, lines, line = entry.split(), [], ""
        for word in words:
            candidate = word if not line else line + " " + word
            if d.textlength(candidate, font=F12) > 290:
                lines.append(line); line = word
            else:
                line = candidate
        if line: lines.append(line)
        for i, line in enumerate(lines[:5]):
            text(d, (310, 203 + i * 18), line, F12, MUTED if kind == "unowned" else INK)
    if submenu:
        panel(d, (377, 90, 226, 210))
        text(d, (393, 103), "RESEARCH", F12)
        labels = ["HABITAT", "STATS", "LEARNSET", "EVOLUTION", "CRY"]
        for i, label in enumerate(labels):
            y = 130 + i * 31
            d.rectangle((387, y, 593, y + 27), fill=SELECTED if i == 0 else PAPER2)
            if i == 0: d.rectangle((387, y, 392, y + 27), fill=ACCENT)
            text(d, (401, y + 5), label, F12, SELECTED_TEXT if i == 0 else INK)
    text(d, (20, 334), "SEEN 001     OWN 001     TOTAL 151", F10, MUTED)
    text(d, (620, 334), "A DETAILS     B BACK", F10, MUTED, "ra")
    return im


def research(mode, gated=False, long=False):
    im = Image.new("RGB", (640, 360), PAPER)
    d = ImageDraw.Draw(im)
    header(d, f"POKEDEX / {mode}", "025  PIKACHU")
    panel(d, (20, 52, 600, 266))
    if gated:
        text(d, (320, 184), "RESEARCH DATA LOCKED - CATCH THIS POKEMON", F16, MUTED, "mm")
    elif mode == "STATS":
        badge(d, 38, 67, "ELECTRIC", (222, 180, 20))
        for i, (label, value) in enumerate((("HP", 35), ("ATTACK", 55), ("DEFENSE", 30), ("SPEED", 90), ("SPECIAL", 50), ("TOTAL", 260))):
            y = 100 + i * 33
            d.rectangle((36, y, 604, y + 28), fill=PAPER2)
            text(d, (50, y + 5), label, F12)
            text(d, (216, y + 5), value, F12, anchor="ra")
            if label != "TOTAL":
                d.rectangle((244, y + 8, 585, y + 20), fill=(190, 192, 180))
                d.rectangle((244, y + 8, 244 + int(341 * value / 255), y + 20), fill=GREEN)
    else:
        rows = []
        if mode == "HABITAT":
            rows = [("VIRIDIAN FOREST", "GRASS", "Lv.3-5", "10.0%"), ("POWER PLANT", "CAVE", "Lv.20-24", "5.0%")]
        elif mode == "LEARNSET":
            rows = [("LEVEL-UP MOVES", "", "", "")]
            rows += [(f"{i:02d}", f"LONG MOVE NAME {i}", "ELECTRIC", f"PP {10+i}") for i in range(1, 15 if long else 6)]
        else:
            rows = [("RAICHU", "USE THUNDER STONE", "", ""), ("?????", "SPECIAL CONDITION", "", "")]
        for i, row in enumerate(rows[:7]):
            y = 65 + i * 32
            d.rectangle((33, y, 607, y + 28), fill=SELECTED if i == 0 else PAPER2)
            if i == 0: d.rectangle((33, y, 38, y + 28), fill=ACCENT)
            color = SELECTED_TEXT if i == 0 else INK
            text(d, (47, y + 5), row[0], F12, color)
            text(d, (273, y + 5), row[1], F12, color)
            text(d, (424, y + 5), row[2], F10, color)
            text(d, (590, y + 5), row[3], F10, color, "ra")
    text(d, (20, 334), "UP / DOWN  SCROLL     LEFT / RIGHT  PAGE", F10, MUTED)
    text(d, (620, 334), "B BACK", F10, MUTED, "ra")
    return im


def place_at_resolution(base, size):
    ww, wh = size
    scale = min(ww / 640, wh / 360)
    scaled = base.resize((round(640 * scale), round(360 * scale)), Image.Resampling.NEAREST)
    out = Image.new("RGB", size, INK)
    out.paste(scaled, ((ww - scaled.width) // 2, (wh - scaled.height) // 2))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    states = {
        "main_unseen": base_main("unseen"),
        "main_seen_unowned": base_main("unowned"),
        "main_owned_long_entry": base_main("owned", long_entry=True),
        "submenu": base_main("owned", submenu=True),
        "habitat": research("HABITAT"),
        "stats": research("STATS"),
        "learnset_long": research("LEARNSET", long=True),
        "evolution": research("EVOLUTION"),
        "gated": research("STATS", gated=True),
    }
    contact = Image.new("RGB", (1920, 1080), INK)
    for i, (name, image) in enumerate(states.items()):
        contact.paste(image, ((i % 3) * 640, (i // 3) * 360))
        image.save(OUT / f"{name}_640x360.png")
    contact.save(OUT / "contact_sheet_3x3.png")
    resolutions = {
        "1080p": (1920, 1080), "1440p": (2560, 1440),
        "4k": (3840, 2160), "narrow_4x3": (1280, 960),
    }
    for label, size in resolutions.items():
        folder = OUT / label
        folder.mkdir(exist_ok=True)
        for name, image in states.items():
            place_at_resolution(image, size).save(folder / f"{name}.png")
    print(OUT)


if __name__ == "__main__":
    main()
