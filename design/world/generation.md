# World generation

- **Mixed generation, procedural first.** The world is procedurally generated for now.
  Handcrafted locations come later.
- Handcrafted locations are made in an existing tile-map editor (**Tiled**) and placed into
  the generated world.
- **Shape:** a bounded world, generated from a seed and streamed in chunks.
  - The maximum size is a limit defined in code, which can be raised later. Nothing should
    assume a fixed size.
- **Biomes**, each with its own:
  - mobs;
  - available resources;
  - suitability for agriculture.
- **Danger:** regions have different danger levels (see Defence in [Building and land](../building/README.md)).
- **Interiors:** each building interior is a separate map. Entering through the door
  switches to it.
- **The worked land** (task 54, 2026-11-06): the generator lays fields over the natural land, so
  it reads as Schleswig-Holstein around 1700–1800. Numbers in `data/landscape.cfg`, first
  values, tune in play.
  - **Fields:** rows of fields between straight east-west boundaries (13 tiles apart, up to 4
    more), each row cut by north-south ones (18 apart, up to 6 more); 80 % of the stretches of
    boundary are there, so some fields run together. Every stretch has **one gap** (a gate, a
    crossing) away from its ends, and nothing that blocks the way stands on a gap or beside it,
    so no field is ever shut in: every boundary blocks, so without gaps the player could be.
  - **The Geest** (dry grass beyond the marsh, outside the forests): a boundary is a **Knick**
    (80 %), a **fieldstone wall** (10 %) or a **wattle fence** (10 %). There are no hedges in the
    forests, the marsh, on wetland or the floodplain.
  - **The marsh** (the low land within 36 tiles of the floodplain's edge) and wetland anywhere:
    a boundary is a **ditch**, water terrain, which is how the marsh is drained and fenced. Beside
    the ditches stand **pollard willows** (10 % of the tiles) and reeds (30 %). Ditches block
    walking like the river (no jumping); their gap is the crossing. The willow (redrawn in task
    56, as the first read as a sheaf of grain on a boulder in winter, and in task 108 at 32 px
    after the art review) is a gnarled brown trunk (mud, mud_dark) about a tile high on its
    ground shadow, with a knobbly head, and 60 to 76 thin rods of mixed lengths: in summer their
    upper parts carry a dense, rounded crown of narrow grey-green leaves with a dark edge and a
    shaded underside, the rods showing below and over it and a few silver leaves; in winter they
    stand bare, umber up to the middle, muted yellow-olive above with a few straw tips, a little
    snow on the head.
  - **Dykes** run on the land side of the floodplain's edge, in stretches picked by a slow noise.
  - **Walking:** Knicks, walls, fences and ditches block it; dykes don't (they are walked on,
    sheep grazed on them). Willows block like the other trees.
  - **Tools:** the axe cuts a Knick down to the ground for 1 log and 2 fibre (its wood was the
    reason it was planted and cut back every few years), and a wattle fence for 2 fibre; the
    pickaxe takes a wall apart for 3 stone. Nothing removes a dyke or fills a ditch (yet): they
    are the land's, not the player's. A willow is felled like the other trees (2 logs, its stump
    may grow a willow sapling again; it drops a willow cutting like a seed).
  - **Building and tilling:** all of them block building and tilling on their tile (a dyke too:
    nothing is built into it). Building next to them is fine. The door's front tile must still
    be walkable, so a door can't open onto a Knick or a ditch.
  - **Clay** is also found near ditches, which makes up for the clay the dykes cover by the
    river.
  - **Old worlds:** the worked land comes from the seed, so saves of version 9 and before show it
    where nothing was edited. Save version 10 lets it give way where the player has made a home,
    as if they had cleared it: 3 tiles around every building and around everything the player put
    down or changed (camp, chests, crops), over the tilled fields (their bounding box and 2 tiles
    more), under the items on the ground and where the player stands, the new objects are removed
    (as edits) and a ditch is grass. A 1-tile ring was too thin: on the user's farm ditches ran
    through the yard. So nothing new stands in or by a house, across the yard, the camp or the
    fields, or shuts the player in; further out an old world gets the new land.

- **Which trees grow where** (task 56, 2026-11-06): the forests stand where they stood, only the
  species of each tree changed, so old saves keep the shape of their land and need no upgrade.
  The woods are broadleaved: on wet ground (the marsh, and the Geest by wetland) alder 4, oak 1
  and birch 1 by weight, on the dry Geest beech 4, oak 3 and birch 2. Pine and spruce were not
  common before the heath plantations of the late 18th century, so they stand only in clumps on
  the Geest, where the composition noise is high (with a mixed rim), two in three of them Scots
  pine. Over three seeds the trees are about 28 % beech, 24 % oak, 19 % birch, 16 % alder, 7 %
  pine and spruce and 4 % willow (before: about half oak, half conifers). Numbers in
  `WorldGenerator`, first values, tune in play.
