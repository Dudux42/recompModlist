"""Build canonical encounter/fishing Lua tables from Yellow Legacy v1.0.10."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / ".audit" / "Pokemon_Yellow_Legacy_v1.0.10"
VANILLA_YELLOW = ROOT / ".audit" / "pokeyellow_vanilla"
REFERENCE = Path(
    r"C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\yellow_legacy_changes"
)
MOD = ROOT / "gen1_balances"


def norm(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", value).upper()


def reference_surface_ids():
    text = (REFERENCE / "learnsets.lua").read_text(encoding="utf-8")
    block = re.search(r"\nencounters\s*=\s*\{(.*)\n\}\s*\n\s*return", text, re.S)
    if not block:
        raise ValueError("reference encounter table not found")
    return re.findall(r'^  \["([A-Z0-9_]+)"\] = \{', block.group(1), re.M)


def parse_surface_files(repo=SOURCE):
    result = {}
    for path in (repo / "data" / "wild" / "maps").glob("*.asm"):
        text = path.read_text(encoding="utf-8")
        label = re.search(r"(?m)^([A-Za-z0-9]+)WildMons:", text)
        if not label:
            continue
        record = {}
        for kind in ("grass", "water"):
            section = re.search(
                rf"def_{kind}_wildmons\s+(\d+).*?\n(.*?)end_{kind}_wildmons",
                text,
                re.S,
            )
            if not section:
                continue
            rate, body = int(section.group(1)), section.group(2)
            slots = [
                {"level": int(level), "species": species}
                for level, species in re.findall(r"\bdb\s+(\d+)\s*,\s*([A-Z0-9_]+)", body)
            ]
            if slots:
                record[kind] = {"fallbackRate": rate, "slots": slots}
        result[norm(label.group(1))] = record
    return result


def parse_two_slot(path: Path):
    return [
        {"level": int(level), "species": species}
        for level, species in re.findall(
            r"\bdb\s+(\d+)\s*,\s*([A-Z0-9_]+)",
            path.read_text(encoding="utf-8"),
        )
    ]


def parse_super_rod():
    result = {}
    text = (SOURCE / "data" / "wild" / "super_rod.asm").read_text(encoding="utf-8")
    for raw in text.splitlines():
        match = re.match(r"\s*db\s+([A-Z0-9_]+),\s*(.+)$", raw)
        if not match or match.group(1) == "-1":
            continue
        map_id, rest = match.groups()
        values = [value.strip() for value in rest.split(",")]
        if len(values) != 8:
            continue
        result[map_id] = [
            {"species": values[index], "level": int(values[index + 1])}
            for index in range(0, 8, 2)
        ]
    return result


def slot_lines(slots, indent):
    pad = " " * indent
    return [
        f'{pad}{{ level = {slot["level"]}, species = "{slot["species"]}" }},'
        for slot in slots
    ]


def surface_lua(records):
    lines = [
        "-- Generated from Pokemon Yellow Legacy v1.0.10 source.",
        "-- Rates are fallbacks only; installation preserves a live edition's rate.",
        "return {",
    ]
    for map_id in sorted(records):
        lines.append(f"  {map_id} = {{")
        for kind in ("grass", "water"):
            surface = records[map_id].get(kind)
            if not surface:
                continue
            lines.append(f"    {kind} = {{")
            lines.append(f"      fallbackRate = {surface['fallbackRate']},")
            lines.append("      slots = {")
            lines.extend(slot_lines(surface["slots"], 8))
            lines.extend(["      },", "    },"])
        lines.append("  },")
    lines.extend(["}", ""])
    return "\n".join(lines)


def fishing_lua(old_rod, good_rod, super_rod):
    lines = [
        "-- Generated from Pokemon Yellow Legacy v1.0.10 source.",
        "-- Old/Good Rod pools are global; Super Rod pools are map-specific.",
        "return {",
    ]
    for rod, slots in (("OLD_ROD", old_rod), ("GOOD_ROD", good_rod)):
        lines.append(f"  {rod} = {{")
        lines.extend(slot_lines(slots, 4))
        lines.append("  },")
    lines.append("  SUPER_ROD = {")
    for map_id in sorted(super_rod):
        lines.append(f"    {map_id} = {{")
        lines.extend(slot_lines(super_rod[map_id], 6))
        lines.append("    },")
    lines.extend(["  },", "}", ""])
    return "\n".join(lines)


def slot_summary(slots):
    return ", ".join(
        f'L{slot["level"]} {slot["species"]}' for slot in slots
    )


def markdown_table(surface, old_rod, good_rod, super_rod):
    lines = [
        "# Gen1 Balances Encounter Table",
        "",
        "Status: canonical source ledger, 2026-08-11  ",
        "Source: Pokemon Yellow Legacy v1.0.10 disassembly, cross-checked against the installed reference mod",
        "",
        "The live Red, Blue, or Yellow encounter rate is preserved whenever that surface exists. `Fallback` is used only if an edition genuinely lacks a required surface.",
        "",
        "## Grass and surf",
        "",
        "| Map | Surface | Fallback | Slots in Gen I probability order |",
        "|---|---|---:|---|",
    ]
    for map_id in sorted(surface):
        for kind in ("grass", "water"):
            record = surface[map_id].get(kind)
            if record:
                label = "Grass" if kind == "grass" else "Surf"
                lines.append(
                    f'| `{map_id}` | {label} | {record["fallbackRate"]} | '
                    f'{slot_summary(record["slots"])} |'
                )
    lines.extend([
        "",
        "## Global rod pools",
        "",
        "| Rod | Pool |",
        "|---|---|",
        f"| Old Rod | {slot_summary(old_rod)} |",
        f"| Good Rod | {slot_summary(good_rod)} |",
        "",
        "Both global pools retain Yellow Legacy's ordinary rejection-loop bite odds; they are not guaranteed catches.",
        "",
        "## Super Rod",
        "",
        "| Map | Four-slot pool |",
        "|---|---|",
    ])
    for map_id in sorted(super_rod):
        lines.append(f"| `{map_id}` | {slot_summary(super_rod[map_id])} |")
    lines.extend([
        "",
        "## Reference corrections locked by tests",
        "",
        "- Route 19 and Route 20 are Surf tables, not Grass tables.",
        "- Route 24 and Route 25 have no fabricated Surf table.",
        "- Route 24 Super Rod begins with level-35 Goldeen.",
        "- Route 25 Super Rod begins with level-25 Krabby.",
        "- Old Rod and Good Rod use one global two-slot pool each.",
        "- All 31 v1.0.10 Super Rod maps are retained, including maps omitted by the installed reference's 23-map conversion.",
        "",
        "## Edition surface audit",
        "",
        "- Vanilla Yellow contains every required grass and surf surface, so all 63 surfaces preserve their native rates.",
        "- The current Red and Blue imports each lack five Yellow-only surf records: Route 6, Route 12, Route 13, Seafoam Islands B3F, and Seafoam Islands B4F.",
        "- On Red and Blue only, those five records use their v1.0.10 source fallback rates: 3 on Routes 6/12/13 and 5 on Seafoam B3F/B4F.",
        "- No other missing surface is fabricated. A missing map or invalid species causes that individual record to fail open with a diagnostic.",
        "",
    ])
    return "\n".join(lines)


parser = argparse.ArgumentParser()
parser.add_argument("--write", action="store_true")
args = parser.parse_args()

surface_source = parse_surface_files()
yellow_source = parse_surface_files(VANILLA_YELLOW)
surface = {}
missing = []
for map_id in reference_surface_ids():
    record = surface_source.get(norm(map_id))
    if record:
        surface[map_id] = record
    else:
        missing.append(map_id)

old_rod = parse_two_slot(SOURCE / "data" / "wild" / "old_rod.asm")
good_rod = parse_two_slot(SOURCE / "data" / "wild" / "good_rod.asm")
super_rod = parse_super_rod()

yellow_missing = []
for map_id, record in surface.items():
    base = yellow_source.get(norm(map_id), {})
    for kind in record:
        if kind not in base:
            yellow_missing.append(map_id + "." + kind)

surface_text = surface_lua(surface)
fishing_text = fishing_lua(old_rod, good_rod, super_rod)

if args.write:
    (MOD / "data_encounters.lua").write_text(surface_text, encoding="utf-8", newline="\n")
    (MOD / "data_fishing.lua").write_text(fishing_text, encoding="utf-8", newline="\n")
    (ROOT / "BALANCES_ENCOUNTER_TABLE.md").write_text(
        markdown_table(surface, old_rod, good_rod, super_rod),
        encoding="utf-8",
        newline="\n",
    )

grass = sum("grass" in record for record in surface.values())
water = sum("water" in record for record in surface.values())
print(
    f"surface_maps={len(surface)} grass={grass} water={water} "
    f"old={len(old_rod)} good={len(good_rod)} super_maps={len(super_rod)} "
    f"missing={','.join(missing) or 'none'} "
    f"yellow_missing={','.join(yellow_missing) or 'none'}"
)
