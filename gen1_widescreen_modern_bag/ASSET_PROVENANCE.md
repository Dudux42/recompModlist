# Item icon provenance

The 20 source strips used by `tools/build_item_icons.py` were supplied directly
by the user in the Codex task on 2026-08-11. Their SHA-256 hashes, cell order,
and included/excluded cells are fixed in that script.

The build performs deterministic border-matte removal, content cropping,
nearest-neighbor normalization, and integer-coordinate centering. It does not
redraw, invent, interpolate, or generatively modify the artwork. Zinc and PP
Max cells are deliberately excluded because those items do not exist in the
target Gen 1 ruleset. The duplicate S.S. Ticket attachment is not used.

Original upstream authorship and redistribution license have not yet been
identified. The icons are therefore suitable for local development and visual
testing but **must not be treated as cleared for public redistribution** until
the user supplies or confirms their source/license status.
