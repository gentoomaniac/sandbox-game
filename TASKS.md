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

- [x] Done

docs/art-style.md bigger item 5: an open hearth under a smoke hood (or a jamb stove),
Dutch tiles behind it, clay or brick floors, plate rack, wall benches; the animated fire of
task 48 kept.

Done: one commit per piece. Floors: red brick in a herringbone in the living rooms (Kate,
longhouse living end), beaten clay in the byre, the barn and the shack, as a new terrain
`CLAY_FLOOR` (footsteps on it are soil; the tileset got two floor tiles, every later tile id
moved up two). The hearth is an open hearth under a smoke hood, its picture 32x64 with the
hood on the back wall (fire box, flame top and light moved with it; same shader, light and
sound), the hearth of buff brick with an iron pot; Dutch tiles under the hood, soot behind
the fire. A plate rack (a wall piece like the window) in the Kate and the longhouse, a
spindle-backed `wall_bench` in the Kate between bed and hearth. The Kate's bed a Durk under
a canopy with curtains, the longhouse's box bed an Alkoven cupboard that stops under the
window's sill. Footprints, beds and gameplay unchanged; every free floor tile stays
reachable. Save version 12: rooms saved before take today's floors and the wall pieces they
lack, where the wall is free (checked on a copy of the user's save: Kate, shack and
longhouse load and look right). No new colours. The open hearth was chosen over the jamb
stove (the guide's first suggestion); the Bilegger is left for a best room.

## 58. The shack in tarred boards

- [x] Done

docs/art-style.md bigger item 6: tarred black or weathered silver boards with a turf roof
(no reeds, as the user decided), so it no longer reads as a frontier cabin.

Done: one commit per piece. Walls of upright boards tarred near-black with a batten over
each joint (the tar's blue-grey sheen on its edge), a sill beam on a low fieldstone base, a
ledged door and the shutter in ox-blood red, the window in a white frame. A turf roof on
birch bark: grass in overlapping clumps lit from the top left, two dry patches, a few
flowers, a ragged crest, and at the eaves a thick lip of turf with blades hanging over the
pale bark edge. Houses now have a picture per season (SeasonalArt.HOUSE_LOOKS: spring,
summer, autumn, bare, snow), picked from the season of the grass on their tile: the turf
(and the barn's turf ridge) is fresh in spring, yellow-brown in autumn, brown-grey in
winter; the build ghost stays summer or snow. Under snow the turf turns into lumpy snow,
lit near the ridge, with the lip and bark showing; the dark grass now maps to snow, which
takes a few shadow flecks off the thatch moss and the barn ridge too. Footprint, door and
window light unchanged. No new colours. Screenshot: buildings.

## 59. A hall house with the gable front

- [x] Done

docs/art-style.md bigger item 7: a new building, the Niedersachsen-style hall house with
the big arched door in the gable, owl hole (Uhlenloch) and crossed horse heads,
half-timbered; buildings.cfg entry with costs and an interior. A Haubarg later.

Done: one commit per piece. `hall_house`, 7x5 tiles, the biggest and dearest building (100
logs, 40 stone, 50 clay, 80 reeds; the longhouse takes 60, 30, 30, 50), between the longhouse
and the barn in the hammer's list. The picture (`buildings.hall_house`, 136 px tall) shows the
gable: oak framing with red brick, herringbone and slanting courses in the upper gable, the
top boarded with the Uhlenloch under a little half-hip, the green Grote Door under a carved
beam, two stable windows (with window lights). `gable_roof` draws the half-hipped thatch seen
end on in task 55's way: two planes (lit left, shaded right) whose courses run up the picture
along the side eaves, rolled side eaves, the reed cut along the rakes, a roll of reed as the
ridge lying along the roof (a turf ridge read as a green pole), moss on the shaded plane, and
white bargeboards crossing over the hip in carved horse heads, which stay clear under snow.
The interior (15x13, only task 57's furniture): the clay Diele from the door between rows of stall posts with hay, and the
brick Flett at its end with the hearth straight behind the door (a cooking station), two box
beds, wall bench, chest, table, bench, stool, plate rack and windows. Tested: footprint,
costs the most, room walls and reachability, floors, hearth and stalls, getting out of the
box beds, E at the hearth and a night in a box bed making it home. No save change (a new
building type only; a copy of the user's save loads). No new colours. Screenshot: buildings.

## 60. Animals of the region

- [x] Done

docs/art-style.md bigger item 8: white storks (on roofs, in the marsh), red-brown cattle
and sheep (on dykes and pasture), geese, as ambient wildlife with sounds; roe deer and
rabbits stay.

Done: four kinds in data/wildlife.cfg, art in tools/art/birds.py (no new colours). `stork`
hunts on wetland, the floodplain and grass with water within 4 tiles (`water_radius`, a new
key of every kind), in spring and summer by day, and flies off at 5 tiles with slow beats and
glides; `roof_stork` flies in from beside the view to a house near it (one per roof), lands
on the ridge (the middle third of the top edge of the house's picture as it is shown, read once
per picture, so it stays on top under snow), standing just in front of where the house sorts
(`BuildingViews.sort_position`), and leaves if the house is gone. Both are `Stork`, which clatters now and then. `geese` is a `GooseFlock` of 6 to
12 greylags on the marsh and floodplain (water within 7 tiles) in autumn, winter and, fewer,
spring: each goose grazes, looks round or steps on its own near the others; the flock looks up
at 9 tiles and takes off together at 6, closing into a V. `flying_geese` is a skein of 7 to 13
crossing high up, mostly at dawn and dusk: `Flock` flies sparrows or geese by kind.
`GroundShadows` are the flight shadows, kept and not made every frame. Sounds `stork_clatter`
(with the clatter) and `goose_honk` (now and then, and on taking off), peaks -25 and -24 dBFS,
quieter than the farm animals. Spawn and `--wildlife` take the four kinds (`roof_stork` on the
nearest roof, the geese as one flock). Livestock already graze the dykes, which are walkable:
no change. Not done: a stork's nest, lapwings and oystercatchers, the early spring of the geese
as such (a season factor of 0.5 for all of spring). Screenshot in docs/screenshots/wildlife.png.

## 61. Coast and tidal flats

- [x] Done

docs/art-style.md bigger item 9: tidal mud with ripples and tideways, salt marsh turning
red in autumn, a Warft (dwelling mound), an Ewer lying on the mud; terrain and world
generator work.

Done: one commit per piece. The coast lies in the west: a coast line x = f(y) about 260 tiles
west of the centre (`data/landscape.cfg` [coast], [tideways], [warften], [ewers]); the sea dyke
on the first land without gaps but for the river, the marsh reaching 36 tiles inland of it; then
salt marsh, tidal mud with tideways (one per 36 rows, clear of the river so no mud is cut off) and
the sea. New terrains `MUD`, `SALT_MARSH`, `SEA` (the salt water: no lily pads, frogs or reeds) and
`WARFT`, and layers `MUD` (over the water, the same in every season and weather), `SALT_MARSH` and
`WARFT` (grass over grass with their own season looks); the tile code's layer field holds the 12.
The salt marsh is drawn in logical colours per look (`seasons.SALT_MARSH_LOOKS`), red-purple in
autumn, with glasswort (a new decoration kind) and the flowers thrift and sea lavender (habitat
`salt_marsh`). The tide (`Tide`, `mud.gdshader`) is a look only: high water every 12 h 25 min, the
water filling a relief of its own; the mud is walked at any tide. A Warft (11 by 8 tiles, with a
Fething, buildable) on the salt marsh in one of 150 rows; an Ewer (3x1 object, tools/art/coast.py)
on the mud in one of 70; MAX_FOOTPRINT is 3x2. Storks and geese also live on the salt marsh, and
the sea counts as their water. Save version 18 gives an old home within reach of the coast its
ground back as grass and takes the new objects off (version 9's clearing, shared); a copy of the
user's save loads unchanged, the farm, camp and houses dry and reachable. Generating a chunk inland
takes 8.0 ms instead of 7.3 (side by side on one machine), on the coast about 7.4. No new colours.
Not done: ice on the mud, mussel beds and seals, a Stackdeich and sluices, the Ewer at full
scale, walking that changes with the tide. Screenshot in docs/screenshots/coast.png.

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

The user's answers of 2026-11-06:
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

- [x] Done

The user's word of 2026-11-06: cows, sheep, chickens and rabbits, spawned for now with a
console command. They wander, graze grass (cows, sheep, rabbits) or peck for seeds and worms
(chickens), and sleep at night. Not all alike: 2-3 looks per species, plus colour variation
when drawn. Products (milk, wool, eggs) and keeping them (pens, feeding, owning) come later.

Done: `FarmAnimal` and `Livestock` in game/state, the numbers in data/livestock.cfg
(`LivestockRules`): idle, walk, graze (peck), run (rabbits, from 2.5 tiles), sleep from
sunset plus `sleep_minutes` to sunrise plus `wake_minutes`, each animal up to 30 minutes
later. An animal steps only where its feet and its nose are on walkable tiles; the map is
asked again only when one of those tiles changes (it costs about 7 µs a tile), so about 130
animals take some 0.3 ms a frame by day. Drawn by `FarmAnimalView`, an `Animal` of the
wildlife whose state comes from Livestock; the WildlifeView makes one per animal near the view.
Sheets `assets/wildlife/<species>_<look>.png` from tools/art/livestock.py (no palette change);
the tint is a sprite modulate drawn from the animal's seed with its look. `spawn
cow|sheep|chicken|rabbit [count]`; the wild rabbit is now `spawn wild_rabbit`. Debug flag
`--livestock=<species>,...`. Save version 13 keeps species, look, tint and position. Sounds
`cow_moo`, `sheep_baa`, `chicken_cluck` through the ambience (rare, -20 to -22 dBFS, none
asleep). Not done: animals don't avoid each other or the player and may stand on a bedroll.

## 74. Professions: woodworker, cook, mason; a UI for them

- [x] Done

The user's word of 2026-11-06: start with the three professions suggested in
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

Done: `Skills` (points in tenths, the total cap, the fade marks) on the player, the rules in
data/skills.cfg (`SkillRules`: 0-100 a skill, 200 in all, 2 points a craft at the recipe's
level falling to none 40 above it). The cap rule: at 200 a skill only grows by taking points
from a skill marked Fade on the skills tab, nothing fades on its own (SPEC, Professions).
data/stations.cfg (`StationRules`) maps object types to stations: the workbench, the kiln
(outdoors only) and the bake oven are placed objects made by hand; the house hearth and the
camp's fire are the hearth. Recipes got `station`, `skill`, `level` and `hours`; E on a
station opens `CraftingScreen` on its recipes, locked ones greyed with the level they need.
A recipe with `hours` is held by its station as `StationWork` in the object's saved state, so
the kiln fires on the game clock while the player is away (no new save field). The skills tab
is a second tab of the character screen (K). Recipes: planks, stool, clogs, carved chest
(20 slots), joined cupboard (25); roast turnip, pottage, pea soup, bread, berry tart and feast
cake (flour by hand from wheat, as there was none); raw bricks and bricks, which build the
oven. Each skill has a master recipe at level 70, so every skill can reach 100. Art in tools/art/crafts.py
(atlas rows 41-44, no palette change). Save version 14 (skills); console `skill`; flags
`--skills` and `--station`. Not done: a look for a firing kiln, live refresh of the kiln's
time while its menu stays open, more brick uses.

## 75. Flowering meadows; bees only at flowers

- [x] Done

The user's word of 2026-11-06: in spring and summer the grass should have flowers on it, and
bees should only be around flowers. Meadow flowers of the region, in patches and drifts
(not evenly sprinkled), changing through the seasons; bees spawn at flowers, stay near them,
and their sound comes only from there.

Done: twelve species (wood anemone, dandelion, cuckooflower, daisy, buttercup, red campion,
red and white clover, yarrow, knapweed, meadowsweet, heather) in tools/art/flowers.py, a row
of their own in the decoration atlas (`TerrainTileset.FLOWER_ROW`), each as a small plant, a
few and two drift tiles; no new colours. A bloom curve per species in data/vegetation.cfg
`[flowers]`. DecorationView sows them per tile when a chunk is drawn: a drift noise and a mix
noise, the habitat from the layer (woods: grass where `World.is_in_woods`) and the chances and
communities of data/flowers.cfg (`FlowerRules`). A tile shows its species furthest into its
bloom, small while it has only just opened or is fading, else its ordinary decoration; the
old evenly sprinkled flowers and the `flower` kind are gone. Bees: `flowers_per_animal`
(data/wildlife.cfg) replaces `needs_flowers`, one bee per 8 tiles of flowers in bloom in and
around the view, up to the cap, spawned only at those in the spawn ring; the buzz was already
the bees' own (the nearest two). For task 77: a worn tile loses its flowers by getting no
habitat in `DecorationView._sow_flowers` and a redraw. Not done: meadowsweet grows on wet
ground and the floodplain, not beside the ditches as such; no blue flower (cornflower belongs
in the rye).

## 76. Console: what can be spawned

- [x] Done

The user's word of 2026-11-06: commands like `spawn` list what they take. `spawn` with no
argument or an unknown name prints the list, and `help spawn` shows it.

Done: `Console._candidates_text` lists the candidates of the kinds in `LISTED_KINDS` (animals,
weather conditions, snow values), from the same `candidates` that Tab uses, wrapped to 70
characters. `spawn` and `spawn <unknown>` print it; `help <command>` shows the usage and the
list (and Tab completes command names after `help`). `weather` already shows its names in its
usage, `give` has the "did you mean" for items (too many to list; Tab completes them).

## 77. Desire paths

- [x] Done

The user's word of 2026-11-06: ways the player walks very often develop paths with less grass.
Defaults: steps on grass wear the tile (grass, then trodden, then a dirt path); an unused path
grows back over days; the wear is saved; worn tiles lose their flowers and grass tufts; paths
are a look only (no change to speed or farming).

Done: `World.wear_tile` counts steps of wear per tile entered (`GameState.walk` outdoors, and
`Livestock` at `animal_step`, half a step), only on grass and the floodplain and not under a
building; `wear_stage` gives trodden from 8 steps and a path from 24, capped at 32
(`data/paths.cfg`, `PathRules`), and `regrow_paths` takes 2 a night in the night upkeep. Only
worn tiles are kept and saved (`"wear"`, save version 15; 14 is task 74's), and tilling clears
the wear. Two terrain layers, `TRODDEN` and `PATH`, between dry grass and soil (the tile code's
layer field is 4 bits now), drawn over any grass with dithered edges; a stage change emits
`tile_changed`, which redraws the four cells and the decoration around the tile. The layers
have no habitat and no decorations, so a worn tile loses its flowers and tufts. The overlay
stack of the seasons' looks is a loop over `VARIETY_LAYERS` and the frost is drawn in layers
too, so paths keep their edges in every look; snow covers them, with the trodden grass in its
snow look over it as a faint track (`SnowTrackLook`); in the bare look the earth turns
`mud_dark`. No new colours. A new chunk's cells are drawn without erasing, which pays for the
extra overlays. `--path=<x>,<y>` and `--path-days=<walked>,<left>` walk a winding route for
screenshots (`DebugPath`). Not done: mud in rain; a path does not change speed. Screenshot in
docs/screenshots/desire-paths.png.

## 78. Waking in the bed; reset and tp indoors

- [x] Done

The user's word of 2026-11-06: passing out outside put the player behind the bed, stuck.
- The bed is drawn in layers (frame and pillow under the player, blanket over), so the
  player lies in it under the blanket; the bed no longer blocks walking, so nobody gets stuck.
- Waking after passing out (and after sleeping) puts the player in the middle of the bed,
  lying under the blanket, instead of standing beside it.
- A `reset` console command puts the player at their bed.
- `tp` also works indoors: it takes the player outside to the tile, if that tile is valid.

Done: `GameState.go_to_home_bed` (waking, `reset`) and `teleport_to` (`tp`); the player lies
in the middle of the bed (`PlayerState.bed_lying_in`, cleared by the first move; not saved).
`PlayerView` lays the asleep frame of the collapse in the bed (rotated head up, or mirrored
head left for the box bed; the type data `bed` is the head direction). The beds of the houses
are drawn below the entities (`InteriorView`'s `Beds` node) and `<bed>_cover.png`, the blanket
cut from the bed's picture by tools/art/interior.py (`BED_COVERS`), is shown above the player
while they lie there; the straw mat got a wool blanket for it. Outdoors the player lies on the
bedroll (above the objects, `LYING_Z_INDEX`) under `assets/bedroll_cover.png`, the bag cut from
its atlas cell by `camp.bedroll_cover` and shown by `ObjectCover` (the snow looks use the same cover). The beds did not block walking any more
(reverted, see the fix below); the saved game of the report (player standing on the box bed of the longhouse, `[1.5, 2.5]`)
loads and walks. No save change, so no new version. `GameState` got the same
`max-public-methods` exception as `World`. Screenshots in docs/screenshots/waking-in-bed.png.

Fix (2026-11-06, "now I'm walking straight on the bed"): the Kate bed, the shack mat and the
box bed block walking again (the bedroll stays walkable). `PlayerState.move` takes the lying
player out on their first move (`_get_out_of_bed`): onto the free tile beside the bed in the
direction pressed, else the front (opposite the head), else the sides, never behind. A player
standing where they do not fit walks through objects (not walls) until free
(`_can_step_off_blocked_tile`), which covers old saves and saves made in bed.

## 79. Dogs, cats and horses; a bone for the dog

- [x] Done

The user's word of 2026-11-06: dogs, cats and horses join the livestock, spawned with the
console like the others, 2-3 looks per species plus tint, sleeping at night. A bone (an
item, spawned for now) given to a dog makes it follow the player for a while.

Defaults (QUESTIONS.md 19): period breeds, e.g. a farm collie, a spitz and a pointer-like
hunting dog; tabby, black and ginger cats; a heavy marsh horse (Oldenburger type) in bay,
black and grey, and a small pony. Cats roam wider than the others and climb nothing yet. A
dog with a bone follows at 1-2 tiles for 3 game hours (saved), then wanders again; giving
it uses up the bone. Dogs bark now and then, cats are silent but for a rare meow, horses
whinny and snort. Save version bump for the follow time.

Done: `dog`, `cat` and `horse` in data/livestock.cfg with their looks (collie, spitz, pointer;
tabby, black, ginger; bay, black, grey, pony), drawn in tools/art/livestock.py by the cow's
frame builder, which grew running legs, a lift between strides and heads and tails per look.
Every livestock sheet has a `run` row now (cattle, sheep, hens and rabbits reuse their walk),
and an awake animal can pick `RUN` (a fourth `activity_weights`, `run_seconds`; `flee_speed` is
now `run_speed`); only the new three do. The horse is 44x36 px a frame, about 32 px long, with
the top of its torso free for a rider. Sounds `dog_bark`, `cat_meow`,
`horse_whinny` (whinnies and snorts) through the ambience. The `bone` item: `ToolUse.Use.GIVE_BONE`
on a dog within a tile of the target, then `Livestock.start_following` sets the animal's
`follow_until_minute` (GameClock `total_minutes`, saved, save version 16); `Livestock.update`
now takes the clock. A follower waits within 2 tiles, walks or runs after the player to 1 tile,
and is put beside them when more than 15 tiles off or stuck for 2 s; it doesn't sleep. Not
done: the bone has no recipe or source yet; a dog left outside while the player is in a house
waits there (the world stands still).

## 80. Mice and frogs; storks eat frogs

- [x] Done

The user's word of 2026-11-06: critters, mice and frogs, the frogs food for the storks.
Ambient wildlife like the birds and rabbits, not livestock.

Defaults (QUESTIONS.md 19): mice near fields, hay, buildings and hedges, scurrying from the
player, mostly at dusk and night; frogs at the water's edge, wet meadows and ditches from
spring to early autumn, hopping, croaking in chorus on spring and summer evenings, gone in
winter. A hunting stork walks to a frog, strikes and swallows it; the frog is gone. Needs
task 60 (storks).

Done: two kinds in data/wildlife.cfg, art in tools/art/animals.py (no new colours). `mouse`
(`Mouse`) lives on grass and soil within 2 tiles of farmland: tilled soil, a crop, a Knick, a
fieldstone wall or a building (`farm_radius`, a new key of every kind, and
`WildlifeRules.has_farm_near`; hay lies only in the barns, so the building counts for it), all
year, mostly at dusk and at night; it sniffs and scurries and dashes off into cover (gone) at
2.5 tiles. `frog` (`Frog`) lives on grass, floodplain and wetland within 2 tiles of water,
spring and summer and fewer in autumn, none in winter, most at dusk, and stays out in the
rain; it sits puffing its throat, hops, and hops off at 1.5 tiles. A hunting `Stork` that
sees a frog within 3 tiles when it picks what to do next walks up to it, strikes and swallows
it (a new `swallow` row of the stork's sheet), and the frog is done; one that hopped away
during the strike is missed. The lookup is `WildlifeView.nearest_animal(kind, point, reach)`
over the few wild animals, for task 82's cats as well. Sound `frog_chorus_loop` (-22 dBFS,
quiet) through the ambience: `AmbienceRules.chorus_level` by `[frog_chorus]` in
data/ambience.cfg (dusk, less at night, spring and summer, as warm as the croaks need it),
fuller with the frogs about up to 3; the single croaks at water stay. `spawn mouse|frog` and
`--wildlife=mouse,frog` come with the kinds. Not done: autumn counts as a whole (no "early"
autumn), frogs don't dive into the water, mice make no sound. Screenshot in
docs/screenshots/mice-and-frogs.png.

## 81. Riding a horse with a saddle

- [ ] Done

The user's word of 2026-11-06: horses can be ridden once you have a saddle, which for now is
spawned with the console. Needs task 79.

Defaults (QUESTIONS.md 19): use the saddle on a horse to saddle it (it stays on the horse;
taking it off gives it back), use a saddled horse to mount it, the same key to get off
beside it. Riding is about twice walking speed and costs no energy; no tools, no building,
no doors while mounted (get off first). The player is drawn sitting on the horse in all four
directions, walking and trotting. Saved: the saddle on the horse; a save made while riding
loads with the player beside the horse.

## 82. Cats hunt mice

- [ ] Done

The user's word of 2026-11-06. Needs tasks 79 and 80. Defaults: a cat that sees a mouse
within a few tiles crouches, creeps, and pounces; about half the pounces catch it.

## 83. Taking down buildings and placed things

- [x] Done

The user's word of 2026-11-06: a way to deconstruct buildings and items. Placed things can
already be taken down with the axe or the pickaxe; buildings can't be removed at all.

Decided by the user (QUESTIONS.md 21): with the hammer in hand, X switches between building
and taking down, and the HUD shows which mode is on. Taking down highlights the building or
placed thing under the cursor; holding the use button for about a second takes it down. A
building gives back about half its materials (rounded down), dropped in front of its door;
the house's own furniture goes with the house. Not while inside it, and not while anything
the player placed is still inside (chests, stations, stools...): those must be taken out
first, and the message says so. If the player's bed was in it, they wake at the camp's
sleeping bag. A stork on its roof flies off. Crafted placed things (chests, stations,
stools) are not broken down: taken down, they go back into the inventory whole (or drop
when it is full). No salvaging of items into materials.

Done: `World.remove_building` (signal `building_removed`, which `BuildingViews.remove` answers)
and `GameState.take_down_building` / `refund_of_building` / `why_not_take_down`. The furniture
the house came with is told from what the player put in by reloading the house's own map
(same type at the same tile, and nothing in it), so an empty chest of the Kate goes with the
house but a full one, or a stool the player added, keeps it standing. The camp's sleeping bag
is not saved: `CampSite.sleeping_bag_of_seed` finds it again from the generated land, so no
save change. `Builder` has the mode (`is_taking_down`, reset when the hammer is let go or
build mode dismissed) and `take_down_target` / `take_down_gives` / `take_down`; what counts as
a placed thing is `ItemTypes.item_placing`. `BuildMode` marks the target and runs the one
second hold; the sound is the axe's chop (`taken_down`). `--taking-down` for screenshots.
Storks: `WildlifeView.is_standing` already made a stork leave a roof that is gone.

## 84. NPCs: a first villager to spawn and chat with

- [x] Done

The user's word of 2026-11-06 (priority, the first step of docs/ideas/NPC.md): NPC art and
an entity that can be spawned randomised via the console. It walks about a bit but stays
close to buildings, so it never leaves the campfire area. The use of E on it opens a chat:
the player's face on the left, the NPC's on the right, a classic IRC-style chat window in
the middle. A random name on spawn. Esc leaves the chat. The chat keeps its history. For
now the NPC always answers "I understand.", but the answer comes from one function that can
later do more (an LLM, see the ideas doc).

Defaults (QUESTIONS.md 22): `spawn npc [count]`; the look is randomised from layers like the
player's (sex, skin, hair, period clothes in their colours); period North Frisian / Low
German first names and surnames matching the sex. The NPC keeps to within about 6 tiles of
the nearest building or campfire at spawn (its anchor), idles and strolls by day and stands
still at night. NPCs, their looks, names, anchors and chat histories are saved (a save
version bump; history capped at the last 200 lines). The chat pauses the game while open;
lines read `[08:15] <You> hello` with the game time; Enter sends, Esc closes; the history
scrolls. The reply function is async-ready (awaited), so a slow LLM fits later.

Done: `Npc` and `Npcs` in game/state, the numbers, names and clothes in data/npcs.cfg
(`NpcRules`): a seed gives the sex, the name and the look, layers of `Appearance` (which got an
`apron` slot) drawn from the player's kind of sheets, the women's dress and the other colours
from tools/art/villagers.py, no new colours. The anchor is the yard in front of the nearest
building's door or the nearest fireplace within 16 tiles, else the spawn spot; a villager
strolls towards points inside 6 tiles of it, never steps out of that circle (one outside only
steps back in), steps only where its body fits on walkable tiles (the map asked only when the
body moves onto new tiles), stops short of the player, and stands still from 30 minutes after
sunset to sunrise. `NpcView` draws it among the entities with the player's frames. E speaks to
the villager on the targeted tile or the nearest one in reach in front
(`Interaction.npc_to_chat`), before chests, stations and beds; `NpcNameTag` shows that one's
name over their head. `ChatScreen` pauses the game, shows 32x32 portraits at 2x laid together from the
layers' portraits (tools/art/portraits.py) and the IRC-style lines, awaits
`NpcDialogue.reply` (for now "I understand." after half a second) and keeps its lines in the
villager's history. `spawn npc [count]`; debug flags `--npcs=<count>` and
`--chat=<line>;<line>`. Save version 17 keeps name, sex, look, position, anchor and the last
200 chat lines. Not done: villagers don't avoid each other and may share a spot; two can get
the same name.

## 85. A local LLM in a container for testing NPC talk

- [x] Done

The user's word of 2026-11-06: a script that brings up an OpenAI-compatible server in a
container (docker via podman on the user's machine) with a model that fits simple NPC
conversations, for testing. Performance doesn't matter in this test.

Defaults (QUESTIONS.md 23): Ollama in a container (`ollama/ollama`, OpenAI-compatible API on
localhost:11434/v1) with a small instruct model of about 2 GB, e.g. Qwen2.5 3B Instruct
(Apache-2.0), on the CPU (the GPU isn't exposed to containers here). `make llm-up` starts it
and pulls the model (kept in a named volume), `make llm-down` stops it, `make llm-check`
sends one chat request and prints the answer. Works with `docker` or `podman`. Normal tests
never need it.

Done 2026-11-06: `tools/llm/llm.sh` (up, down [--purge], check, status, logs) and the targets
`make llm-up`, `llm-down` (`PURGE=1` deletes the model), `llm-check`. Ollama 0.35.0 pinned,
model `qwen2.5:3b-instruct` (override `LLM_MODEL=`), container `sandbox-game-llm`, volume
`sandbox-game-llm-models`, 127.0.0.1:11434 only; podman if present, else docker. A check
answers in about 5 s on the CPU. Note: the 3B model has the Qwen Research License
(non-commercial), not Apache-2.0 as assumed in QUESTIONS.md 23; fine for testing only.

GPU, the user's word of 2026-11-06: give the container the NVIDIA GPU. `llm.sh up` adds
`--device nvidia.com/gpu=all` (CDI, podman and docker) when a CDI spec for it exists,
`LLM_GPU=auto|1|0` overrides, and a container with the other setting is recreated. The host
needs `nvidia-container-toolkit` and `nvidia-ctk cdi generate` once (root, see
tools/README.md).

## 86. NPC replies from the LLM, with compacted memory per NPC

- [x] Done

The user's word of 2026-11-06. Needs tasks 84 and 85. `NpcDialogue.reply` asks the
configured OpenAI-compatible endpoint (endpoint, model, optional key in Settings; "none"
keeps "I understand.") and falls back to a scripted line on time-outs and errors. Save games
keep, per NPC, the compacted history of former conversations: when a chat closes, the
conversation is summarised (by the LLM, or a plain truncation without one) into a memory
line that is saved and used in later prompts; the raw lines stay capped as in task 84.
Tests use a fake backend; an optional test talks to `make llm-up` when it runs.

The prompt, from the user's working example against the test LLM (2026-11-06): a template
in a data file, shaped like this request, which gave good lines with qwen2.5:3b-instruct:

```
"temperature": 0.7, "max_tokens": 60,
system: "You write dialogue lines for villagers in a game set on the North Frisian coast
  in 1750. Answer with the villager's spoken line only: one or two short sentences of
  plain, casual small talk in the language the neighbour speaks. Never break character,
  never mention being an AI, never offer help or advice like an assistant."
user: "Villager: Antje Boysen, a farmer's wife.\nHer neighbour says: \"Fine weather for
  the hay today.\"\nAntje's reply:"
assistant: "Aye, if it holds till Thursday. My Hinrich's out with the scythe already."
user: "Villager: Antje Boysen, a farmer's wife.\nHer neighbour says: \"Good morning! Is
  the dyke holding after the storm?\"\nAntje's reply:"
```

The template fills the villager line from the villager's data: name, sex (her/his),
age, appearance in words (from their look), trade, personality, background story and
memory, and the moment from the game's real state (the date as the HUD shows it and how far
into the season, the clock time and the phase of the day, the actual weather in words:
condition, temperature, wind, rain or snow, frost; and where they are); earlier turns of
the chat go in as user/assistant pairs in the same shape. The example exchange (the
few-shot turn) is part of the template data.

Villagers are defined in data files: a few hand-written ones (Antje Boysen first, as in the
example, then e.g. a fisherman, the miller, a dyke reeve's widow) with a fixed look,
background and personality, spawned by id: `spawn npc antje`. `spawn npc` without an id
keeps making a random villager, who gets a background composed from data tables (trade,
family, a worry, a habit). The ids are listed in the console's spawn list and completion.

Since (2026-11-06, the user's word): the endpoint defaults to the test LLM
(`http://127.0.0.1:11434/v1`); emptied, it is off.

From the review of task 84: the "awaiting an answer" state must belong to the villager, not
the chat screen (closing A's chat while it answers and opening B's must not show B typing
or block B), and `reply` needs a time-out and an error path that return a fallback line, so
the typing line never sticks.

Added by the user while it was built: the moment in the prompt is concrete, from the game's
state: the date as the HUD shows it and how far into the season, the clock time and the part
of the day, and the weather as it is (condition, °C, wind, frost), wording in the data file.

Done: `data/villagers.cfg` (`VillagerRules`, checked at start) has Antje Boysen, Momme Ketels
(fisherman), Ocke Hansen (miller) and Kerrin Paulsen (the dyke reeve's widow); `spawn npc
<id>` puts one near the player, once, and the ids are in the spawn list and Tab completion;
the debug flag `--villager=<id>` does it for screenshots. Made-up villagers draw an age, trade,
family, personality, worry and habit from new tables in `data/npcs.cfg`. `NpcPrompt` builds the
request from `data/npc_talk.cfg` (`NpcTalkRules`) in the user's shape: system line, the Antje
example, the last 8 lines of this conversation, then the villager line, who they are (look in
words from the layers), their memories, the moment (`NpcMoment`: "the 12th day of Spring,
year 1 (mid spring), 08:15 in the morning", "light rain, 9 °C, a fresh west wind", "outside
the kate"), that the player is a newcomer whose name they don't know (else the model named the
player "Jakob"), and what the player said. `OpenAiChat` (an HTTPRequest that runs while
paused, 30 s time-out) asks the endpoint of Settings → Language model (endpoint, model, key;
the key plain text in settings.cfg); `NpcDialogue` (moved to game/scenes) trims the answer
(quotes, name prefix, first line, two sentences) or says a scripted line. `Npc.is_answering`
holds the wait. On closing a chat `NpcDialogue.remember` sums it up in a dated memory line (by
the model, else the start of what the player said), 10 kept, the oldest two merged. Save
versions 19 (who they are) and 20 (memories), after task 61's 18. Tests use `FakeChat`; two tests ask the real
model when `SANDBOX_LLM_URL` is set. Replies from qwen2.5:3b-instruct: Antje, asked whether
the dyke holds: "Moin, welcome. The dyke's as good as it's ever been."; about butter: "Aye, I
do. Why, do you need some?"; Kerrin in a storm at dusk: "The dyke will hold, the Lord is
watching over us. But we must be ever vigilant." Not done: an adapter for Claude's own API,
streaming, suggestions from the model (docs/ideas/NPC.md 6.3).

## 87. Willows that stand out from the grass

- [ ] Done

The user's word of 2026-11-06, with a screenshot: willows sometimes melt into the grass.
The pollard's crown of thin, pale yellow-green shoots has the same values as the meadow and
lush grass under it, with no dark edge and little shadow, so only the trunk reads. Rework
the willow (tools/art/willow.py) so it reads on every ground and in every season: a darker
underside and outline of the crown, a clearer silhouette of the rods against the ground,
the ground shadow, and a check on lush, dry and flowering grass. No new colours.

## 88. Inventory handling

- [ ] Done

The user's word of 2026-11-06:

- **Bug:** some slots in the inventory can't be selected. Find which (likely hit areas or
  an overlapping control) and fix all of them.
- **Dropping:** items from the inventory can be dropped on the ground (e.g. dragged out of
  the screen, or a drop key on the held stack); they lie as ground items like a felled
  tree's drops and can be picked up again.
- **Swapping:** dropping the held item on a slot that holds another item puts it there and
  the item that was in the slot now sticks to the mouse (same items stack as today).
- **Shift-click:** in the backpack moves the stack to the quick bar, on the quick bar moves
  it into the backpack, as long as there is space (stacking onto the same item first).
- **The quick bar while the inventory is open:** the HUD's quick bar is not greyed out and
  is used directly; the extra copy of the quick bar inside the inventory screen goes.

## 89. Crafting UI: buttons clickable all over

- [ ] Done

The user's word of 2026-11-06: in the crafting UI some buttons can only be clicked on small
areas. Make every button and recipe entry clickable over its whole visible area (likely
child controls eating the mouse or a too-small hit rect); check the other screens (storage,
character, settings) for the same and add a test that clicks at the edges of a button.

## 90. Console: noclip

- [ ] Done

The user's word of 2026-11-06: a console command `noclip` that turns off collision for the
player. A toggle like `nocost`, shown on the cheat HUD: the player walks through trees,
rocks, water, buildings and furniture; indoors they stay inside the room's bounds; off
again, a player standing on a blocked tile can walk off it (the step-off rule of task 78).

## Later (not part of the prototype)

- `WildlifeSprites.frame_index` and `max_frames` allocate on every call (`keys()`,
  `values().max()`); the older animals call them per frame. Cache them per sheet. And rename
  `SoundEvents.animal_alarm`, which since task 60 also gives the stork's clatter, to something
  like `animal_state_sound`.
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
