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
  chunk unloading, and object state (e.g. crop growth) is kept. An edited object takes off
  every generated object under its footprint, not only the one at its own tile. Left open: a
  generated object that begins in the neighbour chunk to the left or above and reaches under
  an edit is not found while only this chunk loads (placing one over it is refused in play, so
  only a changed generator could bring it about).
- Buildings are stored at world level as well.
- **Save format later:** seed + edits + buildings + player and clock state. Edits are also
  the natural unit to synchronise in multiplayer.

## What is near is drawn and scanned (decided 2026-11-09, task 142)

Everything the player did stays saved for good, but drawing and scanning are bounded by distance:

- **Ground piles** are indexed by chunk (not saved; rebuilt on load; a pile that is pulled
  moves between cells). Pick-up asks the index for the piles around the player. Only the piles in the
  player's chunk and the next ones are settled (the 1.4 s after a drop) and lose
  "dropped by the player"; a far pile does so once the player comes within a chunk of it.
  Nothing expires or despawns.
- **Pile sprites** exist only for piles within the chunks the world view draws (3 chunks of the
  player, kept until 4), made and freed as the player moves.
- **Villagers** have a view only within the same chunks of the player. Their state goes on all the
  time (they stroll, rest, remember); the view is made again from it when the player comes near.
- **Edits** are also indexed by chunk (positions only, not saved, rebuilt on load): a chunk that
  loads replays its own terrain and object edits, and the world view redraws only its tilled
  tiles, instead of every chunk load going through all the edits of the world. The wet-soil marks
  stay wherever the soil is, loaded or not, and are counted (`SoilWetness.mark_count`).

## Edits back to the generated state are dropped (#32)

- An edit that says no more than the seed does not stay in the save. Every night, `NightUpkeep`
  asks of each edited object that is neither grown up nor rotted away whether it is what the
  generator puts on its tile (`World.drop_edit_if_generated`), and if so forgets the edit: a
  healed tree, a tuft or reed stand that regrew, a bush that bears again. The chunk, loaded or
  not, simply has the generated object again the next time it is made.
- **Why at night:** the night is the only thing that takes state away (healing, regrowth), and it
  already visits every edit. Checking at every write would put the generator in each hit and
  every hourly crop change, and drop edits in the middle of a use.
- **Equal** means the same type and the same data as a freshly generated object of that type
  (`to_dict`: state and storage). The generator gives only a type, never state. A key that holds
  a default value (`damage` 0) is a difference: the code that heals erases keys, so that is
  how an object gets back to an empty state. The generated type is taken for the tile's
  generated terrain, as the chunk is made, not for the player's terrain edits.
- **Cost:** one tile asked of the generator is about 6 microseconds (measured), and nothing is
  generated for the chunk: the check does not need it loaded, and an edit in an unloaded chunk
  is dropped as well. Objects with state are skipped before the generator is asked.
- Not dropped: an edit that removes an object (`null`), also where the generator puts nothing
  (a removed placed object). It stays a harmless leftover.
- The save format is the same, with fewer entries; a save that still holds such an edit loads
  and keeps it until the object changes and is healed again.
