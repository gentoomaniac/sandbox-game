# World objects (architecture)

- Trees, rocks and ores, crops, the camp site, beds and similar things are **world
  objects placed on tiles**, not terrain types.
- A world object keeps its own state (e.g. growth stage, hits left, time until regrowth).
  Tile state stays lean and only describes the ground.
- Whether a tile can be walked on, built on or planted on also depends on the objects on
  it.
- An object can cover several tiles (its **footprint**, e.g. a boulder on 2x1, a sleeping
  bag on 1x2). It is stored at its top left tile only; the tiles it covers are derived.

## World edits (architecture)

- The generated world is a pure function of seed and position. Everything the player
  changes is kept as **edits** at world level, outside the chunks: per world position,
  "this object stands here" or "the generated object here was removed" (later also
  changed terrain, e.g. grass turned to soil).
- When a chunk is generated, the edits for its area are applied on top. Changes survive
  chunk unloading, and object state (e.g. crop growth) is kept.
- Buildings are stored at world level as well.
- **Save format later:** seed + edits + buildings + player and clock state. Edits are also
  the natural unit to synchronise in multiplayer.
