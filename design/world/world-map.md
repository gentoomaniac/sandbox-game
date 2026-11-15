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

## How the fog looks

Unexplored land lies under a soft grey fog (`MapFog`): `DESATURATION` takes 65 % of its colour, and
`GREYING` pulls the rest 40 % to a dark grey, so water, grass, wood and dykes stay apart and
readable, only dim and flat. Explored land is clear. The fog's edge is soft: a tile is as clear as
the share of explored tiles in the 5 x 5 tiles about it, a ramp of about four tiles (`SOFT_RADIUS`).

## How the map is built

`MapBuilder` makes the picture of a chunk at a time and keeps it: an image a pixel a tile (32 x 32
pixels, `MapColors.image_of_chunk`), its foggy look, and the two mixed by the exploration (`MapFog
.apply`) as the texture the screen draws, scaled up so a tile is a block. A chunk with only
unexplored or only explored land about it is just the foggy or the clear image, so the mixing,
which costs most, is for the few at the edge of the explored land. When the player walks on,
`Exploration.revision_around` tells which chunks need their fog made again; `refresh` has the
chunks the world has loaded painted again, for the world changes under them.

A chunk the world has loaded is painted from it. A chunk it has not is generated for the map only,
on a worker thread (three at a time, as the travel masks do), the world's edits are replayed on it
and it is painted; nothing is added to the world. Painting reads the world, so it stays on the main
thread. `update` is called once a frame with the chunks in view, nearest the middle first, and
paints until its time budget is spent, at least one chunk: opening the map never hitches, the
picture fills in from the middle out.
