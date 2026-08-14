"""Extract exact FRLG Oak-speech sprites from the supplied reference sheet.

The source's bottom orange strip contains clean, unscaled sprite pixels.  This
script crops those cells, removes only the exact backdrop color, trims the
transparent result, and adds two pixels of transparent safety padding.
"""

from pathlib import Path
import sys

from PIL import Image


SOURCE_CELLS = {
    "intro_oak_frlg.png": (8, 916, 72, 1012),
    "intro_red_frlg.png": (73, 916, 137, 1012),
    "intro_rival_frlg.png": (203, 916, 267, 1012),
}
BACKDROP = (255, 127, 39)


def extract(source: Path, destination: Path) -> None:
    sheet = Image.open(source).convert("RGBA")
    destination.mkdir(parents=True, exist_ok=True)
    for filename, box in SOURCE_CELLS.items():
        sprite = sheet.crop(box)
        pixels = sprite.load()
        for y in range(sprite.height):
            for x in range(sprite.width):
                r, g, b, a = pixels[x, y]
                if (r, g, b) == BACKDROP:
                    pixels[x, y] = (0, 0, 0, 0)
        alpha_box = sprite.getchannel("A").getbbox()
        if not alpha_box:
            raise RuntimeError(f"empty sprite crop: {filename}")
        sprite = sprite.crop(alpha_box)
        padded = Image.new("RGBA", (sprite.width + 4, sprite.height + 4))
        padded.alpha_composite(sprite, (2, 2))
        padded.save(destination / filename, optimize=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_frlg_oak_speech.py SOURCE.png OUT_DIR")
    extract(Path(sys.argv[1]), Path(sys.argv[2]))
