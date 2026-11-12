# Plan for task 199: process stations (the kiln and the oven)

The design is settled in TASKS.md (task 199); this is how the code does it.

## Data

- `data/stations.cfg`: a station is a process station by its keys
  - `process=true`;
  - `grid=Vector2i(3, 3)`: the columns and rows of its load grid;
  - `button_icon="fire"`: the picture on its activation button, `assets/ui/process_<icon>.png`.
  The kiln and the oven get all three; the workbench and the hearth none (today's menu).
- `data/recipes.cfg`:
  - every recipe of a process station has `hours`, and only those have it;
  - a new optional key `bonus=[[50, 0.25], [70, 0.5]]`: from that many points of the recipe's
    skill a run makes that share of its count extra (rounded down), the highest share reached;
  - the kiln: one `bricks` recipe, 6 raw bricks and 2 logs make 6 bricks in 12 hours, with the
    bonus above (bricks_large and bricks_master go);
  - the oven: logs and hours on its three recipes (bread 2 from 4 flour and a log in 1 hour, a
    berry tart 2 from 2 flour, 12 berries and a log in 1.5 hours, a feast cake from 2 flour,
    4 strawberries, 4 berries and a log in 3 hours); their levels stay.
- A run practises its skill at the level of the highest bonus reached (at least the recipe's
  level), so masonry still teaches up to 100 with the one Bricks recipe, as the master's firing
  at 70 did.

## Classes

- `ProcessLoad` (game/state/process_load.gd): the filter rule, pure. Made with the recipe rules,
  the station's recipe ids and its slot count; every question takes the grid's contents (item
  id to count) and changes nothing.
- `ProcessStation` (game/state/process_station.gd): one process station as the player uses it,
  over the WorldObject (its `storage` is the grid, its `state["run"]` the run): what goes in,
  a recipe click, the activation, the results out. Static `settle` and `is_running` for
  readers without a player (taking it down).
- `StationRules`: `is_process`, `grid_size`, `button_icon`, `slot_count_of(object_type)`.
  WorldObject makes its `storage` for a process station as for a chest (the same save field).
- `ProcessScreen` (game/scenes/process_screen.gd), a Modal, and `ProcessRecipeRow`; Main opens
  it for a process station instead of the crafting menu.
- Crafting loses the slow recipes, and StationWork goes (its work becomes a run).

## The filter rule

The grid's contents must always be part of whole loads of at least one recipe that the player
may make (not locked), at an amount that fits the grid:

- `most_loads(r)`: the most loads n whose materials (n × each material) and products (at the
  recipe's top bonus) each fit the slot count, counting slots as Σ ceil(count / stack limit).
  The grid stays packed (stacks merge as they go in and only whole stacks come out), so that
  count is what the slots hold.
- `loads_holding(r, C)`: −1 when an item of C is not a material of r, else the fewest loads
  that hold C: max over the items of ceil(C[i] / m[i]) (0 for an empty grid).
- r is **open** when 0 ≤ loads_holding ≤ most_loads and most_loads ≥ 1.
- **room for** an item: the most over the open recipes that take it of
  most_loads × m[item] − C[item]; 0 if none. A drag or shift-click moves at most that many.
  The inventory greys the stacks with no room.
- **whole loads**: n when C is exactly n loads of r (n ≥ 1), else 0. The activation runs the
  first recipe (in the order of recipes.cfg) with whole loads; a part load keeps the button
  greyed with what is missing for the next whole load of the first open recipe.
- **amounts**: from max(1, loads_holding) to the least of most_loads and, for each material,
  (C[i] + carried[i]) div m[i]. Max sets the top; the field and +/- stay within. A recipe whose
  top is below its bottom, that is locked or not open is greyed. A click moves
  amount × m − C of each material from the inventory into the grid.

## The run

- `state["run"] = {recipe, start_minute, done_minute, products}`; the grid keeps the
  materials, greyed and locked, while it runs. `settle` (when the clock is past
  `done_minute`) empties the grid, puts the products in and drops `products` from the run,
  which stays until the grid is empty again: until then nothing goes in or starts, and the grid
  only lets things out. Nothing ticks; whoever looks settles first.
- The time is the recipe's `hours` per run, whatever the amount; the skill is practised once
  per run.

## The window

```
 Kiln
 Masonry 52.0
 +----------------------+   [=====-----]       [backpack]
 | [icon] Bricks x6     |   +--+--+--+         5 x 4 slots
 |  Raw brick 6, Logs 2 |   |  |  |  |
 |  [-] [ 3 ] [+] [Max] |   +--+--+--+
 | ...                  |   |  |  |  |
 +----------------------+   +--+--+--+
                            [fire]  note
```

Left the recipe list (scrolls), in the middle the progress bar over the 3×3 grid and the
activation button with a short note, right the backpack; the hotbar is the HUD's, as in the chest
screen. SlotView gets a `move_rule` a screen can set to take over the drops onto and off a slot,
and `is_dimmed` for the greyed stacks.

## Save

Version 31: `_upgrade_from_version_30` gives every kiln and oven (in the world's object edits
and in interiors) an empty grid of 9 slots, and turns a kiln's firing (`state["work"]`) into a
run: its old load in the grid and its old count of bricks as the products, same done minute.
Before that, its own commit drops the upgrade from version 20. The validator checks the grid's
slots and the run.

## Commits

1. This plan, the recipe `bonus` key and `ProcessLoad` with its tests.
2. Save: drop the upgrade from version 20 (oldest read: 21).
3. Art: the fire icon of the activation button (tools/art/ui.py; like the other UI icons, one
   picture serves both arts).
4. Process stations in the shared code: StationRules keys, the grid as `storage`, ProcessStation
   (in, out, click, run, settle, bonus, practice level), the validator; tested with a station
   defined only in test config.
5. The window: ProcessScreen and ProcessRecipeRow, SlotView's move rule and dimming, Main opens
   it for a process station.
6. The kiln and the oven become process stations: the data, save version 31 and its upgrade,
   StationWork and the slow crafting go, taking down settles first, the `--process` debug flag
   for screenshots; README, design pages and docs/ui.md. One commit, as the save upgrade gives
   both their grids.
