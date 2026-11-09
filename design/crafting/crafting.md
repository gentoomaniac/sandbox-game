# Crafting

Decided 2026-11-05.

- **C opens the crafting menu** (rebindable). It lists every recipe with its cost against
  what the player carries, like the build panel; a recipe that can't be afforded is greyed
  with the missing materials marked. Clicking an affordable one takes the materials and puts
  the item in the inventory. Recipes are in `data/recipes.cfg` (result, count, materials),
  validated like the other data files. C shows the recipes made by hand (the chest, the
  campfire and the bedroll, the stations, flour); the others are made at a station (see
  [Professions](professions.md)); the hammer is a later recipe. When the result would not fit
  in the inventory (once the materials are taken) crafting is refused and the menu says so;
  nothing is dropped. A recipe made at a station is also refused, with nothing taken and nothing started,
  when the station is of another kind (a kiln firing at a workbench: "Made at the Kiln"), or not
  on the player's map or out of their reach ("Too far from the station"). The menu is modal, so
  the player cannot walk off with it open; the check guards code that crafts (tests, later
  helpers), not the clicks. The game does not pause while the menu is open (as with the
  character screen), but the player neither walks nor acts. C or Escape closes it.
- **First recipe: the chest**, 5 logs. A chest holds 15 slots (5×3).
- **Placing a chest:** held like seeds; while it is held a ghost of the chest follows the
  targeted tile, and using it places the chest there. The same rules as for buildings, just
  on one tile: not on blocked or unsafe tiles, not in the way of a door (the tile in front
  of it), not on the player. The ghost is green where it fits and red where it doesn't.
  Chests can be placed outdoors and inside houses (the first furniture the player places in
  an interior): inside, on free floor, not on walls, furniture, the exit or the tile inside
  it.
- **Opening a chest:** E on a chest within reach opens the storage screen (a chest on the
  targeted tile wins over sleeping; with a bed in reach and no chest targeted the player
  sleeps, without a bed the nearest chest in reach opens; with the hammer held outdoors E
  still picks the next building).
  The player's inventory is on the left, the chest's 5×3 slots on the right, with a small
  backpack icon above the one and a chest icon above the other (equipment is not shown).
  Items move by clicking as on the character screen (pick up, then click a slot; decided by
  the implementation 2026-11-05 instead of dragging); Shift+click sends a whole stack to the
  other side. The hotbar is the HUD's, lit and clickable while the screen is open (task 88). Opening makes a creaky squeak, closing a soft wooden thump.
- **Picking a chest up:** hitting it with the axe (three hits outdoors) takes it down and
  gives the chest item back; its contents spill onto the ground as piles around it. Inside
  a house there is no ground to spill on: one swing of the axe puts the chest item and its
  contents into the inventory, if they all fit (otherwise nothing happens and the player is
  told).
- A chest and its contents are saved with the world (outdoors) or the building's inside.
