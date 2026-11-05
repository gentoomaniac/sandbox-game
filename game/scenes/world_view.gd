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

## How long a frame may spend bringing the looks up to date after they changed. Scanning a
## chunk takes about 1 ms, redrawing the cells of one whose tiles all changed about 10 ms, so
## the work is cut into cells.
const REFRESH_BUDGET_USEC := 3000
const LOAD_RADIUS := 3
const UNLOAD_RADIUS := 5
## Loading a chunk (generating it, placing objects and drawing its layers and look overlays)
## takes ~14 ms. One per frame keeps a frame under 16 ms and still streams far faster than
## the camera moves; the look refresh waits for frames without a load (see `_process`).
const MAX_LOADS_PER_FRAME := 1
## An object state (see `_object_states`) for a plant that is dormant and not drawn.
const DORMANT := -1
## Added to an object state for a bush that is out of its fruit season.
const BARE_OF_FRUIT_FLAG := 16
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


## A place where a decoration could grow: its look, its Vegetation kind and fixed threshold,
## and whether it is drawn now, and in which look.
class DecorationSpot:
	extends RefCounted
	var atlas_cell: Vector2i
	var kind: StringName
	var threshold: float
	var is_shown := false
	## The terrain layer of its tile, which decides how its look shows.
	var layer := 0
	var look := SeasonBlend.Look.SUMMER


## What a chunk's tiles need for their looks, all by tile index (local y * CHUNK_SIZE + x).
class ChunkLooks:
	extends RefCounted
	## The thresholds of each tile (see SeasonBlend.thresholds).
	var season_thresholds := PackedFloat32Array()
	var weather_thresholds := PackedFloat32Array()
	## The look each tile has now by the season, and the look over it by the weather
	## (SeasonBlend.Look: FROST, SNOW or SUMMER for none).
	var season_looks := PackedByteArray()
	var weather_looks := PackedByteArray()
	## The terrain layer each tile is drawn on (TerrainTileset.Layer): its variety noise is the
	## slowest part of drawing a cell, and it does not change with the looks.
	var layers := PackedByteArray()

	static func index_of(local: Vector2i) -> int:
		return local.y * Chunk.CHUNK_SIZE + local.x


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
var _blend: SeasonBlend
## The day, the snow cover and the frost that the looks are drawn for.
var _look_state := Vector3(-1, 0, 0)
var _conditions: SeasonBlend.Conditions
var _day := 0
var _chunk_looks: Dictionary[Vector2i, ChunkLooks] = {}
## Chunks whose looks are not brought up to date yet, the nearest to the focus last.
var _refresh_queue: Array[Vector2i] = []
## Cells whose overlays must be drawn again after a refresh found their tiles' looks changed.
var _cells_to_redraw: Array[Vector2i] = []
## Where the overlay looks are drawn, by look.
var _overlays: Dictionary[SeasonBlend.Look, TileMapLayer] = {}
## What each object cell was last drawn as, by tile: its look, plus BARE_OF_FRUIT_FLAG if it
## showed as bare of fruit, or DORMANT if it was not drawn.
var _object_states: Dictionary[Vector2i, int] = {}
## Where a decoration could grow, shown or not, so a new day only revisits these tiles.
## Never under an object.
var _decoration_spots: Dictionary[Vector2i, DecorationSpot] = {}
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
	for look in TerrainTileset.OVERLAY_LOOKS:
		var tile_map := TileMapLayer.new()
		tile_map.name = "%sLook" % SeasonBlend.Look.keys()[look].capitalize()
		tile_map.tile_set = _tileset.tile_set
		tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
		add_child(tile_map)
		_overlays[look] = tile_map
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
	_blend = SeasonBlend.new(world.world_seed)
	_day = world.clock.day
	_conditions = _blend.conditions(_day, 0.0, 0.0)
	_look_state = Vector3(_day, 0.0, 0.0)
	for coords in world.loaded_chunk_coords():
		_draw_chunk(world.chunk_at(coords))
	for building in world.buildings():
		_draw_building(building)


## Sets the day, the snow cover and the frost (both 0 to 1) that tiles, plants and houses are
## drawn for. Does nothing while they are as they were; otherwise every loaded chunk is queued
## for a refresh, which `_process` does a few chunks per frame (chunks that load later are
## drawn for them right away).
func refresh_looks(day: int, snow_cover: float, frost: float) -> void:
	var state := Vector3(day, snow_cover, frost)
	if world == null or state == _look_state:
		return
	_look_state = state
	_day = day
	_conditions = _blend.conditions(day, snow_cover, frost)
	_refresh_queue.assign(world.loaded_chunk_coords())
	var focus := _focus_chunk
	_refresh_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus).length_squared() > (b - focus).length_squared()
	)
	for building in _building_sprites:
		_show_windows(building)


## Brings every queued chunk up to date at once (for tests and for a screenshot).
func finish_refresh() -> void:
	while not _refresh_queue.is_empty() or not _cells_to_redraw.is_empty():
		_refresh_step()


## Whether a flower is in bloom on a tile today and not under snow (wildlife visits those).
func has_flower(world_pos: Vector2i) -> bool:
	var spot: DecorationSpot = _decoration_spots.get(world_pos)
	return (
		spot != null
		and spot.is_shown
		and spot.kind == &"flower"
		and spot.look != SeasonBlend.Look.SNOW
	)


## The tiles within a rectangle (in world pixels) where a flower is in bloom today.
func flower_tiles_within(area: Rect2) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var first := Vector2i((area.position / TerrainTileset.TILE_SIZE).floor())
	var last := Vector2i((area.end / TerrainTileset.TILE_SIZE).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if has_flower(Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	return tiles


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
	# A load already fills most of a frame, so the look refresh only runs in frames without one.
	if to_load.is_empty():
		var deadline := Time.get_ticks_usec() + REFRESH_BUDGET_USEC
		while Time.get_ticks_usec() < deadline and _is_refreshing():
			_refresh_step()
	is_settled = to_load.is_empty() and not _is_refreshing()
	_update_see_through(delta)


## Redraws one tile after its state changed. World's `tile_changed` calls it.
func redraw_tile(world_pos: Vector2i) -> void:
	var chunk_looks: ChunkLooks = _chunk_looks.get(Chunk.world_to_chunk(world_pos))
	if chunk_looks != null:
		var local := Chunk.local_pos(world_pos)
		var terrain := world.chunk_at(Chunk.world_to_chunk(world_pos)).terrain_at(local)
		chunk_looks.layers[ChunkLooks.index_of(local)] = _layer_of_tile(terrain, world_pos)
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
	var chunk_looks := _make_chunk_looks(chunk)
	_chunk_looks[coords] = chunk_looks
	_refresh_queue.erase(coords)
	var covered := _covered_tiles(chunk)
	# The corners of the chunk's cells: its own tiles plus the row above and the column to
	# the left. Reading them once, mostly straight from the chunk, is several times faster
	# than looking up 4 corners per cell through the world.
	var size := Chunk.CHUNK_SIZE + 1
	var corner_layers := PackedInt32Array()
	corner_layers.resize(size * size)
	var corner_seasons := PackedInt32Array()
	corner_seasons.resize(size * size)
	var corner_weathers := PackedInt32Array()
	corner_weathers.resize(size * size)
	for y in size:
		for x in size:
			var local := Vector2i(x - 1, y - 1)
			if x == 0 or y == 0:
				corner_layers[y * size + x] = _layer_at(origin + local)
				corner_seasons[y * size + x] = _season_look_at(origin + local)
				corner_weathers[y * size + x] = _weather_look_at(origin + local)
			else:
				var index := ChunkLooks.index_of(local)
				corner_layers[y * size + x] = chunk_looks.layers[index]
				corner_seasons[y * size + x] = chunk_looks.season_looks[index]
				corner_weathers[y * size + x] = chunk_looks.weather_looks[index]
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
			var seasons := PackedInt32Array(
				[
					corner_seasons[top_left],
					corner_seasons[top_left + 1],
					corner_seasons[top_left + size],
					corner_seasons[top_left + size + 1]
				]
			)
			var weathers := PackedInt32Array(
				[
					corner_weathers[top_left],
					corner_weathers[top_left + 1],
					corner_weathers[top_left + size],
					corner_weathers[top_left + size + 1]
				]
			)
			_draw_cell_corners(origin + Vector2i(x, y), corners, seasons, weathers)
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


## The thresholds of a chunk's tiles and the looks they have now.
func _make_chunk_looks(chunk: Chunk) -> ChunkLooks:
	var chunk_looks := ChunkLooks.new()
	var tile_count := Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE
	chunk_looks.season_thresholds.resize(tile_count)
	chunk_looks.weather_thresholds.resize(tile_count)
	chunk_looks.season_looks.resize(tile_count)
	chunk_looks.weather_looks.resize(tile_count)
	chunk_looks.layers.resize(tile_count)
	var origin := Chunk.to_world(chunk.coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var index := y * Chunk.CHUNK_SIZE + x
			var thresholds := _blend.thresholds(origin + Vector2i(x, y))
			chunk_looks.layers[index] = _layer_of_tile(
				chunk.terrain_at(Vector2i(x, y)), origin + Vector2i(x, y)
			)
			chunk_looks.season_thresholds[index] = thresholds.x
			chunk_looks.weather_thresholds[index] = thresholds.y
			chunk_looks.season_looks[index] = _conditions.ground_season_look(thresholds.x)
			chunk_looks.weather_looks[index] = _conditions.weather_look(thresholds.y)
	return chunk_looks


func _is_refreshing() -> bool:
	return not _refresh_queue.is_empty() or not _cells_to_redraw.is_empty()


## Redraws a cell, or if none is waiting, scans the next queued chunk.
func _refresh_step() -> void:
	if _cells_to_redraw.is_empty():
		_refresh_chunk(_refresh_queue.pop_back())
	else:
		_redraw_cell(_cells_to_redraw.pop_back(), false)


## Brings a loaded chunk up to date with the day, the snow cover and the frost: redraws the
## decorations and objects that changed and queues the overlay cells around the tiles whose
## look changed.
func _refresh_chunk(coords: Vector2i) -> void:
	var chunk := world.chunk_at(coords)
	var chunk_looks: ChunkLooks = _chunk_looks.get(coords)
	if chunk == null or chunk_looks == null:
		return
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	var changed_cells: Dictionary[Vector2i, bool] = {}
	for index in chunk_looks.season_looks.size():
		var season_look := _conditions.ground_season_look(chunk_looks.season_thresholds[index])
		var weather_look := _conditions.weather_look(chunk_looks.weather_thresholds[index])
		var pos := origin + Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE)
		if (
			season_look != chunk_looks.season_looks[index]
			or weather_look != chunk_looks.weather_looks[index]
		):
			chunk_looks.season_looks[index] = season_look
			chunk_looks.weather_looks[index] = weather_look
			for offset: Vector2i in CORNER_OFFSETS:
				changed_cells[pos - offset] = true
		var spot: DecorationSpot = _decoration_spots.get(pos)
		if spot != null:
			_update_decoration(pos, spot)
	_cells_to_redraw.append_array(changed_cells.keys())
	for object in chunk.objects():
		if _object_states.get(object.pos, DORMANT) != _object_state(object):
			_on_objects_changed(object.pos)


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
			if world.is_dormant(object):
				continue
			for tile in object.tiles():
				covered[tile] = true
	return covered


func _unload_chunk(coords: Vector2i) -> void:
	for object in world.chunk_at(coords).objects():
		_drop_object_sprite(object.pos)
		_objects.erase_cell(object.pos)
		_object_states.erase(object.pos)
		_remove_light(object.pos)
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	_chunk_looks.erase(coords)
	_refresh_queue.erase(coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			for tile_map in _layers:
				tile_map.erase_cell(origin + Vector2i(x, y))
			for tile_map in _overlays.values():
				tile_map.erase_cell(origin + Vector2i(x, y))
			_decorations.erase_cell(origin + Vector2i(x, y))
			_decoration_spots.erase(origin + Vector2i(x, y))
	world.remove_chunk(coords)


## Redraws a cell if the chunk that owns it is loaded: its terrain layers too, unless only the
## looks of its tiles changed.
func _redraw_cell(cell: Vector2i, is_terrain_changed := true) -> void:
	if not world.is_chunk_loaded(Chunk.world_to_chunk(cell)):
		return
	var corners := PackedInt32Array()
	var seasons := PackedInt32Array()
	var weathers := PackedInt32Array()
	for offset: Vector2i in CORNER_OFFSETS:
		corners.append(_layer_at(cell + offset))
		seasons.append(_season_look_at(cell + offset))
		weathers.append(_weather_look_at(cell + offset))
	if is_terrain_changed:
		_draw_cell_corners(cell, corners, seasons, weathers)
	else:
		TerrainTileset.fill_missing_corners(corners)
		TerrainTileset.fill_missing_corners(seasons)
		TerrainTileset.fill_missing_corners(weathers)
		_draw_overlays(cell, corners, seasons, weathers)


## The one place tile state becomes a look: the layers of a cell's 4 corner tiles (in
## CORNER_OFFSETS order, MISSING where not loaded) decide which layers it draws and with
## which shapes, and their season and weather looks which overlays.
func _draw_cell_corners(
	cell: Vector2i, corners: PackedInt32Array, seasons: PackedInt32Array, weathers: PackedInt32Array
) -> void:
	TerrainTileset.fill_missing_corners(corners)
	TerrainTileset.fill_missing_corners(seasons)
	TerrainTileset.fill_missing_corners(weathers)
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer) == 0:
			_layers[layer].erase_cell(cell)
		else:
			var mask := TerrainTileset.mask_for(corners, layer)
			var atlas_cell := _tileset.atlas_cell(layer, mask, cell)
			_layers[layer].set_cell(
				cell, TerrainTileset.terrain_source_id(SeasonBlend.Look.SUMMER), atlas_cell
			)
	_draw_overlays(cell, corners, seasons, weathers)


## The overlay looks of a cell: for each, the tiles of the 4 corners that show it make the
## mask. A season's look takes its edge shape from the grass layer of the corners (ordinary,
## lush or dry), snow and frost always from ordinary grass. Snow and frost lie over the
## season's look, so a tile under them still counts for that.
func _draw_overlays(
	cell: Vector2i, corners: PackedInt32Array, seasons: PackedInt32Array, weathers: PackedInt32Array
) -> void:
	var shown_seasons := PackedInt32Array()
	var shown_weathers := PackedInt32Array()
	for corner in 4:
		shown_seasons.append(
			TerrainTileset.shown_season_look(corners[corner], seasons[corner] as SeasonBlend.Look)
		)
		shown_weathers.append(
			TerrainTileset.shown_weather_look(corners[corner], weathers[corner] as SeasonBlend.Look)
		)
	for look in TerrainTileset.OVERLAY_LOOKS:
		var is_season := not TerrainTileset.is_weather_look(look)
		var shown := shown_seasons if is_season else shown_weathers
		var mask := 0
		var layer: int = TerrainTileset.Layer.GRASS
		for corner in 4:
			if shown[corner] == look:
				mask |= 1 << corner
				if is_season:
					layer = maxi(layer, corners[corner])
		if mask == 0:
			_overlays[look].erase_cell(cell)
		else:
			_overlays[look].set_cell(
				cell, TerrainTileset.terrain_source_id(look), _tileset.atlas_cell(layer, mask, cell)
			)


func _draw_object(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	_remove_light(world_pos)
	if object == null:
		_objects.erase_cell(world_pos)
		_object_states.erase(world_pos)
		return
	_set_object_cell(object)
	if not object.light().is_empty():
		var light := ObjectLight.new(object.light(), world_pos)
		light.strength = _light_strength
		_lights[world_pos] = light
		add_child(light)


func _set_object_cell(object: WorldObject) -> void:
	_objects.set_cell(
		object.pos, _object_look(object), ObjectTileset.atlas_cell(object, world.is_bare(object))
	)
	_object_states[object.pos] = _object_state(object)


## The look of an object: of the foliage of its season, or snowy or frosty with its tile's
## weather threshold.
func _object_look(object: WorldObject) -> SeasonBlend.Look:
	var thresholds := _blend.thresholds(object.pos)
	return _conditions.foliage_look(thresholds.x, thresholds.y)


## What an object is drawn as: its look, with a flag if it is out of its fruit season, or
## DORMANT if it is not drawn. A change of the state means the cell must be drawn again.
func _object_state(object: WorldObject) -> int:
	if world.is_dormant(object):
		return DORMANT
	return _object_look(object) + (BARE_OF_FRUIT_FLAG if world.is_bare(object) else 0)


func _remove_light(world_pos: Vector2i) -> void:
	var light: ObjectLight = _lights.get(world_pos)
	if light != null:
		_lights.erase(world_pos)
		light.queue_free()


func _draw_building(building: Building) -> void:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var sprite := SeeThroughSprite.new()
	_building_sprites[building] = sprite
	sprite.texture = load(SeasonalArt.house_path(building_type["sprite"], _is_snowy(building)))
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
	var texture_path := SeasonalArt.house_path(
		building_type["sprite_lit"] if is_lit else building_type["sprite"], _is_snowy(building)
	)
	# The strength changes every frame while the tint does; the picture only at dusk and dawn.
	if sprite.texture.resource_path != texture_path:
		sprite.texture = load(texture_path)
	for light: ObjectLight in _window_lights[building]:
		light.strength = _light_strength if is_lit else 0.0


## Whether a house has snow on its roof: when the snow cover is above its tile's threshold.
func _is_snowy(building: Building) -> bool:
	return _conditions.snow_cover > _blend.thresholds(building.origin).y


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
	var sprite := SeeThroughSprite.new()
	sprite.texture = _object_texture(object)
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


## The picture of an object as it looks now, for its stand-in sprite.
func _object_texture(object: WorldObject) -> AtlasTexture:
	var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	var texture := AtlasTexture.new()
	texture.atlas = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, _object_look(object)))
	texture.region = Rect2(
		ObjectTileset.atlas_cell(object, world.is_bare(object)) * cell_size, cell_size
	)
	return texture


## Frees the stand-in sprite of an object, if it has one. The caller sets the cell.
func _drop_object_sprite(world_pos: Vector2i) -> void:
	var sprite: SeeThroughSprite = _object_sprites.get(world_pos)
	if sprite != null:
		_object_sprites.erase(world_pos)
		sprite.queue_free()


func _draw_decoration(world_pos: Vector2i, layer: int) -> void:
	_set_decoration(world_pos, layer, world.object_at(world_pos) != null)


func _set_decoration(world_pos: Vector2i, layer: int, is_covered: bool) -> void:
	var atlas_cell := TerrainTileset.NO_DECORATION
	if not is_covered:
		var cluster := _decoration_noise.get_noise_2dv(Vector2(world_pos))
		atlas_cell = _tileset.decoration_cell(layer, world_pos, cluster)
	_decorations.erase_cell(world_pos)
	if atlas_cell == TerrainTileset.NO_DECORATION:
		_decoration_spots.erase(world_pos)
		return
	var spot := DecorationSpot.new()
	spot.atlas_cell = atlas_cell
	spot.kind = TerrainTileset.decoration_kind(atlas_cell)
	spot.layer = layer
	if spot.kind != &"":
		spot.threshold = world.vegetation.threshold(spot.kind, world.world_seed, world_pos)
	_decoration_spots[world_pos] = spot
	_update_decoration(world_pos, spot)


## Draws, erases or redraws the decoration of a spot, as its kind is present today and as the
## look of its tile is now.
func _update_decoration(world_pos: Vector2i, spot: DecorationSpot) -> void:
	var should_show := spot.kind == &"" or world.vegetation.shows(spot.kind, spot.threshold, _day)
	var look := TerrainTileset.shown_look(
		spot.layer,
		_season_look_at(world_pos) as SeasonBlend.Look,
		_weather_look_at(world_pos) as SeasonBlend.Look
	)
	if should_show == spot.is_shown and (look == spot.look or not should_show):
		return
	spot.is_shown = should_show
	spot.look = look
	if should_show:
		_decorations.set_cell(world_pos, TerrainTileset.decoration_source_id(look), spot.atlas_cell)
	else:
		_decorations.erase_cell(world_pos)


## The look of a tile by the season, or TerrainTileset.MISSING if its chunk is not loaded.
func _season_look_at(world_pos: Vector2i) -> int:
	var chunk_looks: ChunkLooks = _chunk_looks.get(Chunk.world_to_chunk(world_pos))
	if chunk_looks == null:
		return TerrainTileset.MISSING
	return chunk_looks.season_looks[ChunkLooks.index_of(Chunk.local_pos(world_pos))]


## The look of a tile by the weather, or TerrainTileset.MISSING if its chunk is not loaded.
func _weather_look_at(world_pos: Vector2i) -> int:
	var chunk_looks: ChunkLooks = _chunk_looks.get(Chunk.world_to_chunk(world_pos))
	if chunk_looks == null:
		return TerrainTileset.MISSING
	return chunk_looks.weather_looks[ChunkLooks.index_of(Chunk.local_pos(world_pos))]


## The layer a tile is drawn on, or MISSING if its chunk is not loaded.
func _layer_at(world_pos: Vector2i) -> int:
	var chunk_looks: ChunkLooks = _chunk_looks.get(Chunk.world_to_chunk(world_pos))
	if chunk_looks == null:
		return TerrainTileset.MISSING
	return chunk_looks.layers[ChunkLooks.index_of(Chunk.local_pos(world_pos))]


func _layer_of_tile(terrain: Tile.Terrain, world_pos: Vector2i) -> int:
	return TerrainTileset.layer_of(terrain, _variety_noise.get_noise_2dv(Vector2(world_pos)))
