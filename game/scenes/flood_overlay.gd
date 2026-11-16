class_name FloodOverlay
extends Node2D
## Draws the water of the storm surge (see FloodState) over the ground: a sprite for each loaded
## chunk that has water on it, whose mask texture (FloodMask) is made again only when the tiles of
## that chunk change, so no chunk is drawn again for it. The shader is flood.gdshader. Chunks
## without water have no sprite.

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
	_flood.chunk_changed.connect(_refresh)
	residency.chunk_loaded.connect(func(chunk: Chunk) -> void: _refresh(chunk.coords))
	residency.chunk_unloaded.connect(func(chunk: Chunk) -> void: _drop(chunk.coords))
	for coords in world.loaded_chunk_coords():
		_refresh(coords)


func _refresh(chunk_coords: Vector2i) -> void:
	if not _world.is_chunk_loaded(chunk_coords) or _flood.wet_in_chunk(chunk_coords).is_empty():
		_drop(chunk_coords)
		return
	var image := FloodMask.image_of(_flood, chunk_coords)
	if _sprites.has(chunk_coords):
		_sprites[chunk_coords].texture.update(image)
		return
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = _material
	sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	sprite.position = Vector2(chunk_coords * Chunk.CHUNK_SIZE * TILE_SIZE)
	add_child(sprite)
	_sprites[chunk_coords] = sprite


func _drop(chunk_coords: Vector2i) -> void:
	if _sprites.has(chunk_coords):
		_sprites[chunk_coords].queue_free()
		_sprites.erase(chunk_coords)
