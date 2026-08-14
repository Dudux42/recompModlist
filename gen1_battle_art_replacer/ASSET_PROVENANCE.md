# Asset provenance

## Pokemon Red, Blue, and Yellow

- Source repository: `PokeAPI/sprites`.
- Paths: `sprites/pokemon/versions/generation-i/red-blue` and
  `sprites/pokemon/versions/generation-i/yellow`.
- Imported scope: National Dex 001-151 front PNGs.
- Transparency: exact binary alpha masks transferred from each matching
  `transparent` source variant onto the compact colored canvas.
- Repository terms: CC0 1.0 Universal, while its license notice separately
  states that all image contents are copyright The Pokemon Company.
- Red and Blue share the international `red-blue` drawings; no artificial
  recolor or duplicate alternate artwork is claimed.

## Pokemon Black/White presentation

- Species scope: National Dex 001-151.
- Source repository: `PokeAPI/sprites`.
- Paths: `sprites/pokemon/versions/generation-v/black-white/animated` and its
  `shiny` subdirectory.
- Normal and shiny atlas cells are composited directly from the source GIFs.
  Fully enclosed one-to-three-pixel transparent components are restored with
  the GIF transparency index's own RGB value; these are palette-index
  collisions inside the drawing. Larger authored openings and all
  background-connected transparency remain unchanged.
- Timing metadata uses each GIF frame's authored duration.
- Static Gen 5 images are the repaired first composited frame.
- Shiny Scyther has a different source canvas, frame count and duration list;
  its explicit shiny metadata override is preserved rather than normalized.

The build scripts preserve the exact source set boundaries. Missing or invalid
assets fall back within the selected set and then to ROM; they are never
silently substituted from another generation.

## Pokemon FireRed/LeafGreen presentation

- User-supplied source sheet: `Game Boy Advance - Pokemon FireRed _ LeafGreen
  - Pokemon - Pokemon.png`.
- Imported scope: National Dex 001-151 normal and shiny full-size front cells.
- The sheet's full-size back row, header thumbnails, gender/form indicators,
  and non-Gen-1 extras are excluded. No redundant female asset is packaged;
  Nidoran Female and Nidoran Male remain their distinct Dex species.
- Each front cell's exact flat matte is keyed to transparency. Fully enclosed
  one-to-three-pixel matte collisions remain opaque; larger authored openings
  remain transparent.
- Normal and shiny use one shared tight silhouette crop with a transparent
  one-pixel guard border. The source pixels are not rescaled.
- FRLG supplies one front pose, so both STATIC and ANIMATED return that still
  and the Presentation API truthfully reports `animated = false`.

## Pokemon Emerald presentation

- User-supplied sheets: `Game Boy Advance - Pokemon Emerald - Pokemon -
  Pokemon (1st Generation, Normal).png` and the matching `Shiny` sheet.
- Embedded sheet credit: Kanto Pokemon ripped by A.J. Nitro; credit requested.
- Imported scope: National Dex 001-151 normal and shiny fronts, two consecutive
  64x64 poses per species. Footer credits and empty grid space are excluded.
- The exact cyan matte is keyed to transparency. Fully enclosed
  one-to-three-pixel matte collisions remain opaque; larger authored openings
  remain transparent.
- All four normal/shiny poses use one shared tight crop with a transparent
  one-pixel guard border, preserving source pixels and frame alignment.
- Static presentation uses pose 1. Animated presentation alternates the two
  supplied poses at a provider-authored 500 ms cadence because the sheets do
  not include original Emerald timing metadata.
- No female/gender duplicate is packaged. Nidoran Female and Nidoran Male
  remain separate National Dex species.

## Pokemon HeartGold/SoulSilver presentation

- User-supplied source sheet: `DS _ DSi - Pokemon HeartGold _ SoulSilver -
  Battle - Pokemon (1st Generation).png`.
- Embedded sheet credit: game `Pokemon HeartGold/SoulSilver`, subject `Pokemon
  (1st Gen.)`, copyright Nintendo/Game Freak, sprite ripper Random Talking
  Bush, hosting permission The Spriters Resource.
- Imported scope: National Dex 001-151, base male/unisex section where the
  sheet exposes gender-separated sections.
- Each 324-pixel section contains two blue-matte front cells followed by two
  green-matte back cells. Only the two 80x80 blue front cells are extracted.
- The upper row supplies normal art and the lower row supplies shiny art.
- Static presentation uses front frame 1. Animated presentation alternates the
  two supplied front poses at a documented provider-authored 500 ms cadence;
  the sheet itself contains no original duration data.
- Exact blue matte is keyed to transparency. Fully enclosed one-to-three-pixel
  matte collisions remain opaque; larger authored openings remain transparent.
- One shared crop across both poses and both shiny states removes only unused
  outer matte. It preserves source pixels and animation alignment while making
  portrait sizing follow the visible Pokemon instead of the original 80x80 cell.
- The sheet's separate `FIXED KABUTO` correction panel appears after Dex 151.
  Its two normal and two shiny front cells replace Kabuto's sequential panel;
  no other correction or non-front cell is imported.
- No female HGSS section is packaged. Nidoran Female and Nidoran Male remain
  separate because they are distinct species, not gender variants of one file.

## Pokemon Platinum presentation

- User-supplied source sheet: `DS _ DSi - Pokemon Platinum - Pokemon - Pokemon
  (1st Generation).png`.
- Imported scope: National Dex 001-151 normal and shiny base male/unisex front
  pairs. Back-facing pairs and all redundant female sections are excluded;
  Nidoran Female and Nidoran Male remain separate species.
- Platinum mixes green and blue cell mattes when artwork is reused from
  Diamond/Pearl. The extractor identifies the dominant matte per front cell
  and keys it exactly; it does not infer front/back ownership from color.
- One shared crop preserves alignment across both poses and shiny states.
  STATIC uses pose 1; ANIMATED uses a provider-authored 500 ms cadence because
  the composite sheet supplies no original duration metadata.

## Pokemon Crystal presentation

- User-supplied source sheet: `Game Boy _ GBC - Pokemon Crystal - Pokemon -
  Generation 1 Pokemon.png`.
- Imported scope: National Dex 001-151 normal and shiny front sequences. The
  separate final back-facing cell in each species row is excluded.
- Frame order, alpha masks, and durations are referenced from the canonical
  PokeAPI Crystal animated GIF set. RGB pixels come from the supplied sheet.
  Where a repository GIF uses a materially different drawing, transparency is
  derived from the closest supplied front pose instead of mixing artwork.
- All generated frames are checked against the sheet's red outer matte and
  retain transparent guard pixels. No female/gender duplicate is packaged.
