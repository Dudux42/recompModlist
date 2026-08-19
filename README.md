# Dudux42 Gen1Recomp Mod Index

Launcher-ready index and release archive for Dudux42's Gen1Recomp mods.

## Launcher feed

After GitHub Pages deploys the `site/` directory, use:

```text
https://dudux42.github.io/recompModlist/data/index.json
```

The generated feed follows schema version 1 used by the
[`gen1recomp-mod-index`](https://github.com/bryanthaboi/gen1recomp-mod-index)
reference implementation. Each entry points directly to an installable ZIP in
`Releases/`; the ZIPs contain `manifest.json` at archive root.

## Repository layout

```text
mods/Dudux42@<mod-id>/
  meta.json
  description.md
Releases/
  <mod-id>_v<version>.zip
schema/mod.schema.json
scripts/
site/data/index.json
```

## Maintaining the index

1. Put the new flat release ZIP in `Releases/`.
2. Update the matching `mods/Dudux42@<mod-id>/meta.json` version and URL.
3. Run `npm test`.
4. Commit the ZIP, metadata, and rebuilt `site/data/index.json` together.

No dependencies are required beyond Node.js 18 or newer.

## Attribution

The metadata shape and feed format are based on BryanThaBoi's community
Gen1Recomp mod index. Mod assets retain the rights and attribution documented
inside their respective release packages.
