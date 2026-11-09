# Building and land

The first buildings have a page of their own: [first-buildings.md](first-buildings.md).

- **No land ownership.** The player can build anywhere, except on blocked tiles.
- **Placement rules:**
  - **wetland and floodplain tiles are off limits**: no building can be placed anywhere
    that can flood;
  - while placing, blocked tiles are marked, and the player gets a message that the land
    doesn't look safe to build on.
- **Defence:** creatures can threaten what the player builds. Combat stays optional,
  because there are other ways to stay safe:
  - fight the creatures;
  - hire guards;
  - build defences;
  - build in a less dangerous area. This means the world needs regions with different
    danger levels.
- **Buildings are presets with customisation:**
  - each building type is a preset (e.g. house, barn, workshop);
  - options per building: style, doors, and similar visual or functional variants;
  - expansions attach only at **defined attachment points** on a building. That keeps
    interiors predictable to generate and render.

- **Buildings cost materials:** logs, stone, clay and reeds (reeds for the thatch), taken
  from the inventory when the building is placed. The ghost shows the costs against what
  the player carries and refuses the spot while something is missing. No refunds on
  placing. First numbers (tune in play): shack 20 logs, 5 stone (turf roof, no clay or
  reeds); fisherman's hut 25 logs, 5 stone, 15 reeds; Kate 30 logs, 15 stone, 15 clay, 25
  reeds; longhouse about twice the Kate; barn like the Kate with less clay; the hall house
  the most of every material (100 logs, 40 stone, 50 clay, 80 reeds). A new game starts at
  the camp: the materials for a first house have to be gathered.
- **The hammer builds:** holding the hammer is build mode (the ghost follows the cursor,
  use places the building); Q and E (rebindable) pick the building, and B selects the
  hammer. The arrows pick too (task 121): left and right the building, up and down its
  style. While building they belong to the menu and the player walks with WASD only (the
  keys the menu's actions share with walking, `GameSettings.SHARING_PAIRS`). Escape or a
  right click dismisses build mode, and gives the arrows back to walking, until something
  else is held or B is pressed again. With the hammer in hand E picks buildings and does not
  put the player to bed. The `nocost` console cheat waives the costs (`god` and `noweight`
  don't). The player starts with a hammer (later it is crafted); `give hammer` works too.
- **The hammer takes down:** X (rebindable, `take_down_mode`) switches the hammer between
  building and taking down; the panel says "Taking down", the tile under the mouse has a red
  frame and the building or placed thing there is tinted red, with the message saying what it
  gives. Holding Use for a second (`BuildMode.TAKE_DOWN_SECONDS`, with a progress bar) takes
  it down, with the axe's chop. A building gives half of each material, rounded down, dropped
  in front of its door (`GameState.take_down_building`; `nocost` gives nothing). It stays while
  the player is inside, or while anything they put in it is left: a thing they placed, or
  what a chest or station holds; the message says so. The furniture the house came with goes
  with it. A home bed in it falls back to the camp's sleeping bag, and a stork on its roof flies
  off. A placed thing (what an item places: chest, workbench, kiln, oven, stool, carved chest,
  cupboard) outdoors goes whole, with what it holds, into the inventory, or onto the ground
  where it stood when that is full. Crafted items are not broken down into materials.
- **`data/buildings.cfg`** defines the buildings (required keys, the game refuses to start
  if one is missing): name, footprint, door tile, picture and lit picture (the season and
  snow looks are found by name), the interior map, window lights, costs, and documented
  places for future attributes (beds, storage, warmth, comfort) that have no effect yet.
  A building can come in **styles** (tasks 120 and 121, 2026-11-09): other looks of the same
  house, each a section `[<building>.<style>]` after its building (`[kate.brick]`) with its
  own name and whatever it changes (pictures, window lights, costs). The footprint, the door
  and the inside are the building's, so every style of it is the same house. A placed
  building saves its style (save version 24; an older save's buildings have their own look,
  and a style the file no longer has shows as the building's own); its name, pictures,
  window lights and refund are its style's.
