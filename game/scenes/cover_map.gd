class_name CoverMap
extends RefCounted
## What the ground shaders know about the cover of the leaves, the frost and the snow (see
## ground_cover.gdshaderinc and GroundCover): the weather of the moment as global shader
## parameters, and a texture with a texel per world tile of what the tile catches.
##
## The texture is a ring of RING_TILES x RING_TILES tiles that the world wraps around (a tile's
## texel is at its position modulo the ring), so it has a fixed size, about 1 MB, however far the
## player walks. It is only a render cache of GroundCover: a chunk is drawn into it with its
## surroundings (a tree in the next chunk shades the edge of this one) when it is loaded and near
## enough the focus, and the tiles around a change (a tree felled, a house built, a path worn)
## are drawn again. The ring is bigger than the chunks that are loaded around the player, but a
## chunk that is loaded far away (a house kept outside the residency) would wrap onto the ones in
## view, so only chunks within DRAW_RANGE_CHUNKS of the focus are drawn, and the ones that fall out
## of range when the focus moves (`set_focus`) are forgotten, so a change in them cannot reach the
## ring; `draw_missing` draws the ones that come into range.
##
## Global shader parameters belong to the rendering server, not to a scene: `show_world` sets the
## weather back to a bare ground (the view sets the weather of the moment after it), and any
## CoverMap sets the textures again.

## The ring's side in tiles; a chunk is drawn whole, so it divides the chunk size. The same number
## as COVER_MAP_TILES in ground_cover.gdshaderinc.
const RING_TILES := 512
## Chunks further than this from the focus are not drawn: half the ring, less the chunks that
## are drawn around the focus.
const DRAW_RANGE_CHUNKS := 7
const NOISE_PATH := "res://assets/cover/ground_noise.png"
const LEAVES_PATH := "res://assets/cover/leaf_litter.png"
## The snow and the frost that the object atlas gets (see object_cover.gdshaderinc).
const OBJECTS_SNOW_PATH := "res://assets/objects_snow_cover.png"
const OBJECTS_FROST_PATH := "res://assets/objects_frost_cover.png"

var texture: ImageTexture
## The rule the shaders follow, for the game's own questions (footsteps, flowers under snow);
## it has the weather that was set last. Null until a world is shown.
var ground_cover: GroundCover
var _rules: SeasonRules
var _world: World
var _image := Image.create_empty(RING_TILES, RING_TILES, false, Image.FORMAT_RGBA8)
## The chunk the player is in, which the range of the drawing is around.
var _focus := Vector2i.ZERO
## The chunks that were drawn and are in range.
var _drawn: Dictionary[Vector2i, bool] = {}
var _is_changed := false


func _init(rules := SeasonRules.default_rules()) -> void:
	_rules = rules
	texture = ImageTexture.create_from_image(_image)
	RenderingServer.global_shader_parameter_set("cover_map", texture)
	RenderingServer.global_shader_parameter_set(
		"cover_thaw_gain", rules.value("cover", "thaw_gain")
	)
	RenderingServer.global_shader_parameter_set(
		"cover_object_snow_gain", rules.value("cover", "object_snow_gain")
	)
	show_art_set()


## Puts the weather of the shaders back to a bare ground, as it is before a world is shown.
static func reset() -> void:
	_set_shader_weather(0.0, 0.0, 0.0, 0.0)


## Shows the threshold map, the leaves and the snow and frost of the objects of the chosen art set
## (see ArtSet): the first two are the same size in the world's pixels in both.
func show_art_set() -> void:
	RenderingServer.global_shader_parameter_set("cover_noise", load(ArtSet.path(NOISE_PATH)))
	RenderingServer.global_shader_parameter_set("cover_leaves", load(ArtSet.path(LEAVES_PATH)))
	RenderingServer.global_shader_parameter_set(
		"cover_objects_snow", load(ArtSet.path(OBJECTS_SNOW_PATH))
	)
	RenderingServer.global_shader_parameter_set(
		"cover_objects_frost", load(ArtSet.path(OBJECTS_FROST_PATH))
	)


## Draws the channels of a world's tiles from now on, and forgets what was drawn of the last.
## The weather is a bare ground until `set_weather`.
func show_world(world: World) -> void:
	_world = world
	ground_cover = GroundCover.new(world, _rules)
	_image.fill(Color(0, 0, 0, 0))
	_drawn.clear()
	_is_changed = true
	reset()


## Gives the shaders and `ground_cover` the weather of the moment (see GroundCover.set_weather).
func set_weather(litter: float, snow_cover: float, thaw: float, frost: float) -> void:
	assert(ground_cover != null, "show a world first")
	_set_shader_weather(litter, snow_cover, thaw, frost)
	ground_cover.set_weather(litter, snow_cover, thaw, frost)


## Moves the focus: the chunks that are out of range now are forgotten (see `draw_missing`).
func set_focus(focus: Vector2i) -> void:
	_focus = focus
	for coords in _drawn.keys():
		if not _is_in_range(coords):
			_drawn.erase(coords)


## Draws a loaded chunk and the tiles around it that belong to loaded chunks, unless it is too far
## from the focus chunk.
func draw_chunk(coords: Vector2i) -> void:
	assert(_world.is_chunk_loaded(coords), "only a loaded chunk is drawn")
	if not _is_in_range(coords):
		return
	var margin := ground_cover.reach()
	var side := Chunk.CHUNK_SIZE + 2 * margin
	var origin := Chunk.to_world(coords, Vector2i.ZERO) - Vector2i(margin, margin)
	var colours := ground_cover.chunk_channels(coords, margin)
	for index in side * side:
		var tile := origin + Vector2i(index % side, index / side)
		var tile_chunk := Chunk.world_to_chunk(tile)
		if _world.is_chunk_loaded(tile_chunk) and _is_in_range(tile_chunk):
			_image.set_pixelv(_texel_of(tile), colours[index])
	_drawn[coords] = true
	_is_changed = true


## Draws the next loaded chunk that is in range of the focus chunk and not drawn yet, if any (the
## player has walked towards it). Returns whether there was one. A scan of the loaded chunks:
## ask when the focus moved or a chunk loaded, not every frame.
func draw_missing() -> bool:
	for coords in _world.loaded_chunk_coords():
		if not _drawn.has(coords) and _is_in_range(coords):
			draw_chunk(coords)
			return true
	return false


## Forgets a chunk that was unloaded: it is drawn again if it loads again.
func forget_chunk(coords: Vector2i) -> void:
	_drawn.erase(coords)


## Draws the tiles around a tile that changed again (a tree or a building, as far as they reach),
## those of chunks that are drawn (so in range).
func redraw_around(tile: Vector2i) -> void:
	assert(ground_cover != null, "show a world first")
	var reach := ground_cover.reach()
	for y in range(tile.y - reach, tile.y + reach + 1):
		for x in range(tile.x - reach, tile.x + reach + 1):
			var around := Vector2i(x, y)
			if _drawn.has(Chunk.world_to_chunk(around)):
				_image.set_pixelv(_texel_of(around), ground_cover.channels_at(around).as_color())
	_is_changed = true


## Draws a tile again (its terrain or its wear changed), if its chunk is drawn.
func redraw_tile(tile: Vector2i) -> void:
	assert(ground_cover != null, "show a world first")
	if _drawn.has(Chunk.world_to_chunk(tile)):
		_image.set_pixelv(_texel_of(tile), ground_cover.channels_at(tile).as_color())
		_is_changed = true


## Sends what was drawn to the graphics card, once however many chunks and tiles it was.
func upload() -> void:
	if _is_changed:
		texture.update(_image)
		_is_changed = false


## The texel of a world tile, as drawn.
func channels_at(tile: Vector2i) -> Color:
	return _image.get_pixelv(_texel_of(tile))


static func _set_shader_weather(
	litter: float, snow_cover: float, thaw: float, frost: float
) -> void:
	RenderingServer.global_shader_parameter_set("cover_litter", litter)
	RenderingServer.global_shader_parameter_set("cover_snow", snow_cover)
	RenderingServer.global_shader_parameter_set("cover_thaw", thaw)
	RenderingServer.global_shader_parameter_set("cover_frost", frost)


static func _texel_of(tile: Vector2i) -> Vector2i:
	return Vector2i(posmod(tile.x, RING_TILES), posmod(tile.y, RING_TILES))


func _is_in_range(coords: Vector2i) -> bool:
	var offset := (coords - _focus).abs()
	return maxi(offset.x, offset.y) <= DRAW_RANGE_CHUNKS
