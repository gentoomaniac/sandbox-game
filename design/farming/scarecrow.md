# The scarecrow

The user, 2026-11-13, with the crows (task 225): a craftable scarecrow that keeps the crows off the
crops, placed wherever the player wants ("wherever you want, it'll have effect in a certain
radius"). This page is task 226.

- **Made by hand** (data/recipes.cfg, `scarecrow`): 1 log for the stakes, 6 hay and 4 fibre. The
  game has no cloth or old coat to dress it in, so the straw stands for them.
- **A world object** (`WorldObjectTypes.SCARECROW`, 1x1, blocks walking, outdoors only like the
  kiln and the fences): the item puts it down on any tile that can be built on, as the player
  places a chest. The axe takes it down in 2 hits and the hammer's take-down mode takes it down
  too, either for the item. It is saved like other placed objects (type, tile, state).
- **It remembers the day it was put down**: `placed_day` in the object's state, set by
  `ToolUse` when it is placed. Taking it down and putting it up again is a new scarecrow with a new
  day; that is what moving one is.
- **Where they stand is indexed**: `World` keeps the tiles of the scarecrows among its object
  edits (`scarecrows()`, kept by `_edit_object` like the crops), so nothing scans all the objects
  of the world, and a scarecrow in an unloaded chunk still counts. Only player-placed ones are
  there.
- **The guard** (`Scarecrows`, numbers in data/crows.cfg `[raids]`): a scarecrow has a *strength*
  from 0 to 1 by its age in days (today minus `placed_day`; one without a day, e.g. from an old
  save or the console, counts as new): 1 for `scarecrow_fresh_days` (3), then falling evenly over
  `scarecrow_fade_days` (12) to `scarecrow_floor` (0.25), where it stays: the crows learn to
  ignore it, slowly, and never fully. Moving it (taking it down and putting it up) starts it
  anew. A tile within `scarecrow_radius_tiles` (5, measured to the scarecrow's tile) is guarded
  with the chance of the strongest scarecrow's strength: `PositionHash.rolls` of the tile and the
  day, so a tile is either guarded for the whole day or for none of it. That is
  `Scarecrows.is_guarding`, which `GameState` sets as `CropRaids.is_guarded`: a guarded crop is
  not tried by a raid.
- **Crow flocks stay away**: the spawner does not settle a flock of crows on a spot guarded by a
  scarecrow with the chance of the strength there (`WildlifeView._is_drawn_to`), so a field with a
  fresh scarecrow draws no flock at all, and one the crows know draws them nearly as before. A
  flock already there is not driven off; it just finds the crops guarded.
- **Art:** the row `scarecrow` of the object atlas and the item icon, in both art sets.
