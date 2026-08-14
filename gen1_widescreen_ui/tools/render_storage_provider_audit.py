from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 640, 360
PAPER = (242, 242, 232)
PAPER2 = (225, 227, 214)
INK = (14, 17, 18)
SELECTED = (19, 26, 31)
ACCENT = (209, 41, 28)
MUTED = (64, 69, 69)
GREEN = (31, 158, 69)
OUT = Path(__file__).resolve().parents[2] / "visual_audits" / \
    "gen1_widescreen_ui_alpha14.32_storage"
FONT = ImageFont.load_default()


def label(draw, x, y, value, fill=INK):
    draw.text((x, y), value, font=FONT, fill=fill)


def panel(draw, box):
    draw.rectangle(box, fill=PAPER, outline=INK, width=2)
    x0, y0, x1, _ = box
    draw.line((x0 + 6, y0 + 7, x1 - 6, y0 + 7), fill=INK, width=2)


def target(draw, box, state="occupied", selected=False, disabled=False):
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=SELECTED if selected else PAPER2)
    line = (255, 255, 247) if selected else MUTED
    if selected:
        draw.rectangle((x0, y0, x0 + 3, y1), fill=ACCENT)
    if state == "held_origin":
        draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), outline=line)
        draw.rectangle((x0 + 5, y0 + 5, x1 - 5, y1 - 5), outline=line)
        draw.line((x1 - 12, y0 + 3, x1 - 3, y0 + 12), fill=line)
    elif state == "valid_target":
        k = 8
        for points in (((x0+2,y0+k),(x0+2,y0+2),(x0+k,y0+2)),
                       ((x1-k,y0+2),(x1-2,y0+2),(x1-2,y0+k)),
                       ((x0+2,y1-k),(x0+2,y1-2),(x0+k,y1-2)),
                       ((x1-k,y1-2),(x1-2,y1-2),(x1-2,y1-k))):
            draw.line(points, fill=line)
    elif state == "valid_swap":
        draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), outline=line)
        draw.line((x1 - 13, y0 + 3, x1 - 3, y0 + 13), fill=line)
        draw.line((x1 - 3, y0 + 3, x1 - 13, y0 + 13), fill=line)
    elif state == "invalid_target":
        draw.line((x0 + 3, y0 + 3, x1 - 3, y1 - 3), fill=line)
        draw.line((x1 - 3, y0 + 3, x0 + 3, y1 - 3), fill=line)
    if disabled:
        draw.line((x0 + 2, y1 - 3, x1 - 2, y1 - 3), fill=line)
        draw.line((x0 + 2, y1 - 6, x1 - 2, y1 - 6), fill=line)


def base_scene(active=True, party=True, popup=False, target_states=False,
               disabled_reason=None):
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    label(d, 18, 12, "MOVE POKEMON")
    d.rectangle((18, 37, 622, 39), fill=ACCENT)
    drawer_w = 110 if party else 0
    gx = 12 + drawer_w + (8 if drawer_w else 0)
    dx, gw = 430, 430 - gx - 8
    if party:
        panel(d, (12, 51, 122, 321)); label(d, 22, 61, "PARTY")
        for i, name in enumerate(("SPARK", "EEVEE", "", "", "", "")):
            y = 79 + i * 38
            state = "invalid_target" if target_states and i == 1 else "occupied"
            target(d, (20, y, 114, y + 33), state, selected=i == 0,
                   disabled=target_states and i == 1)
            if name:
                d.ellipse((28, y + 5, 50, y + 27), fill=(244, 196, 44), outline=INK)
                label(d, 57, y + 11, name, (255,255,247) if i == 0 else INK)
    panel(d, (gx, 51, dx - 8, 321))
    label(d, gx + 12, 65, "BOX 01   19/20")
    if active:
        d.rectangle((gx + 145, 60, gx + 193, 77), fill=PAPER2, outline=INK)
        label(d, gx + 151, 65, "ACTIVE")
    target(d, (dx - 76, 58, dx - 18, 80), selected=False)
    label(d, dx - 65, 65, "PARTY")
    cell_gap = 4
    cell_w = (gw - 24 - cell_gap * 4) // 5
    names = ["SPARK", "IVY", "ZUBAT", "MEOWTH", "POLI", "ABRA", "VULPIX",
             "GLOOM", "EEVEE", "DITTO", "PONYTA", "LAPRAS", "MAGMAR",
             "DRATINI", "PIDGEY", "MACHOP", "GASTLY", "CUBONE", "TAUROS", ""]
    states = ["held_origin", "valid_target", "valid_swap", "invalid_target"]
    for i, name in enumerate(names):
        col, row = i % 5, i // 5
        x, y = gx + 12 + col * (cell_w + cell_gap), 85 + row * 58
        state = states[i] if target_states and i < 4 else ("empty" if not name else "occupied")
        target(d, (x, y, x + cell_w, y + 52), state, selected=i == 0,
               disabled=target_states and i == 3)
        if name:
            d.ellipse((x + cell_w//2 - 11, y + 4, x + cell_w//2 + 11, y + 26),
                      fill=(244,196,44), outline=INK)
            label(d, x + max(3, (cell_w-len(name)*6)//2), y + 38, name,
                  (255,255,247) if i == 0 else INK)
    panel(d, (438, 51, 628, 321))
    label(d, 451, 64, "SPARK"); label(d, 451, 81, "PIKACHU   F", MUTED)
    d.rounded_rectangle((451, 98, 521, 114), 8, fill=(226,194,45), outline=INK)
    label(d, 465, 102, "ELECTRIC")
    d.ellipse((505, 120, 561, 176), fill=(244,196,44), outline=INK, width=2)
    label(d, 451, 190, "Lv.25", MUTED); label(d, 555, 190, "HP 61/72", MUTED)
    d.rectangle((451, 207, 615, 214), outline=INK); d.rectangle((452,208,589,213), fill=GREEN)
    label(d, 451, 225, "ATK 44       DEF 35", MUTED)
    label(d, 451, 243, "SPD 61       SPC 50", MUTED)
    label(d, 451, 263, "MOVES", MUTED); label(d, 451, 279, "THUNDERBOLT  15/15")
    if popup:
        px, py, pw = 442, 229, 178
        panel(d, (px, py, px+pw, 334)); label(d, px+13, py+13, "ACTIONS")
        for i, row in enumerate(("MOVE", "CANCEL")):
            y = py + 36 + i*29
            target(d, (px+10,y,px+pw-10,y+25), selected=i == 1,
                   disabled=i == 1)
            label(d, px+22, y+8, row, MUTED if i == 1 else INK)
    label(d, 18, 331, disabled_reason or "Choose a Pokemon.", MUTED)
    label(d, 461, 345, "A SELECT  B BACK  L/R BOX", MUTED)
    return img


OUT.mkdir(parents=True, exist_ok=True)
images = {
    "01_active_grid_640x360.png": base_scene(active=True, party=False),
    "02_held_targets_640x360.png": base_scene(target_states=True),
    "03_party_drawer_640x360.png": base_scene(party=True),
    "04_disabled_popup_640x360.png": base_scene(
        popup=True, disabled_reason="Finish moving the held Pokemon first."),
}
for name, image in images.items():
    image.save(OUT / name)

source = images["02_held_targets_640x360.png"]
integer = source.resize((1280, 720), Image.Resampling.NEAREST).crop((0, 0, 640, 360))
noninteger = source.resize((960, 540), Image.Resampling.NEAREST).crop((0, 0, 640, 360))
audit = Image.new("RGB", (1280, 390), PAPER)
audit.paste(integer, (0, 30)); audit.paste(noninteger, (640, 30))
ad = ImageDraw.Draw(audit)
label(ad, 12, 9, "2X INTEGER SCALE - NEAREST")
label(ad, 652, 9, "1.5X NON-INTEGER SCALE - NEAREST")
audit.save(OUT / "05_nearest_scale_audit.png")

for path in sorted(OUT.glob("*.png")):
    print(path)
