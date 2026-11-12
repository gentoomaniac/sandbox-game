class_name WorldView
extends Node2D
## Renders a World, drawing the chunks that a ChunkResidency loads and erasing those it drops.
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
## Drawing a chunk takes about 45 ms: it is cut into steps (a row of cells, the objects, the
## borders) that a frame runs until it has spent this long. The next chunk is loaded when the one
## before is drawn (Main asks `is_drawing`); the look refresh waits for frames without drawing
## (see `_process`). The chunks load well ahead of the view, so the world around the player is
## drawn long before they get there.
const DRAW_BUDGET_USEC := 8000
## The budget while a chunk next to the player's is still undrawn (at the start, after a jump
## to another place): it is on the screen, so it is drawn sooner, at the cost of longer frames.
const URGENT_DRAW_BUDGET_USEC := 16000
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


## A chunk that is loaded and is being drawn, a step per call of `_draw_chunk_step`.
class ChunkDrawing:
	extends RefCounted
	var chunk: Chunk
	## 0 is the layers of the tiles, then a step for each row of cells, the objects, the borders.
	var step := 0

	func _init(chunk_to_draw: Chunk) -> void:
		chunk = chunk_to_draw

	func is_done() -> bool:
		return step > Chunk.CHUNK_SIZE + 2


var world: World
## Y-sorted: whatever is added here is drawn in front of or behind the objects by its y.
var entities := Node2D.new()
## True once every chunk around the focus is loaded.
var is_settled := false
## Where the player stands, in world pixels, and how big they are (see Occlusion; both set by the
## game scene every frame).
var player_feet := Vector2.ZERO
var player_size := Occlusion.PLAYER_SIZE
## The game scene gives it the wind and the rain every frame.
var ambient_motion := AmbientMotion.new()
## The flowers and pebbles on the ground and the hints of clay spots; the wildlife asks it where
## flowers bloom.
var decorations: DecorationView
var _residency: ChunkResidency
var _hit_particles := HitParticles.new()
var _falling_leaves := FallingLeaves.new()
var _variety_noise := FastNoiseLite.new()
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
## The colour of the ground and what lies on it (see GroundLook and CoverMap).
var _ground_look: GroundLook
var _cover_map := CoverMap.new()
## The focus chunk that the cover map was drawn for (once it has one), and whether a chunk may
## be waiting there.
var _cover_focus := Vector2i.ZERO
var _is_cover_focused := false
var _is_cover_missing := false
## The day, the snow cover and the frost that the plants and houses are drawn for.
var _look_state := Vector3(-1, 0, 0)
var _conditions: SeasonBlend.Conditions
## The terrain layer of each tile of a loaded chunk (see TerrainTileset.Layer), by tile index
## (local y * CHUNK_SIZE + x). It comes from the variety noise, the slowest part of drawing a cell.
var _chunk_layers: Dictionary[Vector2i, PackedInt32Array] = {}
## The tiles with something that gives shade or shelter on them, to tell a change that reaches the
## cover from one that does not.
var _crown_tiles: Dictionary[Vector2i, bool] = {}
## The chunk that is loaded and being drawn, if any.
var _drawing: ChunkDrawing
## The loaded chunks that wait to be drawn, the oldest first.
var _to_draw: Array[Chunk] = []
## Chunks whose plants are not brought up to date yet, the nearest to the focus last.
var _refresh_queue: Array[Vector2i] = []
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
	_ground_look = GroundLook.new(ambient_motion.decoration_sway)
	decorations.show_ground_look(_ground_look)


func _ready() -> void:
	add_to_group(ArtSet.VIEWS)
	for layer in TerrainTileset.LAYER_COUNT:
		var tile_map := TileMapLayer.new()
		tile_map.name = TerrainTileset.Layer.keys()[layer].capitalize()
		tile_map.tile_set = _tileset.tile_set
		tile_map.position = -Vector2(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE) / 2
		add_child(tile_map)
		_layers.append(tile_map)
	for layer in TerrainTileset.LAYER_COUNT:
		_layers[layer].material = _ground_look.terrain
	_layers[TerrainTileset.Layer.WATER].material = ambient_motion.water
	_layers[TerrainTileset.Layer.MUD].material = ambient_motion.mud
	_layers[TerrainTileset.Layer.SOIL].material = _ground_look.soil
	# Wet soil lies right over the soil terrain, and clears where snow lies on it.
	_soil_wetness.show_ground_look(_ground_look)
	add_child(_soil_wetness)
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
	add_child(_falling_leaves)
	add_child(_buildings)


## Shows the ground, the objects and the crops, the campfires' flames and the buildings in the
## chosen art set (see ArtSet).
func show_art_set() -> void:
	_tileset.show_art_set()
	_object_tileset.show_art_set()
	_soil_wetness.show_art_set()
	ambient_motion.show_art_set()
	_ground_look.show_art_set()
	_cover_map.show_art_set()
	_buildings.show_art_set()


## Shows the world of a residency, including the chunks that are already loaded in it, and draws
## the chunks it loads from now on. Showing the residency it shows again does nothing; another
## one is refused, as its chunks, objects and houses would stay drawn: make a new view.
func show_world(residency: ChunkResidency) -> void:
	if _residency == residency:
		return
	if _residency != null:
		push_error("WorldView already shows another world")
		return
	_residency = residency
	world = residency.world
	# The view was made before Main chose the art set.
	show_art_set()
	world.objects_changed.connect(_on_objects_changed)
	world.tile_changed.connect(redraw_tile)
	_cover_map.show_world(world)
	decorations.ground_cover = _cover_map.ground_cover
	world.object_hit.connect(_on_object_hit)
	world.clay_spot_changed.connect(_on_clay_spot_changed)
	_soil_wetness.show_world(world, is_snowed_over)
	world.building_placed.connect(_buildings.add)
	world.building_placed.connect(_on_building_changed)
	world.building_removed.connect(_buildings.remove)
	world.building_removed.connect(_on_building_changed)
	world.bell_rung.connect(_buildings.swing_bell)
	residency.chunk_loaded.connect(_on_chunk_loaded)
	residency.chunk_unloaded.connect(_on_chunk_unloaded)
	_variety_noise.seed = world.world_seed + VARIETY_SEED_OFFSET
	_variety_noise.frequency = VARIETY_FREQUENCY
	decorations.show_world(world)
	_blend = SeasonBlend.new(world.world_seed)
	decorations.day = world.clock.day
	_conditions = _blend.conditions(decorations.day, 0.0, 0.0)
	_look_state = Vector3(decorations.day, 0.0, 0.0)
	_buildings.set_looks(_blend, _conditions)
	show_ground_cover(decorations.day, 0.0, 0.0, 0.0)
	_sync_cover_focus()
	for coords in world.loaded_chunk_coords():
		_draw_chunk(world.chunk_at(coords))
	for building in world.buildings():
		_buildings.add(building)


## Shows the ground of a day in the weather of a moment: its colour of the time of year, and the
## fallen leaves, the frost (0 to 1) and the snow cover and the thaw (0 to 1) over it. Cheap, a few
## numbers for the shaders, so the world calls it every game minute and the cover builds up and
## melts evenly.
func show_ground_cover(day: int, snow_cover: float, thaw: float, frost: float) -> void:
	_ground_look.show_mix(_blend.ground_mix(day))
	_cover_map.set_weather(_blend.litter(day), snow_cover, thaw, frost)


## Sets the day, the snow cover and the frost (both 0 to 1) that plants and houses are drawn
## for. Does nothing while they are as they were; otherwise every loaded chunk is queued for a
## refresh, which `_process` does a few chunks per frame (chunks that load later are drawn for
## them right away).
func refresh_looks(day: int, snow_cover: float, frost: float) -> void:
	var state := Vector3(day, snow_cover, frost)
	if world == null or state == _look_state:
		return
	_look_state = state
	decorations.day = day
	_conditions = _blend.conditions(day, snow_cover, frost)
	_refresh_queue.assign(world.loaded_chunk_coords())
	var focus := _residency.focus_chunk
	_refresh_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus).length_squared() > (b - focus).length_squared()
	)
	_buildings.set_looks(_blend, _conditions)


## The picture a building is shown with now, unlit (the roof is the same lit or not).
func building_picture(building: Building) -> String:
	return _buildings.picture_path(building)


## Whether a loaded chunk is not drawn yet.
func is_drawing() -> bool:
	return _drawing != null


## Draws the chunks that are loaded and not drawn yet, at once (for tests).
func finish_drawing() -> void:
	while is_drawing():
		_draw_next_step()


## Brings every queued chunk up to date at once (for tests).
func finish_refresh() -> void:
	while not _refresh_queue.is_empty():
		_refresh_chunk(_refresh_queue.pop_back())


## How brightly the lights shine now (see ObjectLight.strength).
func light_strength() -> float:
	return _light_strength


## Sets how brightly every light shines (see ObjectLight.strength).
func set_light_strength(strength: float) -> void:
	_light_strength = strength
	for light in _lights.values():
		light.strength = strength
	_buildings.set_light_strength(strength)


## The soil of the loaded chunks shows the moisture it has now, and the rain of the hour that has
## just ended on its surface (see SoilWetness), those around the focus first: it changes with the
## hours, quietly, and a few tiles are drawn every frame. Chunks that load later are drawn when
## they load.
func refresh_soil(last_hour_rain: float) -> void:
	if world == null:
		return
	var coords := world.loaded_chunk_coords()
	var focus := _residency.focus_chunk
	coords.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus).length_squared() < (b - focus).length_squared()
	)
	_soil_wetness.refresh_looks(coords, last_hour_rain)


func _process(delta: float) -> void:
	if world == null:
		return
	_sync_cover_focus()
	_draw_within_budget()
	_draw_missing_cover()
	_cover_map.upload()
	# Loading and drawing fill most of a frame, so the look refresh only runs in frames without.
	var is_drawn := _residency.is_complete and not is_drawing()
	if is_drawn:
		var deadline := Time.get_ticks_usec() + REFRESH_BUDGET_USEC
		while Time.get_ticks_usec() < deadline and not _refresh_queue.is_empty():
			_refresh_chunk(_refresh_queue.pop_back())
	is_settled = is_drawn and _refresh_queue.is_empty()
	_update_see_through(delta)
	_update_falling_trees(delta)
	_shed_leaves(delta)


## Redraws one tile after its state changed. World's `tile_changed` calls it.
func redraw_tile(world_pos: Vector2i) -> void:
	var layers: PackedInt32Array = _chunk_layers.get(Chunk.world_to_chunk(world_pos), [])
	if not layers.is_empty():
		var local := Chunk.local_pos(world_pos)
		var terrain := world.chunk_at(Chunk.world_to_chunk(world_pos)).terrain_at(local)
		layers[_tile_index(local)] = _layer_of_tile(terrain, world_pos)
		_cover_map.redraw_tile(world_pos)
	# The tile is a corner of the 4 cells around it.
	for offset: Vector2i in CORNER_OFFSETS:
		_redraw_cell(world_pos - offset)
	if world.is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		decorations.redraw(world_pos, _layer_at(world_pos))


## Called for every tile an object covers; it is drawn from its own tile only.
func _on_objects_changed(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	if object == null or object.pos == world_pos:
		_drop_object_sprite(world_pos)
		_draw_object(world_pos)
	decorations.redraw(world_pos, _layer_at(world_pos))
	var is_crown := object != null and object.type in GroundCover.CROWNED
	if is_crown != _crown_tiles.has(world_pos):
		if is_crown:
			_crown_tiles[world_pos] = true
		else:
			_crown_tiles.erase(world_pos)
		_cover_map.redraw_around(world_pos)
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


## A house was put up or taken down: its lee changes what lies behind it.
func _on_building_changed(building: Building) -> void:
	for tile in building.tiles():
		_cover_map.redraw_around(tile)


func _on_clay_spot_changed(world_pos: Vector2i) -> void:
	decorations.redraw(world_pos, _layer_at(world_pos))


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
	return HitEffect.kind_for(object.type, _foliage_look(object))


## The look of an object's foliage: as it shows, but a frosty tree counts as its season's look, as
## the frost says nothing about its foliage.
func _foliage_look(object: WorldObject) -> SeasonBlend.Look:
	var look := _object_look(object)
	if look == SeasonBlend.Look.FROST:
		return _conditions.foliage_season_look(_blend.thresholds(object.pos).x)
	return look


## Lets the trees among a few tiles picked around the player shed leaves into the wind.
func _shed_leaves(delta: float) -> void:
	var centre := Vector2i((player_feet / TerrainTileset.TILE_SIZE).floor())
	for tile in _falling_leaves.tiles_to_look_at(delta, centre):
		var tree := world.object_at(tile)
		if tree == null:
			continue
		var look := _foliage_look(tree)
		var kind := HitEffect.kind_for(tree.type, look)
		_falling_leaves.shed(kind, look, world.clock.day, _hit_origin(tree), ambient_motion.wind)


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


## Runs the steps of the drawing, one at least, until the budget of the frame is spent.
func _draw_within_budget() -> void:
	if _drawing == null:
		return
	var offset := (_drawing.chunk.coords - _residency.focus_chunk).abs()
	var is_urgent := maxi(offset.x, offset.y) <= 1
	var budget := URGENT_DRAW_BUDGET_USEC if is_urgent else DRAW_BUDGET_USEC
	var deadline := Time.get_ticks_usec() + budget
	_draw_next_step()
	while is_drawing() and Time.get_ticks_usec() < deadline:
		_draw_next_step()


## Does the next step of the drawing.
func _draw_next_step() -> void:
	_draw_chunk_step(_drawing)
	if _drawing.is_done():
		_drawing = _next_drawing()


## Draws a whole chunk at once.
func _draw_chunk(chunk: Chunk) -> void:
	var drawing := ChunkDrawing.new(chunk)
	while not drawing.is_done():
		_draw_chunk_step(drawing)


## Does the next step of drawing a chunk. The cells read the tiles' looks as they are when
## their row is drawn, as the world can change between the steps.
func _draw_chunk_step(drawing: ChunkDrawing) -> void:
	var chunk := drawing.chunk
	var coords := chunk.coords
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	if drawing.step == 0:
		_chunk_layers[coords] = _make_chunk_layers(chunk)
		_refresh_queue.erase(coords)
		_cover_map.draw_chunk(coords)
		for object in chunk.objects():
			if object.type in GroundCover.CROWNED:
				for tile in object.tiles():
					_crown_tiles[tile] = true
	elif drawing.step <= Chunk.CHUNK_SIZE:
		_draw_row(drawing, drawing.step - 1)
	elif drawing.step == Chunk.CHUNK_SIZE + 1:
		for object in chunk.objects():
			_draw_object(object.pos)
	else:
		# The right and bottom neighbours' border cells drew this chunk's tiles with a fallback
		# while it was missing. Now they can blend properly.
		for i in Chunk.CHUNK_SIZE + 1:
			_redraw_cell(origin + Vector2i(Chunk.CHUNK_SIZE, i))
		for i in Chunk.CHUNK_SIZE:
			_redraw_cell(origin + Vector2i(i, Chunk.CHUNK_SIZE))
		# The tilled soil of the chunk now knows whether snow lies on it.
		for pos in world.tilled_tiles_in_chunk(coords):
			_soil_wetness.redraw_tile(pos)
	drawing.step += 1


## Draws the cells of row `y` of a chunk (and their decorations).
func _draw_row(drawing: ChunkDrawing, y: int) -> void:
	var origin := Chunk.to_world(drawing.chunk.coords, Vector2i.ZERO)
	var layers: PackedInt32Array = _chunk_layers[drawing.chunk.coords]
	# The corners of the row's cells: the layers of the row above and of this row, starting one
	# column to the left. Reading them once, mostly straight from the chunk, is several times
	# faster than looking up 4 corners per cell through the world.
	var above := _layer_row(layers, origin, y - 1)
	var below := _layer_row(layers, origin, y)
	for x in Chunk.CHUNK_SIZE:
		var corners := PackedInt32Array([above[x], above[x + 1], below[x], below[x + 1]])
		var pos := origin + Vector2i(x, y)
		_draw_cell_corners(pos, corners, true)
		# The bottom-right corner is this chunk's tile (x, y).
		decorations.place(pos, corners[3], world.object_at(pos) != null)


## The layers of the tiles of row `y` of a chunk, from the column left of it to its last.
func _layer_row(layers: PackedInt32Array, origin: Vector2i, y: int) -> PackedInt32Array:
	var row := PackedInt32Array()
	row.resize(Chunk.CHUNK_SIZE + 1)
	for x in range(-1, Chunk.CHUNK_SIZE):
		if x < 0 or y < 0:
			row[x + 1] = _layer_at(origin + Vector2i(x, y))
		else:
			row[x + 1] = layers[_tile_index(Vector2i(x, y))]
	return row


## The terrain layer of each tile of a chunk.
func _make_chunk_layers(chunk: Chunk) -> PackedInt32Array:
	var layers := PackedInt32Array()
	layers.resize(Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE)
	var origin := Chunk.to_world(chunk.coords, Vector2i.ZERO)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			layers[_tile_index(Vector2i(x, y))] = _layer_of_tile(
				chunk.terrain_at(Vector2i(x, y)), origin + Vector2i(x, y)
			)
	return layers


## Brings a loaded chunk up to date with the day, the snow cover and the frost: redraws the
## decorations and the plants that changed.
func _refresh_chunk(coords: Vector2i) -> void:
	var chunk := world.chunk_at(coords)
	if chunk == null or not _chunk_layers.has(coords):
		return
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	for index in Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE:
		decorations.refresh(origin + Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE))
	for object in chunk.objects():
		if _object_states.get(object.pos, DORMANT) != _object_state(object):
			_on_objects_changed(object.pos)


## The drawing of the oldest chunk that waits, or null if none does.
func _next_drawing() -> ChunkDrawing:
	return null if _to_draw.is_empty() else ChunkDrawing.new(_to_draw.pop_front())


func _on_chunk_loaded(chunk: Chunk) -> void:
	if _drawing == null:
		_drawing = ChunkDrawing.new(chunk)
	else:
		_to_draw.append(chunk)


## Erases a chunk that was dropped from the world.
func _on_chunk_unloaded(chunk: Chunk) -> void:
	var coords := chunk.coords
	if _drawing != null and _drawing.chunk == chunk:
		_drawing = _next_drawing()
	_to_draw.erase(chunk)
	for object in chunk.objects():
		_drop_object_sprite(object.pos)
		_objects.erase_cell(object.pos)
		_object_states.erase(object.pos)
		_remove_light(object.pos)
	var origin := Chunk.to_world(coords, Vector2i.ZERO)
	_chunk_layers.erase(coords)
	_refresh_queue.erase(coords)
	_cover_map.forget_chunk(coords)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			for tile_map in _layers:
				tile_map.erase_cell(origin + Vector2i(x, y))
			decorations.forget(origin + Vector2i(x, y))
			_crown_tiles.erase(origin + Vector2i(x, y))
	for fall in _falling_trees.duplicate():
		if Chunk.world_to_chunk(fall.tree.pos) == coords:
			_end_fall(fall)


## Redraws the terrain layers of a cell if the chunk that owns it is loaded.
func _redraw_cell(cell: Vector2i) -> void:
	if not world.is_chunk_loaded(Chunk.world_to_chunk(cell)):
		return
	var corners := PackedInt32Array()
	for offset: Vector2i in CORNER_OFFSETS:
		corners.append(_layer_at(cell + offset))
	_draw_cell_corners(cell, corners)


## The one place tile state becomes terrain: the layers of a cell's 4 corner tiles (in
## CORNER_OFFSETS order, MISSING where not loaded) decide which layers it draws and with which
## shapes. A cell `is_new` when its chunk was just loaded: it is empty, so nothing needs erasing,
## which saves a good part of a chunk load. The colour of the season and the leaves, frost and
## snow come from the ground shader, not from the cells (see GroundLook).
func _draw_cell_corners(cell: Vector2i, corners: PackedInt32Array, is_new := false) -> void:
	TerrainTileset.fill_missing_corners(corners)
	var drawn := TerrainTileset.drawn_layers(corners)
	for layer in TerrainTileset.LAYER_COUNT:
		if drawn & (1 << layer) == 0:
			if not is_new:
				_layers[layer].erase_cell(cell)
		else:
			var mask := TerrainTileset.mask_for(corners, layer)
			var atlas_cell := _tileset.atlas_cell(layer, mask, cell)
			_layers[layer].set_cell(cell, TerrainTileset.TERRAIN_SOURCE_ID, atlas_cell)


func _draw_object(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	_remove_light(world_pos)
	if object == null or _hidden_trunks.has(world_pos):
		_objects.erase_cell(world_pos)
		_object_states.erase(world_pos)
		return
	if _object_sprites.has(world_pos):
		# A stand-in sprite is showing it (the player stands behind it before its chunk is
		# drawn): the cell stays empty until the sprite goes, and the sprite shows it as it is now.
		_place_object_sprite(_object_sprites[world_pos], object)
		_object_states[world_pos] = _object_state(object)
	else:
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
	for object in Occlusion.occluding_objects(player_feet, world, player_size):
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
		delta,
		player_feet,
		Occlusion.occluding_buildings(player_feet, world.buildings(), player_size)
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
	var cell_size := _picture_size(object)
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
	texture.atlas = load(ObjectTileset.picture(_object_look(object)))
	texture.region = Rect2(_atlas_cell(object) * cell_size, _picture_size(object))
	return texture


## The size of an object's picture in the atlas: a cell, or `cells_wide` of them.
func _picture_size(object: WorldObject) -> Vector2i:
	var cells_wide: int = object.type_data().get("cells_wide", 1)
	return Vector2i(cells_wide * ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)


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


## The terrain layer of a tile, or TerrainTileset.MISSING if its chunk is not loaded.
func _layer_at(world_pos: Vector2i) -> int:
	var layers: PackedInt32Array = _chunk_layers.get(Chunk.world_to_chunk(world_pos), [])
	if layers.is_empty():
		return TerrainTileset.MISSING
	return layers[_tile_index(Chunk.local_pos(world_pos))]


static func _tile_index(local: Vector2i) -> int:
	return local.y * Chunk.CHUNK_SIZE + local.x


## Whether snow lies on most of a tile now, so soil under it doesn't look wet.
func is_snowed_over(world_pos: Vector2i) -> bool:
	return world != null and _cover_map.ground_cover.is_snowed(world_pos)


## Whether snow lies on the ground under a point of the world, `position` in tiles, now.
func is_snow_drawn_at(position: Vector2) -> bool:
	return is_snowed_over(Vector2i(position.floor()))


## Tells whether snow lies on a tile with this snow cover (0 to 1, no thaw), as it will be drawn
## once the ground is shown for it: `func(world_pos: Vector2i) -> bool`.
func snow_checker_for(snow_cover: float) -> Callable:
	return func(world_pos: Vector2i) -> bool:
		return _cover_map.ground_cover.is_snowed_with(world_pos, snow_cover, 0.0)


## Moves the focus of the cover map with the residency's. A chunk that waits for it is drawn by
## `_draw_missing_cover`.
func _sync_cover_focus() -> void:
	if _residency.focus_chunk != _cover_focus or not _is_cover_focused:
		_cover_focus = _residency.focus_chunk
		_is_cover_focused = true
		_cover_map.set_focus(_cover_focus)
		_is_cover_missing = true


## Draws the chunks of the cover map that came into range as the player walked, one a frame.
func _draw_missing_cover() -> void:
	if _is_cover_missing:
		_is_cover_missing = _cover_map.draw_missing()


func _layer_of_tile(terrain: Tile.Terrain, world_pos: Vector2i) -> int:
	var variety := _variety_noise.get_noise_2dv(Vector2(world_pos))
	return TerrainTileset.terrain_layer(terrain, variety, world.wear_stage(world_pos))


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
