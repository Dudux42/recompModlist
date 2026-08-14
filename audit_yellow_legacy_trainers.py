"""Read-only Gate 0 trainer/index audit for the Yellow Legacy ruleset.

Prints a compact JSON report. It does not modify ROMs, source trees, imported
engine caches, or the installed reference mod.
"""

from __future__ import annotations

import json
import re
import argparse
from collections import defaultdict
from pathlib import Path


ROOT = Path(r"C:\Users\invok\OneDrive\Documents\ChatGPT\Gen1 Recomp Mods")
REFERENCE = Path(r"C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\yellow_legacy_changes")
RED_DATA = Path(r"C:\Users\invok\AppData\Roaming\pokemon-love2d\data\generated")
BLUE_DATA = Path(r"C:\Users\invok\AppData\Roaming\pokemon-love2d\blue\data\generated")
ENGINE = ROOT / ".audit" / "gen1recomp_v0.1.71"
VANILLA_YELLOW = ROOT / ".audit" / "pokeyellow_vanilla"
YELLOW_LEGACY = ROOT / ".audit" / "Pokemon_Yellow_Legacy_v1.0.10"


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


def parse_return(path: Path):
    text = path.read_text(encoding="utf-8")
    match = re.search(r"\breturn\s*\{", text)
    if not match:
        raise ValueError(f"no return table in {path}")
    return LuaTableParser(text[match.end() - 1 :]).value()


def normalize_party(party):
    return [
        {"level": int(mon["level"]), "species": str(mon["species"]).upper()}
        for mon in party
    ]


def parse_asm_parties(repo: Path):
    constants = []
    for raw in (repo / "constants" / "trainer_constants.asm").read_text(encoding="utf-8").splitlines():
        match = re.match(r"\s*(?:trainer_const\s+([A-Z0-9_]+)|const\s+(OPP_[A-Z0-9_]+))", raw)
        if match:
            value = match.group(1) or match.group(2)
            if value not in {"NOBODY", "OPP_NOBODY"}:
                constants.append(value if value.startswith("OPP_") else "OPP_" + value)

    text = (repo / "data" / "trainers" / "parties.asm").read_text(encoding="utf-8")
    pointer_block = text.split("assert_table_length", 1)[0]
    labels = re.findall(r"^\s*dw\s+([A-Za-z0-9_]+)Data\s*$", pointer_block, re.M)
    label_to_class = {label: constants[i] for i, label in enumerate(labels) if i < len(constants)}

    result = {}
    current = None
    pending_comments = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        inline_comment = raw.split(";", 1)[1].strip() if ";" in raw else ""
        stripped = raw.split(";", 1)[0].strip()
        label = re.match(r"([A-Za-z0-9_]+)Data:{1,2}\s*$", stripped)
        if label:
            current = label_to_class.get(label.group(1))
            if current:
                result[current] = []
            pending_comments = []
            continue
        if not stripped and inline_comment:
            pending_comments.append(inline_comment)
            continue
        match = re.match(r"db\s+(.+)$", stripped)
        if not match or not current:
            if stripped:
                pending_comments = []
            continue
        values = [part.strip() for part in match.group(1).split(",")]
        if values and values[-1] == "0":
            values.pop()
        if not values:
            continue
        party = []
        if values[0] in {"$FF", "-1"}:
            values = values[1:]
            for i in range(0, len(values), 2):
                if i + 1 < len(values) and values[i].isdigit():
                    party.append({"level": int(values[i]), "species": values[i + 1]})
        elif values[0].isdigit():
            party = [{"level": int(values[0]), "species": mon} for mon in values[1:]]
        if party:
            result[current].append({
                "party": normalize_party(party),
                "comment": " / ".join(pending_comments + ([inline_comment] if inline_comment else [])),
                "line": lineno,
            })
        pending_comments = []
    return result


def parse_lua_trainers(path: Path, bundled=False):
    data = parse_return(path)
    if bundled:
        data = data["trainers"]
    return {
        class_id: [normalize_party(party) for party in entry["parties"]]
        for class_id, entry in data.items()
        if isinstance(entry, dict) and isinstance(entry.get("parties"), list)
    }


def lua_map_consumers(path: Path):
    maps = parse_return(path)
    consumers = defaultdict(list)
    for map_id, map_def in maps.items():
        for obj in map_def.get("objects", []):
            class_id, index = obj.get("trainerClass"), obj.get("trainerParty")
            if class_id and index:
                consumers[(class_id, int(index))].append(f"{map_id}:{obj.get('name', obj.get('index'))}")
    return consumers


def asm_map_consumers(repo: Path):
    consumers = defaultdict(list)
    for path in (repo / "data" / "maps" / "objects").glob("*.asm"):
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = re.search(r"\b(OPP_[A-Z0-9_]+)\s*,\s*(\d+)\b", raw)
            if match and "object_event" in raw:
                consumers[(match.group(1), int(match.group(2)))].append(f"{path.stem}:{lineno}")
    return consumers


def engine_script_consumers():
    consumers = defaultdict(list)
    roots = [ENGINE / "data" / "scripts", ENGINE / "src"]
    pattern = re.compile(r'["\'](OPP_[A-Z0-9_]+)["\']\s*,\s*(\d+)')
    for root in roots:
        for path in root.rglob("*.lua"):
            for lineno, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                for match in pattern.finditer(raw):
                    consumers[(match.group(1), int(match.group(2)))].append(
                        f"{path.relative_to(ENGINE).as_posix()}:{lineno}"
                    )
    return consumers


reference = parse_lua_trainers(REFERENCE / "trainers.lua", bundled=True)
reference_rematches_raw = parse_return(REFERENCE / "rematches.lua")["rematches"]
reference_rematches = {
    class_id: normalize_party(party)
    for class_id, party in reference_rematches_raw.items()
}
red = parse_lua_trainers(RED_DATA / "trainers.lua")
blue = parse_lua_trainers(BLUE_DATA / "trainers.lua")
vanilla_yellow = parse_asm_parties(VANILLA_YELLOW)
legacy = parse_asm_parties(YELLOW_LEGACY)

red_consumers = lua_map_consumers(RED_DATA / "maps.lua")
blue_consumers = lua_map_consumers(BLUE_DATA / "maps.lua")
yellow_consumers = asm_map_consumers(VANILLA_YELLOW)
legacy_consumers = asm_map_consumers(YELLOW_LEGACY)
script_consumers = engine_script_consumers()

verification_failures = []
for class_id, parties in sorted(reference.items()):
    if class_id in {"OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3"}:
        continue
    legacy_parties = legacy.get(class_id, [])
    for index, party in enumerate(parties, 1):
        actual = legacy_parties[index - 1]["party"] if index <= len(legacy_parties) else None
        if party != actual:
            verification_failures.append(f"{class_id}#{index}: reference != legacy")

for class_id, party in sorted(reference_rematches.items()):
    source_rows = [row for row in legacy.get(class_id, []) if "rematch" in row["comment"].lower()]
    if len(source_rows) != 1 or source_rows[0]["party"] != party:
        verification_failures.append(f"{class_id}: rematch mismatch or ambiguous source row")

if len(reference.get("OPP_ROCKET", [])) != 49:
    verification_failures.append("OPP_ROCKET: reference count is not 49")
if len(legacy.get("OPP_ROCKET", [])) != 49:
    verification_failures.append("OPP_ROCKET: legacy count is not 49")

focus_classes = sorted(
    class_id for class_id in set(reference) | set(legacy)
    if len(reference.get(class_id, [])) != len(legacy.get(class_id, []))
    or class_id in {"OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3"}
)

rows = []
for class_id in focus_classes:
    maximum = max(
        len(reference.get(class_id, [])),
        len(legacy.get(class_id, [])),
        len(vanilla_yellow.get(class_id, [])),
        len(red.get(class_id, [])),
        len(blue.get(class_id, [])),
    )
    for index in range(1, maximum + 1):
        ref_party = reference.get(class_id, [])[index - 1] if index <= len(reference.get(class_id, [])) else None
        yl_row = legacy.get(class_id, [])[index - 1] if index <= len(legacy.get(class_id, [])) else None
        vy_row = vanilla_yellow.get(class_id, [])[index - 1] if index <= len(vanilla_yellow.get(class_id, [])) else None
        red_party = red.get(class_id, [])[index - 1] if index <= len(red.get(class_id, [])) else None
        blue_party = blue.get(class_id, [])[index - 1] if index <= len(blue.get(class_id, [])) else None
        key = (class_id, index)
        meaningful = (
            ref_party != (yl_row and yl_row["party"])
            or (yl_row and vy_row and yl_row["party"] != vy_row["party"])
            or bool(red_consumers[key] or blue_consumers[key] or yellow_consumers[key]
                    or legacy_consumers[key] or script_consumers[key])
        )
        if meaningful:
            rows.append({
                "class": class_id,
                "index": index,
                "reference_matches_legacy": ref_party is not None and yl_row is not None and ref_party == yl_row["party"],
                "legacy_changes_vanilla_yellow": yl_row is not None and vy_row is not None and yl_row["party"] != vy_row["party"],
                "legacy_comment": yl_row and yl_row["comment"],
                "legacy_line": yl_row and yl_row["line"],
                "present": {
                    "reference": ref_party is not None,
                    "red": red_party is not None,
                    "blue": blue_party is not None,
                    "vanilla_yellow": vy_row is not None,
                    "legacy": yl_row is not None,
                },
                "consumers": {
                    "red_maps": red_consumers[key],
                    "blue_maps": blue_consumers[key],
                    "yellow_maps": yellow_consumers[key],
                    "legacy_maps": legacy_consumers[key],
                    "engine_scripts": script_consumers[key],
                },
                "party": {
                    "reference": ref_party,
                    "legacy": yl_row and yl_row["party"],
                    "vanilla_yellow": vy_row and vy_row["party"],
                },
            })

report = {
    "identities": {
        "yellow_legacy_commit": "3a5358e",
        "engine_commit": "18b2bcd",
        "vanilla_yellow_commit": None,
    },
    "party_counts": {
        class_id: {
            "reference": len(reference.get(class_id, [])),
            "red": len(red.get(class_id, [])),
            "blue": len(blue.get(class_id, [])),
            "vanilla_yellow": len(vanilla_yellow.get(class_id, [])),
            "legacy": len(legacy.get(class_id, [])),
        }
        for class_id in focus_classes
    },
    "focus_classes": focus_classes,
    "verification": {
        "non_rival_reference_parties_match_legacy": not any("reference != legacy" in item for item in verification_failures),
        "all_12_rematches_match_legacy": len(reference_rematches) == 12 and not any("rematch" in item for item in verification_failures),
        "rocket_party_count": {
            "reference": len(reference.get("OPP_ROCKET", [])),
            "legacy": len(legacy.get("OPP_ROCKET", [])),
        },
        "failures": verification_failures,
    },
    "rows": rows,
}

parser = argparse.ArgumentParser()
parser.add_argument("--compact", action="store_true")
args = parser.parse_args()
if args.compact:
    compact = dict(report)
    compact["rows"] = [
        {key: value for key, value in row.items() if key != "party"}
        for row in rows
        if not row["reference_matches_legacy"]
        or not row["present"]["reference"]
        or not row["present"]["vanilla_yellow"]
    ]
    print(json.dumps(compact, indent=2, ensure_ascii=False))
else:
    print(json.dumps(report, indent=2, ensure_ascii=False))
