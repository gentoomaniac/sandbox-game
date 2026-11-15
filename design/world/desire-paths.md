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
- A path is a look only: it walks, tills and builds like grass.

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
  Every midnight of a time skip (sleep, passing out) is counted like those of play.
- Only the tables of worn tiles and of today's steps are kept: a tile that was stepped on once and
  not again is gone at the next midnight.

## Saved

`world.wear`: `[x, y, days]` for each worn tile, and `world.wear_today`: `[x, y, steps]` for the
steps of the day in progress (save version 43). A save of version 42 kept steps: a tile with 8 or
more steps is trodden (3 days), with 24 or more a path (8 days), and no tile has taken steps
today.

## Art

Trodden grass and the path are two dual-grid layers over the grass with soft dithered edges, in
every season's look and the frost (`tools/art/terrain.py` and `tools/art/classic/terrain.py`). Their
full tiles are an even colour with single specks and no stamps
(`tools/art/test_worn_ground.py`), so a worn yard reads as one joined patch. Snow covers paths,
with a faint trodden track over them; in a bare winter the earth lies dark.
