class_name FloodOverlay
extends Node2D
## Draws the water of the storm surge (see FloodState) over the ground: a sprite for each loaded
## chunk that has water on it or next to it, whose mask texture (FloodMask) is made again only when
## the tiles of that chunk or of a neighbour change, so no chunk is drawn again for it. The shader
## is flood.gdshader. A chunk whose mask has no water, border included, has no sprite.

## The overlay lies on the ground's grid: a tile's picture is centred on its tile (see WorldView).
const TILE_SIZE := TerrainTileset.TILE_SIZE

var _world: World
var _flood: FloodState
## The sprite of each chunk with water on it.
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
var _material: ShaderMaterial


func _init(material: ShaderMaterial) -> void:
	_material = material
	position = -Vector2(TILE_SIZE, TILE_SIZE) / 2


## Shows the water of a world's loaded chunks and of those it loads from now on.
func show_world(world: World, residency: ChunkResidency) -> void:
	_world = world
	_flood = world.flood
	_flood.chunks_changed.connect(_refresh_around)
	residency.chunk_loaded.connect(func(chunk: Chunk) -> void: _refresh(chunk.coords))
	residency.chunk_unloaded.connect(func(chunk: Chunk) -> void: _drop(chunk.coords))
	for coords in world.loaded_chunk_coords():
		_refresh(coords)


## The masks of these chunks and of their neighbours (whose borders show the chunks' tiles), each
## once.
func _refresh_around(changed_chunks: Array[Vector2i]) -> void:
	var affected: Dictionary[Vector2i, bool] = {}
	for coords in changed_chunks:
		for x in range(coords.x - 1, coords.x + 2):
			for y in range(coords.y - 1, coords.y + 2):
				affected[Vector2i(x, y)] = true
	for coords in affected:
		_refresh(coords)


func _has_water_near(chunk_coords: Vector2i) -> bool:
	for x in range(chunk_coords.x - 1, chunk_coords.x + 2):
		for y in range(chunk_coords.y - 1, chunk_coords.y + 2):
			if not _flood.wet_in_chunk(Vector2i(x, y)).is_empty():
				return true
	return false


func _refresh(chunk_coords: Vector2i) -> void:
	if not _world.is_chunk_loaded(chunk_coords) or not _has_water_near(chunk_coords):
		_drop(chunk_coords)
		return
	var image := FloodMask.image_of(_flood, chunk_coords)
	if _sprites.has(chunk_coords):
		_sprites[chunk_coords].texture.update(image)
		return
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = _material
	sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	sprite.position = Vector2(
		(chunk_coords * Chunk.CHUNK_SIZE - FloodMask.BORDER_TILES) * TILE_SIZE
	)
	add_child(sprite)
	_sprites[chunk_coords] = sprite


func _drop(chunk_coords: Vector2i) -> void:
	if _sprites.has(chunk_coords):
		_sprites[chunk_coords].queue_free()
		_sprites.erase(chunk_coords)
