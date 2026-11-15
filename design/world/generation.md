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
- **The open land is bare** ([#60](https://github.com/gentoomaniac/sandbox-game/issues/60),
  2026-11-15; before it had a grid of fields, task 54): the generator lays no fields, fences,
  hedges, walls or ditches over the natural land. Fields come only around the generated villages
  ([#9](https://github.com/gentoomaniac/sandbox-game/issues/9)), and the player digs ditches
  ([#86](https://github.com/gentoomaniac/sandbox-game/issues/86)). See
  [map-generation-review.md](map-generation-review.md) for why and for the before and after maps.
  - **Dykes** are the one work of men left: on the land side of the floodplain's edge, in
    stretches picked by a slow noise, and the sea dyke along the coast (see [coast.md](coast.md)).
    They don't block walking (they are walked on, sheep grazed on them), but they block building
    and tilling on their tile: nothing is built into a dyke. Nothing removes one yet (basic
    terraforming is on the backlog, [#59](https://github.com/gentoomaniac/sandbox-game/issues/59)).
  - **Knicks, walls and fences** are objects the player makes (task 203) and the villages will
    lay. The axe cuts a Knick down for 1 log and 2 fibre (its wood was the reason it was planted
    and cut back every few years), a wattle fence for 2 fibre; the pickaxe takes a wall apart for
    3 stone (see `design/building/fences-and-walls.md`).
  - **The marsh** (the low land within 36 tiles of the floodplain's edge and of the sea dyke) has
    no field layout of its own yet; it decides which trees grow where (below).
  - **Willows** are felled like the other trees (2 logs, the stump may grow a willow sapling
    again; it drops a willow cutting like a seed). They block walking like the other trees. The
    willow is a gnarled brown trunk about a tile high on its ground shadow, with a knobbly head
    and thin rods that in summer carry a dense, rounded crown of narrow grey-green leaves; in
    winter they stand bare with a little snow on the head.
  - **Old worlds:** a save keeps only its seed and its edits, so the land it has not edited is
    always the generator's current land. Saves from before #60 show the new bare land where
    nothing was edited, and its seams with old edits may look odd. That is accepted (the saves of
    that time were test saves) and goes into the release notes.

- **Woods** (task 56, 2026-11-06, redone in [#60](https://github.com/gentoomaniac/sandbox-game/issues/60)):
  trees stand in woods, compact patches that cover about 15 % of the Geest, and nowhere else: a
  lone tree outside a wood is not generated (a village's grove will be one, later). `WoodLayout`
  (numbers in `data/landscape.cfg`, `[woods]`) makes them: a wood is where the forest noise, read
  at a position pushed about by a slow warp noise, is above 0.27 (the noise has a wavelength of about 80 tiles), so the outline is no contour
  line of one noise. There are none in the marsh (the warp makes the marsh edge wavy). The depth
  inside a wood gives an **edge** (shrubs, bushes, few young trees: where the noise barely
  clears the threshold a wood is only a tuft of shrubs) and a **core** (a tile
  holds a trunk with a chance of 0.15 at the edge to 0.55 in the core; crowns overlap). **Clearings** are cut into
  the core by a fine noise: grass and bushes, no tree. Bushes are common at the edge, rare in the
  core.
- **Which trees grow where** (task 56, 2026-11-06): the woods are broadleaved: on wet ground (the
  marsh, and the Geest by wetland) alder 4, willow 2, oak 1 and birch 1 by weight, on the dry
  Geest beech 4, oak 3 and birch 2. Pine and spruce were not common before the heath plantations
  of the late 18th century, so they stand only as patches inside the woods of the Geest, where the
  composition noise is high (with a mixed rim), two in three of them Scots pine. Numbers in
  `WorldGenerator`, first values, tune in play.
