# Dudux42 Gen1Recomp Mod Index

Development, stability, and release archive for Dudux42's Gen1Recomp mods.

## Launcher feed

The launcher-compatible raw feed is:

```text
https://raw.githubusercontent.com/Dudux42/recompModlist/main/site/data/index.json
```

After GitHub Pages deploys the `site/` directory, the same feed is also available at:

```text
https://dudux42.github.io/recompModlist/data/index.json
```

The generated feed follows schema version 1 used by the
[`gen1recomp-mod-index`](https://github.com/bryanthaboi/gen1recomp-mod-index)
reference implementation. It publishes both user-approved releases and current
Stable builds so launcher users can discover and test either channel. Every
entry carries `released` and `channel` metadata: `released: true` identifies a
public release, while `released: false` identifies a Stable test build.

The current public releases are Bill S.S. Ticket Repair 1.0.0, Dramatic Shape
Battle Sprite Lighting Patch 1.0.0, and Gen1 Shiny System 1.0.0. Stable builds
remain clearly labelled and are not promoted to public releases by discovery.

## Build lifecycle

```text
Releases/Old Versions/  Superseded builds retained for recovery
Releases/Stable/        Current accepted/testable builds; discoverable, not released
Releases/Released/      User-approved public releases only
```

Agents may create and validate Stable builds, but only the user can declare a
mod released. Promotion requires moving the approved ZIP from `Stable` to
`Released`, setting its metadata field `released` to `true`, changing its
download URL to `Releases/Released/`, and rebuilding the launcher feed.

## Repository layout

```text
mods/Dudux42@<mod-id>/
  meta.json
  description.md
Releases/
  Old Versions/
  Stable/
  Released/
schema/mod.schema.json
scripts/
site/data/index.json
```

## Maintaining the index

1. Put a validated flat ZIP in `Releases/Stable/` with `released: false` in
   its metadata; it will be discoverable in the Stable channel.
2. Wait for the user to explicitly approve release.
3. Move the approved ZIP to `Releases/Released/`, set `released: true`, and
   update the metadata URL to the Released path.
4. Run `npm run build` and `npm test`.
5. Commit the ZIP, metadata, and rebuilt `site/data/index.json` together.

No dependencies are required beyond Node.js 18 or newer.

## Attribution

The metadata shape and feed format are based on BryanThaBoi's community
Gen1Recomp mod index. Mod assets retain the rights and attribution documented
inside their respective release packages.
