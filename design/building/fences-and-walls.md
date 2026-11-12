# Wattle fences and stone walls

The user, 2026-11-11: "Are the willow fences or the stone walls that the map generated creatable?
If not they should". The world generator lays both along field boundaries (task 31); since task 203
the player makes them and places them piece by piece, like the pig pen's fence (task 165).

- **The pieces are the generated objects.** `wattle_fence` and `stone_wall` are one world object
  type each, whoever put them there: they `connect` "field_boundary" (so a placed piece joins the
  generated run, and the two kinds join each other), block walking, and are taken down with the same
  tool (axe for the fence, 2 hits; pickaxe for the wall, 5 hp) for the same drops. They are saved
  like other placed objects (type and tile), no save change. Each has `placeable_in` outdoors, so
  an item can put it down; the placement rules (a free tile, none on water, buildings or the paths
  that must stay open, none on the player) and the ghost are the pen fence's.
- **Recipes** (data/recipes.cfg):
  - `wattle_fence`: made at the workbench, woodworking 5; 1 log and 4 fibre make 2 pieces (there is
    no hazel rod item, so a log is split into the stakes and rods).
  - `stone_wall`: made by hand, masonry 5; 3 stone make a piece.
- **The drops stay as they were** (fence 2 fibre, wall 3 stone, as the generated runs always gave),
  and the recipes are priced so that taking a piece down never returns more than it cost: a
  fence piece costs 2 fibre and half a log and gives the 2 fibre back; a wall piece costs and gives
  back 3 stone. The wood is not returned. So a generated run is worth the same as a made one, and
  there is nothing to gain by crafting and taking down. The recipes do practise the skills, the
  usual gain, which falls to nothing 40 points above the recipe's level.
- **Art:** both pictures exist in both art sets; the items have an icon of a tile of the line
  (`boundaries.icons()`).
- Wild animals still stand on no building tile (task 201); a fence is not a building, so nothing
  changes for them.
