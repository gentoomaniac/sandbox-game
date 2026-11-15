# The world map and the fog of war

[#104](https://github.com/gentoomaniac/sandbox-game/issues/104). The user, 2026-11-15: "the minimap
for now should actually be an in game map and only accessible via /map as it breaks immersion but
is important for testing"; "unexplored land should be visibly different from explored but still
readable"; "type fog of war". So there is no map on screen: the console command `map` opens a
full-screen map of the land, a test tool, and it is on the console page of the handbook only.

## What the game remembers: the explored land

`Exploration` (`game/state/exploration.gd`, `GameState.explored`) keeps **which tiles the player has
seen**: every tile within 12 tiles (`SIGHT_RADIUS`, a round sight) of every tile they have stood on
or teleported to, outdoors. Inside a house nothing is seen.

Why per tile and not per chunk: a chunk is 32 tiles, so a per chunk record would clear the fog in
squares 32 tiles wide the moment the player steps into one, and the fog's edge would be a grid. Per
tile it clears as the player walks, by their sight. The record is cheap: a chunk the player has seen
anything of keeps one bit a tile, 128 bytes, so even the whole world (64 x 64 chunks) would be half
a megabyte.

It is saved as the `explored` list of the game: `{"chunk": [x, y], "seen": <128 bytes, base64>}`
for each chunk with anything seen (save version 50). A save of version 49 has none seen, and the
land about the player is explored as the game loads, as they see it from where they stand.
