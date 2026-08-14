"""Report Yellow Legacy v1.0.10 Gate 2 data differences from vanilla Yellow."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
VANILLA = ROOT / ".audit" / "pokeyellow_vanilla"
LEGACY = ROOT / ".audit" / "Pokemon_Yellow_Legacy_v1.0.10"
REFERENCE = Path(
    r"C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\yellow_legacy_changes"
)


def norm(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", value).upper()


def parse_moves(repo: Path):
    result = {}
    pattern = re.compile(
        r"^\s*move\s+([A-Z0-9_]+),\s*([A-Z0-9_]+),\s*(-?\d+),\s*"
        r"([A-Z0-9_]+),\s*(-?\d+),\s*(-?\d+)",
        re.M,
    )
    text = (repo / "data" / "moves" / "moves.asm").read_text(encoding="utf-8")
    for move, effect, power, move_type, accuracy, pp in pattern.findall(text):
        result[move] = {
            "power": int(power),
            "accuracy": int(accuracy),
            "pp": int(pp),
            "type": move_type,
            "effect": effect,
        }
    return result


def parse_reference_moves():
    text = (REFERENCE / "main.lua").read_text(encoding="utf-8")
    block = re.search(r"local MOVES\s*=\s*\{(.*?)\n\s*\}\n\n\s*local STATS", text, re.S)
    if not block:
        raise ValueError("reference MOVES table not found")
    result = {}
    for move, body in re.findall(r"^\s*([A-Z0-9_]+)\s*=\s*\{([^}]+)\}", block.group(1), re.M):
        fields = {}
        for field, raw in re.findall(r"(\w+)\s*=\s*(\"[^\"]*\"|-?\d+)", body):
            fields[field] = raw[1:-1] if raw.startswith('"') else int(raw)
        result[move] = fields
    return result


def parse_species(repo: Path):
    stats, level_one, tmhm = {}, {}, {}
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
        if starting:
            level_one[species] = [
                value.strip()
                for value in starting.group(1).split(",")
                if value.strip() != "NO_MOVE"
            ]
        machine = re.search(r"\btmhm\s+(.+?)\n\s*; end", text, re.S)
        if machine:
            body = machine.group(1).replace("\\", " ").replace("\n", " ")
            tmhm[species] = [value.strip() for value in body.split(",") if value.strip()]
    return stats, level_one, tmhm


def parse_evos_learnsets(repo: Path, level_one):
    text = (repo / "data" / "pokemon" / "evos_moves.asm").read_text(encoding="utf-8")
    blocks = re.split(r"(?m)^([A-Za-z0-9]+)EvosMoves:\s*$", text)
    evolutions, learnsets = {}, {}
    for index in range(1, len(blocks), 2):
        species, body = norm(blocks[index]), blocks[index + 1]
        evo_body, _, learn_body = body.partition("; Learnset")
        evo_rows = []
        for level, target in re.findall(
            r"db\s+EVOLVE_LEVEL,\s*(\d+),\s*([A-Z0-9_]+)", evo_body
        ):
            evo_rows.append(["LEVEL", int(level), target])
        for item, target in re.findall(
            r"db\s+EVOLVE_ITEM,\s*([A-Z0-9_]+),\s*\d+,\s*([A-Z0-9_]+)", evo_body
        ):
            evo_rows.append(["ITEM", item, target])
        for target in re.findall(
            r"db\s+EVOLVE_TRADE,\s*\d+,\s*([A-Z0-9_]+)", evo_body
        ):
            evo_rows.append(["TRADE", target])
        evolutions[species] = evo_rows
        rows = [[1, move] for move in level_one.get(species, [])]
        rows.extend(
            [int(level), move]
            for level, move in re.findall(
                r"^\s*db\s+(\d+)\s*,\s*([A-Z0-9_]+)", learn_body, re.M
            )
        )
        learnsets[species] = rows
    return evolutions, learnsets


vanilla_moves = parse_moves(VANILLA)
legacy_moves = parse_moves(LEGACY)
reference_moves = parse_reference_moves()
vanilla_stats, vanilla_level_one, vanilla_tmhm = parse_species(VANILLA)
legacy_stats, legacy_level_one, legacy_tmhm = parse_species(LEGACY)
vanilla_evos, vanilla_learnsets = parse_evos_learnsets(VANILLA, vanilla_level_one)
legacy_evos, legacy_learnsets = parse_evos_learnsets(LEGACY, legacy_level_one)

move_changes = {}
for move, after in legacy_moves.items():
    before = vanilla_moves.get(move)
    fields = {
        field: {"from": before.get(field), "to": value}
        for field, value in after.items()
        if before and before.get(field) != value
    }
    if fields:
        move_changes[move] = fields

stat_changes = {}
for species, after in legacy_stats.items():
    before = vanilla_stats.get(species)
    fields = {
        field: {"from": before.get(field), "to": value}
        for field, value in after.items()
        if before and before.get(field) != value
    }
    if fields:
        stat_changes[species] = fields

learnset_changes = {
    species: {"from": vanilla_learnsets.get(species), "to": rows}
    for species, rows in legacy_learnsets.items()
    if vanilla_learnsets.get(species) != rows
}
tmhm_changes = {
    species: {
        "removed": [move for move in vanilla_tmhm.get(species, []) if move not in rows],
        "added": [move for move in rows if move not in vanilla_tmhm.get(species, [])],
    }
    for species, rows in legacy_tmhm.items()
    if vanilla_tmhm.get(species) != rows
}
evolution_changes = {
    species: {"from": vanilla_evos.get(species), "to": rows}
    for species, rows in legacy_evos.items()
    if vanilla_evos.get(species) != rows
}

reference_field_mismatches = {}
reference_omissions = {}
for move, patch in reference_moves.items():
    source = legacy_moves.get(move, {})
    mismatches = {
        field: {"reference": value, "source": source.get(field)}
        for field, value in patch.items()
        if field != "priority" and source.get(field) != value
    }
    if mismatches:
        reference_field_mismatches[move] = mismatches
    delta = move_changes.get(move, {})
    omitted = {
        field: values for field, values in delta.items() if field not in patch
    }
    if omitted:
        reference_omissions[move] = omitted

report = {
    "counts": {
        "move_records_different_in_asm": len(move_changes),
        "reference_move_records": len(reference_moves),
        "stat_species": len(stat_changes),
        "stat_fields": sum(len(fields) for fields in stat_changes.values()),
        "learnset_species": len(learnset_changes),
        "tmhm_species": len(tmhm_changes),
        "evolution_species": len(evolution_changes),
    },
    "move_changes": move_changes,
    "reference_move_field_mismatches": reference_field_mismatches,
    "reference_omitted_source_fields": reference_omissions,
    "source_only_move_records": sorted(set(move_changes) - set(reference_moves)),
    "stat_changes": stat_changes,
    "learnset_changes": learnset_changes,
    "tmhm_changes": tmhm_changes,
    "evolution_changes": evolution_changes,
}

print(json.dumps(report, indent=2, ensure_ascii=False))
