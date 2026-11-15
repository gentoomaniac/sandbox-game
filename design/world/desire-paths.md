# Desire paths

Grass that is walked on often wears into a path, and grows back when it is left (decided
2026-11-06, task 77; the user, 2026-11-14, [#61](https://github.com/gentoomaniac/sandbox-game/issues/61):
it was too fast, wear needs days, not only steps). All numbers are in `data/paths.cfg`
(`PathRules`); the state is `World`'s.

## What wears

- Only grass (ordinary, lush, dry) and the floodplain wear. Fields, wetland, water, buildings
  (their doors too) and the insides of houses don't. Tilling a path clears its wear.
- Every tile the player steps onto outdoors takes a step (not with noclip). A farm animal or a
  villager takes half a step onto each tile it walks onto, loaded or not (far walkers wear by the
  `WEARS` bit of their `TravelMask`, `World.wear_unloaded`).
- A path is a look only: it walks, tills and builds like grass (except in mud, below).

## Wear takes days

- The steps a tile takes are counted per day (`World._steps_today`). A day on which a tile took
  at least `busy_steps` (10: the player crossing it ten times, or twenty villager steps) is a
  busy day.
- Each tile that is worn, or was walked on today, has a count of days (`World._wear_days`). At
  midnight (`World.end_wear_day`, from `NightUpkeep` with the other nightly upkeep, so no
  per-frame work and nothing for unloaded chunks to do: both tables are plain dictionaries by
  world position) a busy day adds one to the count, up to `most_days` (12), and any other day
  takes `quiet_day_loss` (1) off it. A tile with no days left is grass again and forgotten.
- From `trodden_after_days` (3) the tile is trodden, from `path_after_days` (8) it is a path. So
  a tile is trodden after three busy days in a row and a path after eight. A path that has been
  walked for a long time (12 days) is trodden again after 5 quiet days and grass after 10; one
  that has just formed is grass after 6.
- **Quiet days take days off, they do not reset the count** (chosen): one missed day in a week of
  walking costs a day, not everything, and a worn way grows back about as slowly as it formed.
  "Days in a row" is therefore a little loose: a tile that is walked on every other day never
  gets anywhere, since each quiet day takes off what the busy one added.
- The look only changes at midnight: nothing changes under the player's feet while they walk.
  Every midnight of a time skip (sleep, passing out) is counted like those of play. The steps
  villagers take in a skip are added at its end, so they count for the day it ends in only.
- Only the tables of worn tiles and of today's steps are kept: a tile that was stepped on once and
  not again is gone at the next midnight.

## Mud

- Worn ground (trodden grass and paths) turns to mud in the rain and dries out again, so that a
  laid road, which does not wear and does not get muddy, is worth building (#62).
- **When** (`[mud]` of `data/paths.cfg`): the ground is muddy when the rain of each of the last
  `window_hours` (10) hours, added up (an hour of downpour is 1, of drizzle 0.1), is at least
  `soaked_by` (1.5). A shower of an hour or two makes no mud, a few hours of steady rain do, and it
  dries out 10 hours after the rain stopped (less in a break: the sum falls as the rain hours leave
  the window). It follows from the weather alone (`Weather.rain_in_hour` where the player sees the
  weather, as for `last_hour_rain`), so nothing about it is saved: a loaded game works it out
  again at its first hour. A forced weather (console) rains steadily.
- `GameState.refresh_mud` decides once an hour (main calls it with the soil's hourly refresh) and
  tells `World.set_muddy`. The flag is the world's, not a tile's: a tile is muddy
  (`World.is_muddy_at`) when it is worn and the flag is on, so no per-tile state, no scan.
- **Drawn:** `TerrainTileset.Layer.MUDDY_TRODDEN` and `MUDDY_PATH`, two more terrain layers
  of the same shapes as the dry ones, over them (dark wet earth with glints of standing
  water, both art sets; the same in every season). When the flag changes, `World` emits
  `tile_changed` for every worn tile of the loaded chunks, once per change of weather, and a
  chunk that loads is drawn with the flag as it is.
- **Slower:** the player walks at `walk_factor` (0.7) of their speed on a muddy tile
  (`GameState.walk_speed_factor`, so their walk animation slows too). Not on horseback: a horse's
  pace is its own and nothing slows it.
- **Villagers and animals walk at normal speed in mud, and path searches don't mind it** (decided
  after looking at the design). The `TravelMask`s are immutable snapshots of a chunk and know only
  that grass wears (`WEARS`), not how worn it is or whether it rains; the cost of a lane is read from
  the periodic `TravelSnapshot`. A rain that made many tiles muddy could not touch the masks,
  but a mud cost in `TravelView.cost_of` would only make villagers dodge puddles that do not
  slow them, and slowing them is not clean: far walkers move along masks and the skip
  (`catch_up`) computes where a trip is after N minutes from a fixed speed, so a speed that varies
  by tile and by the weather would need the world's wear and the rain in both and agree between
  them. Animals have no searches and wander in their pens at their own pace. If it is wanted
  later, the place is the cost of a lane in `TravelView.cost_of` (rain flag in the snapshot) for
  routes, and a speed factor in `Npcs._walk` for the live ones only, accepting that the skip
  ignores it.

## Saved

`world.wear`: `[x, y, days]` for each worn tile, and `world.wear_today`: `[x, y, steps]` for the
steps of the day in progress (save version 43). A save of version 42 kept steps: a tile with 8 or
more steps is trodden (3 days), with 24 or more a path (8 days), and no tile has taken steps
today.

## Art

Trodden grass and the path, and their muddy looks, are dual-grid layers over the grass with soft dithered edges, in
every season's look and the frost (`tools/art/terrain.py` and `tools/art/classic/terrain.py`). Their
full tiles are an even colour with single specks and no stamps
(`tools/art/test_worn_ground.py`), so a worn yard reads as one joined patch. Snow covers paths,
with a faint trodden track over them; in a bare winter the earth lies dark.
