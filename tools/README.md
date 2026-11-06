# Tools: the art and sound generators

Every picture and every sound of the game is made by the Python code here. There are no
hand-drawn files to edit: change the code, run `make assets`, and look at the result. The
output is deterministic, so a change that should not alter a picture leaves it byte for byte
the same (`git status` after `make assets` shows what moved).

```sh
make assets    # all art, all sounds, then the palette check and the sound check
make venv      # just the Python environment (make assets does this itself)
```

`make assets` needs Python 3 and nothing else (no Godot). The pinned packages are in
[requirements.txt](requirements.txt). After new art, `make run`, `make test` and
`make screenshot` import it themselves.

## Art: tools/art/

`generate.py` is the entry point: it assembles the object atlas and `main()` writes every
file under `assets/`, one small `write_...` function per family. The drawing is in the modules
by topic. Where is a thing drawn?

| Module | What it draws |
|---|---|
| `generate.py` | The object atlas (`object_atlas()`, with the numbered table of its rows), the writers and `main()`. |
| `canvas.py` | The shared basics: `TILE`, the size of an object cell, `blank`, `filled`, `copy` and a clipped `rect`. |
| `palette.py` | The palette, `to_image`, `save` (one PNG under `assets/`) and the palette check. |
| `terrain.py` | The ground: water, floodplain, wetland, grass, soil, and their decorations. |
| `trees.py` | Oak, spruce, pine, dead tree, bushes, ferns, stones, boulders and stumps. |
| `camp.py` | The fireplace and the bedroll. |
| `character.py` | The player's layers (body, breeches and stockings, clogs, shirt and waistcoat, jacket, hair, hats, hoe), their passing out and the sleeping "z". |
| `interior.py` | The room tiles and the furniture inside the buildings, the hearth too. |
| `buildings.py` | The four buildings, plain and with lit windows. |
| `seasons.py` | The other looks (spring, autumn, bare, frost, snow, dusting, leaf-out steps) made from the summer art by colour remaps and overlays. Also adds its colours to the palette. |
| `crops.py`, `crop_icons.py` | Crop sheets (growth stages and the dead one), seed bag and produce icons, wet soil. |
| `items.py`, `tool_icons.py`, `chest.py` | Item icons, the slot frames and the tools; the chest, which is drawn once for every use. |
| `boundaries.py` | The lines across the land, drawn as solids tile by tile with a picture per connection mask: the Knick. |
| `trunks.py`, `meadow.py`, `reeds.py` | Felled trunks, tall grass and clay hint, reeds. |
| `fire.py` | The animation frames of the campfire and the hearth. |
| `animals.py` | One sheet per animal of the ambient wildlife. |
| `ui.py` | The pixel font, the panel frame and the button frames. |

`generate.py` imports all the others and none of them imports it; most import `canvas.py`, and
Of the art modules, `palette.py` imports only `seasons` (for its colours) and `canvas`.

Pictures are lists of rows of **palette colour names** (`None` is transparent), never RGB
values. The colours are `BASE_COLOURS` in `palette.py` plus `COLOURS` in `seasons.py`, merged
into `PALETTE` (a name in both fails), and the palette is limited to `MAX_PALETTE_COLOURS`
(when it is full, merge two similar colours to add one). A picture with a colour that is not
in it fails with "unknown colour X in <the file being written>". After writing,
`check_palette()` fails if any PNG under `assets/` has a colour outside the palette.

### Adding things

- **A colour:** a name and a hex value in `BASE_COLOURS` in `palette.py` (or in
  `seasons.COLOURS`, if only a season look needs it). Mind the limit above.
- **A sprite for something that already has a type** (an item, a furniture piece): draw it in
  the module of its topic and add it to `ICONS` (items) or to `furniture()` (interior.py; new
  pieces go at the end, the tile ids of the interior tileset are counted in that order). Item
  icons are named after the item id in `game/state/item_types.gd`; the 8x8 version for the
  ground is made for you.
- **A world object** (a tree, a rock, a plant): draw its variants in the module of its topic
  (`trees.py` for most), add a row to `object_atlas()` and to the numbered table above it
  (the table says the order; new rows go at the end, after the chest), and give its type an
  `atlas_row` in `game/state/world_object_types.gd`. `generate.py` writes
  `assets/objects_rows.txt` from the rows it draws, and `tests/test_object_atlas.gd` compares
  it with every type's `atlas_row` and number of looks; the trunk rows are counted from
  `_FIRST_TRUNK_ROW` there, and the order of trees in `trunks.py` and in that file must agree.
  `seasons.py` needs a winter look per kind: add one entry to `_WINTER_LOOKS` (a kind
  without one stops the build with its name), and look at the picture under snow.
- **A building:** its picture in `buildings.py` (`PICTURES`), its section in
  `data/buildings.cfg`, and its interior ([maps/README.md](../maps/README.md)).
- **A crop:** a section in `data/crops.cfg` and a sheet in `crops.py`; no game code.
- **A new kind of file** (a new family of PNGs): a `write_...` function in `generate.py` that
  calls `save` or `save_picture`, and a line in `main()`.

### Seeds: why the art stays the same between runs

Variants (the three oaks, the stones) come from a seed, and a picture must come out the same
every time. So:

- Use `random.Random(seed)` with an integer seed that is written in the code, and nothing
  else for randomness. Never `hash()` of a string (Python changes it from run to run) and
  never the global `random` or the clock.
- **Draw order matters.** A random generator is a sequence: if you draw something new before
  another call to the same generator, everything after it changes. Add new random calls at
  the end of a function, or give the new part its own generator.
- A seed also picks the structure of a variant: `seed % 3` or `seed % 2` decides, say, how
  many branches or tiers a tree has. Choose the seeds of a new object so the variants differ
  (they are 101, 102, 103 for the oaks, 121 to 123 for the spruces).

## Sound: tools/audio/

`generate.py` is the entry point. `EVENTS` lists every sound event with its peak level in dBFS
and the functions that make its variants; it writes `assets/sounds/<event>_<n>.wav`. The
sounds themselves are in `footsteps.py`, `work.py`, `ui.py`, `weather.py` and `animals.py`,
built from the filters, noise, tones and envelopes of `dsp.py`. A variant is a function that
takes a random generator and returns samples.

| Command | What it does |
|---|---|
| `make assets` | Generates the sounds, then runs `check.py` on them. |
| `.venv/bin/python tools/audio/check.py --table` | Checks every file (format, clipping, DC offset, clicks, loop seams) and prints length, peak and level of each. |
| `.venv/bin/python tools/audio/preview.py out.wav` | Joins all sounds into one WAV to listen to, and prints when each starts. |

Each variant gets its own generator, seeded from the event name and the variant number, so
changing one sound leaves all the others the same. A loop (an event name ending in `_loop`)
is built as a circle, and its functions take `loop=True`.

**Adding a sound:** write the function in the module of its kind, add the event to `EVENTS`,
add the event to `SoundRules.EVENTS` (`game/state/sound_rules.gd`) and a section to
`data/sounds.cfg`, then make the game play it (for work and steps, `SoundEvents` decides which
event a happening makes; `GameSounds` and `AudioService` play it). To use a recording instead
of a generated sound, point the event's `files` in `data/sounds.cfg` at the recording.
