# Tools: the art and sound generators

Every picture and every sound of the game is made by the Python code here. Change the code,
run `make art`, and look at the result. The output is deterministic, so a change that should
not alter a picture leaves it byte for byte the same (the working tree's status after `make art`
shows what moved).

```sh
make art          # draw all art (the classic art first) and sounds into art/generated/, then the palette and sound checks (minutes)
make classic-art  # just the classic art (the _16x16 files of art/generated/)
make assets       # build assets/, what Godot reads, from art/generated/ (seconds, draws nothing)
make venv         # just the Python environment (the others do this themselves)
```

Three places: `art/generated/` is what `make art` draws (only the generators write there; it
is in version control), and `assets/` is what `make assets` builds out of it for Godot
(`res://assets/`; build output, not in version control). The generated files have the paths the
game reads, plus the postfix of the art set a picture is drawn for: `_32x32` for the new art
and `_16x16` for the classic art (`art/generated/items/axe_32x32.png` becomes assets/items/axe.png,
`art/generated/items/axe_16x16.png` becomes assets/classic/items/axe.png). Files that exist once
(the palette, the font's page, the sounds) have none. The object and decoration atlases are the
exception: `art/generated/objects/<type>_32x32.png` and
`art/generated/decorations/<layer>_32x32.png` hold one entity each, a row per look (season) and a
cell per variant, and `make assets` packs them into the atlases (`objects*.png`,
`decorations*.png`, one per look; see `atlas.py` and `pack.py`). The classic art is generated at
16 px as it was drawn, and `make assets` scales it up (`classic/scaling.py`).

`make art` and `make assets` need Python 3 and nothing else (no Godot). The pinned packages are
in [requirements.txt](requirements.txt). After new art, `make run`, `make test` and
`make screenshot` import it themselves.

### Replacing one entity's art by hand

Hand-drawn files go in `art/hand/` and `make assets` uses them over the generated ones (nothing
generates into that folder). To redraw the oak, for example:

1. Copy `art/generated/objects/oak_32x32.png` to `art/hand/objects/oak_32x32.png` (the same path
   and name: `_32x32` is the new art, `_16x16` the classic art, whose cells are 48x80 and whose
   files are drawn at 16 px per tile).
2. Open it in any pixel editor. The sheet has a row per look (the order is in
   `art/generated/objects/atlas_32x32.txt`: spring, summer, autumn, bare, frost, snow, dusting, buds,
   young_leaves) and a column per variant, cells of 96x160 px; the object stands on the bottom
   centre of its cell. Keep the picture's size and the palette (`art/generated/palette.png`,
   `.gpl`).
3. Draw only the cells you want to replace and leave the rest fully transparent: those cells stay
   the generated ones, so you can start with the summer row and add the other looks later.
4. `make assets`. It lists the hand files it used (with how many cells each draws), warns about
   colours outside the palette (the art is still used), and fails if a hand file has another size
   than the generated one or replaces no generated file (a typo in the path or the postfix).

The same goes for every other picture (`art/hand/items/axe_32x32.png`, an animal's sheet, a
building) and for sounds, which have no postfix: `art/hand/sounds/axe_chop_1.wav` replaces
`art/generated/sounds/axe_chop_1.wav` (it is not checked for level or loops; the file is used as
it is). The tests of this are `tools/art/test_pack.py` (`make test-tools`, part of `make test`).

## Tests: tools/select_tests.py (`make test-changed`)

`make test-changed [BASE=main]` runs only what the files changed since BASE need. It looks at the
whole range BASE..HEAD (every file of every commit of the branch, so a docs-only last commit hides
nothing) and the uncommitted and new files of the worktree, and prints for each file why and which
tests (`tools/select_tests.py` writes that report; read it when a selection surprises you):

- docs (`*.md`, `docs/`, `design/`, `review/`, `.claude/`): no tests;
- `tools/`: the tests of the Python tools, plus `make art` and a clean `git status art/` when any
  file of a generator folder (`tools/art`, `tools/audio`, `tools/music`, pieces and all, not its
  tests) changes or `art/generated` does; and the GUT tests that reach a file naming the tool's
  `res://tools/...` path (today `test_shader_palette.gd` reads `tools/art/palette.py`);
- `game/` and `tests/` scripts, scenes and shaders: the GUT tests that reach the file, through
  `class_name` uses (comments don't count), `res://` paths in `preload`/`load`/scenes/`.tres`/
  shader `#include`s/`extends "path"` (a path that ends in `/` or is cut at a `%` may name any file
  below it) and paths relative to the file, followed transitively. A changed test file runs
  itself; a changed helper (`tests/livestock_case.gd`) runs its users. A `class_name` that is gone
  or renamed runs everything: the scripts it broke are no longer found by name;
- `data/*.cfg` and `maps/`: the tests that reach a file that names the path or the file name, also
  through a data file that names it (`buildings.cfg` names the interior maps);
- `art/generated`, `art/hand`: the asset tests, i.e. the tests of the files that name the picture's
  `assets/` path or folder (`make assets` packs the sheets of a folder with an `atlas_*.txt` into
  `assets/<folder>.png`, so those are named by that prefix), or a data file naming it, and of the
  loaders of all art. Not everything that draws it: that is the full run's job. A generated
  picture also needs `make art`, whatever else runs, `full` included.

Anything it cannot place runs everything (`make test`): `project.godot`, `addons/`, the Makefile,
`tools/run_tests.py`, a deleted script, a data or art file nothing names, any new kind of path.
It leans towards more tests but promises nothing: it sees only what the code spells out (class
names, `res://` paths, paths relative to the file, data files naming maps and pictures). Not seen:
a path built at run time without a literal prefix, a file found by directory listing, a picture
read only through code that never names its path, and anything git ignores (`addons/`, `assets/`,
so a change there, e.g. a GUT update, is invisible: run `make test`). The art rule is deliberately
one hop. So `make test` before reporting a task, and on main every now and then, stays.

Measured on the merged tasks (files changed in the range, GUT files selected of about 260, and the
estimated time from `build/test-times` against the full run, 2026-11-11): task 174 (soil beds and
crops, mostly art and tools) 41 files, 620 of 1181 s; task 175 (soil wetness, touching `GameState`
and `WorldView`) 236 files, 1157 s; task 177 (night and lantern, touching `GameState` and
`PlayerView`) 235 files, 1120 s. A change to a core script reaches nearly every test: the saving is
for art, data and leaf scripts. One real run (a leaf script, 83 files) took 110 s against 229 s for
`make test`, on a busy machine.

## Tests: tools/run_tests.py

`make test` runs it. `tools/run_tests.py JOBS tests/test_x.gd ...` runs only the files named (what
`make test-changed` does); their times are merged into `build/test-times`. It spreads tests/test_*.gd over `TEST_JOBS` headless Godot processes
(default 8; `TEST_JOBS=1` is one process), each with its own `user://` (`build/user-data-<i>`)
and log (`build/test-<i>.log`), and kills them after `TEST_TIMEOUT` seconds (default 600, the
whole run), counting that as a failure. The files are balanced by their duration in the last
run (`build/test-times`, from GUT's junit output), by file size until a file has a time.
`build/test.log` is the shard logs joined plus a summary (Passing Tests, Failing Tests,
`[Failed] file: test`, time); the exit status is non-zero if any shard or check fails. A test
file that GUT skips, because a script failed to load (a parse error) or because it doesn't extend
GutTest, fails the run and is named, so a broken file can't quietly drop its tests.

## Performance: tools/bench/

`make bench` times the game on a heavy save, headless and muted. The first run writes the save
with `make_fixture.gd` into `build/bench/fixture.save` (seed 7: about 10,000 item piles, 155
villagers, 30,000 tilled tiles and thousands of removed objects round the camp); later runs
reuse it until that script changes (after a save format or world generator change, delete
`build/bench/fixture.save` so it is written again). Then `frames.gd` starts Main on a copy of it
and prints how long the world view took to settle, the node and entity counts, and for four
scenarios (standing for 300 frames, passing out, sleeping in the camp's bed, walking 70 tiles east
across chunk borders) the mean and longest frame and how many frames went over 33 and over 16.7 ms, listing the frames over 33 ms
with their numbers; `pickup.gd` prints the cost of the per-frame pile pick-up; `save.gd` prints
what a save costs: the snapshot on the main thread and the save data and JSON text a worker makes.
Nothing is asserted: run it before and after a change and compare. Task 142 took the mean frame
from 37.2 to 7.3 ms this way, task 147 the longest frame while walking from 82 to 22 ms.

`make bench-music` times the prototype music renderer of task 169 (`music.gd`): renders of the test
piece on their own (8 bars and a minute, 22.05 and 44.1 kHz, mono and stereo, with the memory of
each), then Main on a copy of the same save standing, while renders run on a worker, and while
they run and a timed save is made (and whether it was written), with the frame counts as above,
what the main thread spends per finished render (taking it and handing it to a MusicCrossfade that
crossfades to it on the beat) and how late after their beats the crossfades began;
docs/music-viability.md has its results.

`tools/bench/storks.gd` (task 202; no make target, it needs no save and writes nothing) counts how
often wild storks come into the view and how many are there at once over a game day, in spring and
in summer, at wet meadows and at a village it builds in a new world, with the player standing, walking
a circle, or the time skipped every hour: `godot --headless --path . -s tools/bench/storks.gd`
(`-- --seed=<n>`; set `XDG_DATA_HOME` away from the real one).

## Art: tools/art/

`generate.py` is the entry point: it assembles the object atlas's rows and `main()` writes every
file under `art/generated/`, one small `write_...` function per family. The drawing is in the modules
by topic. Where is a thing drawn?

| Module | What it draws |
|---|---|
| `contrast_sheet.py` | `make contrast-sheet` (after `make assets`): the tall grass, fern and reeds (or the atlas rows named in `KINDS="willow shrub"`) over the grass, lush grass, dry grass and floodplain of every look (each season, frost, snow, and night) into `build/contrast_sheet.png`, to check contrast by eye. |
| `generate.py` | The object atlas (`object_atlas()`, with the numbered table of its rows; `atlas_cells` splits a picture wider than a cell, the Ewer's, into its cells), the writers and `main()`; everything is drawn at the game's 32 px tile (see [docs/art-style.md](../docs/art-style.md), "Resolution"). |
| `canvas.py` | The shared basics: `TILE` (the 16 px of the icons and the classic art), `GAME_TILE` (the game's 32 px tile), the size of an object cell at each (`GAME_OBJECT_*`, and `OBJECT_*` for the classic art), `blank`, `filled`, `copy`, a clipped `rect`, and the two outline helpers: `outline` (a ring outside the drawing) and `outline_edge` (recolours the drawing's border). |
| `palette.py` | The palette, `DARKEST_OF` (the colour that outlines each ramp), `to_image`, `save` (one PNG under `art/generated/`, remembering the cell size of a sheet) and the palette check. |
| `atlas.py` | Writes the sheets of the object and decoration atlases (one image per entity, a row per look) and their `atlas_<art set>.txt`, and reads it. |
| `pack.py` | `make assets`: builds assets/ from art/generated/ and art/hand/ (packs the atlases, lays hand-drawn cells over generated ones, scales the classic art up through `classic/scaling.py`). Draws nothing. Its tests: `test_pack.py`. |
| `terrain.py` | The ground, drawn at 32 px per tile: water, tidal mud, floodplain, wetland, grass, salt marsh, Warft, lush and dry grass, trodden grass, path and tilled soil, their decorations, and the wet look of tilled soil. |
| `flowers.py` | The meadow flowers of the region: the flower row of the decoration atlas, drawn at 32 px. |
| `trees.py` | Oak, spruce, pine, dead tree, bushes, ferns, stones, boulders and stumps, drawn at 32 px, and the shared plant parts (the cell, crowns of leaf sprays, trunks, bare limbs and twigs, blades, ground shadows, dense feet). |
| `beech.py`, `birch.py`, `alder.py` | The beech, the birch and the alder, in leaf and bare. |
| `willow.py` | The pollard willow, in leaf and bare. |
| `camp.py` | The fireplace and the bedroll with its cover, drawn at 32 px. |
| `character.py` | The player's layers at 32 px per tile (body, breeches and stockings, clogs, shirt and waistcoat, jacket, hair, hats, and every tool in the hand: `HELD_TOOLS`), all drawn on one `Figure` (where the head, arms and legs are in a frame), their passing out, sitting on a horse and the sleeping "z". |
| `villagers.py` | The villagers' layers on the same figure: the women's dress (bodice, skirt, apron, shawl, coif, headscarf), other skins, hair colours and cloth, the felt hat, the tricorne and the white stocking cap. |
| `forms.py` | Rounded shapes as masks (ellipse, turned or not, capsule, polygon, rounded box) and their shading by the light from the top left, for the figures of character.py and villagers.py, the farm animals of livestock.py and the wild animals. |
| `portraits.py` | The 32x32 chat portrait of every layer that shows in a bust: the top of its frame facing the viewer. |
| `interior.py` | The room tiles and the furniture inside the buildings, the hearth too, drawn at 32 px; the bed covers. |
| `buildings.py` | The shack, fisherman's hut, Kate (and its brick and Geest styles, `kate(walls=...)`, as kate_brick and kate_geest), longhouse, hall house and barn at 32 px per tile, plain and with lit windows. |
| `church.py` | The church and its bell frame (as buildings.py), and the graves of the churchyard (a row of the object atlas, drawn at 32 px). |
| `seasons.py` | The other looks (spring, autumn, bare, frost, snow, dusting, leaf-out steps) made from the summer art by colour remaps and overlays, the ground's by terrain layer where they differ (`LAYER_REMAPS`: autumn straw only on the dry grass). Also adds its colours to the palette. |
| `crops.py`, `crop_icons.py` | Crop sheets (growth stages and the dead one), seed bag and produce icons. |
| `items.py`, `tool_icons.py` | Item icons, the slot frames and the tools; `icon_of` makes the icon of an item that places a world object from its picture. |
| `chest.py` | The chest at 32 px, one picture outdoors, indoors and for its icon. |
| `boundaries.py` | The lines across the land at 32 px, drawn as solids tile by tile with a picture per connection mask: the Knick (its bushes leafy domes on the bank), the wattle fence, the fieldstone wall and the dyke (bending round its corners). |
| `coast.py` | The things of the Wadden coast: the Ewer lying on the mud, at 32 px, a picture three object cells wide. |
| `landing.py` | The fisherman's landing at 32 px: the jetty (a picture per connection mask), the rowing boat, the net frame and the eel traps, and their icons. |
| `yard.py` | The farm yard at 32 px (task 122): the draw well with its sweep, the trough, the hay rack and the chicken coop, and the icons of the items that place them. The classic art has its own `classic/yard.py` at 16 px (drawn new for the yard, not copied from history). |
| `pen.py` | The pig pen at 32 px (task 165): the fence of split oak rails and its gate, shut and open (lines with a picture per connection mask, drawn with `boundaries.draw_line` and gaps under the rails), the pigs' shelter, and the icons of their items. `classic/pen.py` draws them at 16 px. |
| `crafts.py` | The professions' art: the stations (workbench, kiln, bake oven, cupboard) and the carved chest at 32 px, each drawn once for the atlas, the interior and its icon, and the icons of what is made at them. |
| `trunks.py`, `meadow.py`, `reeds.py` | Felled trunks, tall grass, reeds and the clay hint (drawn at 32 px), the hay, clay and reeds items. |
| `fire.py` | The animation frames of the campfire and the hearth, drawn at 32 px; `strip` scales up the 16 px fireplace around them (the hearth is drawn at 32 px). |
| `animals.py` | One sheet per small wild animal (sparrow, rabbit, squirrel, roe deer, bee, butterflies, mouse, frog), drawn at 32 px per tile. |
| `bird_forms.py` | Birds put together from rounded forms (body, tail, neck, head, bill, folded or open wings, legs), standing or flying, for the bird sheets of animals.py, birds.py and sea_birds.py. |
| `birds.py` | The sheets of the big birds of the marsh: the white stork and the greylag goose, drawn at 32 px per tile. |
| `stork_nest.py` | The sheets of the stork's nest on a roof ridge and of the young over its rim, drawn at 32 px per tile (the classic art has its own in `classic/stork_nest.py`). |
| `livestock.py` | One sheet per farm animal and look (cows, pigs, sheep, hens, tame rabbits, dogs, cats, horses), drawn at 32 px per tile with forms.py: the sheep, dogs, cats and horses share `quadruped_frame` (body and head as shaded polygons, legs through their joints set for each step, the face and marks by hand), the cow and the pig are drawn by hand as maps of letters laid over each other for a pose (`cow_frame`, `pig_frame`), the hen and the rabbit are drawn whole per pose. A horse also has a saddled sheet and the ridden horse's sheets (side, front and back, walking and trotting). |
| `ui.py` | The pixel font, the panel frame and the button frames. |

`generate.py` imports all the others and none of them imports it; most import `canvas.py`, and
Of the art modules, `palette.py` imports only `seasons` (for its colours) and `canvas`.

Pictures are lists of rows of **palette colour names** (`None` is transparent), never RGB
values. The colours are `BASE_COLOURS` in `palette.py` plus `COLOURS` in `seasons.py`, merged
into `PALETTE` (a name in both fails), and the palette is limited to `MAX_PALETTE_COLOURS`
(when it is full, merge two similar colours to add one). A picture with a colour that is not
in it fails with "unknown colour X in <the file being written>". After writing,
`check_palette()` fails if any PNG under `art/generated/` has a colour outside the palette;
hand-drawn files are only warned about, by `make assets`.

### The classic art: tools/art/classic/

The game can show the art of a group redrawn at 32 px per tile as it was before, the 16 px art
doubled (Settings → Display, F7; see `ArtSet` in game/scenes/art_set.gd). That classic art is
generated like the rest: tools/art/classic/ holds the old generators of the groups that went
native, copied from git history as they were, and its `generate.py` writes their files under
art/generated/ as the `_16x16` files (the new art's are `_32x32`), at 16 px;
`make assets` doubles the world's ones by `DOUBLED` in `classic/scaling.py`. The old modules
import their siblings there first and the shared `canvas.py` and `palette.py` of tools/art/
after them; a later change to those two that an old module trips over (a colour renamed) is made
in the old module too. So far: the people (task 113), from commit 97e9736: `character.py`,
`villagers.py` and `portraits.py` unchanged, and `bubbles.py`, the thought bubble part of
`ui.py`; the farm animals (task 114), from commit 2793065: `livestock.py` and `animals.py`
(whose tame rabbit it draws from) unchanged; the wild animals and the flames (task 116), from
the same commit: `animals.py`, `birds.py`, `sea_birds.py` and `fire.py` unchanged (the fireplace
around the flames is the shared, still 16 px `camp.py`, the hearth the classic `interior.py`);
the ground (task 107), from commit acf236e: `terrain.py` unchanged, `ground_looks.py`, the
ground part of `seasons.py` (a module of that name would stand in for the shared one that
`palette.py` imports), and `ground_overlays.py`, the wet soil of `crop_icons.py` (drawn without
`crops.Surface`) and the clay hint of `meadow.py`; the buildings (task 110), from commit
e303759: `buildings.py` and `church.py` unchanged (the graves of `church.py` are not written
there; the looks are the shared `seasons.house`), whose pictures kept their sizes at 32 px, but
for the Kate's brick and Geest styles (task 120), drawn into the old Kate after the fact (its
`walls`, a brick wall and a small tarred foot) so that they have a classic look too; the plants
(task 108), from commit e303759: `trees.py`, `trunks.py`, `beech.py`, `birch.py`, `alder.py`,
`willow.py` and `flowers.py` (the meadow flowers of the classic decorations) unchanged, the
plant parts of `meadow.py` and `reeds.py`, and `object_looks.py`, the object part of
`seasons.py`, which draws the looks of the whole classic object atlas (`object_atlas` there);
the crops (task 109), from commit f2c24f8: `crops.py` unchanged (rye and buckwheat were first
drawn at 32 px and have no classic sheet); the interiors (task 112), from commit f2c24f8:
`interior.py` unchanged, whose pictures kept their sizes; the item icons and the items on the
ground (task 115), from commit 91742f0: `items.py` as `item_icons.py` (so that the shared
modules that import `items` get the new one), `tool_icons.py` and `crop_icons.py` unchanged but
for that import, and `craft_icons.py`, the icon parts of `meadow.py`, `reeds.py`, `crafts.py`,
`church.py` and `landing.py` (their world pictures are the classic ones of task 111); the
buckwheat pancakes were first drawn at 32 px; the walls, fences, the dyke and the placed objects
(task 111), from commit ec0b1af: `boundaries.py`, `camp.py` (with the old, shorter bedroll and
its cover), `chest.py`, `coast.py`, `crafts.py` and `landing.py` unchanged but for `item_icons`
in place of `items`, and `graves.py`, the graves part of `church.py` of commit e303759; it also
writes the stations and the grave marker placed indoors. The new Ewer's picture is three cells
wide, so the classic one lies in the middle of three. The cow's, the horse's and the small wild
animals' cells grew at 32 px, so `set_in_grown_cells` puts their classic cells in the new ones
(bottom centre), as the classic files must have the new cell sizes.

When a group goes native (docs/art-style.md, "Resolution"), before its redraw changes them:

1. Copy each module the group's old drawing is in from the commit before the redraw:
   `git show <commit>:tools/art/<module>.py > tools/art/classic/<module>.py`. Take a whole
   module, or just the group's part of a shared one (as `bubbles.py`), and change nothing but
   what it needs to run beside the others (an import, a path). If a module of that name is
   already there (two groups drawn in one module), add the group's part to it.
2. Add the group's old `write_...` lines to `main` in tools/art/classic/generate.py, writing to
   `f"{CLASSIC}/<path>"`, and its doubled globs to `DOUBLED` in classic/scaling.py.
3. `make art` and `make assets`, and compare a few classic files under assets/classic/ with those
   of the commit (`git show <commit>:assets/<path>`): they are the same picture, byte for byte
   while nothing shared changed.

### Adding things

- **A colour:** a name and a hex value in `BASE_COLOURS` in `palette.py` (or in
  `seasons.COLOURS`, if only a season look needs it). Mind the limit above.
- **A sprite for something that already has a type** (an item, a furniture piece): draw it in
  the module of its topic and add it to `ICONS` (items) or to `furniture()` (interior.py; new
  pieces go at the end, the tile ids of the interior tileset are counted in that order). Item
  icons are 32x32 bodies without an outline (see items.py), named after the item id in
  `game/state/item_types.gd`; the outline and the 16x16 version for the ground are made for
  you.
- **A world object** (a tree, a rock, a plant): draw its variants in the module of its topic
  (`trees.py` for most), add a row to `object_atlas()` and to the numbered table above it
  (the table says the order; new rows go at the end), and give its type an
  `atlas_row` in `game/state/world_object_types.gd`. `generate.py` writes
  `art/generated/objects/atlas_32x32.txt` from the rows it draws (`make assets` copies them to assets/objects_rows.txt), and `tests/test_object_atlas.gd` compares
  it with every type's `atlas_row` and number of looks. A tree that leaves a trunk also has the
  two rows of `trunks.rows(<tree>)` (its bark in `trunks.SPECIES`), and its `trunk` names the
  first of them.
  `seasons.py` needs a winter look per kind: add one entry to `_WINTER_LOOKS` (a kind
  without one stops the build with its name), and look at the picture under snow.
- **A building:** its picture in `buildings.py` or `church.py` (`PICTURES`), its section in
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
and the functions that make its variants; it writes `art/generated/sounds/<event>_<n>.wav`. The
sounds themselves are in `footsteps.py`, `work.py`, `ui.py`, `weather.py`, `fire.py`,
`bell.py` and `animals.py`, built from the filters, noise, tones and envelopes of `dsp.py`. A variant is a
function that takes a random generator and returns samples.

| Command | What it does |
|---|---|
| `make art` | Generates the sounds, then runs `check.py` on them (`make assets` copies them to assets/sounds/). |
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

## Music: tools/music/

A trial (task 169), not played in the game yet. `generate.py` turns each piece of
`pieces/<name>.txt`, plain text of sections, voices and tokens (its docstring has the format and
the effect set), into a 4-channel ProTracker module, `art/generated/music/<name>.mod`, which
`make assets` copies to assets/music/. Godot doesn't import `.mod` files, so the game reads them
as bytes; the export presets of `export_presets.cfg` list `assets/music/*.mod` in their "Filters to
export non-resource files" (`include_filter`), or the exported game would have no music.

| Command | What it does |
|---|---|
| `make art` | Writes the modules, then runs `check.py`: libmodplug (an independent player, through `modplug.py`) must play every row of each piece in its order, at its speed and tempo, and stop. Without libmodplug the check says it was skipped. |
| `make music-check` | Renders every piece with the game's prototype renderer (`game/audio/module_renderer.gd`, through `render.gd`, headless) into build/music/, and `check.py --against build/music` compares each with libmodplug's: length, timing, loudness tick by tick, pitch and spectrum row by row. |

## A local LLM for testing NPC talk: tools/llm/

`llm.sh` runs [Ollama](https://ollama.com) in a container (podman if present, else docker;
`CONTAINER=docker` forces one) with Qwen2.5 7B Instruct, on the NVIDIA or AMD GPU when the
host exposes it to containers (see "Setting up the GPU" below), else on the CPU. It serves an
OpenAI-compatible API at `http://127.0.0.1:11434/v1` (this machine only). The game never
needs it: `make test` does not touch it, unless `SANDBOX_LLM_URL=http://127.0.0.1:11434/v1`
is set, which runs the two tests that ask a real model. It is the game's default endpoint
(Settings → Language model), so villagers talk through it as soon as it is up (README,
"Talking NPCs with a language model").

```sh
make llm-up       # start the container, pull the model if missing; safe to repeat
make llm-check    # one chat request as a 1750s North Frisian villager, with the time taken
make llm-down     # remove the container; the model stays in its volume
make llm-down PURGE=1   # also delete the volume (the model)
make llm-pull LLM_MODEL=qwen2.5:3b-instruct   # fetch another model next to the first
make llm-models   # the models it has, with their sizes
make llm-check LLM_MODEL=qwen2.5:3b-instruct  # ask that one
make llm-eval LLM_MODEL=qwen2.5:3b-instruct   # the villagers' prompts on it, see below
make llm-rm LLM_MODEL=qwen2.5:3b-instruct     # delete it again
make llm-gpu-setup   # once: prepare the GPU (NVIDIA: sudo, AMD: only checks), see below
tools/llm/llm.sh status | logs
```

**Other models.** All pulled models sit side by side in the volume; the server loads the one
a request names. The game uses the model set under Settings → Language model → Model, so
after `make llm-pull` set it there (or `model="..."` under `[language_model]` in
`settings.cfg`). Sizes are Ollama's Q4 downloads; a model needs about that much free memory
plus 1-2 GB while it answers (RAM on the CPU, VRAM on the GPU):

| Tag | Size | Licence | Notes |
|---|---|---|---|
| `qwen2.5:1.5b-instruct` | 1.0 GB | Apache-2.0 | Fast, plainer lines |
| `qwen2.5:3b-instruct` | 1.9 GB | Qwen Research (non-commercial) | Twice as fast as the 7B; its lines drift into nonsense more often; testing only |
| `qwen2.5:7b-instruct` | 4.7 GB | Apache-2.0 | The default: stays in character, follows the chat and the language better; needs about 6 GB free |
| `llama3.2:3b` | 2.0 GB | Llama 3.2 Community | |
| `gemma2:2b` | 1.6 GB | Gemma Terms of Use | |

What fits on the GPU depends on its VRAM: the 7B (4.7 GB) on the 8 GB RTX 4070, and on the
16 GB RX 7900 GRE also `qwen2.5:14b-instruct` (9.0 GB), which follows the chat better still.

- **Model:** `qwen2.5:7b-instruct` (override with `LLM_MODEL=<ollama tag>`), 7.6B parameters,
  Q4_K_M, 4.7 GB, Apache-2.0. It is the default because, with the refined prompts, the 3B
  (`qwen2.5:3b-instruct`, 1.9 GB) was not about as good (see "Trying the prompts"). The 3B has
  the **Qwen Research License** (non-commercial), not Apache-2.0: the 3B size is the exception
  in the Qwen2.5 family. Fine for testing here; never ship it with the game.
  `qwen2.5:1.5b-instruct` is Apache-2.0 too.
- **Coming from the 3B:** settings.cfg keeps only what was changed, so unless the 3B was
  picked in Settings, the game now asks for the 7B. If only the 3B is pulled, the test LLM
  answers "model not found" and villagers say scripted lines until `make llm-up` (which pulls
  the default) or `make llm-pull LLM_MODEL=qwen2.5:7b-instruct` has run; or pick the 3B in
  Settings.
- **Where things live:** the container is `sandbox-game-llm`, the models are in the
  volume `sandbox-game-llm-models`, the image is the pinned `docker.io/ollama/ollama` tag in
  `llm.sh` (5.5 GB, from the container tool's image storage).
- **Remove everything:** `make llm-down PURGE=1`, then `podman rmi docker.io/ollama/ollama:<tag>`
  (or `docker rmi`).
- On 22 CPU cores the 7B answers a short line in two to four seconds (the 3B in one to two);
  speed is not a goal.
- **GPU:** `llm.sh up` finds the GPU by itself (`LLM_GPU=auto`, the default):
  - **NVIDIA** when a CDI spec for `nvidia.com/gpu` is in `/etc/cdi` or `/var/run/cdi`: the
    container gets `--device nvidia.com/gpu=all`.
  - **AMD** when `/dev/kfd` and a render node in `/dev/dri` exist and the user may open them:
    the container runs the `-rocm` image of the same Ollama version with both devices.
  - else the **CPU**, and it says why (no CDI spec, `/dev/kfd` missing or not accessible).

  With both GPUs usable it takes NVIDIA and says so. `LLM_GPU=nvidia` or `amd` choose one and
  fail if it is not usable, `LLM_GPU=1` means any GPU or fail, `LLM_GPU=0` the CPU. The
  container is labelled with what it was started with (nvidia, amd or cpu); a change of
  `LLM_GPU` or of the machine recreates it. `LLM_DRY_RUN=1 tools/llm/llm.sh up` only prints
  the run command (tools/llm/test_llm_gpu.py, part of `make test`, checks the choice that way
  against a fake device tree; `LLM_CDI_DIRS`, `LLM_KFD_DEVICE`, `LLM_DRI_DIR`, `LLM_KFD_NODES` and
  `LLM_AMDGPU_MODULE` point llm.sh at it). `make llm-check` ends with `ollama ps`, whose PROCESSOR
  column says `GPU` or `CPU`.

### Setting up the GPU (once per machine)

`make llm-gpu-setup` looks at the machine: with `nvidia-smi` it does the NVIDIA setup below,
else with an AMD driver it checks the AMD one (`LLM_GPU=nvidia` or `amd` pick one), else it says
there is nothing to set up.

#### NVIDIA

A container only gets the NVIDIA GPU through a CDI spec (Container Device Interface): a file in
`/etc/cdi` that tells podman and docker (28+) which device files and driver libraries to pass in.
The NVIDIA container toolkit writes it. On Gentoo with the RTX 4070 here:

1. The driver works on the host: `nvidia-smi` lists the GPU.
2. Install the toolkit (root):

   ```sh
   sudo emerge app-containers/nvidia-container-toolkit
   ```

3. Write the spec: `make llm-gpu-setup`. It checks steps 1 and 2, runs
   `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`, and lists the devices; it
   should show `nvidia.com/gpu=0` and `nvidia.com/gpu=all`.
4. Start the test LLM on the GPU and check it:

   ```sh
   make llm-up LLM_GPU=1   # fails loudly instead of falling back to the CPU
   make llm-check          # PROCESSOR should say 100% GPU
   ```

**After each driver update** run `make llm-gpu-setup` again: the spec names the driver's library
files by version, and a spec of the old driver makes the container fail to start. Plain
`make llm-up` (`LLM_GPU=auto`) falls back to the CPU only when there is no spec at all.

#### AMD

ROCm runs inside the `-rocm` image, so the host needs no ROCm, only the `amdgpu` kernel driver
(in the mainline kernel; on Gentoo `CONFIG_DRM_AMDGPU` and `CONFIG_HSA_AMD`, plus the
`sys-kernel/linux-firmware` files for the card) and access to two device files: `/dev/kfd` and
a render node (`/dev/dri/renderD128`). Both belong to the `video` or `render` group, so the user
must be in them:

```sh
sudo usermod -aG video,render $USER   # then log out and in again
make llm-gpu-setup                    # checks the devices, the groups and the gfx target
make llm-up                           # picks AMD by itself; LLM_GPU=amd insists
make llm-check                        # PROCESSOR should say 100% GPU
```

`llm-gpu-setup` needs no root: it says what is missing. The first start pulls the ROCm image
(its size is not measured yet). podman gets the groups with `--group-add keep-groups`, docker
with the group ids of the two devices. podman's `keep-groups` works with the crun runtime
(Gentoo's default for podman); with runc, use `CONTAINER=docker`. A Ryzen's built-in graphics
shows up as a second AMD GPU (not tried on such a machine yet); an override would then apply to
both, so set one only if neither card is supported; a hint printed for an RDNA2 one (gfx1035,
gfx1036) may be for the built-in graphics.

ROCm supports a card by its gfx target, printed by `make llm-up` and `llm-gpu-setup` (from
`/sys/class/kfd/kfd/topology/nodes/*/properties`). The RX 7900 GRE (RDNA3, `gfx1100`) is
supported as it is. Consumer cards ROCm does not list may work when told to pose as a
supported one with `LLM_HSA_OVERRIDE` (passed as `HSA_OVERRIDE_GFX_VERSION`); the script
suggests it for the known cases:

| Card | gfx target | `LLM_HSA_OVERRIDE` |
|---|---|---|
| RX 6800, 6900 | `gfx1030` | not needed |
| other RDNA2 (6600, 6700, ...) | `gfx1031` to `gfx1036` | `10.3.0` |
| RX 7900 XT/XTX/GRE | `gfx1100` | not needed |
| RX 7600 | `gfx1102` | `11.0.0` |

An override that does not fit crashes the server instead of falling back: remove it then
(`make llm-up` recreates the container only when the GPU setting changes, so run
`make llm-down` first).

### Trying the prompts: `make llm-eval`

`make llm-eval LLM_MODEL=<tag>` (the test LLM must be up with that model; `LLM_RUNS=n` replies
per scenario, 3 by default) checks the villagers' prompts on a model. Godot builds the requests
with `NpcPrompt` itself (`tools/llm/dump_requests.gd`: 25 fixed scenarios, a greeting, rain at
dusk, switches of language (German after English, also in a longer chat, Danish after English,
English after German, a short "Moin" after German and "Hej" after Danish), Danish, Swedish
(which the game does not know), a phone, a car, a rude line, a fact from earlier in a long chat,
a villager with a memory, a memory summary, and keeping to the sheets: family (also in German),
the husband's name again after a long chat, another villager, the pastor, the Deichgraf (in
German), a sister or brother the villager doesn't have (also in German); Antje, Momme, Ocke and
Kerrin), so the tool never drifts from the game; `tools/llm/eval_prompts.py` sends each one `n` times at the configured
temperature and writes `build/llm-eval/<model>.md`: every reply, with crude checks (too long,
too many sentences, cut off, assistant phrases, label echo, copying the example or the player's
line, the wrong language by stop words and telling letters, a memory not in the first person,
none of the names a scenario expects (Hinrich or Boy for Antje's family, Martens for the pastor,
Momsen for the Deichgraf), a name of the region the request never mentions, that is made up).
The report gives the average prompt tokens too.
The checks only find what is plainly wrong; read the replies. `LLM_API_KEY` set in the
environment is sent as the bearer key, so that `tools/llm/eval_prompts.py --endpoint <url>
--model <name>` can try a hosted model, and `--requests <file>` sends the requests of an earlier
dump (to try old words again). The requests have the cut-down sheets a local model gets;
`--full-sheets` sends the full ones a hosted model gets (report `<model>-full.md`). To try them
on Gemini with your AI Studio key:

```
LLM_API_KEY=AIza... .venv/bin/python tools/llm/eval_prompts.py --full-sheets --runs 2 \
  --endpoint https://generativelanguage.googleapis.com/v1beta/openai --model gemini-3.1-flash-lite
```

On HTTP 429 (the free tier's limit) it stops and writes what it has; `--only <id> ...` runs a few
scenarios. `tools/llm/eval_prompts.py --compare <tag> <tag>` puts the
replies of two earlier runs side by side in `build/llm-eval/compare.md`. It takes about 2
minutes for the 3B and 4 for the 7B with 5 replies each. When the prompt words in
`data/npc_talk.cfg` change, run it on both and read the reports.

## Screenshots in a size

`make screenshot` saves the window as the window manager sized it, and on Wayland that is not the
size asked for. `make screenshot SIZE=1000x1040` runs the game in a viewport of exactly that size
(`game/scenes/screenshot_frame.tscn` instead of the main scene, with `--screenshot-size`), stretched
as the project's window is (the base size, the aspect `expand`, the UI scale of the settings), so
the picture is exactly 1000x1040 and shows the view, the HUD and the UI scale a window of that size
would. The viewport's UI size is a whole number, so a UI layout can be a pixel off the real
window's. Without `SIZE` nothing changes.

## The window of a check

Every window a make target opens for a check, today `make screenshot`, is titled exactly
`Sandbox Game (test)`, with the game flag `--with-working-window-title` (the target passes it by
default). `make run` does not: your own runs keep the normal title, and
`make run ARGS=--with-working-window-title` titles one like a check's.

The user's KDE rules match that title (a KWin rule, keep below on a virtual desktop of its own,
and a Krohnkite exclude), so do not change the text, add a suffix or vary it by target.
`StartupOptions.WORKING_WINDOW_TITLE` is the one place that has it.

Godot gives the window its title only when the game's first scene starts: until then the window,
which the Wayland driver has already given the app id `Sandbox Game` (the project's name), is
called `Godot`, and for a short while `Sandbox Game (DEBUG)`. A rule that applies once, when the
window appears, sees one of those; one that is checked again when the title changes sees the
working title. Godot sets `Sandbox Game (DEBUG)` again as the window closes.
