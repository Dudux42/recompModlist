"""Build Balances stat, learnset, and additive evolution tables."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
VANILLA = ROOT / ".audit" / "pokeyellow_vanilla"
LEGACY = ROOT / ".audit" / "Pokemon_Yellow_Legacy_v1.0.10"
MOD = ROOT / "gen1_balances"

SPECIES_ALIASES = {"MRMIME": "MR_MIME", "NIDORANF": "NIDORAN_F", "NIDORANM": "NIDORAN_M"}


def norm(value: str) -> str:
    token = re.sub(r"[^A-Za-z0-9]", "", value).upper()
    return SPECIES_ALIASES.get(token, token)


def parse_base(repo: Path):
    stats, level_one = {}, {}
    for path in (repo / "data" / "pokemon" / "base_stats").glob("*.asm"):
        text = path.read_text(encoding="utf-8")
        dex = re.search(r"\bDEX_([A-Z0-9_]+)", text)
        values = re.search(
            r"^\s*db\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$",
            text,
            re.M,
        )
        if not dex or not values:
            continue
        species = norm(dex.group(1))
        hp, attack, defense, speed, special = map(int, values.groups())
        stats[species] = {
            "hp": hp,
            "attack": attack,
            "defense": defense,
            "special": special,
            "speed": speed,
        }
        starting = re.search(r"^\s*db\s+([^;\n]+);\s*level 1 learnset", text, re.M)
        level_one[species] = []
        if starting:
            level_one[species] = [
                value.strip()
                for value in starting.group(1).split(",")
                if value.strip() != "NO_MOVE"
            ]
    return stats, level_one


def parse_learnsets(repo: Path, level_one):
    text = (repo / "data" / "pokemon" / "evos_moves.asm").read_text(encoding="utf-8")
    blocks = re.split(r"(?m)^([A-Za-z0-9]+)EvosMoves:\s*$", text)
    result = {}
    for index in range(1, len(blocks), 2):
        species, body = norm(blocks[index]), blocks[index + 1]
        _, _, learn_body = body.partition("; Learnset")
        rows = [[1, move] for move in level_one.get(species, [])]
        rows.extend(
            [int(level), move]
            for level, move in re.findall(
                r"^\s*db\s+(\d+)\s*,\s*([A-Z0-9_]+)", learn_body, re.M
            )
        )
        result[species] = {
            "level1Moves": list(level_one.get(species, [])),
            "learnset": rows,
        }
    return result


def species_lua(changes):
    lines = [
        "-- Yellow Legacy v1.0.10 base-stat changes only.",
        "-- Every omitted stat and species field remains live base data.",
        "return {",
    ]
    order = ("hp", "attack", "defense", "special", "speed")
    for species in sorted(changes):
        fields = ", ".join(
            f"{field} = {changes[species][field]}"
            for field in order
            if field in changes[species]
        )
        lines.append(f"  {species} = {{ baseStats = {{ {fields} }} }},")
    lines.extend(["}", ""])
    return "\n".join(lines)


def learnsets_lua(changes):
    lines = [
        "-- Complete Yellow Legacy v1.0.10 records for species whose starting",
        "-- moves or level-up learnset differ from vanilla Yellow.",
        "return {",
    ]
    for species in sorted(changes):
        record = changes[species]
        starting = ", ".join(f'"{move}"' for move in record["level1Moves"])
        lines.extend([
            f"  {species} = {{",
            f"    level1Moves = {{ {starting} }},",
            "    learnset = {",
        ])
        for level, move in record["learnset"]:
            lines.append(f'      {{ level = {level}, move = "{move}" }},')
        lines.extend(["    },", "  },"])
    lines.extend(["}", ""])
    return "\n".join(lines)


def evolutions_lua():
    levels = {"KADABRA": 42, "MACHOKE": 38, "GRAVELER": 38, "HAUNTER": 42}
    targets = {"KADABRA": "ALAKAZAM", "MACHOKE": "MACHAMP", "GRAVELER": "GOLEM", "HAUNTER": "GENGAR"}
    lines = [
        "-- Trade remains valid; level-up is an additional evolution path.",
        "return {",
    ]
    for species in ("KADABRA", "MACHOKE", "GRAVELER", "HAUNTER"):
        target = targets[species]
        lines.extend([
            f"  {species} = {{ evolutions = {{",
            f'    {{ method = "TRADE", species = "{target}" }},',
            f'    {{ method = "LEVEL", level = {levels[species]}, species = "{target}" }},',
            "  } },",
        ])
    lines.extend(["}", ""])
    return "\n".join(lines)


vanilla_stats, vanilla_level_one = parse_base(VANILLA)
legacy_stats, legacy_level_one = parse_base(LEGACY)
vanilla_learnsets = parse_learnsets(VANILLA, vanilla_level_one)
legacy_learnsets = parse_learnsets(LEGACY, legacy_level_one)

stat_changes = {
    species: {
        field: value
        for field, value in fields.items()
        if vanilla_stats.get(species, {}).get(field) != value
    }
    for species, fields in legacy_stats.items()
}
stat_changes = {species: fields for species, fields in stat_changes.items() if fields}
learnset_changes = {
    species: record
    for species, record in legacy_learnsets.items()
    if vanilla_learnsets.get(species) != record
}

(MOD / "data_species.lua").write_text(species_lua(stat_changes), encoding="utf-8", newline="\n")
(MOD / "data_learnsets.lua").write_text(learnsets_lua(learnset_changes), encoding="utf-8", newline="\n")
(MOD / "data_evolutions.lua").write_text(evolutions_lua(), encoding="utf-8", newline="\n")

print(
    f"stats={len(stat_changes)} fields={sum(map(len, stat_changes.values()))} "
    f"learnsets={len(learnset_changes)} additive_evolutions=4"
)
