"""Audit a flat HGSS Simple Follower release archive."""

from io import BytesIO
import hashlib
import json
from pathlib import Path
import re
import sys
from zipfile import ZipFile

from PIL import Image


archive = Path(sys.argv[1]).resolve()
expected_version = sys.argv[2] if len(sys.argv) > 2 else "0.1.0-alpha.18"

with ZipFile(archive) as release:
    names = release.namelist()
    assert len(names) == 456, f"expected 456 entries, found {len(names)}"
    assert len(names) == len(set(names)), "duplicate archive entries"
    assert all("/" not in name and "\\" not in name for name in names), "nested entry"
    assert {"manifest.json", "main.lua", "README.md"}.issubset(names), "missing root file"

    manifest = json.loads(release.read("manifest.json"))
    assert manifest["id"] == "hgss_simple_follower", "manifest ID mismatch"
    assert manifest["version"] == expected_version, "manifest version mismatch"
    assert manifest["entry"] in names, "manifest entry is absent"
    assert archive.name == f"hgss_simple_follower_v{expected_version}.zip", "filename mismatch"

    groups = {}
    for prefix in ("follower", "shiny", "proxy"):
        pattern = re.compile(rf"^{prefix}_(\d{{3}})\.png$")
        groups[prefix] = {int(match.group(1)): name for name in names
                          if (match := pattern.match(name))}
        assert set(groups[prefix]) == set(range(1, 152)), f"{prefix} mapping incomplete"

    for dex in range(1, 152):
        normal = Image.open(BytesIO(release.read(groups["follower"][dex])))
        shiny = Image.open(BytesIO(release.read(groups["shiny"][dex])))
        proxy = Image.open(BytesIO(release.read(groups["proxy"][dex])))
        assert normal.size == (32, 192) and shiny.size == (32, 192), f"#{dex:03d} sheet size"
        assert proxy.size == (16, 96), f"#{dex:03d} proxy size"
        assert normal.mode == shiny.mode == proxy.mode == "RGBA", f"#{dex:03d} image is not RGBA"
        assert normal.getchannel("A").tobytes() == shiny.getchannel("A").tobytes(), (
            f"#{dex:03d} normal/shiny silhouette mismatch"
        )
        for frame in range(6):
            box = (0, frame * 32, 32, (frame + 1) * 32)
            normal_alpha = normal.getchannel("A").crop(box)
            shiny_alpha = shiny.getchannel("A").crop(box)
            normal_bounds = normal_alpha.getbbox()
            shiny_bounds = shiny_alpha.getbbox()
            assert normal_bounds and shiny_bounds, f"#{dex:03d} frame {frame + 1} empty"
            assert normal_bounds[3] == 32 and shiny_bounds[3] == 32, (
                f"#{dex:03d} frame {frame + 1} is not grounded"
            )

digest = hashlib.sha256(archive.read_bytes()).hexdigest().upper()
print(
    f"release audit: OK — {len(names)} flat unique entries; "
    "151 normal/shiny/proxy mappings; dimensions, RGBA, silhouettes, "
    f"six-frame grounding valid; SHA-256 {digest}"
)
