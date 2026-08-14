"""Read-only cross-check of the installed Gen1Recomp mod against YL v1.0.10."""

from __future__ import annotations

import json
import re
from pathlib import Path


WORKSPACE = Path(r"C:\Users\invok\OneDrive\Documents\ChatGPT\Gen1 Recomp Mods")
REFERENCE = Path(r"C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\yellow_legacy_changes")
UPSTREAM = WORKSPACE / ".audit" / "Pokemon_Yellow_Legacy_v1.0.10"


class LuaTableParser:
    token_re = re.compile(
        r"\s+|--[^\n]*|"
        r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|'
        r"-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_]*|[][{}=,;]"
    )

    def __init__(self, text: str):
        self.tokens = []
        for match in self.token_re.finditer(text):
            token = match.group(0)
            if token.isspace() or token.startswith("--"):
                continue
            self.tokens.append(token)
        self.pos = 0

    def peek(self, offset=0):
        index = self.pos + offset
        return self.tokens[index] if index < len(self.tokens) else None

    def take(self, expected=None):
        token = self.peek()
        if expected is not None and token != expected:
            raise ValueError(f"expected {expected!r}, got {token!r} at {self.pos}")
        self.pos += 1
        return token

    def value(self):
        token = self.peek()
        if token == "{":
            return self.table()
        self.take()
        if token and token[0] in "\"'":
            return bytes(token[1:-1], "utf-8").decode("unicode_escape")
        if token and re.fullmatch(r"-?\d+(?:\.\d+)?", token):
            return float(token) if "." in token else int(token)
        if token == "true":
            return True
        if token == "false":
            return False
        if token == "nil":
            return None
        return token

    def table(self):
        self.take("{")
        result = {}
        array_index = 1
        while self.peek() not in ("}", None):
            if self.peek() == "[":
                self.take("[")
                key = self.value()
                self.take("]")
                self.take("=")
                value = self.value()
            elif re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", self.peek() or "") and self.peek(1) == "=":
                key = self.take()
                self.take("=")
                value = self.value()
            else:
                key = array_index
                array_index += 1
                value = self.value()
            result[key] = value
            if self.peek() in (",", ";"):
                self.take()
        self.take("}")
        if result and all(isinstance(k, int) for k in result) and sorted(result) == list(range(1, len(result) + 1)):
            return [result[i] for i in range(1, len(result) + 1)]
        return result


def parse_assignment(text: str, name: str):
    match = re.search(rf"(?:local\s+)?{re.escape(name)}\s*=\s*\{{", text)
    if not match:
        raise KeyError(name)
    parser = LuaTableParser(text[match.end() - 1 :])
    return parser.value()


def parse_return_table(text: str):
    match = re.search(r"\breturn\s*\{", text)
    if not match:
        raise ValueError("no return table")
    return LuaTableParser(text[match.end() - 1 :]).value()


def norm(value: str):
    return re.sub(r"[^A-Za-z0-9]", "", value).upper()


def listify(value):
    return value if isinstance(value, list) else []


main_text = (REFERENCE / "main.lua").read_text(encoding="utf-8")
moves = parse_assignment(main_text, "MOVES")
stats = parse_assignment(main_text, "STATS")
evos = parse_assignment(main_text, "EVOS")

learnsets_text = (REFERENCE / "learnsets.lua").read_text(encoding="utf-8")
learnsets = parse_assignment(learnsets_text, "learnsets")
tmhm = parse_assignment(learnsets_text, "tmhm")
encounters = parse_assignment(learnsets_text, "encounters")

trainer_bundle = parse_return_table((REFERENCE / "trainers.lua").read_text(encoding="utf-8"))
trainers = trainer_bundle["trainers"]
rival_variants = trainer_bundle["rivalVariants"]
rematches = parse_return_table((REFERENCE / "rematches.lua").read_text(encoding="utf-8"))["rematches"]


upstream_moves = {}
for line in (UPSTREAM / "data" / "moves" / "moves.asm").read_text(encoding="utf-8").splitlines():
    match = re.match(
        r"\s*move\s+([A-Z0-9_]+),\s*([A-Z0-9_]+),\s*(-?\d+),\s*"
        r"([A-Z0-9_]+),\s*(-?\d+),\s*(-?\d+)",
        line,
    )
    if match:
        move_id, effect, power, move_type, accuracy, pp = match.groups()
        upstream_moves[move_id] = {
            "effect": effect,
            "power": int(power),
            "type": move_type,
            "accuracy": int(accuracy),
            "pp": int(pp),
        }

move_mismatches = []
for move_id, patch in sorted(moves.items()):
    source = upstream_moves.get(move_id)
    if source is None:
        move_mismatches.append({"id": move_id, "reason": "missing upstream"})
        continue
    for field, expected in patch.items():
        if field == "priority":
            continue
        actual = source.get(field)
        if actual != expected:
            move_mismatches.append(
                {"id": move_id, "field": field, "reference": expected, "upstream": actual}
            )


upstream_stats = {}
upstream_tmhm = {}
upstream_level1 = {}
for path in (UPSTREAM / "data" / "pokemon" / "base_stats").glob("*.asm"):
    text = path.read_text(encoding="utf-8")
    dex = re.search(r"\bDEX_([A-Z0-9_]+)", text)
    values = re.search(r"^\s*db\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$", text, re.M)
    if not dex or not values:
        continue
    species = dex.group(1)
    hp, attack, defense, speed, special = map(int, values.groups())
    upstream_stats[species] = {
        "hp": hp, "attack": attack, "defense": defense, "speed": speed, "special": special
    }
    level1 = re.search(r"^\s*db\s+([^;\n]+);\s*level 1 learnset", text, re.M)
    if level1:
        upstream_level1[norm(species)] = [x.strip() for x in level1.group(1).split(",") if x.strip() != "NO_MOVE"]
    machine = re.search(r"\btmhm\s+(.+?)\n\s*; end", text, re.S)
    if machine:
        cleaned = machine.group(1).replace("\\", " ").replace("\n", " ")
        upstream_tmhm[norm(species)] = [x.strip() for x in cleaned.split(",") if x.strip()]

stat_mismatches = []
for species, patch in sorted(stats.items()):
    source = upstream_stats.get(species)
    for field, expected in patch["baseStats"].items():
        actual = source and source.get(field)
        if actual != expected:
            stat_mismatches.append(
                {"id": species, "field": field, "reference": expected, "upstream": actual}
            )


evos_moves_text = (UPSTREAM / "data" / "pokemon" / "evos_moves.asm").read_text(encoding="utf-8")
blocks = re.split(r"(?m)^([A-Za-z0-9]+)EvosMoves:\s*$", evos_moves_text)
upstream_learnsets = {}
upstream_evos = {}
for i in range(1, len(blocks), 2):
    label, body = blocks[i], blocks[i + 1]
    species = norm(label)
    evo_section, _, learn_section = body.partition("; Learnset")
    evo_rows = []
    for line in evo_section.splitlines():
        match = re.search(r"db\s+EVOLVE_LEVEL,\s*(\d+),\s*([A-Z0-9_]+)", line)
        if match:
            evo_rows.append({"method": "LEVEL", "level": int(match.group(1)), "species": match.group(2)})
        match = re.search(r"db\s+EVOLVE_ITEM,\s*([A-Z0-9_]+),\s*\d+,\s*([A-Z0-9_]+)", line)
        if match:
            evo_rows.append({"method": "ITEM", "item": match.group(1), "species": match.group(2)})
        match = re.search(r"db\s+EVOLVE_TRADE,\s*\d+,\s*([A-Z0-9_]+)", line)
        if match:
            evo_rows.append({"method": "TRADE", "species": match.group(1)})
    upstream_evos[species] = evo_rows
    rows = []
    for line in learn_section.splitlines():
        match = re.search(r"^\s*db\s+(\d+)\s*,\s*([A-Z0-9_]+)", line)
        if match:
            rows.append((int(match.group(1)), match.group(2)))
    upstream_learnsets[species] = [(1, move) for move in upstream_level1.get(species, [])] + rows


def same_move(a, b):
    aliases = {"PSYCHIC": "PSYCHICM", "HIJUMPKICK": "HIJUMPKICK"}
    na, nb = norm(a), norm(b)
    return aliases.get(na, na) == aliases.get(nb, nb)


learnset_mismatches = []
for species_name, rows in sorted(learnsets.items()):
    species = norm(species_name)
    source = upstream_learnsets.get(species)
    ref_rows = [(int(row[0]), row[1]) for row in listify(rows)]
    if source is None or len(source) != len(ref_rows) or any(
        a[0] != b[0] or not same_move(a[1], b[1]) for a, b in zip(ref_rows, source)
    ):
        learnset_mismatches.append({
            "id": species_name,
            "reference": ref_rows,
            "upstream": source,
        })

tmhm_mismatches = []
for species_name, rows in sorted(tmhm.items()):
    species = norm(species_name)
    source = upstream_tmhm.get(species)
    ref_rows = listify(rows)
    if source is None or len(source) != len(ref_rows) or any(not same_move(a, b) for a, b in zip(ref_rows, source)):
        tmhm_mismatches.append({
            "id": species_name,
            "reference": ref_rows,
            "upstream": source,
        })

evo_mismatches = []
for species, patch in sorted(evos.items()):
    expected = patch["evolutions"]
    actual = upstream_evos.get(norm(species))
    if expected != actual:
        evo_mismatches.append({"id": species, "reference": expected, "upstream": actual})


upstream_encounters = {}
for path in (UPSTREAM / "data" / "wild" / "maps").glob("*.asm"):
    text = path.read_text(encoding="utf-8")
    label = re.search(r"(?m)^([A-Za-z0-9]+)WildMons:", text)
    if not label:
        continue
    map_id = norm(label.group(1))
    entry = {}
    for kind in ("grass", "water"):
        section = re.search(
            rf"def_{kind}_wildmons\s+\d+.*?\n(.*?)end_{kind}_wildmons",
            text,
            re.S,
        )
        rows = []
        if section:
            for level, species in re.findall(r"\bdb\s+(\d+)\s*,\s*([A-Z0-9_]+)", section.group(1)):
                rows.append((int(level), species))
        if rows:
            entry[kind] = rows
    if entry:
        upstream_encounters[map_id] = entry

encounter_mismatches = []
for map_name, entry in sorted(encounters.items()):
    source = upstream_encounters.get(norm(map_name), {})
    for kind in ("grass", "water"):
        if kind not in entry:
            continue
        ref_rows = [(int(row[0]), row[1]) for row in listify(entry[kind])]
        source_rows = source.get(kind)
        if source_rows is None or len(source_rows) != len(ref_rows) or any(
            a[0] != b[0] or norm(a[1]) != norm(b[1]) for a, b in zip(ref_rows, source_rows)
        ):
            encounter_mismatches.append({
                "id": map_name,
                "kind": kind,
                "reference": ref_rows,
                "upstream": source_rows,
            })


trainer_text = (UPSTREAM / "data" / "trainers" / "parties.asm").read_text(encoding="utf-8")
constants_text = (UPSTREAM / "constants" / "trainer_constants.asm").read_text(encoding="utf-8")
trainer_constants = re.findall(r"trainer_const\s+([A-Z0-9_]+)", constants_text)
trainer_constants = [value for value in trainer_constants if value != "NOBODY"]
pointer_area = trainer_text.split("assert_table_length", 1)[0]
trainer_labels = re.findall(r"\bdw\s+([A-Za-z0-9]+)Data", pointer_area)
label_to_id = {label: "OPP_" + trainer_id for label, trainer_id in zip(trainer_labels, trainer_constants)}

trainer_blocks = re.split(r"(?m)^([A-Za-z0-9]+)Data:\s*$", trainer_text)
upstream_trainers = {}
upstream_rematches = {}
for i in range(1, len(trainer_blocks), 2):
    label, body = trainer_blocks[i], trainer_blocks[i + 1]
    trainer_id = label_to_id.get(label)
    if not trainer_id:
        continue
    parties = []
    is_rematch_next = False
    for raw_line in body.splitlines():
        stripped = raw_line.strip()
        if stripped.lower().startswith("; rematch"):
            is_rematch_next = True
            continue
        data_match = re.match(r"db\s+(.+)", stripped)
        if not data_match:
            continue
        values = [part.strip() for part in data_match.group(1).split(",")]
        values = [part for part in values if part and not part.startswith(";")]
        try:
            zero = values.index("0")
            values = values[:zero]
        except ValueError:
            pass
        if not values:
            continue
        team = []
        if values[0] == "$FF":
            pairs = values[1:]
            if len(pairs) % 2:
                continue
            for j in range(0, len(pairs), 2):
                if pairs[j].isdigit():
                    team.append({"level": int(pairs[j]), "species": pairs[j + 1]})
        elif values[0].isdigit():
            level = int(values[0])
            team = [{"level": level, "species": species} for species in values[1:]]
        if not team:
            continue
        if is_rematch_next:
            upstream_rematches[trainer_id] = team
            is_rematch_next = False
        else:
            parties.append(team)
    upstream_trainers[trainer_id] = parties

trainer_mismatches = []
for trainer_id, entry in sorted(trainers.items()):
    expected = entry["parties"]
    actual = upstream_trainers.get(trainer_id)
    if expected != actual:
        trainer_mismatches.append({
            "id": trainer_id,
            "reference_party_count": len(expected),
            "upstream_party_count": None if actual is None else len(actual),
            "intentional_rival_adaptation": trainer_id in {"OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3"},
        })

rematch_mismatches = []
for trainer_id, expected in sorted(rematches.items()):
    actual = upstream_rematches.get(trainer_id)
    if expected != actual:
        rematch_mismatches.append({"id": trainer_id, "reference": expected, "upstream": actual})


old_rod = re.findall(
    r"\bdb\s+(\d+)\s*,\s*([A-Z0-9_]+)",
    (UPSTREAM / "data" / "wild" / "old_rod.asm").read_text(encoding="utf-8"),
)
old_rod = [(int(level), species) for level, species in old_rod]
good_rod = re.findall(
    r"\bdb\s+(\d+)\s*,\s*([A-Z0-9_]+)",
    (UPSTREAM / "data" / "wild" / "good_rod.asm").read_text(encoding="utf-8"),
)
good_rod = [(int(level), species) for level, species in good_rod]

super_text = (UPSTREAM / "data" / "wild" / "super_rod.asm").read_text(encoding="utf-8")
upstream_super = {}
for raw_line in super_text.splitlines():
    match = re.match(r"\s*db\s+([A-Z0-9_]+),\s*(.+)$", raw_line)
    if not match or match.group(1) == "-1":
        continue
    map_id, rest = match.groups()
    values = [value.strip() for value in rest.split(",")]
    if len(values) != 8:
        continue
    upstream_super[map_id] = [(int(values[j + 1]), values[j]) for j in range(0, 8, 2)]

reference_old_pools = []
reference_good_pools = []
super_rod_mismatches = []
for map_id, entry in sorted(encounters.items()):
    rods = entry.get("rods", {})
    if "OLD_ROD" in rods:
        reference_old_pools.append(tuple((int(row[0]), norm(row[1])) for row in rods["OLD_ROD"]))
    if "GOOD_ROD" in rods:
        reference_good_pools.append(tuple((int(row[0]), norm(row[1])) for row in rods["GOOD_ROD"]))
    if "SUPER_ROD" in rods:
        expected = [(int(row[0]), row[1]) for row in rods["SUPER_ROD"]]
        actual = upstream_super.get(map_id)
        if actual is None or len(actual) != len(expected) or any(
            a[0] != b[0] or norm(a[1]) != norm(b[1]) for a, b in zip(expected, actual)
        ):
            super_rod_mismatches.append({"id": map_id, "reference": expected, "upstream": actual})


summary = {
    "reference_counts": {
        "moves": len(moves),
        "move_fields": sum(len(v) for v in moves.values()),
        "species_stat_patches": len(stats),
        "species_stat_fields": sum(len(v["baseStats"]) for v in stats.values()),
        "learnsets": len(learnsets),
        "tmhm_species": len(tmhm),
        "encounter_maps": len(encounters),
        "encounter_grass_maps": sum("grass" in value for value in encounters.values()),
        "encounter_water_maps": sum("water" in value for value in encounters.values()),
        "fishing_maps": sum("rods" in value for value in encounters.values()),
        "trainer_classes": len(trainers),
        "trainer_parties": sum(len(value["parties"]) for value in trainers.values()),
        "rematches": len(rematches),
        "rival_variant_classes": len(rival_variants),
        "evolution_records": len(evos),
    },
    "cross_reference": {
        "move_mismatches_excluding_priority": move_mismatches,
        "stat_mismatches": stat_mismatches,
        "learnset_mismatches": learnset_mismatches,
        "tmhm_mismatches": tmhm_mismatches,
        "evolution_mismatches": evo_mismatches,
        "grass_water_encounter_mismatches": encounter_mismatches,
        "trainer_mismatches": trainer_mismatches,
        "rematch_mismatches": rematch_mismatches,
        "fishing": {
            "upstream_old_rod_global": old_rod,
            "reference_old_rod_unique_pools": len(set(reference_old_pools)),
            "upstream_good_rod_global": good_rod,
            "reference_good_rod_unique_pools": len(set(reference_good_pools)),
            "super_rod_mismatches": super_rod_mismatches,
        },
    },
    "ids": {
        "moves": sorted(moves),
        "stats": sorted(stats),
        "learnsets": sorted(learnsets),
        "tmhm": sorted(tmhm),
        "encounters": sorted(encounters),
        "trainers": sorted(trainers),
        "rematches": sorted(rematches),
    },
}

print(json.dumps(summary, indent=2, ensure_ascii=False))
