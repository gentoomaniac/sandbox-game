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
- **Art:** the row `scarecrow` of the object atlas and the item icon, in both art sets.
