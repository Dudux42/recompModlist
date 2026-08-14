"""Build one crisp party-icon atlas from the supplied HGSS-derived sheets."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "hgss_overworld_sprite_pack" / "assets" / "icons"
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "party_icons.png"

SPECIES = [
    "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER", "CHARMELEON", "CHARIZARD",
    "SQUIRTLE", "WARTORTLE", "BLASTOISE", "CATERPIE", "METAPOD", "BUTTERFREE",
    "WEEDLE", "KAKUNA", "BEEDRILL", "PIDGEY", "PIDGEOTTO", "PIDGEOT", "RATTATA",
    "RATICATE", "SPEAROW", "FEAROW", "EKANS", "ARBOK", "PIKACHU", "RAICHU",
    "SANDSHREW", "SANDSLASH", "NIDORANF", "NIDORINA", "NIDOQUEEN", "NIDORANM",
    "NIDORINO", "NIDOKING", "CLEFAIRY", "CLEFABLE", "VULPIX", "NINETALES",
    "JIGGLYPUFF", "WIGGLYTUFF", "ZUBAT", "GOLBAT", "ODDISH", "GLOOM", "VILEPLUME",
    "PARAS", "PARASECT", "VENONAT", "VENOMOTH", "DIGLETT", "DUGTRIO", "MEOWTH",
    "PERSIAN", "PSYDUCK", "GOLDUCK", "MANKEY", "PRIMEAPE", "GROWLITHE", "ARCANINE",
    "POLIWAG", "POLIWHIRL", "POLIWRATH", "ABRA", "KADABRA", "ALAKAZAM", "MACHOP",
    "MACHOKE", "MACHAMP", "BELLSPROUT", "WEEPINBELL", "VICTREEBEL", "TENTACOOL",
    "TENTACRUEL", "GEODUDE", "GRAVELER", "GOLEM", "PONYTA", "RAPIDASH", "SLOWPOKE",
    "SLOWBRO", "MAGNEMITE", "MAGNETON", "FARFETCHD", "DODUO", "DODRIO", "SEEL",
    "DEWGONG", "GRIMER", "MUK", "SHELLDER", "CLOYSTER", "GASTLY", "HAUNTER",
    "GENGAR", "ONIX", "DROWZEE", "HYPNO", "KRABBY", "KINGLER", "VOLTORB",
    "ELECTRODE", "EXEGGCUTE", "EXEGGUTOR", "CUBONE", "MAROWAK", "HITMONLEE",
    "HITMONCHAN", "LICKITUNG", "KOFFING", "WEEZING", "RHYHORN", "RHYDON", "CHANSEY",
    "TANGELA", "KANGASKHAN", "HORSEA", "SEADRA", "GOLDEEN", "SEAKING", "STARYU",
    "STARMIE", "MRMIME", "SCYTHER", "JYNX", "ELECTABUZZ", "MAGMAR", "PINSIR",
    "TAUROS", "MAGIKARP", "GYARADOS", "LAPRAS", "DITTO", "EEVEE", "VAPOREON",
    "JOLTEON", "FLAREON", "PORYGON", "OMANYTE", "OMASTAR", "KABUTO", "KABUTOPS",
    "AERODACTYL", "SNORLAX", "ARTICUNO", "ZAPDOS", "MOLTRES", "DRATINI", "DRAGONAIR",
    "DRAGONITE", "MEWTWO", "MEW",
]


def normalized_name(path: Path) -> str:
    return "".join(ch for ch in path.stem.upper() if ch.isalnum()) + ".png"


def build(source: Path) -> Image.Image:
    sheet = Image.open(source).convert("RGBA")
    frames = [sheet.crop((0, y, 32, y + 32)) for y in (0, 32)]
    boxes = [frame.getbbox() for frame in frames]
    boxes = [box for box in boxes if box]
    if not boxes:
        raise ValueError(f"empty icon sheet: {source}")

    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    width, height = right - left, bottom - top

    # Fill a 28x28 safe area. NEAREST keeps every edge on the pixel grid and
    # avoids the blur caused by rendering through the stock 16x16 canvas.
    scale = min(28 / width, 28 / height)
    out_w = max(1, round(width * scale))
    out_h = max(1, round(height * scale))
    x = (32 - out_w) // 2
    y = 30 - out_h  # consistent feet/baseline with two pixels of padding

    result = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        crop = frame.crop((left, top, right, bottom))
        resized = crop.resize((out_w, out_h), Image.Resampling.NEAREST)
        result.alpha_composite(resized, (x, y + index * 32))
    return result


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sources = sorted(SOURCE.glob("*.png"))
    if len(sources) != 151:
        raise SystemExit(f"expected 151 icon sheets, found {len(sources)}")
    by_name = {normalized_name(path)[:-4]: path for path in sources}
    atlas = Image.new("RGBA", (512, 640), (0, 0, 0, 0))
    for index, species in enumerate(SPECIES):
        sheet = build(by_name[species])
        x = (index % 16) * 32
        y = (index // 16) * 64
        atlas.alpha_composite(sheet, (x, y))
    atlas.save(OUTPUT, optimize=True)
    print(f"built {len(sources)} icons in {OUTPUT}")


if __name__ == "__main__":
    main()
