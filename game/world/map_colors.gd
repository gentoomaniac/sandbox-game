class_name MapColors
extends RefCounted
## The colours of the top-down maps of the land, one block a tile: the world map of the console
## (see MapBuilder) and tools/world_map.gd. The terrain is the ground colour and what stands on it
## (trees, dykes, buildings, a worn path) is drawn over it. See
## design/world/map-generation-review.md for the picture they make.

const OBJECT_COLORS := {
	&"oak": Color("12401a"),
	&"beech": Color("12401a"),
	&"birch": Color("1b5e20"),
	&"alder": Color("1b5e20"),
	&"willow": Color("6b8e23"),
	&"pine": Color("06290a"),
	&"spruce": Color("06290a"),
	&"dead_tree": Color("5d4037"),
	&"berry_bush": Color("7cb342"),
	&"shrub": Color("7cb342"),
	&"fern_bush": Color("7cb342"),
	&"sapling": Color("7cb342"),
	&"dyke": Color("8d6e63"),
	&"reeds": Color("c0ca33"),
	&"stone": Color("9e9e9e"),
	&"boulder": Color("757575"),
	&"ewer": Color("000000"),
	&"knick": Color("e65100"),
	&"stone_wall": Color("ffffff"),
	&"wattle_fence": Color("f5f5f5"),
	&"grave": Color("616161"),
	&"draw_well": Color("0277bd"),
	&"jetty": Color("795548"),
	&"rowing_boat": Color("4e342e"),
	&"net_frame": Color("ffb300"),
	&"eel_traps": Color("ffb300"),
	&"plank_walk": Color("c9a66b"),
	&"stone_path": Color("efebe9"),
}
const BUILDING := Color("b71c1c")
## Ground worn to a trodden way or a path by walking (see PathRules.Stage); the village's lanes and
## its square are kept so.
const WORN := Color("efebe9")
## A ford: the creek's shallow water over its bed of stones, floodplain to walk on.
const FORD := Color("90caf9")
## The colour of a terrain nothing here knows: loud, so that it is seen.
const UNKNOWN := Color.MAGENTA
const TERRAIN_COLORS := {
	Tile.Terrain.GRASS: Color("c8e6c9"),
	Tile.Terrain.SOIL: Color("a98467"),
	Tile.Terrain.WATER: Color("1e88e5"),
	Tile.Terrain.WETLAND: Color("80cbc4"),
	Tile.Terrain.FLOODPLAIN: Color("dce775"),
	Tile.Terrain.MUD: Color("bcaaa4"),
	Tile.Terrain.SALT_MARSH: Color("c5e1a5"),
	Tile.Terrain.SEA: Color("0d47a1"),
	Tile.Terrain.WARFT: Color("a1887f"),
}


## The colour of a tile, as the topmost thing on it: a building, an object, a worn way, a ford, or
## the ground. `chunk` is the chunk of the tile, which need not be loaded in `world` (the edits are
## to be replayed on it, see World `replay_edits`).
static func of_tile(world: World, chunk: Chunk, local: Vector2i) -> Color:
	var world_pos := Chunk.to_world(chunk.coords, local)
	if world.building_at(world_pos) != null:
		return BUILDING
	var object := chunk.object_at(local)
	if object != null and OBJECT_COLORS.has(object.type):
		return OBJECT_COLORS[object.type]
	if world.wear_stage(world_pos) != PathRules.Stage.UNWORN:
		return WORN
	return ground_of(world.world_seed, chunk, local)


## The colour of the ground of a tile, with no object on it.
static func ground_of(world_seed: int, chunk: Chunk, local: Vector2i) -> Color:
	var terrain := chunk.terrain_at(local)
	var is_ford := (
		terrain == Tile.Terrain.FLOODPLAIN
		and Fords.is_ford_bed(world_seed, Chunk.to_world(chunk.coords, local))
	)
	return FORD if is_ford else TERRAIN_COLORS.get(terrain, UNKNOWN)


## The picture of a chunk for the world map: CHUNK_SIZE pixels square, a pixel a tile, in RGBA8. The
## map scales it up, so a tile is a crisp block. The chunk need not be loaded in `world`.
static func image_of_chunk(world: World, chunk: Chunk) -> Image:
	var image := Image.create_empty(Chunk.CHUNK_SIZE, Chunk.CHUNK_SIZE, false, Image.FORMAT_RGBA8)
	for local_y in Chunk.CHUNK_SIZE:
		for local_x in Chunk.CHUNK_SIZE:
			var local := Vector2i(local_x, local_y)
			image.set_pixel(local_x, local_y, of_tile(world, chunk, local))
	return image
