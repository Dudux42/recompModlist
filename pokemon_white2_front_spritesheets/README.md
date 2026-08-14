# Pokemon White 2 front animation sprite sheets

This archive contains the ROM-native, front-facing animation component sheets for National Dex species 001 through 649, organized by debut generation.

- `gen1/` through `gen5/`: generation folders
- Each generation contains `regular/` and `shiny/` palette folders
- PNG filenames are three-digit National Dex IDs
- `manifest.csv`: extraction result for every species/palette pair
- `GENERATION_INDEX.md`: generation ranges, counts, and folder map

Every PNG is 1024 x 512 pixels at native 1x export scale. These are the articulated component sheets used by the Gen V battle animation system, not pre-rendered frame strips: the game composes and transforms the separate body parts at runtime. Palette color 0 is retained as an opaque background because this reflects the ROM data.

## Provenance

- Source: `Pokemon - White Version 2 (USA, Europe) (NDSi Enhanced).nds`
- Source ROM SHA-256: `3E50AEC3DB401332175A5D2B5FE2A68AC1A05EC63995DBA9D1506B1B51837446`
- Archive: `/a/0/0/4` (Pokegra)
- Decoder: AnimaEngine v1.0.0
- Decoder package SHA-256: `C9B192345D032FA24B804C7B9533734F96A688ED80C107F3A75580194D6CC5AA`

## Verification

- Expected PNG files: 1,298
- Successfully decoded PNG files: 1,298
- Invalid PNG files: 0
- Regular/shiny pairs that were byte-identical: 0

Scope is each species' base, male/unisex form. Female-specific graphics and alternate forms are distinct variants in the ROM and are not included in this base-species set.
