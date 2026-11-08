# Code review, 2026-11-08: simplification, structure, performance

A review of main at c8f5814 (Godot 4.7.2, GDScript, GUT 9.7.1), two days after the review
of 2026-11-06 (docs/code-review-2026-11-06.md). That review's packages (tasks 63 to 71) are
done: `ToolUse`, `StartupOptions`, `DebugRunner`, `DataFile.read_sections`, the packed tile
code, `BuildingViews` and `DecorationView` all exist. This one looks at what has grown since,
and above all at the test run, which went from 1031 tests in 50 s to 1656 tests in 152 s
(171 s wall with Godot's start and the import pass) and now dominates the per-commit loop.

Numbers: game/ has 174 scripts, 26 284 lines; tests/ 179 scripts, 21 592 lines, 1656 tests
in 169 files; data/ 20 cfg files. The machine has 22 cores.

## Verdict in one paragraph

The code is in good shape: the dead-code search found one unused function in all of game/,
there is no TODO, every rules class fails loudly on a missing key, the state/scene split
holds. What is worth doing now is (1) the test run, which can go from 171 s to about 25 s
by sharding across processes, and another 25 to 40 s by fixing a dozen tests and one
fixture; (2) the two data tables that live in code (`item_types.gd`, 535 lines, and
`world_object_types.gd`, 724 lines), which fit the planned "one folder per entity in data/"
restructuring; (3) a handful of small duplications (the save upgrade chain, the "missing
key" loops of 11 rules classes, the `dismiss` boilerplate of six animals). `main.gd` (807
lines, changed in 107 of the last ~150 commits) is the file to watch; it is the only one
still too big for comfort.

## 1. Simplification and less code

Ordered by lines saved per unit of risk.

### 1.1 The save upgrade chain is 44 lines of the same `if` (save_file.gd:84-127)

Twenty-two blocks of `if version <= N: _upgrade_from_version_N(game)`, one more each
version. Replace with one list and one loop:

    const UPGRADES: Array[Callable] = [
        _upgrade_from_version_1, _upgrade_from_version_2, ... _upgrade_from_version_22,
    ]
    for old_version in range(version, VERSION):
        UPGRADES[old_version - 1].call(parsed["game"])

The "how to add a save field" rule at the top of the file loses a step (no new `if`).
Saves ~40 lines, risk none (test_save_upgrade.gd covers every version). Size S.

### 1.2 The "missing key" loops of the rules classes (11 files, 21 loops)

`crop_rules.gd:70-80`, `livestock_rules.gd:100-105`, and the same in sound, weather,
recipe, season, landscape, ambience, building, path, energy and station rules: `for key in
REQUIRED_X_KEYS: if not section.has(key): problems.append("[%s] no %s" % ...)`. One helper
next to `read_sections`:

    static func missing_keys(sections: Dictionary, section: String, keys: Array) -> Array[String]

returning the `"[section] no key"` lines, turns each loop into one line (`found +=
DataFile.missing_keys(...)`). The checks that are not "is the key there" (lengths match,
colours parse, ranges ordered) stay where they are; they are the readable part. Saves ~60
lines, risk none. Size S. (The previous review decided against a rules base class; this is
not one, it is one more static function in DataFile.)

### 1.3 `default_rules` / `from_file` / `_default` in 19 classes (~230 lines)

Every rules class repeats the same 12 lines (livestock_rules.gd:84-95). They cannot share a
typed static function without a base class or `Variant` returns, and the previous review
chose explicit over generic here. Leave it; but when the data/ restructuring comes (item
5 of section 2), the new loaders should not add more copies: give `DataFile` one
`load_or_report(path, make: Callable)` that does the read, the `problems()` report and the
caching, and let each class keep only `static func default_rules() -> X: return
DataFile.load_or_report(...)`. Saves ~150 lines then. Size S, risk low.

### 1.4 `dismiss()` and `_is_dismissed` in six animals (wildlife/*.gd)

rabbit.gd:39-42, squirrel.gd:40-43, deer.gd:35-38, frog.gd:36-39, mouse.gd:31, bee, bird:
each has `var _is_dismissed` and the same three-line `dismiss()` that sets it and calls
`_start_fleeing()` unless already fleeing. Move both to `Animal`: `dismiss()` sets
`_is_dismissed` and calls a `_flee_for_good()` hook (today's `_start_fleeing`). Saves ~30
lines; the flee-state check differs per kind (FLEE vs ALERT), so the hook stays overridable.
Size S, risk low (test_wildlife*.gd cover dismissal).

The rabbit and the frog also share the hop state machine (`_hop_on`, `_flee_hop`,
`_start_fleeing` differ only in zigzag and frame rate; the diff is 20 lines of 50). Not worth
a shared class: the rabbit's zigzag makes the two read differently. Leave.

### 1.5 The animals' numbers are in code, the rules say data/ (wildlife/*.gd)

`data/wildlife.cfg` already has a section per kind (202 keys), yet rabbit.gd:11-21 has
`HOP_LENGTH`, `HOP_SECONDS`, `FLEE_HOP_LENGTH`, `ZIGZAG`, `SAFE_EXTRA_TILES`; squirrel.gd,
deer.gd, frog.gd, mouse.gd, bee.gd the same (about 40 constants over the six files). They
are tuning numbers of exactly the kind `wildlife.cfg` holds (`flee_tiles`, speeds). Move
them into the kind's section and read them through `wildlife.rules`. Saves ~40 lines of
constants, and tuning a hop no longer means a code change. Size S, risk low. Fits the data/
restructuring (one folder per animal).

### 1.6 `ItemTypes` and `WorldObjectTypes` are data in code (item_types.gd 535 lines, world_object_types.gd 724)

47 item entries and 46 object entries as nested dictionary literals, each 6-12 keys, plus
`_with_crop_items`, `_with_crops`, `_with_trunks` that merge the crop and trunk types from
`CropRules`. Everything about them is already what a cfg section is: a name, a description, a
weight, a stack limit, a sheet. These are the two biggest files in game/state after the
world, and they changed 34 and 49 times since Nov 1: every new item or object edits code
that needs an import pass to be seen. Move the tables to `data/items.cfg` and
`data/objects.cfg` (or, with the planned restructuring, one `data/<entity>/entity.cfg` per
item and object: the user's "one folder per entity" note in TASKS.md), read through
`DataFile` with a required-keys check like the other rules. The constants (`ItemTypes.HOE`
etc.) stay in code; only the dictionaries move. The two scripts shrink to ~120 and ~150
lines. Saves ~950 lines of GDScript (they become ~700 lines of cfg), and the number tables
get the same loud validation as the rest. Size L (two workers: items, then objects), risk
medium (every test that reads a type by key keeps working; the checks that types have a
picture, `asset_check.gd`, must follow).

### 1.7 One dead function

The unreferenced-function search over all of game/ found one: `game/scenes/falling_tree.gd:
has_landed`, which nothing calls (the other hit, `PlayerView._unhandled_key_input`, is a
Godot callback). Delete it. Size S. That one hit in 174 scripts says the code is kept
clean.

### 1.8 The console's command table (console.gd:7-50)

`COMMANDS` is one dictionary of usage and help lines, and `run` is one `match`. It is already
the simple shape; nothing to take out. Leave.

### 1.9 Left alone on purpose

- `GameSettings` (715 lines, 28 functions): settings and key bindings in one class, said
  "maybe later" on Nov 6. Still readable; split only if it crosses the 20-public-methods
  lint limit.
- The hand-written `to_dict`/`from_dict`, `Builder`/`Crafting` shortfall loops, the stork and
  goose-flock state machines (297 and 235 lines): long but linear.

## 2. Restructuring for code quality

In order; each is one worker's task. Items 1 to 3 do not touch data/; 4 and 5 are the
data/ restructuring itself.

### 2.1 `main.gd` (807 lines, 44 functions, touched in 107 commits since Nov 1)

Its `_process` (main.gd:348-405) does nine things a frame: tick the clock, weather, tide,
coordinates HUD, use highlight, name tag, build-mode visibility, pass-out check, walking,
ground items, bed cover, door, livestock, NPCs, focus, debug. Readable but it is where every
feature lands. Two moves that keep it in one scene:

- a `PlayScreens` or `Screens` object for the `_screens` list and the five functions around
  it (`_is_any_screen_open`, `_close_topmost_screen`, `_close_all_screens`, `_screens_take`,
  `_open_menu`: ~70 lines);
- the hold/ride/weather/clock debug applications (`_apply_game_options`, `_hold`, `_ride`,
  `_force_weather`: main.gd:673-776, ~100 lines) into `DebugRunner`, which already owns the
  "once drawn" steps. `StartupOptions` parses, `DebugRunner` applies: one place.

Both are pure moves. Size M, risk low (tests/test_screens.gd, the screenshot targets).

### 2.2 `world_view.gd` (844 lines) and `wildlife_view.gd` (462)

Both under the lint limit after the Nov 6 split. `WorldView._process` is already budgeted
(`REFRESH_BUDGET_USEC`, `MAX_LOADS_PER_FRAME`). Nothing to do now; the falling trees
(`_update_falling_trees`, ~60 lines) would be the next thing to take out if it grows.

### 2.3 Signals versus polling

The views follow state signals (`tile_changed`, `NightUpkeep`), and only the per-frame
things poll (walking, livestock, NPCs, build-mode visibility). `_coordinates_hud.show_position`
builds the weather text every frame while visible (main.gd:354-357; the hidden case is
already skipped). `_npc_name_tag.show_over(Interaction.npc_to_chat(...))` runs
`npc_to_chat` every frame; it walks the NPC list. Both are cheap today (a few villagers).
Leave; note in architecture.md that `_process` polls and signals redraw, so new work goes to
the right side.

### 2.4 The save-file upgrade chain

After 1.1 the chain is a list; it keeps growing one function per version (22 so far, ~350
lines of upgrades). That is the right price for strict `from_dict`. Two things to keep it
honest: `test_save_upgrade.gd` (334 lines, the biggest test) should keep one saved JSON per
version under tests/saves/ instead of building dictionaries in code, so a worker can read
what a version 7 save looked like; and the upgrades older than the oldest save anyone has
could be folded ("this game reads versions 12 to 23") once the user says no older save
exists. Size S each, decide later.

### 2.5 The data/ restructuring (TASKS.md "Later", one folder per entity)

What fits it, in order: (a) 1.6 items and objects to cfg; (b) 1.5 the animals' numbers into
wildlife.cfg; (c) crops already come from crops.cfg, and `ItemTypes`/`WorldObjectTypes`
merge them in code: once (a) is done the merge is a cfg include or one folder per crop
(seed item, produce item, object type and sheet together); (d) 1.3 one loader. The rules
classes stay: they are the typed, validated view on a file, which the game needs anyway.

### 2.6 Folders for game/state/ and tests/

game/state/ has 70 scripts flat, tests/ 179. The previous review said "maybe later". Still
fine with class_name lookup, but tests/ at 179 files is where a newcomer searches longest:
`tests/state/`, `tests/scenes/`, `tests/world/` mirroring game/ (and `-ginclude_subdirs` in
the Makefile) is a mechanical move. Do it after the sharding (section 3), since the shard
script lists files. Size S.

## 3. Performance

### 3.1 Runtime

Nothing alarming in the per-frame code. `WorldView._process` is budgeted; `WildlifeView`
ticks on a timer (`tick_seconds`) and only removes gone animals per frame;
`Livestock.update` and `Npcs.update` run per frame but over a dozen entities. Small
things, none worth a task alone:

- main.gd:354 `_weather_and_sun_text` builds a String per frame while the coordinates HUD
  is shown (debug only).
- main.gd:369 `Interaction.npc_to_chat` per frame: a list walk; fine until villages grow.
- `TerrainTileset._init` and `ObjectTileset._init` build their TileSet from the atlases every
  time a view is made (terrain_tileset.gd:178-203): one time at runtime, so no runtime cost,
  but see 3.3 for the tests.

### 3.2 Where the 171 s go (measured today, full run with `-gjunit_xml_file`)

Today's run: GUT 152.1 s for 1656 tests in 169 files; the per-test sum is 150.5 s, so the
tests themselves are the time; the rest (~19 s) is Godot's start, the import pass (2 s) and
loading 179 scripts. A single file run costs ~1.0 s of process overhead (test_game_state:
1.9 s wall, 0.93 s GUT). `GameState.new_game` is cheap: ~0.09 s (10 tests with it in
`before_each` run in 0.93 s). Building a `WorldView` is not: ~0.3-0.45 s each.

Spread: top 5 files 42 s (28%), top 10 68 s (45%), top 20 99 s (66%), the other 149 files
52 s. So fixing the top tests helps, but only sharding changes the order of magnitude.

Top 20 files:

    13.81s   4 tests  test_world_view_tiling.gd
     7.31s  16 tests  test_world_view_looks.gd
     7.18s  13 tests  test_snow_cover.gd
     6.87s  16 tests  test_vegetation.gd
     6.62s  15 tests  test_harvest_animations.gd
     6.56s  11 tests  test_storks.gd
     5.72s   9 tests  test_language_model_page.gd
     5.02s  14 tests  test_game_sounds.gd
     4.80s  11 tests  test_world_view.gd
     4.44s  18 tests  test_weather.gd
     4.04s  13 tests  test_shovel.gd
     4.00s  18 tests  test_npc_memory.gd
     3.79s   7 tests  test_geese.gd
     3.45s   7 tests  test_cats_and_mice.gd
     2.95s   8 tests  test_ambience_sounds.gd
     2.79s   6 tests  test_climate.gd
     2.66s   5 tests  test_mice_and_frogs.gd
     2.38s  16 tests  test_reeds.gd
     2.30s  13 tests  test_open_ai_chat.gd
     2.12s   8 tests  test_coast.gd

Top 20 tests:

     6.87s  test_world_view_tiling :: test_loading_in_any_order_matches_a_full_redraw
     6.75s  test_vegetation :: test_the_fraction_of_present_spots_changes_smoothly_from_day_to_day
     5.84s  test_snow_cover :: test_it_is_gone_by_the_first_day_of_spring_over_seeds_and_years
     5.00s  test_language_model_page :: test_changing_the_endpoint_asks_again_after_a_moment
     4.03s  test_world_view_tiling :: test_chunks_loading_between_refresh_steps_match_a_full_redraw
     2.09s  test_world_view_tiling :: test_lush_and_dry_overlays_have_the_shape_of_their_grass
     2.08s  test_climate :: test_it_is_never_below_freezing_and_never_snows_outside_winter
     1.36s  test_weather :: test_snow_falls_in_winter_and_never_in_midsummer
     1.24s  test_shovel :: test_a_clay_spot_shows_a_faint_hint_until_it_is_dug
     1.20s  test_reeds :: test_no_reeds_stand_in_the_water_or_on_grass_away_from_ditches
     1.11s  test_npc_memory :: test_without_a_model_the_dropped_lines_are_remembered_plainly
     0.95s  test_snow_cover :: test_a_thaw_clears_the_ground_within_a_few_days
     0.82s  test_world_view_tiling :: test_unloading_a_chunk_erases_every_layer_and_overlay_in_it
     0.80s  test_coast :: test_an_ewer_lies_on_three_tiles_of_mud_and_blocks_the_way
     0.70s  test_world_objects :: test_dead_trees_are_more_common_near_wetland
     0.67s  test_world_objects :: test_every_natural_object_type_is_generated
     0.66s  test_storks :: test_a_stork_leaves_a_roof_whose_house_is_gone
     0.61s  test_world_view_looks :: test_a_refresh_is_spread_over_frames
     0.61s  test_storks :: test_a_roof_takes_one_stork
     0.61s  test_npc_dialogue :: test_a_model_that_gives_nothing_gets_a_scripted_line

The JUnit file is build-independent: add `-gjunit_xml_file=build/junit.xml` to `make test`
and the ranking is free every run (the script that made the tables above is
`tools/`-sized: 25 lines of Python).

### 3.3 What makes them slow, and what to do

a. **Sharding (the big one): 171 s to about 25 s.** GUT's `-gtest` takes a comma-separated
   list of scripts, and `make test` already isolates `user://` with `XDG_DATA_HOME`. A
   `make test` that splits tests/*.gd into N lists (longest-first by the last junit.xml, or
   just round-robin by size), runs N headless Godots at once, each with its own
   `XDG_DATA_HOME=build/user-data/N` and `-gjunit_xml_file=build/junit-N.xml`, then does
   today's checks on every log (scripts that failed to load, zero tests, the Warnings,
   Orphans and "leaked at exit" lines) and sums the counts. With N=8 on 22 cores: the
   longest file is 13.8 s, so a balanced shard is ~19 s of tests plus ~2 s of process start,
   plus the import pass once: about 25 s wall. N=4: ~40 s. The per-commit verify loop gets
   6-7 times faster. Risks: tests that depend on another file's side effects (none seen: each
   file makes its own state, and `static var _default` caches are per process); CPU
   contention with the other worktrees' runs (N=8 leaves 14 cores). The log output changes
   from one stream to N; keep `build/test.log` as the concatenation. Size M.

b. **Tiling: 13.8 s for 4 tests.** `test_loading_in_any_order_matches_a_full_redraw`
   (tests/test_world_view_tiling.gd:116) loads 4 chunks in 2 orders on every day of `DAYS`,
   with a full redraw to compare each time. Days could be three (winter, thaw, summer) and
   the orders reduced to the forward and one shuffled order; the second test the same.
   Saves ~8 s. Size S.

c. **Vegetation smoothness: 6.75 s.** tests/test_vegetation.gd:127 counts spots for every
   kind on each of 365 days. Sample every 7th day (the assertion is about neighbouring
   days, so compare day d and d+1 at 52 points) or halve `SPOTS`. Saves ~5.5 s. Size S.

d. **Snow cover: 5.8 s.** tests/test_snow_cover.gd:92 builds a `Weather` for 20 seeds and
   simulates 3 years each. 20 seeds is more than the claim needs; 6 seeds saves ~4 s. The
   other snow and weather tests (test_climate 2.1 s, test_weather 1.4 s) are the same shape:
   many seeds, a whole year. Size S for all three.

e. **A real 5 s wait.** tests/test_language_model_page.gd:108 awaits
   `wait_until(..., 5.0)` and takes 5.00 s exactly: the predicate never turns true, so it
   runs to the timeout, and the assertion passes anyway through the answer that arrives
   after it. Either the predicate is wrong or the wait is useless; fix it and the test takes
   the 0.6 s `models_delay_seconds` says. Saves ~4.4 s. Size S. Also `wait_seconds(0.3)`
   in test_ambience_sounds.gd:67 and test_audio_service.gd:178-181: fine.

f. **View fixtures: 18 files build a WorldView or WildlifeView per test, 67.6 s together.**
   `WorldView.new()` builds a `TerrainTileset` and an `ObjectTileset` from the atlases each
   time (terrain_tileset.gd:178-203: an atlas source per season look, decorations, clay hint)
   and loads the textures; ~0.3-0.45 s a test (test_world_view_looks: 7.3 s for 16 tests
   whose `before_each` is three lines). Two ways, the first is better:
   - build the TileSet atlas sources once per process in a `static var` and give each view a
     copy (`tile_set.duplicate()` is cheap; the materials set per view by `_set_motion` stay
     per instance). The game also makes a WorldView once per interior switch, so it gains
     too. Expected saving: 20-30 s over the suite. Size M, risk medium (the tileset's
     materials and the `AmbientMotion` hook need care; verified by `make screenshot`).
   - or share one WorldView per file in `before_all` and unload/reload chunks in
     `before_each`: more edits (18 files), and tests lose their clean start. Not this.

g. **Shovel: 4 s.** tests/test_shovel.gd:14-22 scans 96x340 tiles in `before_all` (fine,
   once) but loads the chunks of 120 clay spots in `before_each` (13 tests). Twenty spots
   would do for every assertion in the file. Saves ~3 s. Size S.

h. **NPC memory and dialogue: 4 s + 1.5 s.** Each test spins up a `FakeChat` and awaits a
   reply; the 1.1 s test (test_npc_memory.gd, "dropped lines are remembered plainly") is
   worth a look: a fake should answer the same frame. Size S, check by hand.

Taken together, b to g save 45-55 s of the 152 s single-process time; with sharding on top
the wall time is set by the longest shard, so the big files (tiling, looks, snow) matter
twice: they bound the shard.

### 3.4 Test duplication

test_world_view.gd (11 tests), test_world_view_looks.gd (16) and test_world_view_tiling.gd
(4) overlap in what they assert (a chunk's codes after load/unload); worth a read while
doing b, but no merge is needed for speed. The `*_case.gd` fixtures (8 files, used by 66
test files) already keep the fixture code in one place; good.

## 4. Quick wins and larger projects: the task list

Quick wins (S, one worker each, in this order):

1. **Test sharding in `make test`** (M, not S, but first because it pays for everything
   after). Makefile (+ a 30-line shell or Python splitter in tools/), N from `nproc`,
   default 8, `JOBS=1` for the old single run; junit per shard; merged checks. Gain: 171 s
   to ~25 s per run. Also write `-gjunit_xml_file` into every run, and a `make test-times`
   that prints the top files and tests from it.
2. **The slow tests cut to size** (S): tiling days and orders (3.3b), vegetation sampling
   (3.3c), snow/climate/weather seeds (3.3d), shovel spots (3.3g), the 5 s wait (3.3e).
   Files: tests/test_world_view_tiling.gd, test_vegetation.gd, test_snow_cover.gd,
   test_climate.gd, test_weather.gd, test_shovel.gd, test_language_model_page.gd. Gain:
   ~25 s single-process, and the longest shard halves.
3. **Save upgrade chain as a list** (S): game/state/save_file.gd:84-127 and the header rule.
   Gain: 40 lines, one step less per version.
4. **`DataFile.missing_keys`** (S): game/state/data_file.gd plus the 11 rules files. Gain:
   60 lines, one shape for the check.
5. **Animals: `dismiss` into `Animal`, numbers into wildlife.cfg** (S): game/scenes/wildlife/
   rabbit, squirrel, deer, frog, mouse, bee.gd and data/wildlife.cfg. Gain: 70 lines, tuning
   in data.
6. **Delete `FallingTree.has_landed`** (S): game/scenes/falling_tree.gd; nothing calls it.

Larger projects (M/L), after the quick wins:

7. **Tilesets built once per process** (M): game/scenes/terrain_tileset.gd,
   object_tileset.gd, world_view.gd. Gain: 20-30 s single-process; shards shorter. Verify
   with `make screenshot` and the looks tests.
8. **`main.gd` slimmed again** (M): the screens list into one object, the debug applications
   into `DebugRunner`. Gain: ~170 lines out of the most-changed file.
9. **Items to data/** (L): game/state/item_types.gd to data/items.cfg (or one folder per
   item, per the TASKS.md note), `ItemRules` with required keys, `asset_check.gd` follows.
   Gain: ~450 lines of code, validated data, no import pass to add an item.
10. **Objects to data/** (L): game/state/world_object_types.gd the same way, crops and
    trunks merged from the crop folders. Gain: ~500 lines. Do after 9; together they are the
    data/ restructuring's first two entities.
11. **One loader for the rules classes** (S, after 9 and 10): `DataFile.load_or_report`.
    Gain: ~150 lines.
12. **tests/ in folders mirroring game/** (S, after 1): `-ginclude_subdirs`; the shard list
    takes a glob.

Not checked by hand: whether any test relies on running after another file (sharding would
show it on the first run); the exact tileset-sharing gain (measure by timing
test_world_view_looks.gd before and after).

Measurements were made with the junit.xml of one full run today on this machine while other
worktrees were idle-to-light; a second run would move the numbers by a few percent.
