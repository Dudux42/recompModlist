# Widescreen UI owner request: fix Pokédex shiny-star runtime asset loading

## Problem

The Pokédex correctly switches to the shiny portrait, but the shiny-star indicator is absent in the real launcher.

This is **not** a stale or incomplete installation:

- Installed `gen1_widescreen_pokedex` version: `0.1.0-alpha.6`
- Installed `gen1_widescreen_ui` version: `0.1.0-alpha.14.6`
- Installed `assets/shiny_star.png` SHA-256:
  `60DD8BABBBCD2D668A88A15F4F9412F365092798237FA165DEA98F7455B53AD5`
- That hash matches the asset packaged in the alpha.14.6 release.
- The installed `main.lua` contains the expected active call site:
  `drawShinyStarIcon(detailX + detailW - 35, detailY + 10, 16)`

The provider state is also working: the screenshot shows the shiny portrait. The failure is isolated to loading/drawing the indicator bitmap.

## Likely cause

The current implementation constructs a path with:

```lua
mod.assets:path("assets/shiny_star.png")
```

and later loads it through:

```lua
Assets.image(path)
```

The tests stub `mod.assets:path()` as an identity function, so they do not exercise the launcher-prefixed mod path. The real failure is swallowed by `pcall`, cached as `false`, and never diagnosed or retried.

The loader provides a purpose-built mod-scoped API:

```lua
mod.assets:image("assets/shiny_star.png")
```

Use that API for this mod-owned image instead of passing a mod path through the global `Assets.image()` helper.

## Required change

1. Capture/use the mod-scoped image loader for `assets/shiny_star.png`, preferably during mod initialization or through a small lazy loader closure:

   ```lua
   local image = mod.assets:image("assets/shiny_star.png")
   ```

2. Preserve successful immutable caching and nearest-neighbor filtering.
3. Do not silently cache a load failure forever.
   - Emit one deduplicated diagnostic containing the asset name and actual error.
   - A missing/corrupt asset must still fail safely without crashing the menu.
   - Retrying after asset registration/reload is acceptable and preferred.
4. Keep the existing indicator semantics unchanged:
   - Draw only when the currently displayed Pokédex portrait is shiny.
   - Never reveal shiny ownership for unseen or uncaught entries.
   - Keep the icon at the top-right of the detail panel, above the sprite.
   - Continue using the supplied bitmap; do not restore the old vector/polygon star.
5. Do not change Pokédex-provider code. This is a Widescreen-owned rendering/asset fix.

## Regression coverage

Add tests that exercise the runtime-shaped API rather than an identity-path mock:

- Provide a mock `mod.assets:image(relative)` and assert it is called with exactly `"assets/shiny_star.png"`.
- Make `mod.assets:path(relative)` return a realistic prefixed path such as
  `mods/gen1_widescreen_ui/assets/shiny_star.png`; the implementation must not depend on feeding that path into global `Assets.image()`.
- With a valid 32x31 image, assert the bitmap is drawn once when the shiny portrait is active.
- Assert it is not drawn for a normal portrait.
- Assert loading is cached after success.
- Assert a load exception/missing image does not crash and produces only one diagnostic per failure state.
- Retain the existing privacy and layout tests.

## Packaging and handoff

- Bump the Widescreen UI prerelease version.
- Run the complete Widescreen UI test suite.
- Return the updated release ZIP and its SHA-256.
- Report the modified source/test files and the exact test results.

Do not install the build automatically.

## Implementation status

Corrected in `gen1_widescreen_ui` **0.1.0-alpha.14.8**. Launcher verification
showed that `mod.assets:image(relative)` appends `relative` directly to the mod
root. The shared bitmap therefore loads through
`mod.assets:image("assets/shiny_star.png")`, retries after failures,
deduplicates diagnostics, and retains immutable success caching. Runtime-shaped
tests use a realistic prefixed `mod.assets:path()` value and explicitly reject
feeding that path to global `Assets.image()`.
