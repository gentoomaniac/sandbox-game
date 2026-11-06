class_name DebugPath
extends RefCounted
## For screenshots (`--path=<x>,<y>`, `--path-days=<walked>,<left>`): a winding route walked
## from that tile eastwards, CROSSINGS_PER_DAY times a day for the days walked, each crossing
## straying a tile to the side here and there, with a night of regrowth after every day; then
## the nights it is left to grow back. Loads the chunks around the route itself.

const LENGTH := 28
## How far the route bends north and south, and over how many tiles it winds.
const BEND := 3.0
const WINDING := 9.0
const CROSSINGS_PER_DAY := 8
const CHUNK_REACH := 1


static func create(world: World, start: Vector2i, days_walked: int, days_left: int) -> void:
	var generator := WorldGenerator.new(world.world_seed)
	var centre := Chunk.world_to_chunk(start + Vector2i(LENGTH / 2, 0))
	for y in range(-CHUNK_REACH, CHUNK_REACH + 1):
		for x in range(-CHUNK_REACH, CHUNK_REACH + 1):
			var coords := centre + Vector2i(x, y)
			if not world.is_chunk_loaded(coords):
				world.add_chunk(generator.generate_chunk(coords))
	for day in days_walked:
		for crossing in CROSSINGS_PER_DAY:
			for tile in _route(start):
				# One step in six strays to a side.
				var stray := PositionHash.of(tile, day * CROSSINGS_PER_DAY + crossing) % 12
				if stray == 0:
					tile += Vector2i.UP
				elif stray == 1:
					tile += Vector2i.DOWN
				world.wear_tile(tile)
		world.regrow_paths()
	for _night in days_left:
		world.regrow_paths()


## The tiles of the route in the order they are walked: side by side, as feet go, never only
## corner to corner.
static func _route(start: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = [start]
	for x in range(1, LENGTH):
		var target := start + Vector2i(x, roundi(BEND * sin(x / WINDING * PI)))
		var tile: Vector2i = tiles.back() + Vector2i.RIGHT
		tiles.append(tile)
		while tile.y != target.y:
			tile.y += signi(target.y - tile.y)
			tiles.append(tile)
	return tiles
