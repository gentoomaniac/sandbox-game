# Tasks: Prototype

Implements milestone 1 from [SPEC.md](SPEC.md). Each task is small enough for one
developer brief. Tasks whose dependencies are done can run in parallel. The
coordinator ticks a task off here when it is merged.

Tasks 1 to 51 are finished and live in [docs/tasks-done.md](docs/tasks-done.md). Their
numbers still mean the same: SPEC.md and code comments refer to them.

Rules for every task:

- Use only make targets for build, run, test and lint. A new multi-step command gets a new
  make target.
- Keep game state (world, tiles, buildings, crops, time) in plain GDScript classes with no
  rendering or input code. Scenes only read the state and send actions to it.
- State logic gets GUT tests (`make test`). Rendering and input are checked by hand with
  `make run`.
- `make lint` passes.
- Visuals come from the art generator (task 5 on). Until a task adds art for something,
  use simple placeholder shapes in palette colours.

## 52. Art quick wins from the style guide

- [x] Done

See docs/art-style.md, "Changes to make", quick wins 1-8 (the user, 2026-11-06: implement
the suggestions, quick ones first): straw bedroll instead of the sleeping bag; a new straw
hat shape (and a red knitted cap as a second hat); tomatoes replaced by flax (a fibre crop;
old saves map tomatoes to flax), strawberries the small wild kind, the pumpkin a smaller
green garden squash; autumn colours towards brown, ochre and copper (after task 51 is
merged, in seasons.py); small-paned windows on all buildings and the interior window; the
palette swaps (merge the five rare colours, add lime, paint_teal, heather, heather_dark; Kate
wall in lime and door in paint_teal, `spirit` kept for magic); seed sacks that can be told
apart; a copper watering can. Screenshots refreshed (day-and-night.png too).

Done: one commit per quick win, each with its art, tests and docs. Palette: `meadow_dark`,
`lush`, `crimson`, `frost_light` merged; `meadow_light` kept, as since task 51 it is the
Scots pine's lit needles (`green_light` turned them yellow-green); `lime`, `paint_teal`,
`heather`, `heather_dark` added (64 of 64); the Kate is lime-washed with `paint_teal` door
and shutters, and the purple berries, bean flowers, turnip shoulders and butterflies moved
from `arcane` to `heather`, so both magic colours are free. The camp's bed is a straw sack
with a rolled grey wool blanket (id still `sleeping_bag`; snow, frost and dusting looks).
The straw hat has a low crown and a drooping brim; `knitted_cap` is a red stocking cap, in
the starting backpack, with all frames (both hats one row lower, so `HAT_TOP` is -30).
Autumn oaks are brown, ochre or copper, bushes yellow or ochre, no red. Flax replaces
tomatoes: a cool-weather fibre crop with blue flowers, no regrow, not food, yielding a new
`flax` item rather than `fibre` (each crop's produce is its own item from crops.cfg, and
flax stalks are a material of their own before retting); save version 7 maps tomatoes and
their seeds to flax wherever they lie. Strawberries are wild, the pumpkin a small green
squash (id kept). Windows have 2x2 px panes in 1 px bars (3x3 in houses, 2x3 in the
shack, whose window grew taller; the dormers likewise; lit panes glow evenly); every
`window_lights` point is on glass. Seed sacks have a crop-coloured string, the crop painted
large and its seeds spilled. The watering can is copper with a big rose. Screenshots:
camp, buildings, day-and-night, seasons, character; the others only show the new can
icon in the hotbar and were left.

## 53. Period clothes for the player

- [x] Done

docs/art-style.md bigger item 1: knee breeches, white stockings, clogs, a red waistcoat
over a linen shirt, a short blue or brown jacket, long hair tied back; every animation and
the collapse frames; the starting clothes and the spare shirt become the period ones.

Done: one commit per piece. Breeches (3 rows, banded at the knee) over white stockings
that run into the feet; a red waistcoat with tin buttons over a linen shirt (`clothes_0`),
the spare shirt the plain linen one (`clothes_1`); a short open blue jacket in a new `coat`
equipment slot and layer (between clothes and hair), in the starting backpack; wooden clogs,
the first feet item, worn from the start; hair 2, mid-brown tied back with a black ribbon
(F6 cycles three). No new colours. Ids: `tunic` is `waistcoat`, `trousers` is `breeches`,
`shirt` kept; save version 9 renames them in the equipment, inventory, ground items and
chests (indoors too) and puts clogs on the bare feet. The clothes got lighter so a new game
still carries under the free 20 kg (19.9). Hats unchanged (`HAT_TOP` still -30).
Screenshot: character.

## 54. Knicks, dykes and marsh ditches

- [x] Done

docs/art-style.md bigger item 2: autotiled Knick hedges on earth banks (hazel, hawthorn),
dykes with turf, straight drainage ditches with reeds, pollard willows, wattle fences and
fieldstone walls, placed by the world generator where they fit (marsh, field edges).

Done: one commit per piece, then polish. Line objects (a type that `connects`) are one object
per tile, drawn by connection mask (World `connections`, 16 pictures per variant), as solids on
the ground in tools/art/boundaries.py: the Knick (3 variants), the wattle fence, the
fieldstone wall (3 variants) and the dyke, with all their seasons; the pollard willow is a new
tree with a trunk. `data/landscape.cfg` (LandscapeRules) and `FieldLayout` lay rows of fields
over the land; every stretch of boundary has a gap, nothing blocking stands on or beside it.
Geest: Knicks, walls, fences; marsh and wetland: ditches (water terrain) with willows and
reeds; dykes along the floodplain. Knicks, walls, fences and ditches block walking, dykes don't;
axe and pickaxe take hedges, fences and walls down. Save version 10 clears the new land 3 tiles
around buildings and the player's objects, over the tilled fields (grown by 2), under ground
items and where the player stands. Generating a chunk takes about 6.5 ms instead of 3.7. Screenshot: landscape. Decisions in SPEC, World, "The worked land".

## 55. Thatch as courses, clear roof planes

- [x] Done

docs/art-style.md bigger item 3: thatch drawn in 3-4 px courses with grouped strokes, clear
roof planes and ridge so roofs read as steep hipped roofs, not domes; crossed ridge sticks
on the Kate as an option. All buildings and their snow and lit looks.

Done: one commit per piece. `thatch_roof` draws courses about 4 px high with wavy edges,
lit along the top in broken runs, with reed ends 1-3 px long hanging below, on three
planes: the lit left hip, the front slope and the shaded right hip, with a lit hip line,
hips with a slight belly and a straight ridge; rolled eaves, dormers, moss and weathering
(crowded reed ends) in patches, the weathering kept off the door swells. Only the lowest
courses bend over a door swell. The Kate has crossed ridge sticks, and so does the longhouse, which shares them
(`kate(ridge_sticks=False)` gives the turf ridge back), drawn taller so they show against
the sky. Under snow the reed ends and most course lines are filled, leaving the planes and
an odd short line; this also fills the shack's board joints under snow, its only change.
No new colours, window lights unchanged.

## 56. Tree species of the region

- [x] Done

docs/art-style.md bigger item 4 (after task 51): beech, birch, alder and pollard willow as
the common trees with their seasons, wood and seeds; spruce and pine rarer, in clumps or
on the Geest; hazel and hawthorn in the Knicks.

Done: one commit per piece. Beech (tools/art/beech.py), birch (birch.py) and alder (alder.py)
with their summer art and a bare redraw for winter (fine twigs from `trees.twigs`), leaf-out
steps, autumn copper, yellow and a dull green-brown, their long and short trunks, a seed each
(beechnut, birch catkin, alder cone) that plants a sapling of them, sway and hit leaves. A tree
now names its trunk rows (`trunk.atlas_row`), so new trees go at the end of the atlas. The
Scots pine is redrawn taller (75 px) with a loose flat-topped crown and a warm brown trunk. The
generator keeps every tree where it stood and only picks the species anew: alder, oak and birch
on wet ground, beech, oak and birch on the dry Geest, pine and spruce only in clumps on the
Geest; no save upgrade, as no type changed and no tree moved (checked on a copy of the user's
save). No new colours. Screenshot: seasons. Decisions in SPEC, Time and seasons ("Trees of the
region") and World ("Which trees grow where"). Added on the user's word: the pollard willow
redrawn as a real Kopfweide (gnarled trunk, knobbly head, many thin rods), and a willow cutting
as its seed, which also fixes a crash on picking a willow sapling.

## 57. Hearth and furnishing of the period

- [ ] Done

docs/art-style.md bigger item 5: an open hearth under a smoke hood (or a jamb stove),
Dutch tiles behind it, clay or brick floors, plate rack, wall benches; the animated fire of
task 48 kept.

## 58. The shack in tarred boards

- [ ] Done

docs/art-style.md bigger item 6: tarred black or weathered silver boards with a turf roof
(no reeds, as the user decided), so it no longer reads as a frontier cabin.

## 59. A hall house with the gable front

- [ ] Done

docs/art-style.md bigger item 7: a new building, the Niedersachsen-style hall house with
the big arched door in the gable, owl hole (Uhlenloch) and crossed horse heads,
half-timbered; buildings.cfg entry with costs and an interior. A Haubarg later.

## 60. Animals of the region

- [ ] Done

docs/art-style.md bigger item 8: white storks (on roofs, in the marsh), red-brown cattle
and sheep (on dykes and pasture), geese, as ambient wildlife with sounds; roe deer and
rabbits stay.

## 61. Coast and tidal flats

- [ ] Done

docs/art-style.md bigger item 9: tidal mud with ripples and tideways, salt marsh turning
red in autumn, a Warft (dwelling mound), an Ewer lying on the mud; terrain and world
generator work.

## 62. Post mill and draw well

- [ ] Done

docs/art-style.md bigger item 10: a post mill and a draw well as landmark props, placed by
the world generator near settlements or on rises.

## 63. Onboarding docs and build papercuts

- [x] Done

From docs/code-review-2026-11-06.md. docs/architecture.md (~80 lines: game/state pure and
tested, game/world, game/scenes rendering; data/*.cfg -> *_rules.gd -> *Types as the way
to add content; the main nodes (Main, GameState, World, WorldView); which tests/*_case.gd to
extend; `make screenshot` for rendering; key bindings live in project.godot, change them in
the game; the debug flags), linked first under "For developers". tools/README.md (module
map, add a sprite/object/colour/sound, seed rules: `random.Random(seed)` only, no `hash()`,
draw order matters, `seed % 3` picks structure, the commands). maps/README.md (editing
interiors in Tiled: interior.tsx tile properties such as `exit`, the CSV `ground` and
`furniture` layers, one file per building id, InteriorLoader asserts). Finished tasks 1-51
moved to docs/tasks-done.md (TASKS.md keeps the rules, open tasks and "Later"; the dead
"Parallel plan" goes; check links). SPEC: real status line and make target list.
docs/art-review-2026-11-05.md archived or linked from art-style.md. Makefile: `make help`
as the default goal (targets and their variables AT, TIME, ZOOM, OUT, KEEP_SAVE, SOUND,
ARGS, GODOT); Tiled optional in `make setup`; `make clean` (build/); tools/requirements.txt
with the pinned Pillow and numpy and a `make venv` target that `make assets` depends on.

Done: docs/architecture.md, tools/README.md and maps/README.md, linked from the README.
Tasks 1-51 are in docs/tasks-done.md (task numbers in SPEC and code comments stay valid).
The art review is in docs/archive/. SPEC has a real status line and target list.
`make help` is the default, Tiled is optional in `make setup`, `make clean` exists, and
`make venv` (pins in tools/requirements.txt, gdtoolkit too) serves `make setup` and
`make assets`, which now runs without Godot. A venv is no longer repaired when a package
is missing: delete it and run `make venv`.

## 64. Quiet, honest tests

- [x] Done: 843 warnings and 6 orphans now 0 (the orphan leak was in the test, not the game: WildlifeView.ground was never parented; the test also leaked it at exit); 14 headers added (not 12); `make test` prints the counts and fails on 0 tests; test_collapse_flow steps the fade tweens with `custom_step`.

From docs/code-review-2026-11-06.md. Fix the 840 "Float/Int comparison" warnings
(tests/test_vegetation.gd) and 3 in tests/test_tiredness.gd; the 6 Node2D orphans in
tests/test_ambience_sounds.gd; delete the placeholder tests/test_pipeline.gd; a one-line
`##` header on the 13 test files without one (test_camera_rig, test_buildings,
test_chunk_streaming, test_day_night_tint, test_game_clock, test_game_state,
test_interior, test_targeting, test_tile, test_terrain_tileset, test_view_math,
test_world); test_collapse_flow drives the fade directly instead of waiting real seconds;
`make test` fails when no test ran, and prints the warning and orphan counts.

## 65. The art generators split by topic

- [x] Done: generate.py 2362 to 247 lines; canvas.py, palette.py, terrain.py, trees.py, camp.py, character.py, interior.py split out, one commit per step, `make assets` byte-identical after each. Deviations: `palette.save(rows, path, size, height)` takes the rows, not an image, so an unknown colour names the file being written; the atlas rows are tied to the GD `atlas_row` numbers by a generated assets/objects_rows.txt (read by test_object_atlas), which is the one new file in assets/; the atlas kind `fern` stays (it seeds the season looks) while the type is `fern_bush`, so the test has one alias.

From docs/code-review-2026-11-06.md; runs right after task 52, before task 53, so the later
art tasks work in the new layout. tools/art/generate.py (2290 lines) split along its
sections into palette.py, canvas.py (TILE, the 48x80 object cell constants now copied into
trunks/meadow/reeds/generate, one blank-canvas maker, one clipped `rect`, `copy`),
terrain.py, trees.py, character.py, interior.py; generate.py keeps the atlas assembly and
`main` (a `save(image, path)` helper that makes directories, the per-family writers, a
short final print; module-level drawing moved into `main`; FURNITURE defined once). One
numbered table of the object atlas rows above `object_atlas()` (the docstring misses the
chest row), the trunk-row order dependency named in trunks.py and in
world_object_types.gd, and a test tying the GD `atlas_row` numbers to it. seasons.py: copy
the canvas once at the top of `_winter_object` (snow_caps mutates the shared summer art),
a per-kind look table instead of the if-chain so a kind without a winter look fails
loudly. Palette: fail on duplicate names when seasons' colours are merged in, and say
"unknown colour X in <asset>". Outline helpers stay separate (different art rules). Must
leave `make assets` byte-identical.

## 66. Small state cleanups

- [x] Done: one commit per item. Save VERSION is now 8 (`_upgrade_from_version_7` gives old saves the moisture, clay, outfit, energy, health, debuff, chest store and crop growth they lack; every from_dict is strict). `World.new(seed, clock)` and `GameState.new(clock)` keep a default clock because many tests build them bare. Interaction uses Targeting.REACH. The five tests of the old lenient from_dict were replaced by upgrade tests.

From docs/code-review-2026-11-06.md. Delete unused tile state: Tile.water_level and
snow_depth with Chunk's arrays and accessors, Tile.is_tillable and is_plantable; keep
`frozen` with a comment (hook for frozen rivers); fix SPEC and TASKS lines that promise
them. `current_map` becomes a getter from `_building_inside` (one field instead of two that
must agree). `World.new(seed, clock)` instead of overwriting its own clock; one place that
wires `new_day` for new_game and from_dict; a comment that `clock.day` is already the new
day in `_on_new_day`. One `REACH` (Interaction and Targeting). Save: a "how to add a field"
rule at the top of save_file.gd, the silent `data.get(...)` fallbacks in from_dict
(soil moisture, spent clay, energy, equipment) and the crop `days_grown` conversion moved
into a versioned upgrade step so every from_dict is strict; upgrade tests. Small: `_hit`
returns nothing; `PositionHash.rolls(pos, salt, chance)` for the three roll idioms;
`Inventory.duplicate()` instead of the to_dict clone in Crafting; `is_blocked_by_thing`
renamed.

## 67. Tool use out of GameState

- [x] Done

From docs/code-review-2026-11-06.md. The use-action rules (~250 of GameState's lines: the
`Use` enum, COST_KINDS, use_at, use_tile, _do_use, _use_tool, _use_cutting_tool,
_use_by_hand, _use_inside, _hit, _dig, the mowing, _rolls_seed, _items_of_chest,
CLAY_DIG_*, ACTIVE_TOOLS) move to `game/state/tool_use.gd` (`ToolUse`, given the state like
Builder and Crafting). GameState keeps one-line forwards so scenes and tests keep working.
A pure move; no behaviour change.

Done: `ToolUse` holds all of it (GameState 591 -> 331 lines, ToolUse 301). `Use` moved to
`ToolUse.Use` (and `COST_KINDS` to `ToolUse.COST_KINDS`) with every caller updated: the enum
belongs to the rules that produce it, and a newcomer finds it next to them. GameState makes a
`ToolUse` per call and forwards `use_at`, `use_tile`, `use_facing_tile`, `can_use_held_item` (a
field would be a reference cycle: the state and the rules would never be freed).

## 68. World split and one way to read data files

- [x] Done

From docs/code-review-2026-11-06.md. Ground items out of World into their own class
(`_ground_items`, drop_items, _scatter_tiles, _hash_fraction, ground_items_near; no chunk
coupling); then the nightly upkeep (pass_night, _dry_and_wet_soil, _recover_clay_spots)
into its own; drop World's `max-public-methods` exception. One static
`DataFile.read_sections(path)` used by the ten rules classes (no base class), and one
validation API across them (`problems()` + `is_valid()`, renaming `missing_keys`/
`bad_values`). README/architecture: "adding a data file".

Done: `GroundItems` (`world.ground_items`: all, near, count_of, add, remove, the signals
`added`/`removed`/`dropped`, and `drop`) and `NightUpkeep.pass_night(world, ...)` (static, given
the world) are out of World (652 -> 506 lines). Neither keeps the World, so there is no
reference cycle: `World.drop_items` stays as the one entry point and passes itself to
`GroundItems.drop` per call (it is the one that knows what can be walked on). World still has 37
public methods (chunks, objects, soil, buildings, clay), so the `max-public-methods` exception
stays, with a comment on what is left. `DataFile.read_sections(path)` is used by the nine rules
classes and `Vegetation`; all of them have `problems()` and `is_valid()` (`missing_keys` and
`bad_values` are gone). docs/architecture.md has "Adding a data file".

## 69. main.gd slimmed

- [x] Done

From docs/code-review-2026-11-06.md. The ~45 debug flags into a parsed `StartupOptions`
(typed fields, one `_tile(arg)` helper; also the flags now parsed in PlayerView, BuildMode
and AudioService; unknown flags warn) and a small runner for the "once the world is drawn,
do X" steps and the screenshot countdown; the flags documented in one place, main.gd's
header points there. All screens (character, crafting, storage, console, pause) get the
same `open()`/`close()`/`is_open()` (close safe when closed; StorageScreen connects
safely), and Main keeps one list of them for the Escape order, "is any open", "close all"
and the UI sounds. `_ready` in three named steps (make views, connect state, apply start
options) with the order dependencies written down. Input order unchanged.

Done: every screen has `open()`, `close()` and `is_open()` (`close()` is safe when closed;
StorageScreen listens to the inventory and chest only while open). Main keeps `_screens`, a
plain array of the console and the three screens in Escape order, with three small functions
over it (any open, close topmost, close all) and the UI sound loop; the pause menu stays
apart because Escape opens it and it pauses the game. `StartupOptions`
(game/scenes/startup_options.gd) parses every flag once into typed fields and its header is
the one list of flags; PlayerView, BuildMode and AudioService read it. `DebugRunner` does the
"once the world is drawn" steps and the screenshot countdown. `_ready` is `_load_game`,
`_make_views`, `_connect_state_and_views`, `_apply_start_options`, then the sounds, with the
order written down. main.gd went from 871 to 671 lines.

## 70. world_view.gd: one tile code, buildings and decorations apart

- [x] Done

From docs/code-review-2026-11-06.md (and the task 29 note in "Later"). Layer, season look
and weather look of a tile packed into one int per tile (thresholds stay apart); one
`_code_at`; one corner grid in `_draw_chunk` and `_redraw_cell`. Then BuildingViews (the
building sprites, window lights, snowy check) and DecorationView (decoration spots, flowers
for the wildlife) as their own small views; streaming, terrain and objects stay in
WorldView. Verified with the season and tiling tests and a screenshot diff.

Done: `TerrainTileset.tile_code` packs layer (bits 0-2), season look (3-6) and weather look
(7-10) into one int; `ChunkLooks.codes` holds one per tile, `WorldView._code_at` reads it, and
`_draw_chunk` and `_redraw_cell` build one corner grid / one 4-code array that
`_draw_cell_corners` and `_draw_overlays` take (overlay rules untouched). `BuildingViews`
(game/scenes/building_views.gd) and `DecorationView` (game/scenes/decoration_view.gd) are
nodes WorldView owns; the wildlife reads `world_view.decorations`. world_view.gd went from 991
to 789 lines. Pixels unchanged: checked by an exact digest of every tile layer, sprite and
light (8 buildings, 7 day/snow/frost states, lights on and off) before and after each step.

## 71. Scene odds and ends

- [x] Done

From docs/code-review-2026-11-06.md. One `hash.gdshaderinc` for the hash/hash4 copied in
five shaders, the stale double comment in fire.gdshader, "palette: tools/art" notes next
to shader colours. The "object is gone" contract written once (a World helper or a signal
argument) instead of re-derived in WorldView, GameSounds and GroundItemView (and a named
"waiting" flag on a hop instead of `elapsed == 0.0`). One backdrop colour and one spelling
(colour vs color) in the screens; `TerrainTileset.tile_centre`; FallingTree emits
`finished` once; the weather text not built while F3 is off; no list copies per frame when
empty.

Done: `game/scenes/hash.gdshaderinc` (hash, hash4; the five copies were identical) is included
by lily_pad, fire, rain_splashes, water and weather_precipitation; each shader colour block
says "palette: tools/art/palette.py" and whether tests/test_shader_palette.gd guards it.
`World.is_gone(object)` is the one "the hit took it down" check (WorldView, GameSounds);
`ItemHop.just_dropped` replaces `elapsed == 0.0`. `UiColors.BACKDROP` is the one backdrop;
constant names say `color`. `TerrainTileset.tile_centre` replaces the `_centre_of` copies and
the inline math (wildlife included). FallingTree emits `finished` once. Main builds the F3
text only while it shows; WorldView returns early with no falling trees.

## 72. Lighter load, 8-slot hotbar, 4×5 backpack

- [x] Done

The user's answers of 2026-11-07:
- Tools weigh nothing, and the weight that costs no extra energy goes up to 40 kg.
- The backpack is shown as 4×5 again (not 2×10).
- The hotbar has 8 slots instead of 10 (keys 1-8). Old saves move whatever sits in the two
  dropped hotbar slots into the backpack, or onto the ground at the player's feet when it is
  full.

Done: tools (every item with a `tool`) weigh 0 and the tooltip leaves out the weight line of a
weightless item; `free_kg` is 40. The backpack is a grid of 5 columns and 4 rows on both screens,
the hotbar a row of its own below it (8 slots wide; on the storage screen it no longer wraps to
the backpack's width). `Inventory.HOTBAR_SIZE` is 8, so there are 28 slots; keys 1-8 (the
`hotbar_9` and `hotbar_10` actions are gone, and `GameSettings.RETIRED_ACTIONS` lets a settings
file that still binds them load without a warning). Save version 11: the upgrade moves what lay
in old hotbar slots 8 and 9 into the first free backpack slots (onto stacks of the same item
first), else onto the ground at the player's feet (piles 0.3 tiles apart), and a selected slot
that is gone becomes slot 0. The version 1 step now builds its inventory in version 5's 20
slots (it used the current layout, which the later steps would misread); the version 5 step
widens to 30 literally. The 8 starting items fill the hotbar, so a new game has no free hotbar
slot; harvests go to the backpack. Tests: `HotbarHold` fetches an item (or an empty hand) into
the held slot, `SaveUpgradeCase` shares the old-save helpers.

## 73. Livestock: cows, sheep, chickens, rabbits

- [ ] Done

The user's word of 2026-11-07: cows, sheep, chickens and rabbits, spawned for now with a
console command. They wander, graze grass (cows, sheep, rabbits) or peck for seeds and worms
(chickens), and sleep at night. Not all alike: 2-3 looks per species, plus colour variation
when drawn. Products (milk, wool, eggs) and keeping them (pens, feeding, owning) come later.

## 74. Professions: woodworker, cook, mason; a UI for them

- [ ] Done

The user's word of 2026-11-07: start with the three professions suggested in
docs/ideas/crafting-and-professions.md (woodworker at a workbench, cook at hearth and oven,
mason with bricks and a kiln) and a UI for them. Decided by the user:
- **Skills grow both ways:** crafting raises the skill (no gain from trivial recipes), and
  skill levels unlock the next tier of recipes. Skill numbers are shown.
- **A hard total cap, as points:** only one profession can reach the maximum; with it the
  player can be above average in one or two others, not more.
- **Stations are placed objects** (workbench, oven, kiln), crafted and placed like the chest.
  The bench and oven craft at once; the kiln fires over time (overnight). The house hearth is
  the cook's first station.
- **UI:** a skills tab beside the character screen with each profession's level and progress;
  using a station opens the crafting menu filtered to it, with locked recipes shown along with
  the skill they need.

## Later (not part of the prototype)

- A committed pixel guard (a GUT test hashing the tile cells, sprites and lights for a fixed seed
  and a few days) would catch silent rendering changes in refactors like task 70; left out while
  the art tasks change the pictures on purpose, as its golden value would need updating each time.

- World keeps its `max-public-methods` lint exception after task 68 (chunks, objects, soil,
  buildings and clay share the same edits). Getting under 20 would take one more split, most
  likely buildings and their placement rules.

- Season looks follow-ups (from the task 29 review): SeasonBlend's four boundaries
  as a loop over SeasonRules.BOUNDARIES; `frost_at` belongs with the season rules, not
  SnowCover. SnowCover's cold start (~80 ms for a fresh region in late winter) could be
  spread over frames. Snow cover of the player's region is applied to the whole loaded
  world for now.

- Split the object edits and regrowth (`_object_edits`, `replace_object`, `hit_object`,
  `change_object`, `pass_night`) out of `World` into their own class with their own tests,
  and drop the `max-public-methods` lint exception in world.gd.
- Edits of objects that are back to their generated state (a healed tree) stay in the
  save; harmless, bounded by what the player touched.
- Ground items (task 33 review): `World.ground_items_near` scans every pile each frame
  (fine for tens, not hundreds; piles never expire): bucket per tile or chunk. A pile that
  falls back onto a non-walkable source may be out of reach. A pulled pile moves straight
  through walls and water (the pull reaches 1.25 tiles since 2026-11-05).
- Task 35 review: time a chunk load with the clay probe and hint layer against the ~14 ms
  baseline; a mown tuft stays an object edit forever after it regrew (drop edits that are
  back to their generated state); ResourceCase `_hold` could just select a hotbar slot.
- Held art and use poses for axe, pickaxe, scythe and shovel.
- A planted sapling can be picked up again by hand for free; decide whether that's fine.
- The shovel could later dig up a young sapling to move it.

- Floodplain farming: floodplain is the most fertile farmland, but only grass can be tilled
  now. Tilling it needs a "tilled" tile property that keeps the floodplain flag, so floods
  can still act on it.

Art notes from the art round 2 review and look:

- Extra vegetation (done, branch `extra-vegetation`): spruce, pine, dead tree, berry bush,
  shrub, sapling, fern bush; joined trunks, ground shadows, 32×48 object cells. Fern and
  sapling sprites are still plain.
- Dusk (18:30) comes out olive and muddy rather than warm orange; tune the tint gradient.
- Lush and dry grass areas look blotchy; dry should differ in hue (yellower), not only
  brightness.
- The grass texture is busy (many dark marks).
- `tools/art/generate.py`: shared sprites (pebbles, fern, clover, brown caps) are defined
  several times; move them to module level. Add a small `size(picture)` helper.
- No test yet that `redraw_tile` redraws decorations and unload erases them.

Art scale pass notes (16a–16c reviews and look):

- Pines read as olive-brown blobs with stubby trunks inside forests (redrawn in task 51).
- The sleeping bag (1×2, vertical) reads like an upright sign behind the player; it should
  look flat on the ground. The character's face turns slightly pink at night.
- Seed mound and sprout stages are plain; the hoe is a thin stick from front/back.
- A grass tuft can stay under a boulder's right half at the load frontier (hidden).
- Saves from before 16a put the 1×1 bag where the new spawn is; `add_chunk` replay checks
  only the origin tile of multi-tile objects.
- Interior: the table reads like a chest, the chest is hard to identify, the bed is flat,
  the floor boards are very high contrast.

Saving notes from the task 15 review:

- A version-1 save with valid JSON but missing keys or bad references hits asserts in
  `from_dict`; fine while only the game writes saves, but handle gracefully before players
  edit or share saves.
- Only closing the window saves; Ctrl-C/SIGTERM doesn't.
- `--new-game` without `--save-path` replaces the real save on quit (intended); `make screenshot`
  uses build/screenshot.save, so test runs never touch it.

See-through notes from the task 14 review:

- `sprite_height` on tree types is hand-set and 1–2 px under the art for oak and dead tree.
  Add a test that each declared height is at least the opaque height in the atlas.
- `Occlusion.building_rect` calls `load()` and `world.buildings()` copies the array every
  frame; cache texture sizes per building sprite.
- A swapped sprite may change draw order against a same-row neighbour tree (small pop).
- Skip `_update_see_through` while inside a building.

Performance notes from the task 6 review:

- Loading a chunk takes about 8 ms on average, with spikes up to 16 ms when crossing a
  chunk border. Profile `_load_chunk` first. Likely fixes, cheapest first: generate
  chunks on a `WorkerThreadPool` task (generation is pure); split drawing over frames;
  skip `set_cell` for layers a cell doesn't use.

World generation notes from the task 3 review:

- The river is measured by vertical distance to its centre line, so it gets thin (about
  2 tiles) in steep bends. Use perpendicular distance, or a smaller meander.
- The wetland noise seed is `seed + 1`, which equals the river noise of the next seed.
  Use a large constant offset.
- More rivers, lakes or biomes: split `terrain_at` into one helper per feature instead of
  growing its if-chain.

Harvesting trees and rocks (tools, harvest levels, regrowth), saving and loading,
inventory, energy, weather, biomes, combat, reputation, building
customisation and expansions, real art.
