# Asset provenance

## FRLG player batch

- Source supplied by the user: `Game Boy Advance - Pokemon FireRed _ LeafGreen - Playable Characters - Player Sprites.png`.
- Source dimensions: 673x638 RGBA.
- Depicted game/source: Pokemon FireRed and Pokemon LeafGreen (Game Boy Advance).
- Sheet compiler/ripper: not identified in the supplied file. The filename and sheet labeling are preserved here; no unsupported author attribution is invented.
- Transformation: exact reviewed rectangles were cropped; the sheet's orange `#ff7f27` and green `#22b14c` matte colors were converted to transparent alpha; walk and bicycle frames were reordered from the source's `step A | neutral idle | step B` columns into a twelve-pose idle/step-A/step-B sequence covering down/up/left/right, while Surf retains its six-pose source coverage. No interpolation, recoloring, generative processing, or ROM content outside this supplied sheet was used.
- Reproduction tool: `tools/extract_frlg_player_batch.py` in the editable source tree.
- Machine-readable dimensions and SHA-256 hashes: `FRLG_EXTRACTION_REPORT.json`.
- Output assets: Red/Leaf walk, bicycle, Surf composition, player front, battle back, and main-menu presentation images.
- Rights: these are game-derived graphics supplied by the user for this mod. They are not covered by the code license. No ROM is included.

The full source sheet is intentionally not packaged in the release.

## FRLG trainer and player-throw batch

- Source supplied by the user: `Game Boy Advance - Pokemon FireRed _ LeafGreen - Trainers & Non-Playable Characters - Trainers.png`.
- Source dimensions: 536x1400 RGBA.
- Depicted game/source: Pokemon FireRed and Pokemon LeafGreen (Game Boy Advance).
- Sheet host: The Spriters Resource trainer asset page; individual ripper attribution was not embedded in the supplied PNG, so none is invented here.
- Transformation: exact 64x64 cells were cropped and the orange `#ff7f27` matte was converted to transparent alpha. Enemy mappings follow direct Kanto class equivalents; unsupported special portraits retain ROM art.
- Reproduction tool: `tools/extract_frlg_trainers_batch.py` in the editable source tree.
- Machine-readable dimensions and SHA-256 hashes: `FRLG_TRAINER_EXTRACTION_REPORT.json`.
- Output assets: 45 extracted trainer fronts (44 mapped to Gen 1 opponent
  classes) plus five Red and five Leaf player-back throw frames.
- Rights: these are game-derived graphics supplied by the user for this mod. They are not covered by the code license. No ROM is included.

The full source sheet is intentionally not packaged in the release.
