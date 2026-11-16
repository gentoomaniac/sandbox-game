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
  hedges, walls or ditches over the natural land. Fields come only with the village, which is not
  generated but placed once when a new game starts at a site found from the seed
  ([#9](https://github.com/gentoomaniac/sandbox-game/issues/9), [wehlsbuell.md](wehlsbuell.md)), and the player digs ditches
  ([#86](https://github.com/gentoomaniac/sandbox-game/issues/86)). See
  [map-generation-review.md](map-generation-review.md) for why and for the before and after maps.
  - **Dykes** are the one work of men left: on the land side of the floodplain's edge, in
    stretches picked by a slow noise, and the sea dyke along the coast (see [coast.md](coast.md)).
    Each is a thin line of tiles joined on their sides along the edge of the land, which runs on
    the diagonal where the edge slants (issue
    [#94](https://github.com/gentoomaniac/sandbox-game/issues/94)): the generator takes the first
    tile of the land in each row of the coast (each column of the river) and the tiles along each
    step to the next, after cutting off a bulge of the land narrower than 3 rows (a morphological
    opening), which the line could only follow in a block or a spur; a stair of single steps is
    then drawn as one bank on the diagonal (see LineSlants). A river dyke's stretch takes
    whole columns, so it begins and ends on a clean end, and a tile left on its own where a creek
    cuts the line has none.
    They don't block walking (they are walked on, sheep grazed on them), but they block building
    and tilling on their tile: nothing is built into a dyke. Nothing removes one yet (basic
    terraforming is on the backlog, [#59](https://github.com/gentoomaniac/sandbox-game/issues/59)).
    Every dyke tile has a height and a strength (`DykeProfile`, from the seed, shared by a
    stretch of about 60 tiles); the hover says them, and a storm surge runs over the low ones (see
    [storm-surge.md](storm-surge.md)).
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

- **The river and the creeks** ([#60](https://github.com/gentoomaniac/sandbox-game/issues/60)):
  the river is a centre line y = f(x) (`RiverLine`) from a slow noise that swings it up to 90
  tiles north and south, a finer one that adds bends of up to 5 tiles (both with two octaves only, so the meanders are smooth and the slope stays under 1.5 tiles per column), and a third that makes it
  up to 2 tiles wider per bank here and there, so it winds and is not the same width all along.
  **Creeks** (`CreekLayout`, `[creeks]` in `data/landscape.cfg`) are few: the land is cut into
  bands of 160 tiles along x, 60 % of the bands have one, from the river north or south for 50 to
  130 tiles. A creek starts in a small wetland, is about 2 tiles wide, swings in S-bends of about 35 tiles, up to
  22 tiles either side of its band's middle (where it moves more than a tile per row, a row's water spans to the rows beside it, so it stays joined) and runs
  into the river through the floodplain and the dyke. A band whose creek could come within 4 tiles
  of the coast line (its wandering included) has none, so a creek never breaks the sea dyke. A
  **ford** (a round patch of shallow ground about 3 tiles across, on the creek's middle line, so it
  is about 3 tiles long along the creek whichever way it runs; it is floodplain terrain drawn as
  shallow water over a bed of stones, [#96](https://github.com/gentoomaniac/sandbox-game/issues/96),
  [#99](https://github.com/gentoomaniac/sandbox-game/issues/99)) lies once in every 36 rows of it,
  counted from the river at the band's middle, so a walker crosses. No reeds stand in a ford, it is
  never drawn worn or muddy, and it takes no footprints (`Fords`). Creeks block walking like the
  river; reeds grow where one crosses the floodplain and clay is found along it.
- **Woods** (task 56, 2026-11-06, redone in [#60](https://github.com/gentoomaniac/sandbox-game/issues/60)):
  trees stand in woods, compact patches that cover about 15 % of the Geest, and nowhere else: a
  lone tree outside a wood is not generated (a village's grove will be one, later). `WoodLayout`
  (numbers in `data/landscape.cfg`, `[woods]`) makes them: a wood is where the forest noise, read
  at a position pushed about by a slow warp noise, is above 0.27 (the noise has a wavelength of
  about 80 tiles), so the outline is no contour line of one noise. There are none in the marsh (the warp makes the marsh edge wavy). The depth
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
- **Dead and half-dead trees** (issue #102, 2026-11-15): rare single trees on open grass, as the
  one dead tree was (0.15 % of the tiles that have no bush, stone or tree, 2 % within 5 tiles of
  wetland), and of the kind of the trees around: the kind `_tree_type_at` picks for the tile, so
  by the wet ground mostly alder and willow. 60 % of them are dead (`dead_<kind>`, 3 looks), 40 %
  half-dead (`half_dead_<kind>`, 2 looks: a dead side or a dead top); a second roll of the tile
  decides, and the look comes from the position hash like every object's. The single `dead_tree`
  is not placed any more, and old saves keep theirs.
