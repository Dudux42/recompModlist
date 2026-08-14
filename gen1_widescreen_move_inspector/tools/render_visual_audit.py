from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / ".audit" / "move_inspector_visual"
FONT = ROOT / "gen1_widescreen_ui" / "assets" / "fonts" / "pixelify_sans" / "PixelifySans-VariableFont_wght.ttf"

INK = (14, 17, 18, 255)
PAPER = (246, 246, 237, 250)
PAPER2 = (224, 227, 214, 250)
SELECTED = (19, 26, 31, 255)
WHITE = (255, 255, 245, 255)
ACCENT = (209, 41, 28, 255)
MUTED = (64, 69, 69, 255)
TYPE = {
    "NORMAL": (168, 168, 120), "FIRE": (240, 128, 48),
    "WATER": (104, 144, 240), "ELECTRIC": (248, 208, 48),
    "GRASS": (120, 200, 80), "ICE": (152, 216, 216),
    "FIGHTING": (192, 48, 40), "POISON": (160, 64, 160),
    "GROUND": (224, 192, 104), "FLYING": (168, 144, 240),
    "PSYCHIC": (248, 88, 136), "BUG": (168, 184, 32),
    "ROCK": (184, 160, 56), "GHOST": (112, 88, 152),
    "DRAGON": (112, 56, 248),
}


def font(size):
    return ImageFont.truetype(str(FONT), size)


F16, F12, F10 = font(16), font(12), font(10)


def panel(draw, box):
    x, y, w, h = box
    draw.rectangle((x + 4, y + 5, x + w + 4, y + h + 5), fill=(5, 6, 8, 150))
    draw.rectangle((x, y, x + w, y + h), fill=INK)
    draw.rectangle((x + 2, y + 2, x + w - 2, y + h - 2), fill=PAPER)
    draw.rectangle((x + 6, y + 6, x + w - 6, y + 7), fill=INK)
    draw.rectangle((x + 6, y + h - 8, x + w - 6, y + h - 7), fill=INK)


def fit(draw, text, face, width):
    if draw.textlength(text, font=face) <= width:
        return text
    while text and draw.textlength(text + "..", font=face) > width:
        text = text[:-1]
    return text + ".."


def type_badge(draw, type_id, x, y, w=132, h=16):
    label = type_id.replace("_TYPE", "").replace("_", " ")
    color = TYPE.get(label, (102, 110, 115))
    draw.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=INK)
    draw.rounded_rectangle((x + 1, y + 1, x + w - 1, y + h - 1), radius=(h - 2) // 2, fill=color)
    draw.rectangle((x + 4, y + 3, x + w - 4, y + 4), fill=tuple(min(255, c + 45) for c in color))
    text_color = INK if label in {"NORMAL", "ELECTRIC", "GRASS", "ICE", "GROUND", "ROCK"} else WHITE
    length = draw.textlength(label, font=F10)
    draw.text((x + (w - length) // 2, y + 2), label, font=F10, fill=text_color)


def status_panel(draw, enemy=True):
    box = (12, 10, 190, 52) if enemy else (442, 168, 190, 72)
    panel(draw, box)
    x, y, w, _ = box
    name = "VENUSAUR" if enemy else "CHARIZARD"
    draw.text((x + 13, y + 9), name, font=F12, fill=INK)
    draw.text((x + w - 44, y + 9), "Lv.50", font=F12, fill=INK)
    draw.text((x + 13, y + 29), "HP", font=F10, fill=MUTED)
    draw.rectangle((x + 50, y + 32, x + w - 13, y + 38), fill=INK)
    draw.rectangle((x + 51, y + 33, x + w - 28, y + 37), fill=(48, 181, 71))


def screen(state):
    image = Image.new("RGBA", (640, 360), (47, 72, 88, 255))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 72, 639, 243), fill=(106, 154, 94, 255))
    draw.ellipse((145, 104, 330, 169), fill=(208, 206, 173, 255))
    draw.ellipse((329, 181, 548, 243), fill=(205, 202, 168, 255))
    status_panel(draw, True)
    status_panel(draw, False)

    x, y, w, h = 8, 244, 624, 108
    panel(draw, (x, y, w, h))
    moves = state.get("moves", ["FLAMETHROWER", "SLASH", "FLY", "GROWL"])
    selected = state.get("selected", 1)
    swap = state.get("swap")
    for i in range(1, 5):
        col, row = (i - 1) % 2, (i - 1) // 2
        cx, cy = x + 12 + col * 221, y + 12 + row * 43
        chosen = i == selected
        draw.rectangle((cx, cy, cx + 216, cy + 38), fill=SELECTED if chosen else PAPER2)
        if chosen:
            draw.rectangle((cx, cy, cx + 5, cy + 38), fill=ACCENT)
        if swap == i and not chosen:
            draw.rectangle((cx + 2, cy + 2, cx + 214, cy + 36), outline=ACCENT, width=1)
        label = moves[i - 1] if i <= len(moves) else "-"
        draw.text((cx + 12, cy + 11), fit(draw, label, F12, 194), font=F12,
                  fill=WHITE if chosen else INK)

    dx = x + 463
    if state.get("basic"):
        draw.text((dx, y + 8), "MOVE INFO", font=F12, fill=MUTED)
        type_badge(draw, state.get("type", "NORMAL"), dx, y + 28)
        draw.text((dx, y + 51), state.get("pp", "PP  10/10"), font=F12, fill=INK)
    else:
        draw.text((dx, y + 8), "MOVE INSPECTOR", font=F12, fill=MUTED)
        type_badge(draw, state.get("type", "FIRE"), dx, y + 25)
        draw.text((dx, y + 45), state.get("pp", "PP  11/15"), font=F10, fill=INK)
        stats = f"POW {state.get('power', '95')}  ACC {state.get('accuracy', '100%')}"
        draw.text((dx, y + 59), fit(draw, stats, F10, 150), font=F10, fill=INK)
        match = f"{state.get('matchup', 'SUPER EFFECTIVE')} {state.get('multiplier', '4×')}"
        draw.text((dx, y + 73), fit(draw, match, F10, 150), font=F10, fill=INK)
        flags = state.get("flags", "STAB")
        if flags:
            draw.text((dx, y + 87), flags, font=F10, fill=ACCENT if "DISABLED" in flags else MUTED)
    return image


def add_label(image, label):
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 250, 22), fill=(0, 0, 0, 210))
    draw.text((8, 3), label, font=F12, fill=WHITE)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scenarios = [
        ("4x + STAB / four moves", {}),
        ("neutral / two moves", {"moves": ["TACKLE", "TAIL WHIP"], "type": "NORMAL", "pp": "PP  35/35", "power": "40", "accuracy": "100%", "matchup": "NEUTRAL", "multiplier": "1×", "flags": ""}),
        ("long names / resisted", {"moves": ["SOLAR BEAM EXTENDED", "DOUBLE-EDGE", "RAZOR LEAF", "SLEEP POWDER"], "type": "GRASS", "power": "120", "accuracy": "100%", "matchup": "RESISTED", "multiplier": "½×", "flags": "STAB"}),
        ("type immunity", {"type": "ELECTRIC", "power": "95", "matchup": "IMMUNE", "multiplier": "0×", "flags": ""}),
        ("status move", {"type": "NORMAL", "power": "—", "accuracy": "100%", "matchup": "TYPE CHART", "multiplier": "1×", "flags": ""}),
        ("fixed damage", {"type": "GHOST", "power": "FIXED", "accuracy": "100%", "matchup": "TYPE CHART", "multiplier": "0×", "flags": ""}),
        ("special formula", {"type": "FIGHTING", "power": "VARIES", "accuracy": "100%", "matchup": "TYPE CHART", "multiplier": "2×", "flags": ""}),
        ("disabled + swap", {"selected": 2, "swap": 4, "type": "NORMAL", "flags": "STAB  DISABLED"}),
        ("zero PP / boosted max", {"pp": "PP  0/24", "type": "FIRE", "flags": "STAB"}),
        ("dual-type target", {"type": "FIRE", "matchup": "SUPER EFFECTIVE", "multiplier": "4×"}),
        ("always-hit accuracy", {"type": "NORMAL", "power": "60", "accuracy": "ALWAYS", "matchup": "NEUTRAL", "multiplier": "1×", "flags": "STAB"}),
        ("Mimic safe basic panel", {"basic": True, "moves": ["SURF", "ICE BEAM", "BODY SLAM", "RECOVER"], "type": "WATER", "pp": "PP  15/15"}),
    ]
    montage = Image.new("RGBA", (640 * 4, 360 * 3), (18, 18, 18, 255))
    for index, (label, state) in enumerate(scenarios):
        card = screen(state)
        add_label(card, label)
        montage.paste(card, ((index % 4) * 640, (index // 4) * 360))
    montage.save(OUT / "widescreen_move_inspector_states.png")

    base = screen({})
    for name, width, height in [
        ("1080p", 1920, 1080), ("1440p", 2560, 1440),
        ("4k", 3840, 2160), ("narrow_1280x800", 1280, 800),
    ]:
        scale = min(width // 640, height // 360)
        scaled = base.resize((640 * scale, 360 * scale), Image.Resampling.NEAREST)
        output = Image.new("RGBA", (width, height), (8, 8, 8, 255))
        output.paste(scaled, ((width - scaled.width) // 2, (height - scaled.height) // 2))
        output.save(OUT / f"widescreen_move_inspector_{name}.png")


if __name__ == "__main__":
    main()
