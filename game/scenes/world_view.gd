class_name WorldView
extends Node2D
## Renders a World and streams chunks in and out around a focus.
##
## One TileMapLayer per terrain layer for the whole world (not per chunk), drawn as a dual
## grid (see TerrainTileset): cell (x, y) of every layer is shifted half a tile up and left,
## so its corners sit on world tiles (x - 1, y - 1) to (x, y). A chunk owns the cells whose
## bottom-right tile is its own, so loading or unloading it fills or erases those cells,
## with no nodes to create or free. On top, a decoration layer on the plain tile grid
## scatters flowers, pebbles and the like; they are only looks, not world objects. Above
## that, an objects layer on the same grid draws the world's objects. It sits in the
## y-sorted `entities` node, where the player (and later creatures) stand among them, and
## keeps no decoration under an object. Objects that shine get an ObjectLight.
## Buildings are sprites in that node too, so they sort with the objects and the player. They
## belong to the world, not to a chunk, so they stay when chunks unload.
##
## See-through: while a tree or building hides the player (see Occlusion) it fades inside a
## circle around the player. A building is a SeeThroughSprite already; a tree is a cell of the
## objects layer, which can't fade, so while it occludes (and while it fades back) its cell
## is erased and a SeeThroughSprite at the same place in the y-sorted node draws it instead.

const LOAD_RADIUS := 3
const UNLOAD_RADIUS := 5
## Loading a chunk (generating it, placing objects and drawing its layers) takes ~8 ms, at
## worst ~10 ms.
## One per frame keeps a frame well under 16 ms and still streams far faster than the
## camera moves.
const MAX_LOADS_PER_FRAME := 1
## The windows of buildings are lit (and shine) once the light strength is at least this.
const WINDOW_LIT_STRENGTH := 0.3

## The 4 corner tiles of a cell, in mask order: top-left, top-right, bottom-left,
## bottom-right.
const CORNER_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)
]

## Visual-only noise, seeded from the world seed with offsets far from the generator's.
## Variety: grass turns lush or dry over patches about this many tiles across.
const VARIETY_SEED_OFFSET := 7919
const VARIETY_FREQUENCY := 0.008
## Decoration clusters, a few tiles across.
const DECORATION_SEED_OFFSET := 104729
const DECORATION_FREQUENCY := 0.12

var world: World
## Y-sorted: whatever is added here is drawn in front of or behind the objects by its y.
var entities := Node2D.new()
## True once every chunk around the focus is loaded.
var is_settled := false
## Where the player stands, in world pixels (set by the game scene every frame).
var player_feet := Vector2.ZERO
var _generator: WorldGenerator
var _variety_noise := FastNoiseLite.new()
var _decoration_noise := FastNoiseLite.new()
var _focus_chunk := Vector2i.ZERO
var _tileset := TerrainTileset.new()
var _object_tileset := ObjectTileset.new()
## Indexed by TerrainTileset.Layer.
var _layers: Array[TileMapLayer] = []
var _decorations := TileMapLayer.new()
var _objects := TileMapLayer.new()
## The light of each shining object, by tile.
var _lights: Dictionary[Vector2i, ObjectLight] = {}
var _light_strength := 1.0
## The sprites that stand in for object cells while they are see-through, by tile.
var _object_sprites: Dictionary[Vector2i, SeeThroughSprite] = {}
var _building_sprites: Dictionary[Building, SeeThroughSprite] = {}
## The lights in the windows of each building.
var _window_lights: Dictionary[Building, Array] = {}


func _ready() -> void:
	for layer in TerrainTileset.LAYER_COUNT:
		var tile_map := TileMapLayer.new()
		tile_map.name = TerrainTileset.Layer.keys()[layer].capitalize()
		tile_map.tile_set = _tileset.tile_set
		tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
		add_child(tile_map)
		_layers.append(tile_map)
	_decorations.name = "Decorations"
	_decorations.tile_set = _tileset.tile_set
	add_child(_decorations)
	_objects.name = "Objects"
	_objects.tile_set = _object_tileset.tile_set
	_objects.y_sort_enabled = true
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.add_child(_objects)
	add_child(entities)


## Shows a world, including the chunks that are already loaded in it.
func show_world(world_to_show: World) -> void:
	world = world_to_show
	world.objects_changed.connect(_on_objects_changed)
	world.tile_changed.connect(redraw_tile)
	world.object_hit.connect(_shake_object)
	world.building_placed.connect(_draw_building)
	_generator = WorldGenerator.new(world.world_seed)
	_variety_noise.seed = world.world_seed + VARIETY_SEED_OFFSET
	_variety_noise.frequency = VARIETY_FREQUENCY
	_decoration_noise.seed = world.world_seed + DECORATION_SEED_OFFSET
	_decoration_noise.frequency = DECORATION_FREQUENCY
	for coords in world.loaded_chunk_coords():
		_draw_chunk(world.chunk_at(coords))
	for building in world.buildings():
		_draw_building(building)


## Sets how brightly every light shines (see ObjectLight.strength).
func set_light_strength(strength: float) -> void:
	_light_strength = strength
	for light in _lights.values():
		light.strength = strength
	for building in _building_sprites:
		_show_windows(building)


## Streaming follows this world tile position.
func set_focus(world_pos: Vector2i) -> void:
	_focus_chunk = Chunk.world_to_chunk(world_pos)


func _process(delta: float) -> void:
	if world == null:
		return
	var plan := ChunkStreaming.plan(
		_focus_chunk, world.loaded_chunk_coords(), LOAD_RADIUS, UNLOAD_RADIUS
	)
	for coords: Vector2i in plan["unload"]:
		_unload_chunk(coords)
	var to_load: Array = plan["load"]
	for coords: Vector2i in to_load.slice(0, MAX_LOADS_PER_FRAME):
		_load_chunk(coords)
	is_settled = to_load.is_empty()
	_update_see_through(delta)


## Redraws one tile after its state changed. World's `tile_changed` calls it.
func redraw_tile(world_pos: Vector2i) -> void:
	# The tile is a corner of the 4 cells around it.
	for offset: Vector2i in CORNER_OFFSETS:
		_redraw_cell(world_pos - offset)
	if world.is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		_draw_decoration(world_pos, _layer_at(world_pos))


## Called for every tile an object covers; it is drawn from its own tile only.
func _on_objects_changed(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	if object == null or object.pos == world_pos:
		_drop_object_sprite(world_pos)
		_draw_object(world_pos)
	_draw_decoration(world_pos, _layer_at(world_pos))


## Shakes a hit object: as a sprite, since a cell of the objects layer can't move alone.
func _shake_object(object: WorldObject) -> void:
	if not _object_sprites.has(object.pos):
		_swap_cell_for_sprite(object)
	_object_sprites[object.pos].shake()


func _load_chunk(coords: Vector2i) -> void:
	var chunk := _generator.generate_chunk(coords)
	world.add_chunk(chunk)
	_draw_chunk(chunk)


func _draw_chunk(chunk: Chunk) -> void:
	var coords := chunk.coords
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	var covered := _covered_tiles(chunk)
	# The corners of the chunk's cells: its own tiles plus the row above and the column to
	# the left. Reading them once, mostly straight from the chunk, is several times faster
	# than looking up 4 corners per cell through the world.
	var size := Chunk.CHUNK_SIZE + 1
	var corner_layers := PackedInt32Array()
	corner_layers.resize(size * size)
	for y in size:
		for x in size:
			var local := Vector2i(x - 1, y - 1)
			if x == 0 or y == 0:
				corner_layers[y * size + x] = _layer_at(origin + local)
			else:
				corner_layers[y * size + x] = _layer_of_tile(
					chunk.terrain_at(local), origin + local
				)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var top_left := y * size + x
			var corners := PackedInt32Array(
				[
					corner_layers[top_left],
					corner_layers[top_left + 1],
					corner_layers[top_left + size],
					corner_layers[top_left + size + 1]
				]
			)
			_draw_cell_corners(origin + Vector2i(x, y), corners)
			# The bottom-right corner is this chunk's tile (x, y).
			_set_decoration(
				origin + Vector2i(x, y), corners[3], covered.has(origin + Vector2i(x, y))
			)
	for object in chunk.objects():
		_draw_object(object.pos)
	# The right and bottom neighbours' border cells drew this chunk's tiles with a fallback
	# while it was missing. Now they can blend properly.
	for i in Chunk.CHUNK_SIZE + 1:
		_redraw_cell(origin + Vector2i(Chunk.CHUNK_SIZE, i))
	for i in Chunk.CHUNK_SIZE:
		_redraw_cell(origin + Vector2i(i, Chunk.CHUNK_SIZE))


## The tiles of a chunk that objects cover: those of its own objects, and those of objects
## from the loaded chunks above and to the left that reach in. Cheaper for a whole chunk than
## asking the world about every tile.
func _covered_tiles(chunk: Chunk) -> Dictionary[Vector2i, bool]:
	var covered: Dictionary[Vector2i, bool] = {}
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
		var neighbour := world.chunk_at(chunk.coords + offset)
		if neighbour == null:
			continue
		for object in neighbour.objects():
			for tile in object.tiles():
				covered[tile] = true
	return covered


func _unload_chunk(coords: Vector2i) -> void:
	for object in world.chunk_at(coords).objects():
		_drop_object_sprite(object.pos)
		_objects.erase_cell(object.pos)
		_remove_light(object.pos)
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			for tile_map in _layers:
				tile_map.erase_cell(origin + Vector2i(x, y))
			_decorations.erase_cell(origin + Vector2i(x, y))
	world.remove_chunk(coords)


## Redraws a cell if the chunk that owns it is loaded.
func _redraw_cell(cell: Vector2i) -> void:
	if not world.is_chunk_loaded(Chunk.world_to_chunk(cell)):
		return
	var corners := PackedInt32Array()
	for offset: Vector2i in CORNER_OFFSETS:
		corners.append(_layer_at(cell + offset))
	_draw_cell_corners(cell, corners)


## The one place tile state becomes a look: the layers of a cell's 4 corner tiles (in
## CORNER_OFFSETS order, MISSING where not loaded) decide which layers it draws and with
## which shapes.
func _draw_cell_corners(cell: Vector2i, corners: PackedInt32Array) -> void:
	TerrainTileset.fill_missing_corners(corners)
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer) == 0:
			_layers[layer].erase_cell(cell)
		else:
			var mask := TerrainTileset.mask_for(corners, layer)
			var atlas_cell := _tileset.atlas_cell(layer, mask, cell)
			_layers[layer].set_cell(cell, TerrainTileset.TERRAIN_SOURCE_ID, atlas_cell)


func _draw_object(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	_remove_light(world_pos)
	if object == null:
		_objects.erase_cell(world_pos)
		return
	_set_object_cell(object)
	if not object.light().is_empty():
		var light := ObjectLight.new(object.light(), world_pos)
		light.strength = _light_strength
		_lights[world_pos] = light
		add_child(light)


func _set_object_cell(object: WorldObject) -> void:
	_objects.set_cell(object.pos, ObjectTileset.SOURCE_ID, ObjectTileset.atlas_cell(object))


func _remove_light(world_pos: Vector2i) -> void:
	var light: ObjectLight = _lights.get(world_pos)
	if light != null:
		_lights.erase(world_pos)
		light.queue_free()


func _draw_building(building: Building) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var sprite := SeeThroughSprite.new()
	_building_sprites[building] = sprite
	sprite.texture = load(building_type["sprite"])
	sprite.centered = false
	# The sprite is sorted by its position: the middle of its bottom footprint row, like an
	# object standing on that row. Its bottom edge is the footprint's bottom edge.
	var half_tile := TerrainTileset.TILE_SIZE / 2
	var footprint_bottom: int = (
		(building.origin.y + building_type["footprint"].y) * TerrainTileset.TILE_SIZE
	)
	sprite.position = Vector2(
		building.origin.x * TerrainTileset.TILE_SIZE, footprint_bottom - half_tile
	)
	sprite.offset = Vector2(0, half_tile - sprite.texture.get_height())
	entities.add_child(sprite)
	_add_window_lights(building, sprite)


## Building windows: a lit sprite variant and a small warm light in each window, on at night.


func _add_window_lights(building: Building, sprite: Sprite2D) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var lights: Array[ObjectLight] = []
	for window_centre: Vector2i in building_type["window_lights"]:
		var light := ObjectLight.new(building_type["window_light"], building.origin)
		# On the window pane. The sprite's top left is its position plus its offset.
		light.position = sprite.position + sprite.offset + Vector2(window_centre)
		lights.append(light)
		add_child(light)
	_window_lights[building] = lights
	_show_windows(building)


func _show_windows(building: Building) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var is_lit := _light_strength >= WINDOW_LIT_STRENGTH
	var sprite := _building_sprites[building]
	var texture_path: String = building_type["sprite_lit"] if is_lit else building_type["sprite"]
	# The strength changes every frame while the tint does; the picture only at dusk and dawn.
	if sprite.texture.resource_path != texture_path:
		sprite.texture = load(texture_path)
	for light: ObjectLight in _window_lights[building]:
		light.strength = _light_strength if is_lit else 0.0


## Fades what hides the player and puts back what no longer does.
func _update_see_through(delta: float) -> void:
	for sprite in _object_sprites.values():
		sprite.is_occluding = false
	for object in Occlusion.occluding_objects(player_feet, world):
		if not _object_sprites.has(object.pos):
			_swap_cell_for_sprite(object)
		_object_sprites[object.pos].is_occluding = true
	for pos in _object_sprites.keys():
		var sprite := _object_sprites[pos]
		sprite.update(delta, player_feet)
		if sprite.is_plain():
			_drop_object_sprite(pos)
			_set_object_cell(world.object_at(pos))
	for sprite in _building_sprites.values():
		sprite.is_occluding = false
	for building in Occlusion.occluding_buildings(player_feet, world.buildings()):
		_building_sprites[building].is_occluding = true
	for sprite in _building_sprites.values():
		sprite.update(delta, player_feet)


## Erases an object's cell and draws the same picture as a sprite, sorted the same way.
func _swap_cell_for_sprite(object: WorldObject) -> void:
	var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	var texture := AtlasTexture.new()
	texture.atlas = load(ObjectTileset.ATLAS_PATH)
	texture.region = Rect2(ObjectTileset.atlas_cell(object) * cell_size, cell_size)
	var sprite := SeeThroughSprite.new()
	sprite.texture = texture
	sprite.centered = false
	# Like the tile map draws it (see ObjectTileset): sorted by the middle of the footprint's
	# bottom row, the cell's bottom on the footprint's bottom edge.
	var footprint: Vector2i = WorldObjectTypes.TYPES[object.type]["footprint"]
	var sort_shift := Vector2(0, (footprint.y - 1) * TerrainTileset.TILE_SIZE)
	sprite.position = (Vector2(object.pos) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE
	sprite.position += sort_shift
	sprite.offset = (
		-Vector2(cell_size) / 2 - Vector2(ObjectTileset.cell_origin(footprint)) - sort_shift
	)
	entities.add_child(sprite)
	_object_sprites[object.pos] = sprite
	_objects.erase_cell(object.pos)


## Frees the stand-in sprite of an object, if it has one. The caller sets the cell.
func _drop_object_sprite(world_pos: Vector2i) -> void:
	var sprite: SeeThroughSprite = _object_sprites.get(world_pos)
	if sprite != null:
		_object_sprites.erase(world_pos)
		sprite.queue_free()


func _draw_decoration(world_pos: Vector2i, layer: int) -> void:
	_set_decoration(world_pos, layer, world.object_at(world_pos) != null)


func _set_decoration(world_pos: Vector2i, layer: int, is_covered: bool) -> void:
	if is_covered:
		_decorations.erase_cell(world_pos)
		return
	var cluster := _decoration_noise.get_noise_2dv(Vector2(world_pos))
	var atlas_cell := _tileset.decoration_cell(layer, world_pos, cluster)
	if atlas_cell == TerrainTileset.NO_DECORATION:
		_decorations.erase_cell(world_pos)
	else:
		_decorations.set_cell(world_pos, TerrainTileset.DECORATION_SOURCE_ID, atlas_cell)


## The layer a tile is drawn on, or MISSING if its chunk is not loaded.
func _layer_at(world_pos: Vector2i) -> int:
	var chunk := world.chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null:
		return TerrainTileset.MISSING
	return _layer_of_tile(chunk.terrain_at(Chunk.local_pos(world_pos)), world_pos)


func _layer_of_tile(terrain: Tile.Terrain, world_pos: Vector2i) -> int:
	return TerrainTileset.layer_of(terrain, _variety_noise.get_noise_2dv(Vector2(world_pos)))
