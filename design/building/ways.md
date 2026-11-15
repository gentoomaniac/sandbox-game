# Ways: a plank walk and a stone path

The user, 2026-11-14, [#62](https://github.com/gentoomaniac/sandbox-game/issues/62), answering #57:
proper roads the player makes, so desire paths and mud ([desire-paths.md](../world/desire-paths.md))
can be fixed. Made and placed a piece a tile like the fence and wall pieces
([fences-and-walls.md](fences-and-walls.md)).

- **Ground objects, not terrain** (chosen). `plank_walk` and `stone_path` are world objects with
  `deck` (walked on, drawn under whoever stands on it, not trampled by villagers) and `way` (below).
  Terrain would be an edit of the ground with a save of its own; an object is saved like any placed
  object (type and tile), so there is no save change, and taking one up is the usual take-down.
- **Where:** `placed_on` the dry ground and not the tilled soil (a field is for crops: take the way
  up and till). The plank walk goes on grass, a Warft, the floodplain, tidal mud and the salt marsh
  (so it is a jetty of the land, a walk through the flats); the stone path only on the dry three.
  Nothing goes on water. The rules of a free tile are the jetty's: no object or building there, none
  in front of a door on land, none on the player. A hoe does not till a way.
- **Recipes** (data/recipes.cfg):
  - `plank_walk`: made at the workbench, woodworking 5; 2 planks make 2 pieces.
  - `stone_path`: made by hand, masonry 5; 2 stone make a piece.
- **Taken up** with the matching tool, for the piece (`drops` is the item itself, one piece for one):
  the axe for the plank walk (2 hits), the pickaxe for the stone path (3 hits). A piece never gives
  back more than it cost. Unlike the jetty (over water), a way can be taken up from under the
  player's feet: it has ground under it.
- **Art:** both in both art sets, atlas rows 60 and 61 (`tools/art/ways.py`): full-tile pieces with
  no connection masks, 2 variants of the planks and 3 of the cobbles, in every season's look.
- **They never wear and never turn to mud, and are walked a little faster** (chosen: 1.1, `[way]`
  of data/paths.cfg, a reward for the work, not much). Laying one clears the wear beneath. How is in
  [desire-paths.md](../world/desire-paths.md#ways). A way over flooded mud (the plank walk) is walked
  dry-shod, at the same speed, like a jetty.
