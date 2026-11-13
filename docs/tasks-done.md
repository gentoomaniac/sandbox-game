

## 208. Dig up bushes with the shovel and plant them elsewhere

- [x] Done

Done: 2026-11-13. The shovel (any grade) digs a berry bush, shrub or fern up whole in `dig_hits`
(3) worth of its power (rusty 3 hits, iron 2; hits heal overnight, saved like tree hits); the bush
goes to the inventory as an item (stacks 5/5/10, weights 5/4/2), or to the ground if full; the
tile is left as grass. Held, it shows a placement ghost cut from the summer object atlas (works
for every outdoor placeable now); it plants on free outdoor grass only, and no land object may
block the tile in front of a door. A replanted berry bush starts picked and bears after its
regrowth days. Saplings are not bushes. No save version change.

The user, 2026-11-11: "Bushes need to be removable. Use a shovel to dig them out and be able to
place them somewhere else"
- The bushes (game/state/world_object_types.gd): BERRY_BUSH (blocks walking, picked for berries,
  regrows), SHRUB and FERN_BUSH (fibre by hand); check for other bush-like plants (the young
  saplings may fit too: say). Today they can be picked or cut by hand, but not moved.
- The shovel used on a bush digs it out whole: the bush becomes an item ("Berry bush", "Shrub",
  "Fern"; icon from its world sprite, both arts) in the inventory (or dropped if full), its tile is
  left as dug earth or grass. The bush keeps what matters (a berry bush's picked/regrow state may
  reset, say which). Digging takes a few shovel hits like other shovel work, with its sound and
  energy cost.
- The item is placed like other placeable things (a placement ghost if they have one) on a free
  tile where a bush can grow (grass or similar, not on water, paths, buildings, farmland), and
  becomes the same world object again, with its season looks and regrowth. Saved like other placed
  objects (save version bump if the save needs it).
- Picking berries and cutting by hand stay as today; only the shovel digs out.
- Tests: digging each bush gives its item, placing it back, refused tiles, a berry bush still
  bears after replanting, save and load. README, design pages.
