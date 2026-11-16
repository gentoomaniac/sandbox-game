
# The storm surge (Sturmflut)

Plan for [#103](https://github.com/gentoomaniac/sandbox-game/issues/103), 2026-11-15, **approved
with all defaults, 2026-11-16** (the user was away and took the defaults of the open questions).
Built step by step; step 11 (player dykes) waits for #59. Numbers go in a new `[surge]` section of
`data/landscape.cfg` (the dykes' heights and the flood) and of `data/weather.cfg` (the chance),
first values, tune in play. See [coast.md](coast.md) for the sea, the tide, the dyke and the
Warften.

## What exists today (checked)

- `Tide` is a pure function of time and place (period 745 min, `HIGH_WATER` 1.06), used only for
  the mud; the sea has no level the land is measured against.
- The weather has `storm` (0..1, from wind: `[wind]` `strong_from` 8, `strong_full` 16 m/s), and
  autumn is the windy season (`wind_mean` 6, spread 5). The shore waves turn rough with `storm`
  already (`sea_storm_loop`, `SeaSounds`).
- `WorldObjectTypes.DYKE` is a turfed bank that slants (`LineSlants`). It has no value, and
  nothing builds or removes one yet (#59 is open). The generator makes it; only edits are saved.
- The terrain has **no height**: `Tile.Terrain` is GRASS, SOIL, WATER, WETLAND, FLOODPLAIN,
  MUD, SALT_MARSH, SEA, WARFT and so on. Tiles have `moisture` (`World.set_moisture`).
- Crops live in `CropLife`; the mud of rain and the wet ground (#54, #90) exist.

## When

- A surge needs **high water** (the tide's peak) **and** a heavy storm together. At each high
  water in the season the game rolls: chance `base_chance * storm^2` when `storm >= min_storm`
  (0.7).
- Season: autumn and winter (`[surge] first_day` to `last_day`), winter at half the chance. The
  first values give about one surge per game year.
- The surge's **water level** (metres over mean high water) is `level_min + (level_max -
  level_min) * storm`: 1.6 at a storm of 0.7 up to 3.2 at a full one, plus a little random. It
  holds for the 3 hours around high water, then falls. The roll comes from the world seed and
  the tide's number, so it is deterministic, like the weather.
- A debug command `surge [level]` starts one (like `weather`).
- **Built values** (`[surge]` of `data/weather.cfg`): the weather's `storm` never passes 0.37
  (it is the lesser of the rain and the wind's ramp), so the plan's 0.7 could never come. A storm
  counts as a share of `full_storm` (0.35), from `min_storm` (0.12); the strongest storm within
  the 3 hours around the high water counts; the chance is `base_chance` (1.1) times the share
  squared. Measured over 20 years of ten seeds that is about 1.1 surges per game year (0.4 to 2.2
  between seeds), at levels from 2.0 to 3.4 m.

## Dyke height and quality

Every dyke tile, generated or built, has two values:

- **height** in metres over mean high water,
- **strength** 0..1: how well it is turfed and packed.

**Generated:** height is 2.4 +- 0.8 from the generator's slow dyke noise, so a stretch of a few
dozen tiles shares one value and some stretches are low: the places a surge comes through. River
dykes are lower (1.0 +- 0.3); a river flood is not part of this plan. Strength is 0.6 +- 0.2.
They are computed from the seed on demand; only a tile the game changed is saved.

**Player-built** (needs #59, which adds building and removing a dyke; this plan adds the value).
A player's dyke holds back the tide and surges like the sea dyke:

- It starts at height 0.8, strength 0.3 (a heap of clay).
- **Higher:** each layer of clay (4 per tile, from the clay pit) adds 0.3 m, with spade work
  as for tilling. The top is 3.6 m, above the generated dykes, so a careful player is safe.
- **Better:** sods (cut turf, 2 per tile) laid on the slopes add 0.3 strength each, up to 1. A
  bare dyke stays weak.
- It is still walked on.

**At the surge**, for each dyke tile the water reaches:

- `level <= height`: it holds.
- `level > height`: the sea **runs over**; the tile is a breach that feeds the flood, and its
  height falls to 0.3 m.
- Holds, but `level > height - (1 - strength) * 0.5`: it is **damaged**, its height falls by
  `0.3 * (1 - strength)`. A weak dyke is torn, a strong one scratched.
- **Repair:** clay (and sods) with the work of building. The villagers mend a generated stretch
  after `repair_days` (6) so no hole stays for ever; the player's own they leave.

**How it shows:** a look per height (three in the dyke's atlas row: low under 1.5 m, normal,
high over 2.8 m) and a torn crest for a damaged one, so a weak stretch is seen from afar; and a
hover hint (`ActionHint`): "Dyke, 2.1 m, well turfed", with the forecast level while a surge is
coming.

## The flood

**Height field.** A pure function `Elevation.at(pos)` of the world seed, like `Tide`, never
saved (metres over mean high water):

- a base per terrain: MUD about 0, SALT_MARSH 0.8, WETLAND 0.8, FLOODPLAIN 1.0, WARFT 3.6, and
  GRASS and SOIL 1.2 at the dyke rising 0.02 m per tile inland up to 4.0 (the Geest);
- plus a slow noise of +- 0.3 m (its own seed offset), so the flood has a shape;
- the **Koog**, the first 36 tiles behind the sea dyke (the marsh's reach), is the lowest land
  (1.2 to 1.9 m), so a surge of 1.6 to 3.2 m fills it and stops where the ground rises.

**Filling.** From each breach, a flood fill (4 neighbours) over land tiles with `Elevation <
level`, at `tiles_per_second` (60) while the surge holds, with a **volume budget** per breach
(about 4000 tile-metres, depth `level - elevation` per tile): a big basin is only partly
filled, so a flood is a few tiles to a few chunks. Warften, the Geest, dyke tiles higher than the
level and inner dykes stop it.

**Staying and draining.** A flooded tile has a depth. The flood **lasts 1 to 2 game days**
(`stay_hours` 30 +- 12), then drains from the highest tiles first at the same rate. Nothing
drains it sooner (a sluice, the Siel, is a later idea).

**The water is an overlay**, not terrain: a shader like the mud's (`flood.gdshader`) fed by a
mask texture per chunk. The tiles' terrain is not edited while the water stands, so no chunk
rebuilds and no edit records to clean up. Rules read `World.is_flooded` for land too (the one
place `is_ground_walkable` already asks for mud): deeper than 0.35 m is not walkable (the player
wades as in #63), shallower is. Nothing is dropped on flooded ground.

**Afterwards:** a drained tile is wet at full moisture and muddy for `mud_days` (3), like the
wet ground of #54/#90, and dries as it does; desire paths there wear off faster. **Salt:** a tile
that stood under the sea carries `salt_days` (40 first value; rain takes a day off per rain
hour) and **spoils the field**: nothing planted on it grows, and the hover says "Salt: 31 days".

**Crops:** seedlings under water die at once; any crop still under over 0.1 m after a day dies
(`CropLife`). Tilled soil stays tilled; the salt is the harm.

**Things:** items on the ground under over 0.5 m of water drift 1 to 3 tiles inland, or are lost
(30 %). Fences, walls, houses and objects stand; chests and the inventory are never touched.
Wild animals leave by the wildlife's flee rule; farm animals and the horse walk to the nearest
tile above the level (as they leave flooded mud now, `test_livestock_tide`) and stay there. **Villagers** flee to the Warft or
the nearest dry ground when the warning is up (their paths already go round flooded ground),
their day plans held, and go home once it has drained.

## The warning

A surge is rolled at the high water before, so it is known **6 game hours ahead**:

- **Sky and wind:** the weather is forced to storm, a dark overcast with the wind rising to
  the surge's strength; grass and trees bend as in a storm now.
- **Waves:** `sea_storm_loop` (#97, #101) at full volume, and the surf drawn higher at the dyke
  foot.
- **Villagers' talk:** the language model gets "a surge is expected tonight, the dyke at
  such a stretch is low" in its context (`npc_prompt`).
- **The church bell:** a new sound (a sound-designer task), three strokes an hour at the warning
  and without a break from the first breach.
- A log line at the first breach: "The sea is running over the dyke".

## Performance

- The fill and the drain run from `GameState._process` on a **budget of tiles per frame** (a few
  hundred at most), with a queue and the wet set in a `FloodState`, never a scan of the world.
- The overlay mask is an image per chunk (a byte a tile), updated only when its tiles change. No
  chunk rebuild.
- Unloaded chunks are not simulated: the wet tiles are kept in the list, a chunk that loads gets
  its mask from it, and time spent away counts at once (a flood that ran out has drained).
- `Elevation` is cached per chunk when a fill reads it, as `Tide` keeps its tiles.

## Saving

The next free `SaveFile` version (50 today; the build checks), by the steps in `save_file.gd`.
Fields in `GameState.to_dict`, checked in `SaveValidator`:

- `surge`: whether one is active, its level, the tide number, when it started, its breach tiles
  and how far it has drained;
- the **wet tiles** per chunk (`[x, y, depth_cm, salt_days]`; one surge is a few thousand tiles at
  most) and when each drains;
- the **dyke edits**: per changed tile `[x, y, height_cm, strength_pct]`, among the world edits
  (`World.edits_snapshot`); untouched generated dykes are not saved;
- a `warned` flag, so loading in the warning hours does not roll again.

The upgrade from the old version gives an idle surge, no wet tiles and no edits, with a test in
`tests/test_save_upgrade*.gd`. Dropping the oldest upgrade is a commit of its own.

## Tests, the handbook and the pictures

- **Tests:** `Elevation` is deterministic and rises inland; the roll (no storm, summer, a full
  autumn storm; the same seed rolls the same); a dyke holds below its height, runs over above
  it, is damaged by its strength; the fill stops at higher ground and at the volume budget; the
  Warft stays dry; drain order; crops die, salt blocks planting and runs out; items wash away;
  walking in the flood; the save round trip and the upgrade; a player's dyke gains height from
  clay and strength from sods, taking the materials.
- **Handbook:** a page "The sea dyke and the storm surge": the signs, the hover, raising a dyke,
  what the salt does. `coast.md` links here; `generation.md`, `farming/crops.md` and
  `tech/saving.md` get a line each.
- **Pictures** (`docs/screenshots`, taken with `surge` on a seed): the dyke at its three
  heights, a surge over a low stretch, the flooded Koog with the Warft dry, a field after, with
  the salt hover.

## Steps (each atomic: code, tests and docs, passing `make test`)

1. `Elevation` and the `[surge]` data, with tests. Nothing uses it yet. **Built.**
2. Height and strength of the generated dykes, the hover hint, the three looks (pixel artist). **Built** without the three looks: the hover says "Dyke, low, 1.2 m, bare"; the pixel art (three heights and a torn crest in the dyke's atlas row) is still to draw.
3. Dyke edits in the world edits; the save version bump with its upgrade and validator check
   (then the drop of the oldest upgrade as its own commit). **Built** (version 55; the drop of
   the version 44 upgrade came first).
4. The roll (season, storm, high water, level) and the `surge` command; the log says one is
   coming, nothing floods. **Built** (`SurgeRoll`, `SurgeUpkeep`, `SurgeEvent`, `SurgeFlow`).
5. `FloodState`: breach rule, fill with budget and volume, drain; the flooded rules in `World`.
   **Built.** The sea meets the sea dykes of the chunks that are loaded when it rises (and of
   those loaded while it holds); a stretch far from the player is not flooded. The fill takes
   about 6 microseconds a tile: a step of 300 tiles measured under 2 ms, a whole flood of 5400
   tiles 30 ms.
6. The overlay: `flood.gdshader`, the chunk masks; the pictures. **Built** without the pictures
   (`FloodOverlay`, `FloodMask`, `flood.gdshader`): a mask of a chunk is made again in 0.35 ms
   at the most (1024 wet tiles), only for the chunks a batch of tiles touched. Checked that the
   shader compiles and draws; the pictures for the user come later.
7. Saving the surge and the wet tiles (a second version bump). **Built** (version 56; the drop of
   the version 45 upgrade came first). The fields are in the world's data, not the game's
   (`World.snapshot`); the wet tiles, their salt, the mud and the dykes to mend are `[x, y, value]`
   lists. The salt and mud days are set by the flood and saved, the harm that reads them is step 8.
8. The harm: crops, salt and its hover, wet ground after, items washing away.
9. Animals and villagers flee and return; the routines' hold.
10. The warning: forced storm, surf, talk, and the bell (the sound first, a sound-designer task).
11. Player dykes: clay and sods, raising, repair. Needs #59 merged; if not, this waits and the
    rest stands without it.
12. The handbook page, the screenshots, the doc lines; `coast.md` marks it done.

## Open questions (each answerable in a word)

1. **Season:** autumn and winter, winter at half the chance? Default **yes**.
2. **Rate:** about one surge a game year at the first values? Default **yes**.
3. **Duration:** 1 to 2 days (30 +- 12 hours)? Default **yes**.
4. **Salt:** a field spoiled for how many days? Default **40**.
5. **Items on the ground:** drift inland, 30 % lost? Default **yes**.
6. **Villagers mend a generated dyke** after 6 days? Default **yes**.
7. **Player dyke:** clay for height, sods for strength? Default **yes**.
8. **Dykes settle** over the years (height falls)? Default **no**.
9. **A river flood** in this plan? Default **no**, the sea only.
10. **Can a surge flood house floors?** Default **no**: walls and floors stand, the ground around
    them floods.
11. **Bell:** wait for the sound (steps 4 to 9 first)? Default **yes**.
12. **Save version:** the next free one at build time? Default **yes**.

