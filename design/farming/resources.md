# Resources: trees and minerals

- The world has **trees and minerals in different varieties** (e.g. several tree types,
  stone, ores).
- Vegetation varieties so far: beech, oak, birch, alder, pollard willow, spruce (needle
  tree), Scots pine, dead tree, and bushes (e.g. berry bush, plain shrub).
- Each variety has a **harvest level**: harvesting it needs a tool of at least that level.
  This ties resources to tool upgrades (see Tools in [Inventory, tools and character](../player/inventory-and-character.md)).
- The biome decides which varieties occur where (see [Biomes](../world/generation.md)).
- **Stronger tools unlock new varieties and harvest the older ones faster** (fewer hits).
  Together this is a progression loop: better tools → new resources → better tools.
- **Felling and mining** (decided 2026-11-05):
  - Every tree and mineral has hit points; each hit with a tool takes off the tool's
    power, which grows with its level. So a better tool needs fewer hits.
  - A tool below the object's harvest level does nothing, with a short message
    (e.g. "Needs a better pickaxe.").
  - First numbers (2026-11-05, tune in play): tool power = level. Hit points: oak 5,
    spruce 4, pine 7 (level 2), dead tree 3, stone 3, boulder 6 (level 2), stump 2, dead stump 2;
    beech 5, alder 4, birch 3 (soft wood) (task 56).
    Damage heals overnight.
- **Harvesting, reworked** (decided 2026-11-05; replaces drops straight into the inventory,
  stumps regrowing into trees and the generic sapling):
  - **Final resources lie on the ground** where they come off, as items you collect by
    walking over them (pulled in from 1.25 tiles, widened 2026-11-05, once a dropped
    pile has hopped out, about 1.4 s). Final
    resources are logs (the item `wood` becomes `logs`), stone, clay, hay, all crop
    produce, and also what is picked by hand (berries, fibre) and seeds. They stay on the
    ground (saved) until collected; with a full inventory they stay where they are.
  - **Intermediate leftovers are objects** that are hit again with the right tool.
  - **Trees:** felling leaves a stump on the tree's tile and a fallen trunk (2×1, lying
    away from the player; 1×1 if there is no room). The axe cuts the trunk into most of the
    logs (e.g. oak 3, beech 3, spruce 3, pine 4, birch 2, alder 2, dead tree 2) and chops out
    the stump for 1 log. Living trees sometimes leave a seed of their species on the ground
    (acorn, beechnut, birch catkin, alder cone, spruce cone, pine cone, and the willow a
    willow cutting, a rod stuck in the ground as willows are really grown; about 25 %). Every
    tree whose stump can grow a sapling has one, as a sapling picked by hand gives it back.
  - **Trunk placement** (decided 2026-11-05): a trunk always lies horizontally (there is no
    vertical art). With the player left or right of the tree it lies on the far side of the
    stump; with the player above or below it lies to the right of the stump, or to the left if
    the right has no room. With no room for 2×1 a 1×1 trunk lies on any free tile beside the
    stump (never the player's), and with none there is no trunk. The numbers are in
    world_object_types.gd: trunk hit points (oak 4, beech 4, spruce 3, alder 3, pine 5, birch 2,
    dead tree 2), rot after 14
    days, sapling chance 30 %, seed chance 25 %.
  - **Stumps don't regrow into trees.** A stump left alone rots away over about two weeks;
    when it is gone it has a chance (about 30 %) to leave a sapling of its tree's species
    in its place.
  - **The dead tree leaves a dead stump** (decided 2026-11-05): grey, weathered wood with a
    broken, splintered top and a dark rotten heart (2 looks, a snow look too), not the fresh
    brown stump of a living tree. Same numbers (2 hp, axe, 1 log, rots away after 14 days),
    but it never leaves a sapling, and it throws splinters when hit. Stumps of dead trees
    felled before this change stay brown: nothing in an old save tells them from an oak's.
  - **Seeds per species:** a tree seed is planted on grass anywhere, becomes a sapling of
    its species and then that tree. The generic sapling item goes away.
  - **Stone:** a mined stone breaks into stone items scattered around its tile; a boulder
    (level 2) into more of them.
  - **Harvest animations** (decided 2026-11-05; view only, the state changes at once):
    a felled tree topples away from the player onto the side where its trunk will lie
    (about 0.6 s, speeding up, leaves or snow burst on impact) before the trunk shows;
    everything a harvest drops starts at its source and hops in a small arc, with a little
    bounce, to where it lands: logs out of a cut trunk and a stump, stones out of a broken
    stone, hay and reeds out of mown stands, clay out of a dug spot, and the same for crops
    and bushes picked by hand. The tree rotates on the art grid.
  - **Hit feedback:** every hit shakes the object, the finishing one too. A tree with
    foliage drops a few leaves (needles for spruce and pine, all year), a snowy tree a
    puff of snow, a bare tree nothing. Stone and boulders throw a few small splinters
    that arc out and fade. Effects are pixel particles on the art grid, in colours that
    stand out from what they fall from, and leaves fall past the canopy onto the ground.
  - A berry bush gives berries and bears again after a few days; picking it doesn't
    remove it. Shrubs and fern bushes give fibre.
  - Collected items go onto existing stacks first, then into free slots, and into the held
    slot only when nothing else is free, so an empty hand stays empty while harvesting.
- **Scythe and tall grass:** tall grass grows in meadows, in over spring, tallest in summer,
  gone in winter (a vegetation curve). The scythe mows 4 tiles per swing: the 2 straight
  ahead and the tiles left and right of the nearer one (the nearer one is the targeted
  tile, "ahead" the way the player faces). Mowing nothing does nothing and costs nothing.
  Tall grass doesn't block walking, a hand can't pick it, and the hoe, planting and
  building clear it (no hay). Each mown tuft gives 2 hay on the ground and looks mown
  (stubble) for 4 days, then grows back. First numbers (2026-11-05, tune in play).
- **Reeds:** dense stands on the banks of the river (the floodplain within 2 tiles of the
  water), at wetland edges and beside the marsh ditches, thick in patches and thin elsewhere,
  all year, with no dormancy:
  green in spring and summer, golden in autumn and winter, snow-capped under snow. They don't
  block walking, the hoe doesn't clear them and a hand can't pick them. The scythe cuts them
  (the same 4-tile swing as tall grass): each stand gives 2 reeds on the ground and is left as
  low stubble. Cut reeds grow back only in their growing season: their needs (temperature,
  sunlight, and the growth a stand needs to stand again) are a `[reeds]` section of
  `data/crops.cfg`, no crop (no seeds, no sheet). Each night a cut stand gathers growth from
  the day's temperature and sun by the same score as a crop's, with no soil moisture (reeds
  stand in water), and stands again once it has enough. It gathers nothing on days too cold or
  too dark, so a stand cut in autumn stays cut through winter. First numbers (2026-11-05, tune
  in play): 4 growth, minimum 5 degrees, best 20, maximum 32, sun 2 to 6 hours: some five to
  eight good days.
- **Shovel and clay:** some spots near rivers, lakes and wetland hold clay, hinted only
  slightly on the ground (a few reddish-grey pixels; easy to miss). Digging such a spot
  with the shovel sometimes gives clay; a dug spot is spent for some days. Digging
  anywhere else gives nothing. First numbers (2026-11-05, tune in play): 40 % chance of 2 clay
  (a roll of the spot and the day), a dug spot is spent for 5 nights, spots lie on grass with
  water (the river or a ditch) or wetland within 5 tiles, in clusters, never where an object stands. The shovel's
  targeting highlight shows on any free grass tile, so spots can't be told from the cursor.
- **Digging up bushes (task 208):** the shovel on a berry bush, a shrub or a fern digs it out
  whole: `dig_hits` (3) in the object table, as `hp` is, each shovel hit taking off its grade's
  power (so a rusty iron shovel needs 3 hits, an iron one 2), each with the dig sound and
  energy. The last hit gives the bush as an item (berry bush, shrub, fern; it lies on the
  ground if the inventory is full) and leaves grass. The hits heal overnight. Picking and
  cutting by hand are unchanged, and the hammer does not take bushes down. The item is placed
  on free grass outdoors (not on water, tilled soil, other objects, buildings or in front of a
  door) as the same object again, with its seasons. A replanted berry bush counts as picked and
  bears after its regrowth days (the picked state is not kept: digging and replanting must not
  make berries); a fern or berry bush follows its season as any other. Saplings are not
  bushes: they stay as they are and come from seeds. No save change: a bush is an ordinary
  object and the items are ordinary item ids.
- **Regrowth:**
  - a felled tree leaves a stump that rots away and may leave a sapling (see above);
  - minerals respawn slowly, mainly in areas the player hasn't visited for a while;
  - the player can plant trees (from seeds or saplings).
