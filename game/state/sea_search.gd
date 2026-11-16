class_name SeaSearch
extends RefCounted
## Finds the water of the sea nearest to a tile without looking at every tile: a grid of
## `step` tiles around it, nearest first, and the first sample in water is then refined to the tile
## along the way back to the start. Only loaded chunks are looked at (an unloaded one is no
## water), and nothing is allocated for a tile. Water is the sea (the open sea, the tideways, the
## river's mouth) and, with `is_flooded_mud_sea`, the tidal mud the tide has covered (the cheap
## test of one point of the relief, `Tide.relief_at`, not the tile's whole height).

## The farthest `nearest` can look, in tiles: the chunks around the player stay loaded to three
## chunks (96 tiles) at least, and an unloaded one is no water.
const MAX_RADIUS := 96.0

## The offsets of each step's grid, nearest first.
static var _grids: Dictionary[int, Array] = {}

var world: World
var step := 6
var is_flooded_mud_sea := true
## The height of the water on the mud's relief (`Tide.water_height`), as of the last `nearest`.
var _water_height := 0.0


## The offsets of a grid of `step` tiles in a circle round (0, 0) out to MAX_RADIUS, nearest first.
static func grid(grid_step: int) -> Array:
	if not _grids.has(grid_step):
		var offsets: Array[Vector2i] = []
		var count := int(MAX_RADIUS / grid_step)
		for y in range(-count, count + 1):
			for x in range(-count, count + 1):
				var offset := Vector2i(x, y) * grid_step
				if offset.length() <= MAX_RADIUS:
					offsets.append(offset)
		offsets.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared()
		)
		_grids[grid_step] = offsets
	return _grids[grid_step]


## The way from `from` to the nearest water tile within `radius` tiles, in tiles; INF if there is
## none. `tide_level` is `Tide.level` now.
func nearest(from: Vector2i, radius: float, tide_level: float) -> Vector2:
	_water_height = Tide.water_height(tide_level)
	for offset: Vector2i in grid(step):
		if offset.length() > radius:
			break
		if _is_water(from + offset):
			return _refined(from, offset)
	return Vector2.INF


# Walks back from a sample in water towards the start while the tiles are still water.
func _refined(from: Vector2i, offset: Vector2i) -> Vector2:
	var direction := Vector2(offset).normalized()
	var found := Vector2(offset)
	for back in range(1, step):
		var tile := Vector2i((Vector2(offset) - direction * back).round())
		if not _is_water(from + tile):
			break
		found = Vector2(tile)
	return found


func _is_water(tile: Vector2i) -> bool:
	var chunk := world.chunk_at(Chunk.world_to_chunk(tile))
	if chunk == null:
		return false
	var terrain := chunk.terrain_at(Chunk.local_pos(tile))
	if terrain == Tile.Terrain.SEA:
		return true
	return (
		is_flooded_mud_sea
		and terrain == Tile.Terrain.MUD
		and Tide.relief_at_tile_point(Vector2(tile) + Vector2(0.5, 0.5)) < _water_height
	)
