class_name WorldView
extends Node2D
## Renders a World and streams chunks in and out around a focus.
##
## One TileMapLayer per terrain layer for the whole world (not per chunk), drawn as a dual
## grid (see TerrainTileset): cell (x, y) of every layer is shifted half a tile up and left,
## so its corners sit on world tiles (x - 1, y - 1) to (x, y). A chunk owns the cells whose
## bottom-right tile is its own, so loading or unloading it fills or erases those cells,
## with no nodes to create or free. On top, the DecorationView on the plain tile grid
## scatters flowers, pebbles and the like. Above that, the damp or wet look of tilled soil (see
## SoilWetness), and an objects layer on the same grid that draws the world's objects. It sits
## in the y-sorted `entities` node, where the player (and later creatures) stand among them, and
## keeps no decoration under an object.
## Objects that shine get an ObjectLight. Plants, water, fires and lily pads move in the wind
## by the materials of `ambient_motion`, and the rain splashes on the ground under the objects.
##
## A tree that is felled topples as a FallingTree sprite while the state already has its stump
## and its trunk; the trunk's cell stays erased until the fall ends.
## The buildings are BuildingViews, sprites in that node too, so they sort with the objects and
## the player.
##
## See-through: while a tree or building hides the player (see Occlusion) it fades inside a
## circle around the player. A building is a SeeThroughSprite already; a tree is a cell of the
## objects layer, which can't fade, so while it occludes (and while it fades back) its cell
## is erased and a SeeThroughSprite at the same place in the y-sorted node draws it instead.

## A tree was felled and starts to fall, for `seconds` until it lands.
signal tree_felled(tile: Vector2i, seconds: float)
## A felled tree hit the ground (where the sound of it belongs). `tree` is the object it was.
signal tree_landed(tree: WorldObject)

## How long a frame may spend bringing the looks up to date after they changed. Scanning a
## chunk takes about 1 ms, redrawing the cells of one whose tiles all changed about 10 ms, so
## the work is cut into cells.
const REFRESH_BUDGET_USEC := 3000
## The lower part of a tree's canopy, as a share of its picture's height above the picture's
## bottom: what falls from there passes the trunk and shows against the ground.
const CANOPY_HEIGHT_SHARE := 0.45
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

## The 4 corner tiles of a cell, in mask order: top-left, top-right, bottom-left,
## bottom-right.
const CORNER_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)
]

## Visual-only noise, seeded from the world seed with an offset far from the generator's.
## Variety: grass turns lush or dry over patches about this many tiles across.
const VARIETY_SEED_OFFSET := 7919
const VARIETY_FREQUENCY := 0.008


## What a chunk's tiles need for their looks, all by tile index (local y * CHUNK_SIZE + x).
class ChunkLooks:
	extends RefCounted
	## The thresholds of each tile (see SeasonBlend.thresholds).
	var season_thresholds := PackedFloat32Array()
	var weather_thresholds := PackedFloat32Array()
	## The code of each tile (see TerrainTileset.tile_code): the terrain layer it is drawn on,
	## the look it has now by the season and the look over it by the weather. The layer comes
	## from the variety noise, the slowest part of drawing a cell, and does not change with the
	## looks.
	var codes := PackedInt32Array()

	static func index_of(local: Vector2i) -> int:
		return local.y * Chunk.CHUNK_SIZE + local.x


var world: World
## Y-sorted: whatever is added here is drawn in front of or behind the objects by its y.
var entities := Node2D.new()
## True once every chunk around the focus is loaded.
var is_settled := false
## Where the player stands, in world pixels (set by the game scene every frame).
var player_feet := Vector2.ZERO
## The game scene gives it the wind and the rain every frame.
var ambient_motion := AmbientMotion.new()
## The flowers and pebbles on the ground and the hints of clay spots; the wildlife asks it where
## flowers bloom.
var decorations: DecorationView
var _generator: WorldGenerator
var _hit_particles := HitParticles.new()
var _variety_noise := FastNoiseLite.new()
var _focus_chunk := Vector2i.ZERO
var _tileset := TerrainTileset.new(ambient_motion)
var _object_tileset := ObjectTileset.new(CropRules.default_rules(), ambient_motion)
## Indexed by TerrainTileset.Layer.
var _layers: Array[TileMapLayer] = []
var _soil_wetness := SoilWetness.new()
var _objects := TileMapLayer.new()
## The light of each shining object, by tile.
var _lights: Dictionary[Vector2i, ObjectLight] = {}
var _light_strength := 1.0
var _blend: SeasonBlend
## The day, the snow cover and the frost that the looks are drawn for.
var _look_state := Vector3(-1, 0, 0)
var _conditions: SeasonBlend.Conditions
var _chunk_looks: Dictionary[Vector2i, ChunkLooks] = {}
## Chunks whose looks are not brought up to date yet, the nearest to the focus last.
var _refresh_queue: Array[Vector2i] = []
## Cells whose overlays must be drawn again after a refresh found their tiles' looks changed.
var _cells_to_redraw: Array[Vector2i] = []
## Where the overlay looks are drawn, by look. A season's look has this layer for ordinary
## grass and all other land, and a layer over it for each lush and dry grass (see below).
var _overlays: Dictionary[SeasonBlend.Look, TileMapLayer] = {}
## The overlays of a season's look over lush and dry grass, by Vector2i(look, layer). They
## stack like the terrain layers they follow, so lush and dry grass keep their own edges.
var _variety_overlays: Dictionary[Vector2i, TileMapLayer] = {}
## What each object cell was last drawn as, by tile: its look, plus BARE_OF_FRUIT_FLAG if it
## showed as bare of fruit, or DORMANT if it was not drawn.
var _object_states: Dictionary[Vector2i, int] = {}
## The sprites that stand in for object cells while they are see-through, by tile.
var _object_sprites: Dictionary[Vector2i, SeeThroughSprite] = {}
var _falling_trees: Array[FallingTree] = []
## The trunks (by tile) that a falling tree is about to lie down as, and that are not drawn yet.
var _hidden_trunks: Dictionary[Vector2i, bool] = {}
var _buildings := BuildingViews.new(entities)


func _init() -> void:
	decorations = DecorationView.new(_tileset)


func _ready() -> void:
	for layer in TerrainTileset.LAYER_COUNT:
		var tile_map := TileMapLayer.new()
		tile_map.name = TerrainTileset.Layer.keys()[layer].capitalize()
		tile_map.tile_set = _tileset.tile_set
		tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
		add_child(tile_map)
		_layers.append(tile_map)
	_layers[TerrainTileset.Layer.WATER].material = ambient_motion.water
	# Wet soil lies right over the soil terrain, under the snow and the other looks.
	add_child(_soil_wetness)
	for look in TerrainTileset.OVERLAY_LOOKS:
		var look_name: String = SeasonBlend.Look.keys()[look].capitalize()
		_overlays[look] = _add_overlay("%sLook" % look_name)
		if TerrainTileset.is_weather_look(look):
			continue
		for layer in TerrainTileset.VARIETY_LAYERS:
			var layer_name: String = TerrainTileset.Layer.keys()[layer].capitalize()
			_variety_overlays[Vector2i(look, layer)] = _add_overlay(
				"%s%sLook" % [look_name, layer_name]
			)
	add_child(decorations)
	add_child(RainSplashes.new(ambient_motion))
	_objects.name = "Objects"
	_objects.tile_set = _object_tileset.tile_set
	_objects.y_sort_enabled = true
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.add_child(_objects)
	add_child(entities)
	add_child(_hit_particles)
	add_child(_buildings)


func _add_overlay(overlay_name: String) -> TileMapLayer:
	var tile_map := TileMapLayer.new()
	tile_map.name = overlay_name
	tile_map.tile_set = _tileset.tile_set
	tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
	add_child(tile_map)
	return tile_map


## Shows a world, including the chunks that are already loaded in it.
func show_world(world_to_show: World) -> void:
	world = world_to_show
	world.objects_changed.connect(_on_objects_changed)
	world.tile_changed.connect(redraw_tile)
	world.object_hit.connect(_on_object_hit)
	world.clay_spot_changed.connect(_on_clay_spot_changed)
	_soil_wetness.show_world(world, is_snowed_over)
	world.building_placed.connect(_buildings.add)
	_generator = WorldGenerator.new(world.world_seed)
	_variety_noise.seed = world.world_seed + VARIETY_SEED_OFFSET
	_variety_noise.frequency = VARIETY_FREQUENCY
	decorations.show_world(world)
	_blend = SeasonBlend.new(world.world_seed)
	decorations.day = world.clock.day
	_conditions = _blend.conditions(decorations.day, 0.0, 0.0)
	_look_state = Vector3(decorations.day, 0.0, 0.0)
	_buildings.set_looks(_blend, _conditions)
	for coords in world.loaded_chunk_coords():
		_draw_chunk(world.chunk_at(coords))
	for building in world.buildings():
		_buildings.add(building)


## Sets the day, the snow cover and the frost (both 0 to 1) that tiles, plants and houses are
## drawn for. Does nothing while they are as they were; otherwise every loaded chunk is queued
## for a refresh, which `_process` does a few chunks per frame (chunks that load later are
## drawn for them right away).
func refresh_looks(day: int, snow_cover: float, frost: float) -> void:
	var state := Vector3(day, snow_cover, frost)
	if world == null or state == _look_state:
		return
	_look_state = state
	decorations.day = day
	_conditions = _blend.conditions(day, snow_cover, frost)
	_refresh_queue.assign(world.loaded_chunk_coords())
	var focus := _focus_chunk
	_refresh_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus).length_squared() > (b - focus).length_squared()
	)
	_buildings.set_looks(_blend, _conditions)


## Brings every queued chunk up to date at once (for tests and for a screenshot).
func finish_refresh() -> void:
	while not _refresh_queue.is_empty() or not _cells_to_redraw.is_empty():
		_refresh_step()


## Sets how brightly every light shines (see ObjectLight.strength).
func set_light_strength(strength: float) -> void:
	_light_strength = strength
	for light in _lights.values():
		light.strength = strength
	_buildings.set_light_strength(strength)


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
	_update_falling_trees(delta)


## Redraws one tile after its state changed. World's `tile_changed` calls it.
func redraw_tile(world_pos: Vector2i) -> void:
	var chunk_looks: ChunkLooks = _chunk_looks.get(Chunk.world_to_chunk(world_pos))
	if chunk_looks != null:
		var local := Chunk.local_pos(world_pos)
		var terrain := world.chunk_at(Chunk.world_to_chunk(world_pos)).terrain_at(local)
		var index := ChunkLooks.index_of(local)
		var code := chunk_looks.codes[index]
		chunk_looks.codes[index] = TerrainTileset.tile_code(
			_layer_of_tile(terrain, world_pos),
			TerrainTileset.season_of(code),
			TerrainTileset.weather_of(code)
		)
	# The tile is a corner of the 4 cells around it.
	for offset: Vector2i in CORNER_OFFSETS:
		_redraw_cell(world_pos - offset)
	if world.is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		decorations.redraw(world_pos, _code_at(world_pos))


## Called for every tile an object covers; it is drawn from its own tile only.
func _on_objects_changed(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	if object == null or object.pos == world_pos:
		_drop_object_sprite(world_pos)
		_draw_object(world_pos)
	decorations.redraw(world_pos, _code_at(world_pos))
	# The lines beside it may join it now, or no longer.
	for side in World.CONNECTION_SIDES:
		var neighbour := world.object_at(world_pos + side)
		if (
			neighbour != null
			and neighbour.pos == world_pos + side
			and neighbour.type_data().has("connects")
		):
			_drop_object_sprite(neighbour.pos)
			_draw_object(neighbour.pos)


func _on_clay_spot_changed(world_pos: Vector2i) -> void:
	decorations.redraw(world_pos, _code_at(world_pos))


## A tool hit an object: what it leaves, if any, shakes (a stump, after the last hit), and
## what flies off it depends on the look the object had. The finishing hit on a tree has it
## topple instead, and the stump shakes when it lands.
func _on_object_hit(object: WorldObject) -> void:
	if world.is_gone(object) and object.type_data().has("leaves"):
		_start_fall(object)
		return
	_hit_particles.emit(_hit_effect(object), _hit_origin(object))
	var standing := world.object_at(object.pos)
	if standing != null:
		_shake_object(standing)


func _hit_effect(object: WorldObject) -> HitEffect.Kind:
	var look := _object_look(object)
	if look == SeasonBlend.Look.FROST:
		look = _conditions.foliage_season_look(_blend.thresholds(object.pos).x)
	return HitEffect.kind_for(object.type, look)


## Where a hit object throws its particles, in world pixels: the canopy of a tree, else the
## middle of the object.
func _hit_origin(object: WorldObject) -> Vector2:
	var type_data := object.type_data()
	var footprint: Vector2i = type_data["footprint"]
	var middle := (Vector2(object.pos) + Vector2(footprint) / 2) * TerrainTileset.TILE_SIZE
	if not type_data.has("sprite_height"):
		return middle
	var bottom := (object.pos.y + footprint.y) * TerrainTileset.TILE_SIZE
	return Vector2(middle.x, bottom - CANOPY_HEIGHT_SHARE * type_data["sprite_height"])


## Shakes an object: as a sprite, since a cell of the objects layer can't move alone.
func _shake_object(object: WorldObject) -> void:
	if _hidden_trunks.has(object.pos):
		return
	if not _object_sprites.has(object.pos):
		_swap_cell_for_sprite(object)
	_object_sprites[object.pos].shake()


func _load_chunk(coords: Vector2i) -> void:
	var chunk := _generator.generate_chunk(coords)
	world.add_chunk(chunk)
	_draw_chunk(chunk)
	# The tilled soil of the chunk now knows whether snow lies on it.
	for pos in world.tilled_tiles():
		if Chunk.world_to_chunk(pos) == coords:
			_soil_wetness.redraw_tile(pos)


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
	var corner_codes := PackedInt32Array()
	corner_codes.resize(size * size)
	for y in size:
		for x in size:
			var local := Vector2i(x - 1, y - 1)
			if x == 0 or y == 0:
				corner_codes[y * size + x] = _code_at(origin + local)
			else:
				corner_codes[y * size + x] = chunk_looks.codes[ChunkLooks.index_of(local)]
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var top_left := y * size + x
			var codes := PackedInt32Array(
				[
					corner_codes[top_left],
					corner_codes[top_left + 1],
					corner_codes[top_left + size],
					corner_codes[top_left + size + 1]
				]
			)
			_draw_cell_corners(origin + Vector2i(x, y), codes)
			# The bottom-right corner is this chunk's tile (x, y).
			decorations.place(
				origin + Vector2i(x, y), codes[3], covered.has(origin + Vector2i(x, y))
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
	chunk_looks.codes.resize(tile_count)
	var origin := Chunk.to_world(chunk.coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var index := y * Chunk.CHUNK_SIZE + x
			var thresholds := _blend.thresholds(origin + Vector2i(x, y))
			chunk_looks.season_thresholds[index] = thresholds.x
			chunk_looks.weather_thresholds[index] = thresholds.y
			chunk_looks.codes[index] = TerrainTileset.tile_code(
				_layer_of_tile(chunk.terrain_at(Vector2i(x, y)), origin + Vector2i(x, y)),
				_conditions.ground_season_look(thresholds.x),
				_conditions.weather_look(thresholds.y)
			)
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
	for index in chunk_looks.codes.size():
		var old_code := chunk_looks.codes[index]
		var code := TerrainTileset.tile_code(
			TerrainTileset.layer_of(old_code),
			_conditions.ground_season_look(chunk_looks.season_thresholds[index]),
			_conditions.weather_look(chunk_looks.weather_thresholds[index])
		)
		var pos := origin + Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE)
		if code != old_code:
			chunk_looks.codes[index] = code
			_soil_wetness.redraw_tile(pos)
			for offset: Vector2i in CORNER_OFFSETS:
				changed_cells[pos - offset] = true
		decorations.refresh(pos, chunk_looks.codes[index])
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
	var overlays := _overlays.values() + _variety_overlays.values()
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			for tile_map in _layers:
				tile_map.erase_cell(origin + Vector2i(x, y))
			for tile_map in overlays:
				tile_map.erase_cell(origin + Vector2i(x, y))
			decorations.forget(origin + Vector2i(x, y))
	world.remove_chunk(coords)
	for fall in _falling_trees.duplicate():
		if Chunk.world_to_chunk(fall.tree.pos) == coords:
			_end_fall(fall)


## Redraws a cell if the chunk that owns it is loaded: its terrain layers too, unless only the
## looks of its tiles changed.
func _redraw_cell(cell: Vector2i, is_terrain_changed := true) -> void:
	if not world.is_chunk_loaded(Chunk.world_to_chunk(cell)):
		return
	var codes := PackedInt32Array()
	for offset: Vector2i in CORNER_OFFSETS:
		codes.append(_code_at(cell + offset))
	if is_terrain_changed:
		_draw_cell_corners(cell, codes)
	else:
		TerrainTileset.fill_missing_corners(codes)
		_draw_overlays(cell, codes)


## The one place tile state becomes a look: the codes of a cell's 4 corner tiles (in
## CORNER_OFFSETS order, MISSING where not loaded). Their layers decide which layers it draws
## and with which shapes, and their season and weather looks which overlays.
func _draw_cell_corners(cell: Vector2i, codes: PackedInt32Array) -> void:
	TerrainTileset.fill_missing_corners(codes)
	var corners := TerrainTileset.layers_of(codes)
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
	_draw_overlays(cell, codes)


## The overlay looks of a cell: for each, the tiles of the 4 corners that show it make the
## mask. A season's look is drawn like the grass terrain it covers: ordinary grass (and all
## other land) first, then lush and dry grass over it with their own masks, so their edges
## stay soft instead of filling the whole cell. Where lush or dry grass has the same mask as
## the layer below, it alone is drawn, since both edges together would show as a fringe.
## Snow and frost lie over the season's look, so a tile under them still counts for that,
## and are drawn as ordinary grass.
func _draw_overlays(cell: Vector2i, codes: PackedInt32Array) -> void:
	var corners := TerrainTileset.layers_of(codes)
	var shown_seasons := PackedInt32Array()
	var shown_weathers := PackedInt32Array()
	for corner in 4:
		shown_seasons.append(
			TerrainTileset.shown_season_look(
				corners[corner], TerrainTileset.season_of(codes[corner])
			)
		)
		shown_weathers.append(
			TerrainTileset.shown_weather_look(
				corners[corner], TerrainTileset.weather_of(codes[corner])
			)
		)
	for look in TerrainTileset.OVERLAY_LOOKS:
		if TerrainTileset.is_weather_look(look):
			var mask := _overlay_mask(look, TerrainTileset.Layer.WATER, shown_weathers, corners)
			_set_overlay_cell(_overlays[look], look, TerrainTileset.Layer.GRASS, mask, cell)
			continue
		var ordinary_mask := _overlay_mask(look, TerrainTileset.Layer.WATER, shown_seasons, corners)
		if ordinary_mask == 0:
			_overlays[look].erase_cell(cell)
			_variety_overlays[Vector2i(look, TerrainTileset.Layer.LUSH_GRASS)].erase_cell(cell)
			_variety_overlays[Vector2i(look, TerrainTileset.Layer.DRY_GRASS)].erase_cell(cell)
			continue
		var lush_mask := _overlay_mask(
			look, TerrainTileset.Layer.LUSH_GRASS, shown_seasons, corners
		)
		var dry_mask := _overlay_mask(look, TerrainTileset.Layer.DRY_GRASS, shown_seasons, corners)
		_set_overlay_cell(
			_overlays[look],
			look,
			TerrainTileset.Layer.GRASS,
			0 if ordinary_mask == lush_mask else ordinary_mask,
			cell
		)
		_set_overlay_cell(
			_variety_overlays[Vector2i(look, TerrainTileset.Layer.LUSH_GRASS)],
			look,
			TerrainTileset.Layer.LUSH_GRASS,
			0 if lush_mask == dry_mask else lush_mask,
			cell
		)
		_set_overlay_cell(
			_variety_overlays[Vector2i(look, TerrainTileset.Layer.DRY_GRASS)],
			look,
			TerrainTileset.Layer.DRY_GRASS,
			dry_mask,
			cell
		)


## The corners that show `look` and are on `min_layer` or above, as a mask.
func _overlay_mask(
	look: SeasonBlend.Look, min_layer: int, shown: PackedInt32Array, corners: PackedInt32Array
) -> int:
	var mask := 0
	for corner in 4:
		if shown[corner] == look and corners[corner] >= min_layer:
			mask |= 1 << corner
	return mask


## Draws the tile of atlas row `row` with `mask` on an overlay layer, or erases the cell if
## the mask is empty.
func _set_overlay_cell(
	tile_map: TileMapLayer, look: SeasonBlend.Look, row: int, mask: int, cell: Vector2i
) -> void:
	if mask == 0:
		tile_map.erase_cell(cell)
	else:
		tile_map.set_cell(
			cell, TerrainTileset.terrain_source_id(look), _tileset.atlas_cell(row, mask, cell)
		)


func _draw_object(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	_remove_light(world_pos)
	if object == null or _hidden_trunks.has(world_pos):
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
	_objects.set_cell(object.pos, _object_source(object), _atlas_cell(object))
	_object_states[object.pos] = _object_state(object)


## The source that an object is drawn from: its own sheet for a crop, else the object atlas in
## its look.
func _object_source(object: WorldObject) -> int:
	if object.is_crop():
		return _object_tileset.crop_source_id(object.type)
	return _object_look(object)


## The look of an object: of the foliage of its season, or snowy or frosty with its tile's
## weather threshold.
func _object_look(object: WorldObject) -> SeasonBlend.Look:
	var thresholds := _blend.thresholds(object.pos)
	return _conditions.foliage_look(thresholds.x, thresholds.y)


## What an object is drawn as: its look, with a flag if it is out of its fruit season, or
## DORMANT if it is not drawn. A change of the state means the cell must be drawn again. A crop
## has the same look all year; its growth comes through `objects_changed`.
func _object_state(object: WorldObject) -> int:
	if object.is_crop():
		return 0
	if world.is_dormant(object):
		return DORMANT
	return _object_look(object) + (BARE_OF_FRUIT_FLAG if world.is_bare(object) else 0)


func _remove_light(world_pos: Vector2i) -> void:
	var light: ObjectLight = _lights.get(world_pos)
	if light != null:
		_lights.erase(world_pos)
		light.queue_free()


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
	_buildings.update_see_through(
		delta, player_feet, Occlusion.occluding_buildings(player_feet, world.buildings())
	)


## Erases an object's cell and draws the same picture as a sprite, sorted the same way.
func _swap_cell_for_sprite(object: WorldObject) -> void:
	var sprite := SeeThroughSprite.new()
	_place_object_sprite(sprite, object)
	entities.add_child(sprite)
	_object_sprites[object.pos] = sprite
	_objects.erase_cell(object.pos)


## Gives a sprite the picture of an object as it looks now, at the place and sorted the same way
## as the tile map draws it (see ObjectTileset): sorted by the middle of the footprint's bottom
## row, the cell's bottom on the footprint's bottom edge.
func _place_object_sprite(sprite: Sprite2D, object: WorldObject) -> void:
	var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	sprite.texture = _object_texture(object)
	sprite.centered = false
	var footprint: Vector2i = WorldObjectTypes.TYPES[object.type]["footprint"]
	var sort_shift := Vector2(0, (footprint.y - 1) * TerrainTileset.TILE_SIZE)
	sprite.position = TerrainTileset.tile_centre(object.pos)
	sprite.position += sort_shift
	sprite.offset = (
		-Vector2(cell_size) / 2 - Vector2(ObjectTileset.cell_origin(footprint)) - sort_shift
	)


## The picture of an object as it looks now, for its stand-in sprite.
func _object_texture(object: WorldObject) -> AtlasTexture:
	var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	var texture := AtlasTexture.new()
	texture.atlas = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, _object_look(object)))
	texture.region = Rect2(_atlas_cell(object) * cell_size, cell_size)
	return texture


## The object's cell in its source as it looks now (see ObjectTileset.atlas_cell).
func _atlas_cell(object: WorldObject) -> Vector2i:
	var connections := world.connections(object) if object.type_data().has("connects") else 0
	return ObjectTileset.atlas_cell(object, world.is_bare(object), connections)


## Frees the stand-in sprite of an object, if it has one. The caller sets the cell.
func _drop_object_sprite(world_pos: Vector2i) -> void:
	var sprite: SeeThroughSprite = _object_sprites.get(world_pos)
	if sprite != null:
		_object_sprites.erase(world_pos)
		sprite.queue_free()


## The code of a tile (see TerrainTileset.tile_code), or TerrainTileset.MISSING if its chunk is
## not loaded.
func _code_at(world_pos: Vector2i) -> int:
	var chunk_looks: ChunkLooks = _chunk_looks.get(Chunk.world_to_chunk(world_pos))
	if chunk_looks == null:
		return TerrainTileset.MISSING
	return chunk_looks.codes[ChunkLooks.index_of(Chunk.local_pos(world_pos))]


## Whether snow or a dusting of it lies on a tile, so soil under it doesn't look wet.
func is_snowed_over(world_pos: Vector2i) -> bool:
	var code := _code_at(world_pos)
	if code == TerrainTileset.MISSING:
		return false
	var look := TerrainTileset.weather_of(code)
	return look == SeasonBlend.Look.SNOW or look == SeasonBlend.Look.DUSTING


func _layer_of_tile(terrain: Tile.Terrain, world_pos: Vector2i) -> int:
	return TerrainTileset.terrain_layer(terrain, _variety_noise.get_noise_2dv(Vector2(world_pos)))


## Starts the fall of a tree that was just replaced by its stump. Its trunk is already in the
## world; it stays hidden until the tree has landed.
func _start_fall(tree: WorldObject) -> void:
	var fall := FallingTree.beside_trunk_of(tree, world, player_feet.x)
	fall.impact_effect = _hit_effect(tree)
	_place_object_sprite(fall, tree)
	fall.landed.connect(_on_tree_landed.bind(fall))
	fall.finished.connect(_end_fall.bind(fall))
	entities.add_child(fall)
	_falling_trees.append(fall)
	if fall.trunk != null:
		_hidden_trunks[fall.trunk.pos] = true
		_drop_object_sprite(fall.trunk.pos)
		_draw_object(fall.trunk.pos)
	tree_felled.emit(tree.pos, FallingTree.FALL_SECONDS)


func _update_falling_trees(delta: float) -> void:
	if _falling_trees.is_empty():
		return
	for fall in _falling_trees.duplicate():
		fall.advance(delta)


func _on_tree_landed(fall: FallingTree) -> void:
	_hit_particles.emit(fall.impact_effect, fall.impact_point())
	var stump := world.object_at(fall.tree.pos)
	if stump != null:
		_shake_object(stump)
	tree_landed.emit(fall.tree)


## Takes the tree's sprite away and draws its trunk. Also how a fall ends when its chunk unloads.
func _end_fall(fall: FallingTree) -> void:
	_falling_trees.erase(fall)
	fall.queue_free()
	if fall.trunk != null:
		_hidden_trunks.erase(fall.trunk.pos)
		if world.is_chunk_loaded(Chunk.world_to_chunk(fall.trunk.pos)):
			_draw_object(fall.trunk.pos)
