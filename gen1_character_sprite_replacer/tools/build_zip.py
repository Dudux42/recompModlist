#!/usr/bin/env python3
"""Build and audit the flat Character Sprite Replacer release ZIP."""

from __future__ import annotations

import json
from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parents[2]
MOD = ROOT / "gen1_character_sprite_replacer"
RELEASES = ROOT / "Releases"

manifest = json.loads((MOD / "manifest.json").read_text(encoding="utf-8"))
version = manifest["version"]
target = RELEASES / f"gen1_character_sprite_replacer_v{version}.zip"

names = [
    "manifest.json", "main.lua", "character_packs.lua", "player_role_map.lua",
    "overworld_sprite_map.lua", "trainer_class_map.lua", "trainer_object_map.lua",
    "README.md", "CHANGELOG.md", "LICENSE", "ASSET_PROVENANCE.md",
    "FRLG_EXTRACTION_REPORT.json", "FRLG_TRAINER_EXTRACTION_REPORT.json",
]
names += sorted(path.name for path in MOD.glob("frlg_*.png"))
external = [
    ROOT / "GEN1_WIDESCREEN_UI_CHARACTER_PRESENTATION_REQUEST.md",
    ROOT / "DRAMATIC_SHAPE_ENHANCED_CHARACTER_REQUEST.md",
]

if len(names) != len(set(names)):
    raise SystemExit("duplicate source basenames")
for name in names:
    if not (MOD / name).is_file():
        raise SystemExit(f"missing release file: {name}")
for path in external:
    if not path.is_file():
        raise SystemExit(f"missing request: {path.name}")

RELEASES.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name in names:
        archive.write(MOD / name, name)
    for path in external:
        archive.write(path, path.name)

with zipfile.ZipFile(target) as archive:
    entries = archive.namelist()
    if len(entries) != len(set(entries)):
        raise SystemExit("duplicate archive entries")
    if any("/" in entry or "\\" in entry for entry in entries):
        raise SystemExit("nested archive entry")
    if manifest["entry"] not in entries or "manifest.json" not in entries:
        raise SystemExit("manifest or entry missing at archive root")
    archived_manifest = json.loads(archive.read("manifest.json"))
    if archived_manifest["version"] != version:
        raise SystemExit("archive manifest version mismatch")

print(target)
print(f"entries={len(entries)}")
