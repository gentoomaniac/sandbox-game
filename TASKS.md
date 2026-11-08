# Tasks: Prototype

Implements milestone 1 from the [design](design/README.md). Each task is small enough for one
developer brief. Tasks whose dependencies are done can run in parallel. The
coordinator ticks a task off here when it is merged.

SPEC.md became the [design/](design/README.md) tree on 2026-11-08. Old task notes below that say
"SPEC" mean those pages; "SPEC.md" and its section names are history.

Tasks 1 to 51 are finished and live in [docs/tasks-done.md](docs/tasks-done.md). Their
numbers still mean the same: the design and code comments refer to them.

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

- [x] Done

The user's word of 2026-11-06: horses can be ridden once you have a saddle, which for now is
spawned with the console. Needs task 79.

Defaults (QUESTIONS.md 19): use the saddle on a horse to saddle it (it stays on the horse;
taking it off gives it back), use a saddled horse to mount it, the same key to get off
beside it. Riding is about twice walking speed and costs no energy; no tools, no building,
no doors while mounted (get off first). The player is drawn sitting on the horse in all four
directions, walking and trotting. Saved: the saddle on the horse; a save made while riding
loads with the player beside the horse.

Done: the `saddle` item (`give saddle`, one to a slot). The use key with it puts it on the horse
in front (`ToolUse.Use.SADDLE`, `FarmAnimal.is_saddled`, saved, save version 22), with an empty
hand takes it off (`UNSADDLE`; the empty hand's slot always has room, so nothing is refused). A
saddled horse has sheets of its own, `horse_<look>_saddled`. E on a saddled horse in front
(`Interaction.horse_to_mount`, after a villager, before chests and beds) gets on it
(`GameState.mount`, `PlayerState.horse`, `FarmAnimal.is_ridden`), E again gets off
(`dismount`): on free ground within 2 tiles, its side first, never water, a wall or a building;
with no room the player stays on ("No room to get off here."). A ridden horse does nothing of
its own and goes where the player rides; it walks at walking speed and trots at twice it after
0.6 s of riding on (`ride_walk_factor`, `ride_trot_factor`, `trot_after_seconds` in
data/livestock.cfg), for no energy and unslowed by tiredness. The rider's body collides as on
foot and keeps off buildings' tiles, so no door is passed (a horse in a doorway is ridden out);
the use key (`Use.RIDING`), the hammer, a door ahead and (the user, 2026-11-07) the crafting
key say "Get off the horse first."; only the inventory (with the hotbar and dropping) and eating
work, and nothing is picked up while riding. Passing out slides the player off first if there is
room; a teleport and waking in the home bed leave the horse. A save on horseback writes the
player beside the horse (nothing about riding is saved). Art: the player's layers astride
(assets/character/riding/, tools/art/character.py `riding_sheet`) and the ridden horse
behind and in front of the rider in four directions, standing, walking and trotting
(`horse_<look>_ridden[_over]`, tools/art/livestock.py `ridden_sheets`; the pony has its own
views); no new colours. `PlayerView` draws them with the horse's tint and shadow, the rider
rising with the trot; occlusion counts the rider and horse (`Occlusion.RIDER_SIZE`). Debug flag
`--riding=<look>`. Not done: no hoofbeats (no sound for them yet), no saddle recipe, the pony
carries an adult whose feet nearly touch the ground. Screenshot in docs/screenshots/riding.png.

## 82. Cats hunt mice

- [x] Done

The user's word of 2026-11-06. Needs tasks 79 and 80. Defaults: a cat that sees a mouse
within a few tiles crouches, creeps, and pounces; about half the pounces catch it.

Done: a cat's `FarmAnimalView` looks for a mouse when the cat picks what to do next
(`WildlifeView.nearest_animal`, within `sight_tiles`, 3.5) if `Livestock.can_hunt` (a cat, up
and about, not asleep, rested), and starts the hunt: three new activities of `FarmAnimal`,
`CROUCH` (1.5 s, facing the mouse), `CREEP` (0.3 tiles a second, `track_prey` following the
mouse, given up after 12 s, when blocked or when the mouse is gone: `stop_hunt`) and `POUNCE`
(from 1.2 tiles, a leap at 3.5 tiles a second onto where the mouse was). As the cat pounces the
view draws the catch (`catch_chance` 0.5, `wildlife.rng`): a miss sends the mouse dashing off
into cover away from the cat (`Mouse.flee_from`), a catch takes it if it is within
`catch_tiles` of where the cat lands. Then the cat rests 60 s (`hunt_rest_seconds`). The numbers
are a new `[hunting]` section of data/livestock.cfg. The hunt is not saved (nor are the
mice), so a game saved mid-hunt loads with the cat looking about; no save version bump. Mice
take no notice of a creeping cat. Art: `crouch`, `creep` and `pounce` rows of every cat sheet
(tools/art/livestock.py, low torso, flat tail, a leap and a landing with the head down); no new
colours. Debug flag `--hunt` (a cat of each look with a mouse ahead). Not done: cats don't
carry or eat what they catch, and hunt nothing but mice; the cats' sleeping hours are those of
task 79, so they hunt at dusk and before dawn rather than through the night. Screenshot in
docs/screenshots/cats-hunting.png.

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

Since (2026-11-06, the user's word): the model lost the thread, as only the lines since the
last memory went in (at most 8), and every closed chat became a memory. Now the last 24
lines of the chat go in, also those already remembered.

## 87. Willows that stand out from the grass

Dropped as a task (the user, 2026-11-07): kept as a point for the next graphics review, see
Later.

## 88. Inventory handling

- [x] Done

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

Done: **The bug:** the fade screen's invisible text box (layer 2, centred, 320x32, default mouse
filter) caught every click on the strip in the middle of the window, which lay over the
bottom rows of the backpack; it now ignores the mouse. tests/test_inventory_clicks.gd clicks
every slot at its centre and corners with the fade screen and the hotbar in the tree.
**Quick bar:** `HotbarHud` is on layer 2 (above the screens' backdrop, under the fade), its
slots are clickable (`SlotView.is_clickable`) only while the character page or the chest screen
is open, and both screens take the hotbar in their constructor, listen to its slot views and
draw no row of their own (the tooltip ids of those slots are `hotbar_<n>`, no longer
`inventory_<n>`). **Swap:** `ItemSlots.move_to` says whether it swapped; the screens then keep
the picked slot (now holding the displaced item) as the pick; on the character screen also onto
and off the equipment slots. **Shift-click:** `Inventory.move_to_other_part` (character
screen); the chest screen already sent stacks to the other side. **Dropping:** a left click
outside the panel (and the hotbar) with a backpack or hotbar stack picked emits `drop_requested`
(chest screen too, for inventory picks; an equipment or chest pick is just let go), and the new
action `drop_item` (default T; Q and G were taken or clashed with test bindings) drops the held
stack: `GameState.drop_from_inventory` lays it in front of the player with `World.drop_items`;
such piles (`GroundItem.is_dropped_by_player`) are pulled in again only after the player has
left their reach (not saved: a game saved right after a drop collects the pile on load).
Nothing is dropped inside a house. The hotbar is on layer 2 only while a screen that uses it
is open (else layer 1 with the other HUDs), and only that screen listens to its clicks; the
dragged icon has a layer of its own (3), above the hotbar.

## 89. Crafting UI: buttons clickable all over

- [x] Done

The user's word of 2026-11-06: in the crafting UI some buttons can only be clicked on small
areas. Make every button and recipe entry clickable over its whole visible area (likely
child controls eating the mouse or a too-small hit rect); check the other screens (storage,
character, settings) for the same and add a test that clicks at the edges of a button.

Done: no code fix was needed; the cause was the one task 88 fixed in commit 296d0c7: the fade
screen's invisible text box (layer 2, centred) kept the default mouse filter and ate the
clicks on a strip in the middle of the window, which cut across recipe rows. Without that fix
the new test fails on the crafting rows at those places. Every recipe row (by hand and at a
station), storage and character slot, tab button and pause menu page button and slider
answers the mouse at its centre and just inside each corner (what is scrolled out of a list
is left out), with the game's other HUD layers in the viewport; the HUDs that need a game
state (build panel, vitals, cheats) are checked to have no control that stops the mouse.
Tests: tests/test_click_areas.gd, helpers in tests/click_case.gd.

## 90. Console: noclip

- [x] Done

The user's word of 2026-11-06: a console command `noclip` that turns off collision for the
player. A toggle like `nocost`, shown on the cheat HUD: the player walks through trees,
rocks, water, buildings and furniture; indoors they stay inside the room's bounds; off
again, a player standing on a blocked tile can walk off it (the step-off rule of task 78).

Done: `CheatFlags.is_noclip` (HUD "No clip"), `PlayerState.move(..., is_noclip)` checks only
that the body's tiles exist (`is_on_map`): the room's tiles indoors, loaded chunks outdoors;
a room's wall tiles are on the map, so noclip reaches the wall but not beyond. The step-off
rule of task 78 refuses steps into water, so a player left in a lake would be stuck: turning
noclip off where the player doesn't fit puts them on the nearest tile they fit on, within 12
tiles, never on a building's tiles (its door would take them inside; one lying in a bed stays
in it): `GameState.put_player_on_free_ground`; the console says so when nothing is free. A
noclip walk wears no desire path. Tests: tests/test_noclip.gd.

## 91. NPC chat history: a set length, the rest compacted, a clear for debugging

- [x] Done

The user's word of 2026-11-06, after finding that villagers lost the thread (fixed for now
by telling the last 24 lines, commit 4e7826c):

- **A setting for the chat history length** (Settings → Language model, e.g. "Lines a
  villager keeps", default 24): each villager keeps that many of the latest chat lines in
  the save, and all of them are sent to the model as earlier turns.
- **The older rest is compacted:** lines that fall out of the kept history are summed up
  into the villager's memory (by the model, or plainly without one), saved, and sent too.
  This replaces making a memory every time a chat closes: a memory is made when lines drop
  out, so a reopened chat goes on where it left off. The memory cap and merging of task 86
  stay. Lowering the setting compacts the lines it drops.
- **Clearing, for debugging:** typing `/clear` in the chat (IRC style) forgets the chat
  history and the memories of that villager (with a line saying so); the README and the
  input's placeholder mention it.

Save: the kept lines and memories are already saved; a save version step only if the format
changes. Tests with FakeChat; the README's "What the model is told" updated.

Done: `GameSettings.chat_history_lines` (2 to 200, default 24, not per provider, in
`[language_model]` of settings.cfg only when changed; the `history_lines` of npc_talk.cfg and
the 200-line cap are gone, so the setting is the one source). `NpcDialogue.compact` keeps a
villager's chat at that length and makes a memory of the lines that drop out, once per
exchange (the model's summary, else `plain_memory`); a loaded game and a lowered setting
compact every villager (`compact_all`). Dropped lines wait in `Npc.uncompacted_lines`, which is
saved, until their memory is made: a save made while a summary is asked for loses none, and
the next load summarises them. One summary at a time per villager (`is_compacting`), lines
that drop meanwhile are summed up next; a summary in flight when the chat is cleared is
dropped. Closing a chat no longer makes a memory; `lines_since_memory` became
`remembered_lines` (save version 21, tests/test_save_npcs.gd): the oldest kept lines a version
20 memory already holds, dropped without a second summary. The setting is applied when the
menu closes, not at each step of its slider. `/clear` in the chat input forgets the chat, memories and lines
waiting (a line says so, not sent, not kept); other text with a slash is said as it is. Tests:
tests/test_npc_memory.gd and the settings, save and prompt tests.

## 92. A font with umlauts and Scandinavian letters

- [x] Done

The user's word of 2026-11-06, with screenshots of the chat: å, ä, ö, ü, æ, ø (and the like)
show as boxes with hex codes, as the villagers answer in German and Danish too. Give the
game's pixel font the Latin-1 Supplement at least (À-ÿ, with ß), and the Latin Extended-A
letters the region's languages use, drawn in the font's style (generated, like the rest of
the art, or a pixel font with a licence that allows it); check the chat, the HUD, the
console and the menus, and add a test that every character of those ranges has a glyph.

Done: tools/art/ui.py builds the Latin-1 letters (À-ÿ), the Latin Extended-A letters of the
region and the typographic punctuation from the base letters plus two-row marks (hand-drawn:
ß æ Æ œ Œ ð þ Þ ı Ø and the stroked ø đ Ð ł Ł), and € £ © § µ ² ³ • ‹ › ‚. The line is now
12 px (was 10): two rows above the capitals are for the marks, as a label clipped them on its
first line. test_font_coverage.gd checks the glyphs; the README shows a chat with German and
Danish lines. Still missing: ½ ¼ ¾, ď ť ľ ĥ ķ ģ, Cyrillic and Greek, emoji; the en and em
dash are as wide as the hyphen (a glyph is at most 6 px wide).

## 93. Claude as a language model choice in Settings

- [x] Done: `ModelChat` (the POST, no redirects, the once-per-endpoint warning, the model list)
  with `OpenAiChat` and `ClaudeChat` on it; the provider is a row of `GameSettings.LANGUAGE_MODEL_PROVIDERS`
  (`openai` default, `claude`, with the protocol it speaks), each provider keeps its own
  endpoint, model and key (a section each in settings.cfg), and NpcDialogue and the page pick
  the chat by protocol, so a preset is one more row; Claude's numbers
  and the models that take fallbacks are in `[claude]` of data/npc_talk.cfg; the drop-down
  asks `<endpoint>/models` (not for a provider that needs a key, without one), debounced on
  typing, and warns once per failure. The tests use a
  small TCP server (`CannedHttpTest`); a real Claude is asked only with `ANTHROPIC_API_KEY`
  set, and was not here, so the requests follow Anthropic's API reference unverified against
  the live API.

The user's word of 2026-11-06: hook Claude up to the villagers' talk, as an option to pick
in Settings, not the default (the local test LLM stays the default).

- **Settings → Language model gets a provider choice:** "OpenAI-compatible" (the default:
  the test LLM, Ollama, LM Studio, hosted OpenAI-style APIs) or "Claude". Picking Claude
  fills the endpoint `https://api.anthropic.com/v1` and a Claude model (default
  `claude-opus-5-5`; `claude-haiku-5-5` named as the much cheaper choice), each still
  editable; the key field takes the Anthropic API key (plain text in settings.cfg, as the
  page says).
- **A Claude adapter** beside OpenAiChat, behind the same interface: POST
  `<endpoint>/messages` with `x-api-key` and `anthropic-version: 2026-10-21` headers; the
  template's system line as the top-level `system`, the example exchange and the chat as
  user/assistant turns; no `temperature` (current models refuse it); `max_tokens` about
  1000 (thinking counts against it; the reply is trimmed to two sentences anyway) and a low
  effort (`output_config: {effort: "low"}`); the reply from the `text` blocks of `content`;
  `stop_reason` `refusal` or any error gives a scripted line; server-side fallbacks
  (`anthropic-beta: server-side-fallback-2026-07-01`, `fallbacks: "default"`) on models
  that take them. No redirects, the key never logged, time-out as now.
- **The model is picked from a list** (the user, 2026-11-06), for both providers: the page
  asks the endpoint which models it has (`GET <endpoint>/models`: the test LLM lists what
  `make llm-pull` fetched; Claude's `GET /v1/models` with the key lists the Claude models)
  and shows them in a drop-down, refreshed when the endpoint or key changes and by a button.
  When the endpoint can't be asked (down, no key yet), the drop-down shows the saved model
  and a note, and the name can still be typed.
- Tests with canned HTTP responses like test_open_ai_chat.gd (success, refusal, error, the
  headers and body shape, both model lists); an optional real test only with an env var set. README: how to
  pick Claude, what it costs per line roughly, that the chat goes to Anthropic.

## 94. Refine the villagers' prompts for the local model; the default test model

- [x] Done

The user's word of 2026-11-07: have a worker refine the queries for the local model, also try
them on 3B; if 3B gives about the same quality, keep it as the default (they had agreed to
make qwen2.5:7b-instruct the default otherwise).

Done: `make llm-eval LLM_MODEL=<tag>` (tools/llm/dump_requests.gd has Godot write the requests
of 13 fixed scenarios with NpcPrompt itself; tools/llm/eval_prompts.py sends each `LLM_RUNS`
times and writes build/llm-eval/<model>.md with every reply and crude checks; `--compare`
puts two models side by side). Baseline of the old words, 5 replies per scenario, replies
without a failed check: 3B 52/65, 7B 55/65 (7 wrong language each). The new words
(data/npc_talk.cfg only, no change of shape): the example exchange is told of a blacksmith
who is not a villager, so the models stop copying Antje's answer and habits into other
villagers' mouths; the system line asks to answer what was said, says an English line gets an
English answer whatever the villager's home, to use the background only where it fits, to be
puzzled by phones and cars, to answer rudeness sharply; a memory is one sentence of at most
25 words in the first person. Result: 3B 57/65, 7B 60/65, wrong language 3 each, memories in
the first person 5/5 for both. Tried and dropped: a second example in German, a longer
language line, "never repeat their words". Decision: **7B is the default** (3B was faster,
1.1 s against 2.2 s a reply, but drifts into nonsense and loses the thread more often; the 7B
is Apache-2.0, the 3B has the Qwen Research License). Following the player's language is
still only about 3 of 5 in German after English for both; naming the language to the model
(the game detecting it) is an idea for later.

## 95. Villagers answer in the language the player speaks to them

- [x] Done

The user's word of 2026-11-07: if it can, the game should detect the language; villagers
respond in the language the player speaks to them. Task 94 left following a switch of language
at about 3 of 5 (German after English), with the prompt only asking for "the language the
neighbour just spoke in". The game detects the language of the player's line (English, German
or Danish, from word lists and letters in data/npc_talk.cfg) and names it in the prompt
("Hark answers in German."); a line too short to tell keeps the language of the player's last
line that could be told, and with none the prompt keeps today's words. Measured with
`make llm-eval` on the 7B and the 3B.

Done: `NpcLanguage` (game/state/npc_language.gd) scores the lowercased words of a line against the
short word lists of `[language]` in data/npc_talk.cfg (one point per word, two per telling letter: ä
ö ü ß German, æ ø Danish) and names the language if it has at least 2 points and more than any
other. Too short or tied ("Hi", "Moin", "Hej", a name): the player's latest earlier line in the chat
that can be told, else nothing, and the prompt keeps its old words (`language_unknown`,
`last_reply_unknown`). The last turn now says "Antje answers in German." and ends with "Antje's
reply in German:" (`trimmed_reply` strips whichever label was used); nothing is saved, it is derived
from the chat. A language that is none of the three (the user's Swedish case, "Tjena! Hur går det
idag för dig?", which Gemini answered with "I don't understand this foreign language") has a list of
its own (`other`) so that it is not taken for Danish, and is then not named; "å" tells no language
for the same reason, and the Danish words Swedish shares (det, går, dig...) are in both lists so
they favour neither. Eval: five new scenarios (German after a longer English chat, Danish after
English, "Moin" after German, "Hej" after Danish, Swedish), the language check counts telling
letters and has `LLM_API_KEY`/`--endpoint`/`--requests`. Replies in the right language, 5 per
scenario: with the old words (17 scenarios) 7B 72/85 and 3B 72/85; with the new ones (the same plus
Swedish, 18 scenarios) 7B 90/90 and 3B 86/90. The 7B had 0/5 on Moin and Hej and 3/5 on German after
a longer English chat before; the four 3B misses are it only echoing "Hej!"; Swedish: both answer in
Swedish, but the check can only tell they do not answer in English. Tried and dropped: carrying the
language in the earlier turns (not needed after this), a second wording (the first was already at 0
wrong language on the 7B). Not measured on Gemini: the sandbox refused to read the user's key.

## 96. Villagers with more background, family and friends, and a village they share

- [x] Done

The user's word of 2026-11-07: with Gemini the talk works well, but replies are not consistent
enough; villagers need way more background and instructions. A worker writes it for now
(the user may edit it later); relationships and family members must exist and be spawnable.
Plan: a longer sheet per hand-written villager (how they speak with sample lines in their
voice, the people they know by name and what they think of them, likes, wants, their day,
what they don't know or won't talk about); one village sheet every villager shares (the
village and its places, who lives where, landlord, pastor, Deichgraf, prices, this year's
news) so villagers don't contradict each other; family and friends named there are villagers
of data/villagers.cfg that can be spawned; firmer instructions (keep to what was said
earlier, never make up family or names, stay in one's own voice; perhaps a lower
temperature); made-up villagers get their sheet drawn once and kept. Hosted models (Gemini,
Claude) get the full sheets, local models a cut-down version. Seen by the user with Gemini:
"Aye." in the middle of a German talk (the English habit leaks into other languages).

Done: `data/village.cfg` (`VillageSheet`) is Wehlsbüll, a made-up marsh parish two hours north
of Husum in 1750: the village, places, who is who (Pastor Johann Martens, the Deichgraf Peter
Momsen, the Deichvogt Brar Feddersen, the Krug's Tete Jacobsen, the sexton Claus Thomsen, the
Amtmann at Husum, and the families), money and prices, this year's news (the cattle plague, the
dyke broken last autumn, the land militia), the church year and what people know of the world (the
Danish king holds all Schleswig since 1721, who speaks what), each topic with a full and a short
text. `data/villagers.cfg` gives each villager a sheet: home, speech as a manner (no English
words: "Says Aye" is gone), sample lines, people (family and friends by id, with kind and what
they think), likes, wants, day, habits, avoids, secrets. Four new villagers make the families
whole and can be spawned: `hinrich` and `boy` Boysen, `inken` Ketels (Boy's sweetheart), `gesche`
Hansen (Antje's friend, Kerrin's niece). `VillagerRules` checks that each one named is a villager
who names them back with a matching kind and sex, a parent is 15 or more years older, and a
married couple shares a home (tests/test_villagers.gd). Fixed on the way: Kerrin was 30 in 1717,
not a girl; Ocke's grudge is the king's Amt, not the duke's toll. Made-up villagers draw the whole
sheet once from the tables of `data/npcs.cfg` (trades with their day, speeches with sample lines,
homes on the edges of the parish, likes, wants, habits, avoids, secrets), have no people, no
surname of the village sheet, and a spouse with their own surname; save version 23 keeps the
sheet (a version 22 made-up villager is made up anew by their name, with another surname if theirs
is now one of the village's families). The system line has firmer rules (keep to the sheets and to what was said;
never make up relatives, names or places, say one doesn't know; one's own manner, the samples show
the manner, not the language) and then the sheets: in full for a provider with `needs_key` (Gemini,
Claude; `NpcDialogue.has_full_sheets`), cut down for a local model (the villager's essentials,
people by name and kind, speech, one sample line; the village line and who is who). Temperature
0.5 (was 0.7). The eval has 7 new scenarios (family, also in German; the husband's name again; another
villager; the pastor; the Deichgraf in German; a sister or brother they don't have, also in German),
a check for expected names and for made-up ones, prompt tokens, and `--full-sheets`.

Measured with `make llm-eval`, 5 replies each of 25 scenarios, replies without a failed check:
before, 7B 110/125 and 3B 87/125 at 515 prompt tokens (the 7B named no pastor or Deichgraf right
in 10 of 10, made up names 7 times, e.g. "Herr Müller"; "Aye" in 23 replies, three children
named Boy, Anna and Heinrich). After (cut-down, 0.5): 7B 123/125 and 3B 96/125 at 850 tokens
(1.65x; 7B 3.5 s against 3.1 s a reply), "Aye" in 6 English replies and none of the others,
"Pastor Johann Martens" and "Peter Momsen" named every
time on the 7B, no sister made up. At 0.7: 7B 118, 3B 95. The cut-down before trimming (1150
tokens) gave the 3B 110 and the 7B 121. The full sheets on the 7B: 50/50 (2 each) at 2375 tokens,
but 12.9 s a reply on the CPU. The 3B still often says it doesn't know the pastor or that Momme
has no children. Not measured on Gemini: no key here; the command is in tools/README.md
(`--full-sheets --endpoint ... --model gemini-3.1-flash-lite`). The cfg wins for a hand-written
villager (the coordinator's decision after review, as the user will edit the sheets): a loaded
game takes their sheet from data/villagers.cfg as it is now; the saved sheet only stands in when
their id has left the file.

## 97. Chat screen laid out like a messenger

- [x] Done

The user's word of 2026-11-07: the chat is hard to read with all the text and the font. Make
it look a bit like WhatsApp: the player's lines on one side and the villager's on the other,
as bubbles with more space between them, so the conversation is easy to follow (the user
showed a WhatsApp screenshot: bubbles in two colours, right for one's own lines, the time
small in the bubble's corner, the name above the other's lines).

- [x] Done: the chat is bubbles in a ScrollContainer: the villager's on the left (portrait left too, the player's right) in stone_dark with their name in gold above the first bubble of a run, the player's on the right in water_deep, the time small in each bubble's corner, at most 70% of the window wide, 2 px between lines of one speaker and 6 px at a change, "..." as the villager's bubble while they answer, a grey centred notice for `/clear`; it scrolls to the newest line (the scrollbar's `changed`). `line_text` is gone, unused. New debug flag `--chat-script` (canned lines, no model; a last `...` leaves the villager typing). The bubbles are StyleBoxFlat with a 3 px radius and no antialiasing, no art or palette change.

## 98. A flaky goose test

- [x] Done

Seen on 2026-11-07 while task 96 was verified: tests/test_geese.gd failed twice in a row on
one commit (a flock of 5 where 6 to 12 are expected) and passed on the third run. The wildlife
view calls `rng.randomize()`, so the test is not deterministic, and `_place_geese` can place
fewer geese than the flock size. Seed the test (or let it pass a seed) and make sure a flock
is always placed in full, or that the test asks for what the game promises.

Done: a flock got 4 tries per goose to find a dry spot not crowded by another, and 5 of 300
seeds came out under 6 geese. Now it gets 20 tries per goose (`GooseFlock.PLACING_TRIES`), and
none of 300 seeds came out short (a one-off measurement, not a test). On a narrow shore a flock
still makes do with fewer geese, as there is no room for more; SPEC says so. The wildlife tests
(tests/wildlife_case.gd) seed the view's dice, so they throw the same numbers every run.

## 99. Sea birds of the coast

- [x] Done

The user's word of 2026-11-08: sea birds that are active on the coastline, some pecking in the
Watt, some going into the water to catch fish; think about the birds that naturally occur in
the region (the North Frisian Wadden Sea in 1750). Candidates: oystercatchers, redshanks,
curlews and dunlin probing the mud flats; shelducks dabbling; herring and black-headed gulls;
terns plunge-diving for fish; cormorants diving and drying their wings. Ambient wildlife like
task 60's geese: on Terrain.MUD, SEA and SALT_MARSH and their edges, by season and time of
day, spawnable from the console.

Done: four species the visitor of the Wadden Sea surely sees, each with its own behaviour, in
data/wildlife.cfg: `oystercatcher` (groups of 2 to 5 on the mud and the salt marsh, all year, a
few at night; probe, look up at 6 tiles, fly off low at 4), `dunlin` (flocks of 12 to 24 only on
the mud, spring and autumn, fewer in winter; probe fast, take off at 3.5 tiles and swing round
in a wheel), `gull` (herring gulls on the mud, the salt marsh and the sea all year; walk, peck,
call, swim, fly off gliding at 3 tiles) and `tern` (common terns over the sea and the tideways
from late spring to the end of summer; fly along, hover, plunge in with a splash, now and then
a fish; after 2 to 4 dives they leave; no notice of the player). The waders are `GroundFlock`s
(the former `GooseFlock`, now with its numbers per kind in `FLOCKS`: a bunch instead of a V, the
wheel), the others `Gull` and `Tern`. The tide counts for the animals: above `flooded_tide`
(0.6) the mud is water (`WildlifeView.is_water`, `can_stand`), so waders on it fly off and
dunlin find none, gulls swim there and terns may dive. Made by hand (`spawn`, `--wildlife`)
the sea birds appear only where they live, so near the coast; no extra debug flag was needed
(`make screenshot AT=-298,-60 TIME=11:00 ARGS="--day=21 --wildlife=oystercatcher,dunlin"`).
Sheets from tools/art/sea_birds.py, no new colours. Not done: their calls (the oystercatcher's
piping, the gulls' laughing); cormorants, curlews, shelducks; waders roosting on the salt marsh
at high water as a flock of their own; a flock partly on the salt marsh only takes off when
the tide reaches its middle.

## 100. One shared outline helper for the art, and a contrast sheet

- [x] Done

From the visual review of 2026-11-08 (Fable; the user started it): the art generators have
eight outline helpers of their own (items.outlined has the only "darkest of the pixel's ramp"
table; animals, character, trees.shaded_blob, trunks, interior, buildings, chest and four in
boundaries). Move items' helper and its table to one place (e.g. `canvas.outline(picture,
colour=None, keep_bottom=False)` and `palette.DARKEST_OF`) and use it where the others do the
same; no change to how anything looks. Add a tool under tools/ that draws the vegetation atlas
rows over the ground colours of every look (season, frost, snow), so contrast can be checked.

Done: `canvas.outline` (outside ring; colour or a function of the surrounded pixel; `ignoring`
for the ground shadow) and `canvas.outline_edge` (recolours the border; `keep_bottom`), and
`palette.DARKEST_OF` / `palette.darkest_of`. `items.outlined` (now a thin wrapper), animals and
livestock, trees' `outline_in_bark`, trunks, interior and crafts, buildings and the chest use
them; every generated asset is byte-identical. Left alone: `character.outlined` (skips pixels
the body already outlines), `trees.shaded_blob` (outlines circles while shading them) and the
callbacks in boundaries.py (their own screen map, not a picture). `make contrast-sheet` writes
build/contrast_sheet.png (tools/README.md).

## 101. Tall grass, fern and reeds stand out from the ground

- [x] Done

The user's word of 2026-11-08: like the willows, some grass and reeds (and the bushes by a
stream) have too little contrast against the ground; a slight outline would help. The review
found tall grass, fern and reeds drawn in the two lightest shades of their ramp, 40-60 % empty,
with no dark edge and a 1-2 px foot shadow: they vanish on olive and autumn ground. Fix, within
the SPEC rule (no ink on vegetation, ramp-darkest outlines only, none on terrain): a ground
shadow under each clump (`trees.ground_shadow()`), the bottom third of a clump in its two
darkest shades with light shades on top, and the task-100 outline only round dense cores,
never single blade tips; check every season, dusk, night and snow with the contrast sheet.
The willow (TASKS Later, graphics review) is a task of its own.

Done: tall grass, fern and reeds each have `trees.ground_shadow`, a dense foot
(`trees.dense_foot`) in their two darkest shades rimmed with green_deep (no ink, no rim round
blade tips) and the lower third of the blades dark, light shades above. seasons.py keeps the
foot dark in autumn, bare, frost and snow (`_DARK_FOOT` for tall grass; `green_deep` is umber
for the golden reeds and the dry and frosted fern). No new colours. Checked on the contrast
sheet in every look and at night, and in screenshots of a stream with tall grass and reeds in
summer and autumn (docs/screenshots/outlines.png is before and after). Open: at night and on
autumn_light ground the light blades still sit close to the ground in value; the willow is its
own task.

## 102. A church with a wooden bell frame and a churchyard

- [x] Done

The user's word of 2026-11-08: the village needs a small church (review/art-review-2026-11-08,
task 9 and buildings row 5). A small marsh-village church of North Frisia in 1750 for the
parish of Wehlsbüll (data/village.cfg): a nave of brick (or tuff), a steep tiled roof, small
arched windows, a south porch; beside it a free-standing wooden bell frame (Glockenstapel) on
a brick base; the churchyard with a fieldstone wall and grave crosses, on the highest Warft.
Buildable or placed, no interior yet.

Done: two buildings the hammer builds (data/buildings.cfg), drawn in tools/art/church.py with
no new colours. The church, 6x4 (70 logs, 35 stone, 45 clay): tuff ashlar nave and lower
chancel, red pantile roofs that keep their light and shade under snow, three leaded arched
windows that light at night, a lime-washed south porch with the door; the interior system
was cheap, so it has a nave inside (maps/interiors/church.tmx: twelve pews, a table as the
altar). The bell frame, 2x2 (25 logs, 5 stone, 10 clay): oak on a brick base under oak
shingles, the bell in it; a building with an empty `interior_map`, so nobody goes in and none
of its tiles can be walked on (`Building.has_inside`). The churchyard: the existing
fieldstone wall, and grave markers made at the workbench (woodworking 15) and placed
outdoors, standing as an oak cross, a headstone or a fieldstone slab by their tile. The world
generator places none: the world has no village and its Warften are empty, so placing the
church there waits for a village; `--churchyard=<x>,<y>` puts the yard in view for
screenshots. Screenshot docs/screenshots/church.png.

## 103. A fisherman's hut, a jetty, nets and a boat

- [x] Done

The user's word of 2026-11-08 (review/art-review-2026-11-08, task 10 and buildings rows 6 and
12): the Ketels' home at the landing by the sluice: a small turf-and-thatch hut of tarred
boards, a net-drying frame and eel traps by the door, a plank jetty on posts at the water and a
flat rowing boat beside it.

Done: the fisherman's hut is a building (4x2, after the shack in data/buildings.cfg: tarred
boards under a reed thatch with a turf ridge, one small window; 25 logs, 5 stone, 15 reeds; a
7x6 room like the shack's). The landing is world objects placed with items (tools/art/
landing.py, atlas rows 47-50): a jetty laid a piece per tile that joins its neighbours and is
walked on over water or mud (the new `deck` and `placed_on` keys of WorldObjectTypes; placing
checks every footprint tile now), a rowing boat (2x1, water or mud), a net frame (2x1) and
eel traps. Jetty and boat at the workbench, frame and traps by hand. Snowy and lit looks as
the other buildings and objects. `--landing=x,y` places it for screenshots; docs/screenshots/
fisher-hut.png. Not done: fishing, a usable boat, nets as a crafting material, the net needle
in Inken's hands, mooring the boat on a rope.

## 104. Save upgrades for the last 10 versions only

- [x] Done

The user's word of 2026-11-08: the game is in development and practically only the user plays
it, so keep the code for save compatibility to the last 10 versions at most. With VERSION 23,
saves of versions 13 to 23 load; older ones are rejected the existing way (renamed .bak, a new
game). Drop `_upgrade_from_version_1` to `_12`, the constants and helpers only they use, and
their tests; state the rule in save_file.gd's header (when VERSION goes up, the oldest step
goes) and in SPEC "Saving".

Done: `SaveFile.OLDEST_VERSION := VERSION - 10` (13 today); older saves are rejected with a
message naming the versions read. Removed `_upgrade_from_version_1` to `_12`, their calls in
`read` (the plain chain stays), TOMATOES_TO_FLAX, TUNIC_AND_TROUSERS_TO_PERIOD, the
VERSION_10_* constants, UPGRADE_PILE_SPACING, `_saved_objects` and `_rename_items`
(about 250 lines), and their tests (test_save_upgrade_hotbar and _interiors deleted, the
rest trimmed). Kept for steps 17 and later: `_home_tiles`, `_clear_new_land`,
COAST_TERRAINS and the clearance constants. New tests: version 12 is refused, version 13
loads. The drop is a commit of its own (`Save: drop the upgrades from versions 1 to 12
(oldest read: 13)`), so an older save can be rescued from its parent; the rule is in
save_file.gd's header and SPEC "Saving".

## 105. make test runs the tests in parallel

- [x] Done

The user's word of 2026-11-08, after the code review measured the suite: one Godot process took
about 170 s, and the per-commit verify loop runs it once per commit.

Done: `make test` runs `tools/run_tests.py`, which spreads tests/test_*.gd over `TEST_JOBS`
headless Godot processes (default 8; `TEST_JOBS=1` is one process like before), each with its
own user:// (build/user-data-<i>) and log (build/test-<i>.log), after one shared import. The
files are balanced by their time in the last run (build/test-times, written from GUT's junit
output), by size until a file has a time. Every check holds per shard (a script that failed to
load, no tests run, "leaked at exit", Godot's exit status) and the exit status is non-zero if any
shard fails. build/test.log is the shard logs joined, ending with a summary block that keeps
GUT's labels (Passing Tests, Failing Tests), `[Failed] <file>: <test>` lines and the warning and
orphan counts. Wall time of a full run (22 cores, 1656 tests): TEST_JOBS=1 169 s, 4 52 s, 8 36 s,
12 29 s; 8 is the default as the gain flattens and several worker loops share the machine. Order
dependence: runs with 3, 4, 5, 8, 12 and 16 shards, with time-balanced and size-balanced
assignments, all green. The one failure found, `test_language_model_page` under load, was not
order but time: `CannedHttpTest` waited for the client by frame count, and a headless frame takes
microseconds, so it gave up before the client connected; it now waits 5 s of clock time.

## 106. The engine at 32×32 art pixels per tile, the 16 px art doubled for now

- [x] Done

The user's decision of 2026-11-08, after review/resolution-mockup-2026-11-08: switch to 32×32
art pixels per tile, with a native 640×360 view (20×11 tiles) at the widest zoom; "still retro
enough, but things are actually visible". This first step changes the engine and leaves the
look as it is: one tile size everywhere (TerrainTileset.TILE_SIZE and every pixel number that
follows from it, the viewport and zoom range in ViewMath, frame and cell sizes, window light
positions in data/buildings.cfg, ground item and shadow sizes, tests that pin sizes), and
every generated picture doubled pixel for pixel at the end of the art pipeline, so the game
plays and looks as today at zoom 1 while the art is redrawn group by group (tasks 107 to 116),
each group dropping its doubling. UI icons and slots stay as they are until task 115.

Done: `TerrainTileset.TILE_SIZE` is 32 and every pixel number of the game follows from it, or
from `TerrainTileset.ART_16_SCALE` (2) where it is measured on a 16 px picture: frame sizes
(`WildlifeSprites`), seats and poses (`PlayerView`), the object cell (3×5 tiles), the hops,
flights and speeds of the wild animals, contact and flight shadows (drawn on the 16 px grid,
scaled), hit particles, sweat, the thought bubble, the "z"s, ground items, the name tag, the
build and take-down frames. The shaders of the art (sway, lily pads, water, mud, fire, rain
splashes, rain and snow, fog) work on the art's pixels through a uniform `art_scale`
(art_scale.gdshaderinc). `ViewMath`: zoom 1 is the widest view, a native 640×360 (20×11 tiles,
×3 at 1080p and ×4 at 1440p; tested), where the game starts; zoom 2 is the closest (320×180);
`make screenshot ZOOM=` takes 1 to 2. tools/art/generate.py scales the files of `DOUBLED` from
`canvas.TILE` (16) to `canvas.GAME_TILE` (32) pixel for pixel as its last step; each of tasks
107 to 116 takes its group out (docs/art-style.md, "Resolution", says how). Not doubled: item
icons, UI slots and frames, the chat portraits (task 115). The doubled pictures' own pixels in
data are doubled too (`sprite_height`, `window_lights`); the sound reach is in tiles. Positions,
speeds and reach were in tiles already: no saved value is in pixels, the save format is the same.
Screenshots at both zooms (summer, snow, rain, fog, night, the church and its lit windows,
inside, livestock, wildlife, riding, passing out, sweat, the highlight, the build ghost, a felled
tree, a chat, villagers, the console, the inventory) match the ones before pixel for pixel but
for animation and random placement. The README's camp and zoom pictures are retaken.

## 107. 32 px art: ground (terrain, paths, soil, water, mud, the dual-grid looks)

- [x] Done

Done: every terrain layer, its edge tiles and decorations, the wet look of tilled soil and the
clay hint are drawn at 32 px (tools/art/terrain.py, the wet soil moved there from
crop_icons.py) in the style of the mockup and left `DOUBLED`. From the art review: the ground
is calm behind small figures (a base colour with blade roots and small tufts, a dark root
fanning to lit tips, gathered in patches by a tile-periodic noise, few light pixels, no outline
on terrain); tilled soil reads as earth, not stacked logs (one broken row of light on the crest,
ragged bands, square field edges dark under the turf); autumn keeps the marsh's grass green with
olive tips, straw only on the dry grass of the Geest (`seasons.LAYER_REMAPS`), and the salt
marsh reads as marsh (olive turf with red-purple glasswort in autumn, cool green patches in
summer, where it was purple all over and dry olive). The path is
packed earth worn pale in patches with clog prints and pebbles; the mud has wavy ripple marks;
pebbles, lily pads, caps and pools are shaded with forms.py. Every layer keeps its number of
tiles and decorations, so no game data changed. The ground's shaders (water, mud, lily pads,
swaying decorations) get `art_scale` 1 from AmbientMotion, or 2 in the classic art; the tide's
relief is in world pixels; the meadow flowers are still 16 px art, scaled up in their row of
the decoration atlas, with a sway material of their own (`flower_sway`, art_scale 2). The
classic art (task 117) has the old ground: terrain.py, the ground part of seasons.py
(`ground_looks.py`) and the wet soil and clay hint (`ground_overlays.py`) of commit acf236e,
byte for byte the files before; the terrain tileset is the first tileset to follow the art set
(`TerrainTileset.show_art_set` swaps its atlases' pictures, as both sets have the same tiles, a
test checks it; no extra tileset is built, so the tests are no slower), and so does the wet
soil. WorldView now shows the chosen set when given a world, as it is made before Main reads
the setting (`--classic-art` at start). Checked in screenshots at zoom 1 and 2: grass, lush and
dry grass, floodplain and river banks, wetland, a desire path, a field tilled, wet in rain and
with crops, the coast (salt marsh, a Warft with its Fething, the tidal mud at low and high
water), spring, summer, autumn (Geest and marsh), bare winter, frost, snow, the dusting, dusk
and night, and both art sets (at start and after F7); `make contrast-sheet` (plants read on
the new ground in every look). README pictures retaken: camp, zoom, coast, desire paths, field,
art sets.
Left for later: the coast's dyke, the Knick, fences and walls (boundaries.py) and the Ewer
(coast.py) are rows of the object atlas, so they stay with tasks 108 and 111; the meadow flowers
(task 108) look coarse on the new ground until they are redrawn; the seasons, meadows,
landscape and outlines pictures of the README show mostly plants and were not retaken; the
water's ripples and the lily pads' drift work in art pixels, so they are finer and move half as
far in the new art; the wet soil's patches are the same on every tile, as before.

## 108. 32 px art: plants (trees, the willow, bushes, tall grass, fern, reeds, flowers, decorations)

- [x] Done

Done: every plant row of the object atlas is drawn at 32 px per tile in the style of the mockup
(trees.py, beech.py, birch.py, alder.py, willow.py, trunks.py, the tall grass in meadow.py,
reeds.py), and so are the meadow flowers of the decoration atlas (flowers.py), which lose their
own sway material. The oak, beech, alder, birch, the bushes and the sapling have crowns of leaf
sprays (`trees.foliage`), round furrowed trunks spreading into roots, and bare limbs that fan out
into twigs (`trees.crown_limb`); the spruce hangs in drooping tiers; the pine, the dead tree,
stumps, trunks, stones and boulders keep their shapes with more detail; tall grass and reeds are
two-pixel blades with a lit edge over the dense dark foot of task 101, the fern a fan of combs.
From the art review: the pollard willow has a dense, rounded crown with a dark edge and a shaded
underside, rods below and over it, silver leaves, a knobbly head and a mud-coloured trunk on its
ground shadow (bare: umber rods up to the middle); tall grass, fern and reeds read on autumn
ground (autumn tall grass turns `reed` where it was the dry grass' own `autumn_light`) and, a
little weaker, at night; no vegetation is outlined in ink (the dead tree, its stump and the
trunks are rimmed in their darkest bark); `maple_light` is `leaf_orange`. Snow caps are twice
as deep on the plants, and snow lies along the bare oak's and beech's limbs. The atlas is
written at 32 px (cells of 96×160, `canvas.GAME_OBJECT_CELL_*`); its rows not drawn anew are in
`DOUBLED_ROWS` and scaled up after their looks are made (not in `object_atlas()` itself, so their
snow caps and frost specks keep the 16 px grain): byte for byte the rows of before, in every look.
The plants' sway profiles are measured on the new art in the world's pixels, and AmbientMotion
gives their materials art_scale 1, or 2 with the profiles halved in the classic art; the crops
keep 2. The plants now sway half as far on screen as before, on purpose (the user, 2026-11-08:
the calmer world is better, the old one felt busy), and in an order (the user: "grass and crops
usually move more than large trees"): tall grass, reeds, fern and the meadow flowers most, the
bushes and the sapling less, the big trees least and slowest; in a light air the grass's tips
flick while the trees stand still (a test checks the order). Task 109 matches it for the
crops. The trees' `sprite_height` is measured anew. The classic art (task 117): the plant
generators of commit e303759 under tools/art/classic/ (`object_looks.py` is the object part of
seasons.py) write the whole classic object atlas, byte for byte the atlas before, and the
classic decorations' flowers; the object tileset follows the art set (`ObjectTileset.show_art_set`,
a test checks both sets have the same cells). Checked in screenshots at zoom 0.5, 1 and 2 (the
camp, a wood, the marsh ditches with willows, a meadow through spring and summer, the forage and
felled scenes) in spring, summer, autumn, a rainy autumn evening, the night, bare winter and
snow, and in the classic art; `make contrast-sheet` for tall grass, fern, reeds and the willow.
README pictures retaken: camp, zoom, seasons, meadows, landscape, outlines (the new art only),
harvest (the stumps and trunks, without the fall), forage.
Left for later: the camp (fireplace, bedroll), walls, fences, the dyke and the placed objects
stay doubled for task 111 (it takes them out of `DOUBLED_ROWS`); on dry autumn grass the light
blades of tall grass still sit close to the ground (the foot and the olive edges carry it). Not
changed, as they are distances in the world's pixels and right in both art sets:
`FallingTree.IMPACT_HEIGHT` and the see-through sprite's hop and edge. The screenshot window was
1474×439, so the README pictures are wide strips stacked.

The objects atlas (assets/objects*.png) is shared by 108 and 111 and has one cell size for all
its rows: do 108 and 111 together, or the first of them writes the whole atlas at 32 px, with a
`DOUBLED_ROWS` set inside `object_atlas()` for the rows not yet redrawn (scaled up there instead
of by `DOUBLED`), and the sway materials' `art_scale` per type (2 for the old rows, 1 for the
native ones). contrast_sheet.py needs no change.

## 109. 32 px art: crops and fields

- [x] Done

Done: every crop's four growth stages and its dead look are drawn at 32 px per tile
(tools/art/crops.py) after the field of the mockup, and left `DOUBLED`: a cell a tile wide, two
tall for the tall crops, the plants' feet on the lowest ridge of the new tilled soil (task 107),
on a shadow of dark earth; leaves, heads, roots and fruit are rounded forms shaded with forms.py
and rimmed in the darkest shade of their own colours (no ink), stalks, awns, flowers and pods
drawn over them. The sown mound, seed leaves, turnip rosettes and the purple-shouldered root, a
potato bush of leaflets that flowers and dies back yellow over its tubers, feathery carrot
fronds over orange shoulders, the mockup's cabbage, onion bulbs with fallen tops, wheat with
paired grains and awns, peas on brushwood, runner beans on a pole, flax in blue flower and boll,
wild strawberries and the small green squash. From the art review: the Geest grains rye and
buckwheat are new crops end to end (data/crops.cfg, their sheets, seed and produce icons in
crop_icons.py, flour from either in recipes.cfg; neither is eaten raw); the crops still read on
the dark soil. The crops sway on the pixels of their art (`AmbientMotion.crop_material` by cell
size and art scale, the material chosen per crop by the sheet it shows): calm like the plants
of task 108 and in the grass's band, more than the big trees (`CROP_SWAY` strength 1.3, it was
0.6 on doubled pixels), so their tips flick in a light air while the trees stand still;
test_plant_sway.gd checks the order, docs/art-style.md writes it down. No other number of the game was measured on crop art
(the cells' sizes come from the sheets). The classic art (task 117) has the old crops: crops.py
of commit f2c24f8 in tools/art/classic/, byte for byte the old sheets, loaded through `ArtSet`
by `ObjectTileset` (`show_art_set`, called by WorldView); rye and buckwheat show their new sheets
in both sets. The drawing helpers of the old crop art (`KEYS`, `Surface`) moved to
crop_icons.py, their only other user. `--field` lays the crops out three to a row on one tilled
patch, so the whole field fits into the widest view. Checked in screenshots at zoom 0.5, 1 and
2: every crop and stage in summer, autumn, under snow, at dusk and at night, in both art sets;
README field picture retaken.
Left for later: `make contrast-sheet` draws atlas rows only, so the crops were checked on the
soil in screenshots and sheets instead; the classic crops now sway with strength 1.3 on their
doubled pixels, more than they did; the crafting menu lists three recipes named "Flour" (from
wheat, rye or buckwheat); a buckwheat dish (pancakes, groats) would need a new item (task 115);
the potato bush is a dome of small leaflets that reads as a bush but could be leafier.

## 110. 32 px art: buildings (shack, fisherman's hut, Kate, longhouse, hall house, barn, church, bell frame) and their seasonal and lit looks

- [x] Done

Done: every building is drawn at 32 px per tile (tools/art/buildings.py, church.py) after the
Kate of the mockup, and left `DOUBLED`: thatch in 7 px courses with a broken lit top, reed ends
of mixed length and a ragged shadow line, rolled eaves 12 rows deep with a ragged dark hem,
eyebrow dormers, crossed ridge sticks and turf ridges; round fieldstones each lit on its own;
windows of 5 px panes with a glint (lit, each pane one warm colour), braced shutters on hinges;
the Kate's split teal door, the longhouse's arched green door, the barn's braced double doors,
the ledged doors of the huts, the hall house's Grote Door with a carved beam, herringbone and
slanting brick, bargeboards crossing in horse heads; brick 8 px long, half-timber 4 px wide,
tarred boards with battens, a lime wash with flakes and rain splash; the church's tuff ashlar,
pantiles 10 px wide, leaded windows in brick arches and the porch, the bell frame's oak, bronze
bell and shingles. The doors are about 60 px high, so the people (61 px) fit through them;
every picture keeps its size (the walls are taller, the roofs a little lower), so the classic
pictures need no padding and stand where they stood. From the review: the buildings table's
materials (thatch, timber, brick, lime, green and teal paint); the outline in the darkest shade
of the roof's ramp, the eaves' shadow and a ground shadow kept; the longhouse door stays on its
long side, as art-style.md says (a Geesthardenhaus), and SPEC now says so too. The window lights
in data/buildings.cfg are measured on the new windows (a test checks they are on lit glass);
the stork stands `ROOF_FOOTING` (4 px) into a roof, right in both sets; no other number in the
game was measured on building art (the build ghost and the sprites take their size from the
picture). The snow look is the shared `seasons.house`, unchanged. The classic art (task 117)
has the old houses: buildings.py and church.py of commit e303759 in tools/art/classic/, the
pictures loaded through `ArtSet` (`BuildingViews.picture_path`, the build ghost; WorldView
shows the buildings anew on F7). New debug flag `--street=<x>,<y>`: every building in a row on
a lane of grass. Checked in screenshots at zoom 0.5, 1 and 2: every building in spring,
summer, autumn, bare winter, snow, at dusk and at night with the windows lit, in both art sets,
the player at the doors; README pictures retaken (buildings, church, fisher-hut, build, take-down).
Left for later: the Kate variants of the review (task 120); the graves in church.py are world
objects (task 111) and still 16 px; `make contrast-sheet` draws atlas rows only, so the
buildings' contrast was checked in screenshots on every ground; the snow look keeps 2 to 4 rows
of the eaves' dark underside, which is thinner at 32 px than it was (a native snow look would
mean a copy of `seasons.house`, which task 108 owns); in the classic art the window lights sit
on the new windows' places, a few pixels off the old windows.

## 111. 32 px art: walls, fences, the dyke and placed objects (chests, stations, the landing, graves)

- [x] Done

Done: every row of the object atlas is drawn at 32 px now, so `DOUBLED_ROWS` and `doubled` are gone,
and so are the explicit doublings of the stations, the grave marker and the indoor chest
(`write_interior`, `interior.chest_picture`) and `standing_outdoors`' 16 px shadow (it uses
`trees.ground_shadow`); `bedroll_cover.png` left `DOUBLED`. Each placed thing is as big as its
doubled picture was, so it stands where it stood and no number of the game changed (the fireplace's
flame box, the bedroll's cover row and the jetty's deck are the same). The lines (boundaries.py):
the Knick a turfed bank with a low dark core and hazel and hawthorn bushes drawn as leafy domes,
each drawn whole by the tile it stands on so no bush breaks at a seam; the wattle fence's rods woven
round stakes; the fieldstone wall's squat stones in two courses; the dyke (review task 5) a bank
with a flat crest and a sheep track that bends round each corner in a quarter circle, which keeps a
straight arm's distances across the tile's sides, so a dyke on the slant (a stair of corners, as the
generator makes it) is one winding bank and needs no new masks or game data; green in autumn like
the marsh. The camp (camp.py): a ring of field stones, ash, embers and three split logs; the quilted
bedroll with its blanket roll and its cover. The chest, the carved chest with tulips, the workbench,
the kiln, the oven and the cupboard (chest.py, crafts.py), the oak cross, headstone and granite slab
(church.py), the landing (landing.py). The Ewer (coast.py) is in scale with the people (the review):
a hull about seven tiles long and a mast more than twice a person's height, a picture three cells
wide; a type's `cells_wide` makes ObjectTileset create one tile over that many cells (and
WorldView's stand-in sprite take them), the Ewer's footprint is 7x1 (`MAX_FOOTPRINT` 7x2;
landscape.cfg's Ewers need 7 tiles of mud) and generate.py's `atlas_cells` splits the picture. No
save change: Ewers come from the seed, so an old world keeps those with 7 tiles of mud and loses the
rest; a jetty or boat built far out on the mud of an old save could now overlap a kept Ewer's longer
hull (rare, accepted). Snow lies twice as deep on all of them. Their item icons and ground items are
made from the new pictures (task 115's `items.icon_of` takes a 32 px picture, halving one much
bigger than an icon). fire.strip and fire.burning take every picture at the game's tile now.
canvas.py's object cell is defined at 32 px (`GAME_OBJECT_*`); `OBJECT_*` stays for the classic
art's old generators, which import it. The classic art (task 117): boundaries.py, camp.py (with the
old bedroll and cover, replacing task 112's bedroll.py), chest.py, coast.py, crafts.py and
landing.py of commit ec0b1af in tools/art/classic/, byte for byte the classic atlas before but for
the Ewer, which lies in the middle of its three cells; the classic art also writes the stations and
the grave marker placed indoors. New debug flag `--yard=<x>,<y>`: the chest and the stations in a
row with a Knick, a wattle fence, a wall and a dyke on the slant behind them. Checked in screenshots
at zoom 0.5, 1 and 2: the camp by day, at dusk and waking on the bedroll, the yard in summer,
autumn, bare winter, snow and at night, the landing in summer and on a snowy winter night, the Ewer
at high and low water beside the player, the river dykes of the marsh, the churchyard by day and on
a snowy night, in both art sets; `make contrast-sheet` for the four lines. README pictures retaken:
camp, stations, waking-in-bed (the bedroll), church (the graves and the wall), art-sets; new: ewer,
landing.
Left for later: the farm yard objects of review task 6 (task 122); where the dyke is two tiles wide
(2x2 blocks at the river's bends, T-junctions) it shows a ring with a dip in the middle, as a 4-side
mask cannot know the diagonal neighbour; the fisher-hut, landscape and coast pictures of the README
were not retaken (the hut would not place by the water in the shots; the new landing and Ewer
pictures show what changed); the classic Ewer stands on the new 7x1 footprint, which is wider than
its picture; the wattle fence and the wall seen end-on (running north-south) are thin columns, as
before.

The objects atlas is shared with 108; see there.

From task 112: draw the bedroll's row of the object atlas and its cover (`camp.bedroll_cover`,
assets/bedroll_cover.png, still in `DOUBLED`) at 32 px, and remove the explicit `doubled(...)`
of the stations and the grave marker in `write_interior` (generate.py) and of the chest in
`interior.chest_picture` once chest.py, crafts.py and the graves are drawn at 32 px.

## 112. 32 px art: interiors and furniture

- [x] Done

Done: the rooms and their furniture are drawn at 32 px per tile (tools/art/interior.py) and
left `DOUBLED`: floor bricks 16x8 in a herringbone, calm (one colour of brick, soft joints,
a worn spot on every third) and beaten clay trodden in soft patches, an oak ceiling beam over smoked plaster, a wainscot of raised panels, oak wall
plates and corner posts, a deep-set window, the doormat plaited; the bed with its canopy and
curtains, the box bed, the sleeping mat, the table with a candle, a pewter plate and a jug,
the stool, the bench and the wall bench with turned legs and spindles, the stall partition,
the hay pile, barrel, sacks, crate and the plate rack with Delft and pewter plates, and the
hearth (a lime-washed hood with soot, Delft tiles with flowers, buff brick, logs and an iron
pot). From the review: each piece outlined in the darkest shade of its own ramp, a dithered
floor shadow under what stands free. Every picture keeps its size and every tile its id, so
the maps are unchanged. The beds fit the 61 px figure of `PlayerView.LYING_POSES`: the
blanket and the cover go down to the foot, and the box bed's front board starts under the
figure; in the box bed the figure lies 2 px left and up (`LYING_POSES`, head to the left), so
its head is on the pillow inside the bed. The bedroll at the camp (16 px, the atlas is task
111's) is two rows longer, so it reaches the foot of its footprint and its cover hides the
clogs; the classic object atlas keeps the old bedroll, so the classic set has the old cover
too (tools/art/classic/bedroll.py, `ObjectCover` loads it through `ArtSet`). The hearth's flame box is unchanged (`FIRE_PROFILES` keeps its numbers); its still
picture shows the native flame (`fire.strip` and `fire.burning` take the pictures' scale),
and its light is placed in native pixels. The classic art (task 117) has the old rooms:
interior.py of commit f2c24f8 in tools/art/classic/; the atlas, the furniture, the covers and
the ghost of a placed piece load through `ArtSet`, and `InteriorView` shows its room anew on
F7. The stool's item icon keeps the 16 px stool (now in crafts.py); the indoor chest, the
stations and the grave marker are still 16 px art, scaled up in write_interior. Debug flags:
`--inside=<building>` walks into the first building of that type (with `--street`, every
interior can be shot), and `--sleep` with `--inside` lies down in the room's first bed.
Checked in screenshots at zoom 0.5, 1, 1.2 and 2: every interior (shack, fisherman's hut,
Kate, longhouse, hall house, barn, church) by day and at night with the hearth lit, waking in
the straw mat, the bed, the box bed and on the bedroll, in both art sets (at start and after
F7). README pictures retaken: interiors, day-and-night, waking-in-bed.
Left for later: the chest indoors comes from chest.py and the stations from crafts.py (task
111), scaled up until they are redrawn; the bedroll's row of the object atlas is task 111's,
which may draw it at 32 px with its cover (then `BEDROLL_COVER_FROM_ROW` and the cell are
native); rooms have no seasonal looks, so seasons, frost and snow change nothing inside;
`make contrast-sheet` draws atlas rows only, so the furniture was checked on brick and clay
in screenshots; the screenshot window here is 1474x439, so the README pictures are cut from
shots at zoom 1 and 1.2.

## 113. 32 px art: the player and the villagers (character layers, every action, riding, collapse, portraits)

- [x] Done

Done: every character layer is drawn at 32x64 (tools/art/character.py, villagers.py) in the
style of the mockup: rounded forms shaded by the light from the top left (a new
tools/art/forms.py with the mockup's shapes and shading), faces with eyes, a glint, brows, a
nose shadow, cheeks and a mouth, collars, buttons and pockets, full sleeves gathered at the
wrist, knee bands with a button, white stockings and clogs with a lit top and a dark sole. All
layers draw on one `Figure` (head, torso, arms and legs of a facing and pose), so the looks still
combine; the hands stay in front of what is worn. The walk, passing out (64x64 frames), riding,
the held hoe, the sleeping "z" and the thought bubble are redrawn; the chat portraits are the top
of each layer's front frame, so they have the new faces (the chat layout is unchanged). From the
art review: a white stocking cap besides the red one (now a stocking cap with a tip and tassel),
a striped apron and a tricorne, worn by made-up villagers (data/npcs.cfg, data/npc_talk.cfg).
The people stand on the animals' contact shadow. The character sheets, the "z" and the bubbles
left `DOUBLED`; the game's numbers measured on them are native (head tops and sweat in
`TirednessView`, the name tag, the lying poses, the "z"s, the bubble's pop, the character
preview at one UI pixel per art pixel). The seat on the horse keeps its row, as the horse is
still doubled 16 px art: task 114 measures `SEAT` anew. Checked in screenshots at zoom 1 and 2
(every facing and walk frame, riding the bay, the grey and the pony from the side, the front
and behind, the collapse, beds, villagers of every look, the portraits, the inventory, summer, snow and night); README pictures retaken.
Left for later: the trades' props in hand (net, crook, ...) for task 115; the bedroll's and the
beds' covers (16 px art) are shorter than the 61 px figure, so its clogs show at the foot of
the bedroll: tasks 111 and 112 draw the covers to the foot; the waking picture shows the shack
and the camp only (a Kate or longhouse would not place by the camp with `--house`).

## 114. 32 px art: farm animals (cow, sheep, chicken, horse, dog, cat, rabbit), every action

- [x] Done

Done: every farm animal sheet is drawn at 32 px per tile (tools/art/livestock.py) in the style
of the mockup, with every action and frame it had: idle, walk, graze, sleep and run, the cat's
crouch, creep and pounce, the saddled horse and the ridden horse from the side, the front and
behind, standing, walking and trotting. The four-legged animals share `quadruped_frame`: body
and neck with the head as polygons shaded as one rounded form (forms.py, with a new
`top_light` and `shade_by_level`), legs as limbs through their joints swung and folded for each
step, the far ones a step darker; the face, ears, manes and tails in strands and each look's
marks by hand (pied patches shaded with the body, dapples, a dun's stripe, a bay's points and
blaze, tabby stripes, wool curls). The cow's head is hand-drawn and transposed for grazing; the
pony is the horse at four fifths; the hen and the rabbit are drawn whole per pose. In scale with
the 61 px people (the horse 57 px to the withers, the cow 40 px to its back), the small animals
a little larger than life; the outline is the darkest colour of each coat. The farm sheets left
`DOUBLED` (the glob split so the wild animals stay doubled for task 116) and their numbers are
native: the cell sizes in `WildlifeSprites` (cow 72x54, horse 88x76), the contact shadows of
`FarmAnimalView` (`Animal.art_scale` 1), and in `PlayerView` the `SEAT` and `PONY_SEAT` measured
on the new saddles, `RIDE_LIFTS` and the ridden horse's shadow. From the review of task 113: a
blue saddle cloth sets the rider's brown breeches off from a bay. Checked in screenshots at
zoom 1 and 2 (every species and look, summer, snow and night, the hunting cats at dusk, riding
the bay, the grey and the pony from the side, the front and behind, walking and trotting);
README pictures retaken (livestock, dogs, cats and horses, the hunt, riding). The 16 px farm
animals are the classic art (task 117): their old livestock.py and animals.py in
tools/art/classic/, the cow's and the horse's classic cells set in the new, larger ones, the
sheets loaded through `ArtSet` (FarmAnimalView in `ArtSet.VIEWS`, the ridden horse in
PlayerView), the rider seated where it was on the classic horses (`CLASSIC_SEAT`); checked in
both sets (cows, horses, riding).
Left for later: `make contrast-sheet` draws atlas rows only, so the animals were checked on
grass, snow and night in screenshots instead; the riding legs of the people (task 113) are
short for the 32 px horse, so from the front the rider's feet hang at the saddle cloth rather
than down the barrel; a lying animal's folded legs mostly hide under its body; the contact
shadow is three art rows tall, so under the native animals it is half as tall as under the
still doubled ones (task 116 may even them out).

## 115. 32 px art: items and icons (ground items, inventory icons, the UI slots that show them)

- [x] Done

Done: every item icon is drawn at 32 px (tools/art/items.py, tool_icons.py, crop_icons.py and
the icon parts of meadow.py, reeds.py, crafts.py, church.py and landing.py) in the style of the
32 px art: forms.py shading from the top left, wood grain, cloth folds, iron with a lit and a
dark rim and a bright edge, each a body outlined in the darkest shade of its own ramp
(`items.RIMS`). The items on the ground are the bodies at half size (16 px, `items.ground_item`),
no longer `DOUBLED`, on a contact shadow (`GroundItemView`); the drop's hop and the sprite
offset are in world pixels. The UI keeps its 20 UI pixel slots and shows a 32 px icon at half
size in 16 UI pixels (`SlotView.ICON_RECT`, `ItemIcon` for the recipe rows and the picked
icon), an icon pixel as big as a world pixel at the widest zoom, through
`sharp_pixels.gdshader` so the pixels stay square at 1.5 window pixels; 36 UI pixel slots for
full-size icons were tried in a screenshot and turned down (the hotbar took over a third of the
screen). The seed sacks are one linen sack told apart by the crop's string, its produce painted
on it and its seeds. From the art review: the pickaxe is the Geest's pick for grubbing out and
splitting the fieldstones of the till (a point and a chisel), in art-style.md's tools; the
spade has an iron shoe. The three flour recipes have names of their own (`name` in
data/recipes.cfg, `RecipeRules.name_of`): Wheat, Rye and Buckwheat flour, a long name clipped; the flour is one
item. A buckwheat dish: buckwheat pancakes, 2 from 3 buckwheat at the fire (cooking 15, 14
energy). The classic art (task 117): the old icon generators in tools/art/classic/
(`item_icons.py`, `tool_icons.py`, `crop_icons.py`, `craft_icons.py`), the icons and the doubled
ground items under assets/classic/, byte for byte main's; the slots, recipe rows, picked icons
and ground items load through `ArtSet`. Debug flag `--items=<x>,<y>`: every item on the ground
and in the inventory. Checked in screenshots at zoom 0.5, 1 and 2 in spring, summer, autumn,
frost, snow, dusk and night, in both art sets, and the character screen, the crafting menu and
the hotbar; README pictures retaken (character, crafting) and added (items).
Left for later: the sickle, flail, rake, pitchfork, buckets and yoke have no job in the game
yet (grain harvest and threshing, hay, carrying water), so they have no icons; the icons of the
items that place a world object (chest, stations, grave marker, the landing's pieces) are their
16 px world pictures doubled until task 111 redraws those (`items.icon_of` then needs no
doubling); the station-menus and chest README pictures show the new icons but were not
retaken; `make contrast-sheet` has no items, so they were checked on screenshots over grass,
sand, snow and dyke instead.

## 116. 32 px art: wild animals (birds, flocks, storks, geese, sea birds, deer, squirrels, rabbits, mice, frogs, bees, butterflies) and effects (fire, particles, rain splashes, hit effects)

- [x] Done

Done: every wild animal is drawn at 32 px, every action and frame it had, in the style of the
mockup: rounded forms shaded from the top left (forms.py, whose ellipse can now be turned),
eyes with a glint, legs with joints (the deer's knee and hock), each outlined in the darkest
colour of its own coat or plumage. The sparrow, rabbit, squirrel, roe deer, bee, butterflies,
mouse and frog are in animals.py; the birds are put together by a new bird_forms.py (body,
tail, neck, head, bill, folded or open wings, legs drawn over the outline) for the sparrow, the
stork and goose (birds.py) and the oystercatcher, dunlin, gull and tern (sea_birds.py). From the
art review: the small animals are drawn a little larger than life (cells twice the 16 px ones,
the sparrow, rabbit, bee, butterflies and dunlin bigger still), and every animal stands on a
contact shadow, now a flat oval in the game's pixels (`Animal.draw_contact_shadow`, its half
widths native for the wild and the farm animals and the people; `Animal.art_scale` and the
`scale` parameter are gone); the birds' flight shadows (`GroundShadows`) are native too. The
wild sheets left `DOUBLED`; their frame sizes in `WildlifeSprites` and the wild animals' hops,
speeds and margins are in the game's pixels. The classic art (task 117) has the old wild
animals and flames (tools/art/classic/ birds.py, sea_birds.py and fire.py of commit 2793065,
the grown cells set in the new ones); the wild sheets and the flame strips load through ArtSet,
and the animals, the flocks' birds, WorldView and InteriorView (the fires) join ArtSet.VIEWS.
The hit particles, the splashes and the weather are code and look new in both sets. The
effects: the flame's loop is drawn at 32 px (fire.py; fire.gdshader works on the world's pixels,
the fireplace and hearth around the flame are scaled up into the strip), the hit particles fly
and are drawn natively (leaves with their corners left out and a shaded side, long needles,
round snow, chips, drops), the rain's splashes show a streak, a crown and a ring, and the
weather (rain, snow, wind streaks, leaves, fog) works on single pixels; `art_scale` is left to
the plants, water, mud and lily pads. Checked by eye in screenshots at zoom 1 and 2 (every
species and action, flight and shadows, the stork on a roof, gulls swimming, terns diving, the
fire by day and night, hits, rain, storm, snow, fog, summer, autumn, dusk) and in sheets over
grass, sand, snow and water, and the wild animals and the fire in the classic art too; README
pictures retaken (wildlife, mice and frogs, sea birds, weather, camp, zoom).
Left for later: the still pictures of the fireplace (atlas cell) and the hearth keep their 16
px flame until tasks 111 and 112 redraw them; the Ewer (an object of the coast) is not in this
group: its scale against the 61 px people is for task 111; `make contrast-sheet` covers the
object atlas only, so the animals' contrast was checked on sheets over the grounds of every
look instead; the day-and-night picture (the hearth inside a house) and the harvest picture
were not retaken (`--inside` did not get into a house in time).

The redraw takes in the findings of review/art-review-2026-11-08 (the user, 2026-11-08: "make
sure the redraw includes the art review feedback"); each group's brief points at the review and
lists its part:
- every group: the contrast and outline rule (the darkest shade of an asset's own ramp at its
  outer edge against the ground, a ground shadow, never ink on vegetation, none on terrain;
  canvas.outline / outline_edge from task 100) and a check with `make contrast-sheet`;
- 107 ground: autumn is not one straw yellow everywhere (the marsh stays green until November,
  straw only on the dry Geest); tilled rows that don't read as stacked logs (a softer ridge
  highlight, no rounded ends); a calmer ground behind small figures;
- 108 plants: the pollard willow (a dense crown with an edge, rods over it, trunk in mud/mud_dark
  rather than grey stone, its ground shadow); tall grass, fern and reeds legible on autumn and
  night ground (task 101 left those weak); rename `maple_light` while touching seasons.py;
- 109 crops: the Geest grains of the village sheet (rye, buckwheat) if cheap, else a task;
- 110 buildings: the longhouse door as SPEC and art-style.md say (or fix the docs); the Kate in
  brick and Geest variants (review task 7) if it fits; the buildings table of the review as
  the reference for new ones;
- 111 objects: the dyke as a sloped bank with corner and diagonal pieces (review task 5); the
  farm yard objects (chicken coop, trough, hay rack, draw well, stork's nest; review task 6) if
  they fit, else their own task;
- 113 people: the clothes art-style.md lists but the art lacks (stocking caps in two colours,
  striped apron, tricorne), the trades' props held in hand where cheap;
- 115 items: the period tools art-style.md lists (sickle, flail, rake, pitchfork, bucket, yoke)
  and a period job for the pickaxe, or the docs corrected;
- 116 wild animals: small animals drawn a little larger than life, contact shadows; the Ewer's
  scale against the people;
- the last group: docs/art-style.md and SPEC brought in line with the art (review task 14).

Each of 107 to 116 redraws its group at 32 px in the style of the mockup (more detail, legs
with joints, faces, small animals drawn a little larger than life, a calmer ground behind small
figures, contact shadows), drops the doubling for it, checks every season, frost, snow, dusk
and night in screenshots and the contrast sheet, and retakes the README pictures it shows.
Order: 106 first; then 113 and 114 (what reads worst), 107 and 108 (what everything stands on),
the rest after; a group may be split if it is large.

## 117. Switch between the classic 16 px art and the new 32 px art

- [x] Done

The user, 2026-11-08: "Since you fixed the engine to run in both old and new textures, add a
functionality to switch in-between those. You can recover the already changed ones from git
history, make it a setting under the video settings and add an F-key to change it on the fly."
And: "There's a script to generate the art, correct? Make sure there's a target that also
generates the old art".

Done: the old art is generated, not copied. tools/art/classic/ holds the people's generators of
commit 97e9736 (`character.py`, `villagers.py` and `portraits.py` unchanged, the thought bubble
part of `ui.py`), and `make classic-assets` (run first by `make assets`, so the palette check
covers it) writes their pictures under assets/classic/ with the new files' names, doubled as
then: byte for byte the art of 97e9736, with the new files' cell sizes. `ArtSet` loads the
classic picture where there is one and the new one where there is none (the white stocking
cap, the striped apron and the tricorne have none); every load of the people's art goes through
it (the player, the villagers, the character screen, the chat portraits, the "z"s, the thought
bubble). The setting is "Art: New 32 px / Classic 16 px" under Settings → Display
(`classic_art` under [display] in settings.cfg; not in the save) and F7 ("Classic or new art"
under Settings → Controls) switches it on the fly and saves it; the views that keep their
pictures load them anew, the rest on their next frame. The numbers measured on the art stay the
new art's: in the classic art the head and hat tops and the name tag are 2 to 3 pixels off and
the "z"s start 8 pixels further left, still over the head, which does not show. Debug flags:
`--classic-art` (not saved) and `--switch-art` (F7 just before a screenshot). Checked in
screenshots at zoom 1 and 2: villagers and the player in both sets, F7 pressed in a running
game, passing out with the "z"s, the Display and Controls pages; README picture added.
Each of tasks 107 to 116 moves its group's old generators to tools/art/classic/ and loads its
pictures through `ArtSet` (docs/art-style.md, "Resolution"; tools/README.md): 114 and 116 are
running beside this task, so their classic art comes with them or right after.

## 118. Zoom out as far as before the 32 px switch

- [x] Done

Done: the widest view shows 1280×720 art pixels, 40×22 tiles, again (zoom 0.5, `ViewMath.MIN_ZOOM`;
`WIDEST_VISIBLE_SIZE`, and the stage-one viewport is that plus the margin). Zoom 1 and 2 keep
their size (640×360, 320×180), so `--zoom=` and `make screenshot ZOOM=` mean what they did; the
game starts at 0.5. The zoom keys `=` and `-` (and the keypad's + and −), the actions `zoom_in`
and `zoom_out`, are rebindable and listed on the Controls page and in the README; a press is two
wheel notches and holding repeats. Where an art pixel is smaller than a window pixel (windows
under 1280×720) the sharp-bilinear shader averages four taps. Cost, measured in a busy scene
(rain, 8 villagers, deer, rabbits, gulls, cows, sheep, dusk) at 1920×1080 on an Intel Arc: the
world viewport's GPU time went from 1.09 to about 2.8 ms, the whole frame's GPU time from about
4.8 to 6.4 ms, so the frame stays capped by the 145 Hz display (6.9 ms) either way. Nothing else
needed a change: the weather and fog shaders work in viewport pixels (they follow
`VIEWPORT_SIZE`), and spawning, wildlife and streaming count in tiles or follow the view
(`view_rect`), and the same 40×22 tiles worked before task 106.

The user, 2026-11-08: "we need the zoom back. Now we need to zoom even further to get the same
effect as before". Before task 106 the widest view (zoom 0.5 of 16 px art) showed 640x360 art
pixels, 40x22 tiles; since 106 the widest view (zoom 1, `ViewMath.MIN_ZOOM`) shows 640x360 of
the 32 px art, only 20x11 tiles, so the same zoom-out shows a quarter of the world. Let the view
zoom out to about 40x22 tiles again (1280x720 art pixels at the widest, each art pixel then
smaller than a screen pixel at small windows: check it stays crisp, e.g. by the viewport size
and `screen_scale`), keep zooming in to today's closest view, and start at the widest as now.
Also check the zoom is easy to find since the wheel turns the hotbar: Ctrl and the wheel zoom
today; list it on the Controls page and the README, and consider keys (+/-) as well. Mind the
cost of the larger viewport (world, shadows, weather, lights drawn over 4x the pixels) and what
assumes 640x360 (`VIEWPORT_SIZE`, `WIDEST_VISIBLE_HEIGHT`, the screenshot tool, tests).

## 119. The tools in the character's hand

- [x] Done

Done: every tool shows in the hand (`HELD_TOOLS` in tools/art/character.py, one sheet
assets/character/held_<tool>.png each, the item's `held_sheet`): the hoe, shovel, scythe, axe,
pickaxe, hammer and watering can, at 32 px in every facing and walk frame, in the colours of
their icons. One helper places them the hoe's way, in the right hand: the long tools (hoe,
shovel on its blade, scythe) stand on the ground beside the figure, the short ones (axe and
pickaxe at the throat, hammer, the copper can by its handle) hang in the hand with the head
above it and, seen from the side, swing with the near hand; from behind the tool is behind the
body, its head turned outward so it shows beside it. There is no fishing rod in the game, and
the player has no use (swing) animation, so there was no swing for a tool to follow: a tool
stays in the hand as it is used, and riding, passing out and lying in bed still let go of it.
The classic art keeps its hoe; the other tools show the new picture in both sets (checked: they
sit by the doubled 16 px figure's hand). A test checks every tool has a held sheet in the
character's cells in both sets. Checked in screenshots of every tool in all four facings at
zoom 1 and 2 in both sets; the README's build picture is retaken with the hammer in hand.

The user, 2026-11-08: "most tools don't show on the character". Only the hoe has a
`held_sheet` (game/state/item_types.gd) and a held layer drawn (tools/art/character.py); the
others (axe, pickaxe, shovel, watering can, scythe, hammer, fishing rod, and what else the
player can hold) show nothing in the hand. Draw a held layer for each at 32 px in every facing
and pose the hoe has (idle, walk, and the use animation where there is one), set `held_sheet`
for each, and check them in screenshots in all four facings; classic art (task 117) falls back
to the new picture for those without an old one. Task 115 (items and icons) redraws the
icons; this task is the hand-held pictures, and may go with 115 if that is simpler.

## 120. Kate variants: a brick Kate and a Geest Kate

- [ ] Done

From review/art-review-2026-11-08 (its task 7 and buildings row 7), left out of task 110: two
more looks of the Kate, for Kerrin's house at the dyke foot, the mill house and the sexton's
house: red brick walls (`rust`, `red_light`, joints `sand`) with white frames, green paint and
a brick chimney; and a Geest look, lime-washed over a black tarred foot instead of the
fieldstones, under a turf ridge. The art is cheap (`buildings.kate` takes the walls as a
parameter; task 110 tried both looks); the open question is the game side. The review proposes
a `style` per building in data/buildings.cfg (SPEC "presets with customisation"), which means a
saved style per placed building (a save version), a way to pick it with the hammer and the
pictures per style; two more building types in data/buildings.cfg would need no code, but
each needs its own interior map today (test_interior_maps) and the hammer's list grows.

## 121. A building menu: the buildings and their variants, with a preview

- [ ] Done

The user, 2026-11-08: "we need a proper building menu which allows the different variants and
maybe a small preview. It could look like a matrix on top of the quick bar where you see the
main buildings and their variants popping up to the top when you selected a building."
Today the hammer's Q and E step through data/buildings.cfg in file order, one building at a
time. Instead, with the hammer held, a row of the main buildings sits just above the hotbar
(each a small picture of the building, its name and cost); picking one makes its variants pop up
in a column above it (task 120's brick and Geest Kate, later styles), and the chosen variant
shows a larger preview with its materials and whether the inventory has them. Keys and mouse
both work (arrows or Q/E along the row, up and down through the variants, a click picks; Esc
closes), the ghost in the world follows the choice, and it reads in both art sets (task 117).
Goes with task 120: the variant needs a saved style per placed building (a save version) and
the variants' pictures; plan the data shape (a building and its styles in data/buildings.cfg)
together.

## 122. The farm yard: chicken coop, trough, hay rack, draw well and stork's nest

- [ ] Done

From review/art-review-2026-11-08 (its task 6 and buildings rows 1 to 3 and 16), left out of
task 111 because each needs game data as well as art: a chicken coop (a building 2x2, low and
boarded, a ramp with cleats to a hatch, a nest-box lid; the hens sleep in it and the eggs are
collected there; an interior map), a trough (a hollowed oak log or a plank box with water) and a
hay rack (oak posts with slanting slats, hay behind them), 2x1 world objects that feed and water
the livestock (SPEC, Livestock), a draw well with a sweep (1x1 plus the sweep above it: an oak
well head on a fieldstone ring, a forked post, the balanced pole, the bucket and a weight stone;
water for the can, the animals and the house) and a stork's nest on a roof ridge (the
`roof_stork` standing in it). Draw them at 32 px in the style of task 111 (tools/art/, a new
yard.py), give them types, recipes and placement (data/, world_object_types.gd), and decide
what each does for the animals.

## Later (not part of the prototype)

- **A relationship system** (the user, 2026-11-08): friendship levels per villager, like Stardew
  Valley, but actions count as well as gifts, in the manner of the Sims (helping, talking,
  events, rudeness, theft, being there in trouble). A first draft is in
  [design/villagers/relationships.md](design/villagers/relationships.md), planned and not
  decided. Plan with the user (its open questions are in QUESTIONS.md), then split into tasks.

- **Economy and currency** (the user, 2026-11-08): small trades with villagers, shops that buy and
  sell for money, and the player's own little stall where villagers occasionally buy produce and
  goods. A first draft is in [design/economy/README.md](design/economy/README.md), planned and
  not decided. Plan with the user (its open questions are in QUESTIONS.md), then split into
  tasks. It also settles where seeds come from once shops exist.

- **The camp's bedroll and campfire can be taken down and built** (the user, 2026-11-08): today
  they come with the camp and stay where they are. Let the player take them down (as task 83
  does for buildings and placed things) and craft or build them again elsewhere, with sensible
  materials (straw and a wool blanket; stones and wood), keeping the bed the player wakes in
  (task 78) and the campfire's cooking station working wherever they stand.

- **One folder per entity in data/** (the user, 2026-11-08): the data of one thing is spread
  over several files today; bread, for example, is an item in game/state/item_types.gd, its
  energy in data/energy.cfg, its recipe in data/recipes.cfg and its skill in data/skills.cfg. Restructure data/ by kind and entity, e.g. data/consumables/<consumable>.cfg
  (or a folder per entity) holding everything about it: name, item, energy, crafting, sounds,
  looks. The game still reads everything at load, but each entity is in one place, so adding or
  extending one touches one file. Plan the kinds and the file shape first, then move one kind
  at a time with the rules classes (and their validation and tests) reading the new layout.

- **Graphics review: willows melt into the grass** (the user, 2026-11-06, with a screenshot;
  was task 87, to look at in the next graphics review). The pollard's crown of thin, pale
  yellow-green shoots has the same values as the meadow and lush grass under it, with no dark
  edge and little shadow, so only the trunk reads. Ideas: a darker underside and outline of the
  crown, a clearer silhouette of the rods against the ground, the ground shadow, and a check on
  lush, dry and flowering grass in every season (tools/art/willow.py). No new colours.
The user's word of 2026-11-08: the same problem as the willows affects some grass and reeds (and
the bushes by a stream): too little contrast against the ground behind them. A slight outline
for assets would be good. A visual review on Fable runs on 2026-11-08 (contrast and outlines,
the art-style docs against the art, the villagers' and the village's places without art, and
the buildings a village needs: house varieties, a small church, farm buildings such as a
chicken coop and troughs for cows and horses).

- **Test LLM on the GPU, and which models fit** (the user, 2026-11-06): set up CDI for the
  RTX 4070 (tools/README.md, GPU), then try which models fit in its 8 GB of VRAM and how
  their villager lines compare (e.g. qwen2.5:7b-instruct, llama3.1:8b, gemma2:9b).
- **More hosted providers: OpenAI, others** (the user, 2026-11-07). Gemini is done (a row of
  `GameSettings.LANGUAGE_MODEL_PROVIDERS` with its own settings, 2026-11-07); OpenAI and the
  like would be one more row each, with a README line; a native adapter only where the
  compatible endpoint falls short.

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
