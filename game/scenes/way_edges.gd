class_name WayEdges
extends RefCounted
## The edge of a road (#84): a free tile beside a way gets a rim of trodden earth along the side
## next to the way, so a road has a worn shoulder, and a road made wider by a way laid along it has
## none inside. It is no object and nothing about it is saved: it is worked out from the ways
## around the tile, drawn on a layer of its own over the ground and under the objects, and drawn
## again when a way is laid or taken up beside the tile (see WorldView). The pictures are the atlas
## row `WorldObjectWays.EDGE_ROW`, one per mask of the sides that have a way beside them.

## The ground it is drawn on: the dry open grass the ways lie on, not tilled soil (a way beside a
## field) nor the flats, where the tide comes.
const TERRAINS: Array[Tile.Terrain] = [
	Tile.Terrain.GRASS, Tile.Terrain.WARFT, Tile.Terrain.FLOODPLAIN
]

## The layer to show, under the entities.
var layer := TileMapLayer.new()
var _world: World
## The look (an ObjectTileset source) of the edge at a tile, which follows the season (a Callable
## taking the tile).
var _look_at: Callable
## What is drawn, by the chunk that has the tile: tile -> `Vector2i(look, mask)`.
var _drawn: Dictionary[Vector2i, Dictionary] = {}


func _init(tile_set: TileSet, material: Material) -> void:
	layer.name = "WayEdges"
	layer.tile_set = tile_set
	layer.material = material


func show_world(world: World, look_at: Callable) -> void:
	_world = world
	_look_at = look_at


## The sides of a tile (as the bits of a connection mask, see World `connections`) that have a way
## beside them; none if the tile has a way itself or is not ground for the edge.
func sides_with_ways(world_pos: Vector2i) -> int:
	var tile := _world.tile_at(world_pos)
	if (
		tile == null
		or not TERRAINS.has(tile.terrain)
		or _is_way(_world.type_standing_at(world_pos))
	):
		return 0
	var mask := 0
	for side in World.CONNECTION_SIDES.size():
		if _is_way(_world.type_standing_at(world_pos + World.CONNECTION_SIDES[side])):
			mask |= 1 << side
	return mask


## Draws the edge of a tile again: nothing if no way lies beside it, or its chunk is not loaded.
func draw(world_pos: Vector2i) -> void:
	var chunk_coords := Chunk.world_to_chunk(world_pos)
	if not _world.is_chunk_loaded(chunk_coords):
		return
	var cells: Dictionary = _drawn.get_or_add(chunk_coords, {})
	var mask := sides_with_ways(world_pos)
	if mask == 0:
		if cells.erase(world_pos):
			layer.erase_cell(world_pos)
		return
	var cell := Vector2i(_look_at.call(world_pos), mask)
	if cells.get(world_pos) != cell:
		cells[world_pos] = cell
		layer.set_cell(world_pos, cell.x, Vector2i(mask, WorldObjectWays.EDGE_ROW))


## Draws the edges of a tile and of the 4 tiles beside it: a way was laid or taken up there.
func draw_around(world_pos: Vector2i) -> void:
	draw(world_pos)
	for side in World.CONNECTION_SIDES:
		draw(world_pos + side)


## Draws the edges round the ways of a chunk that was loaded, those on its border tiles that the
## ways of a chunk beside it reach too (it may have been drawn before this one was there).
func draw_chunk(chunk: Chunk) -> void:
	for object in chunk.objects():
		if _is_way(object.type):
			draw_around(object.pos)
	var origin := Chunk.to_world(chunk.coords, Vector2i.ZERO)
	var last := Chunk.CHUNK_SIZE - 1
	for i in Chunk.CHUNK_SIZE:
		_draw_if_way_beyond(origin + Vector2i(0, i), Vector2i.LEFT)
		_draw_if_way_beyond(origin + Vector2i(last, i), Vector2i.RIGHT)
		_draw_if_way_beyond(origin + Vector2i(i, 0), Vector2i.UP)
		_draw_if_way_beyond(origin + Vector2i(i, last), Vector2i.DOWN)


## Draws the edges of a chunk again: a new day may have changed their look.
func refresh_chunk(chunk_coords: Vector2i) -> void:
	for world_pos: Vector2i in _drawn.get(chunk_coords, {}).keys():
		draw(world_pos)


## The chunk is dropped: its edges go.
func forget_chunk(chunk_coords: Vector2i) -> void:
	for world_pos: Vector2i in _drawn.get(chunk_coords, {}):
		layer.erase_cell(world_pos)
	_drawn.erase(chunk_coords)


## Draws the edge of a tile at the border of a loaded chunk if a way lies beyond it, in the chunk
## beside, where only a loaded chunk has ways to see.
func _draw_if_way_beyond(world_pos: Vector2i, direction: Vector2i) -> void:
	var beyond := _world.object_at(world_pos + direction)
	if beyond != null and _is_way(beyond.type):
		draw(world_pos)


static func _is_way(type: StringName) -> bool:
	return type != &"" and WorldObjectTypes.TYPES[type].has("way")
