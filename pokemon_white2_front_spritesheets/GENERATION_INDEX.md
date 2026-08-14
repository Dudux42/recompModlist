# Pokemon White 2 sprite-sheet generation index

The collection is divided according to the generation in which each species debuted. Every species has one regular and one shiny front-facing animation component sheet.

| Folder | Generation | National Dex range | Species | Regular sheets | Shiny sheets | Total sheets |
|---|---:|---:|---:|---:|---:|---:|
| `gen1` | I | 001-151 | 151 | 151 | 151 | 302 |
| `gen2` | II | 152-251 | 100 | 100 | 100 | 200 |
| `gen3` | III | 252-386 | 135 | 135 | 135 | 270 |
| `gen4` | IV | 387-493 | 107 | 107 | 107 | 214 |
| `gen5` | V | 494-649 | 156 | 156 | 156 | 312 |
| **Total** |  | **001-649** | **649** | **649** | **649** | **1,298** |

## Folder layout

```text
pokemon_white2_front_spritesheets/
|-- gen1/
|   |-- regular/001.png ... 151.png
|   `-- shiny/001.png ... 151.png
|-- gen2/
|   |-- regular/152.png ... 251.png
|   `-- shiny/152.png ... 251.png
|-- gen3/
|   |-- regular/252.png ... 386.png
|   `-- shiny/252.png ... 386.png
|-- gen4/
|   |-- regular/387.png ... 493.png
|   `-- shiny/387.png ... 493.png
|-- gen5/
|   |-- regular/494.png ... 649.png
|   `-- shiny/494.png ... 649.png
|-- manifest.csv
|-- GENERATION_INDEX.md
`-- README.md
```

## Asset format

Each 1024 x 512 PNG is a ROM-native articulated component sheet. Pokemon White 2 composes and transforms these separate pieces at runtime to produce the battle animation; the files are not pre-rendered animation frame strips.

The set covers each species' base male/unisex form. Female-specific graphics and alternate forms remain separate variants in the ROM and are outside this collection.
