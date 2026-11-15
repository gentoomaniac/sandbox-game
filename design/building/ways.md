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
- **Art:** both in both art sets, atlas rows 60 and 61 (`tools/art/ways.py`), in every season's
  look. A way is a line object (`connects`: the group `way`, so either kind joins the other, see
  [fences-and-walls.md](fences-and-walls.md)): a picture per connection mask of the 4 sides, 4
  variants of the planks and 3 of the cobbles. The mask is computed at draw time from the world
  (nothing is saved) and the piece is drawn again when a way beside it is laid or taken up (the
  view redraws the 4 sides of a changed tile, as for the fences). The diagonals do not count.
- **Edges** (#84, the user's verdict on the first look): a way is not a straight band.
  - Beside another way a piece runs on flush, no edge and no gap: laying a second way along the
    first makes a road of any width that still has a clean edge on both outer sides.
  - On a side with no way the edge is irregular: the plank walk's boards stop a pixel or three short
    of the side, each its own length, some with a corner sawn off, and the outer board is chipped;
    the stone path has a kerb of edging stones (each its own depth from the edge, the corners
    rounded) that holds the cobbles together.
  - Planks vary: 3 to 5 px wide, patterns per variant, a butt joint here and there and a knot (the
    eye of a branch) in some tiles. The widths of every variant add up to the tile, so the boards
    of tiles above and below meet at their gap. The variant is picked by the row (or column) the
    boards lie in, not by the tile (`WorldObjectWays.variant_tile`), so the boards of a road two
    tiles wide have the same widths side by side and line up across the seam.
- **Which way the boards lie** (#84, rule chosen): across the way, perpendicular to the road's
  direction, worked out from the neighbours (`WorldObjectWays.boards_lie_east_west`, the same rule
  in the art for every mask):
  - a way runs along the axis that has more neighbours on it. A run north to south has boards
    lying east to west; a run east to west has boards lying north to south;
  - a way's end (one neighbour) lies as its run does;
  - a T lies as the run it is on does: the tile where the stem leaves has two neighbours on one axis
    and one on the other, so the axis with two wins;
  - with as many on both axes (a corner, a crossing, a tile alone) the boards lie east to west. A
    tile alone has no direction to be across (it is not saved which way it was laid from), so it
    takes this default; the next piece laid beside it gives it one.
  A way of the other kind counts as a neighbour: where a plank walk leaves a stone road, the road
  joins it flush.
- **They never wear and never turn to mud, and are walked a little faster** (chosen: 1.1, `[way]`
  of data/paths.cfg, a reward for the work, not much). Laying one clears the wear beneath. How is in
  [desire-paths.md](../world/desire-paths.md#ways). A way over flooded mud (the plank walk) is walked
  dry-shod, at the same speed, like a jetty.
- **Villagers use them** (cost, not speed, like the lanes): a tile with a way costs what a worn path
  does (`cost_path` of data/npcs.cfg, 0.6; the mask's `WAY` flag, read in `TravelView.cost_of`).
  The mask is dropped when a way is laid or taken up, as for any object edit. A way is free for them
  like a deck, and the grass of a far chunk with one on it takes no steps (the mask's `wears`).
  They walk at their own pace on it: only the player's is faster (see the pathfinding design for
  why a speed that varies by tile stays out of the skip).
