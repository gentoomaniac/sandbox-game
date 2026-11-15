# gdlint: disable=max-public-methods
# (World is the one entry point for map changes: chunks, objects, soil, buildings and clay all
# read and write the same edits, so they stay together; ground items, the nightly upkeep and the
# making of save data (WorldSave) were split off.)
class_name World
extends GameMap
## The world: a seed, fixed bounds and the chunks that are currently loaded.
##
## The world is centred on the origin: with MAX_SIZE_CHUNKS = 64, chunk coordinates run
## from -32 to 31 on both axes, so world tile positions run from -1024 to 1023.

## The moisture of a tilled tile changed (see `set_moisture`).
signal soil_moisture_changed(world_pos: Vector2i)
## A tool hit an object (see `hit_object`). The finishing hit emits it too, after the object
## is removed or replaced by what it leaves.
signal object_hit(object: WorldObject)
## A clay spot was dug, or has recovered (see `spend_clay_spot`).
signal clay_spot_changed(world_pos: Vector2i)
## A building was placed.
signal building_placed(building: Building)
## A building was taken down.
signal building_removed(building: Building)
## The player rang a bell frame (see GameState `ring_bell_in_reach`).
signal bell_rung(building: Building)
## The terrain or an object of this chunk was edited, loaded or not (`_edit_terrain`,
## `_edit_object`: every change of the map's terrain and objects goes through them).
signal edited(chunk_coords: Vector2i)
## Why a footprint tile can't be built on.
enum Blocked {
	## Water, wetland or floodplain, or the tile is not loaded.
	TERRAIN,
	## A world object or a building is on it.
	OCCUPIED,
}

## A dug clay spot has no clay for this many nights.
const CLAY_SPENT_NIGHTS := 5

## The sides of a tile that a line object can join (see `connections`), in the order of the
## bits of a connection mask: north, east, south, west. tools/art/boundaries.py draws the
## pictures in this order.
const CONNECTION_SIDES: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT
]

## The only place that defines the world size. Must be even so the world is centred.
const MAX_SIZE_CHUNKS := 64

var world_seed: int
## The game's clock: what the seasonal plants follow (see `is_dormant`). It belongs to the
## GameState, which gives it in.
var clock: GameClock
var vegetation := Vegetation.default_vegetation()
## The moisture of the tilled soil (see `moisture_at`).
var soil: SoilMoisture
## The tilled soil that nobody tends, and grows over (see `settle_fallow_soil`).
var fallow := FallowSoil.new()
## Whether the rain has made worn ground mud (see `set_muddy`).
var is_muddy := false
## The prints in snow and mud that walkers leave (see Footprints).
var footprints := Footprints.new()
## The wear of the grass, by walking (see `wear_tile`).
var wear := WorldWear.new()
## The village the world was built with (see VillageBuilder), or null.
var village: Village
## The clay spots that were dug, with the nights left until they hold clay again (see
## `recover_clay_spots`).
var _spent_clay_spots: Dictionary[Vector2i, int] = {}
var _generator: WorldGenerator
var _chunks: Dictionary[Vector2i, Chunk] = {}
## What the player changed, kept outside the chunks so it survives their unloading: per world
## position the object that stands there now, or null where the generated object was
## removed. Together with the seed this is the whole world (the future save format).
var _object_edits: Dictionary[Vector2i, WorldObject] = {}
## The positions of the crops among them, which every hour of the simulation visits.
var _crop_positions: Dictionary[Vector2i, bool] = {}
## The tiles of the scarecrows the player put down, in loaded chunks or not.
var _scarecrow_positions: Dictionary[Vector2i, bool] = {}
## The tiles of the campfires, in loaded chunks or not.
var _campfire_positions: Dictionary[Vector2i, bool] = {}
## Terrain the player changed (e.g. grass tilled to soil), by world position. Replayed on
## chunks before the objects, which may depend on the ground.
var _terrain_edits: Dictionary[Vector2i, Tile.Terrain] = {}
## The world positions of the terrain edits and of the object edits by the chunk they are in, in
## the order they were first made (the keys of a dictionary, which keeps it), so that a chunk
## replays its own edits, in that order, without looking at the others. Not saved: `from_dict`
## builds them again.
var _terrain_edit_positions_by_chunk: Dictionary[Vector2i, Dictionary] = {}
var _object_edit_positions_by_chunk: Dictionary[Vector2i, Dictionary] = {}
## Buildings are the player's work and must outlive the chunks they stand on, and one can
## cross a chunk border, so they live here and not in chunks.
var _buildings: Array[Building] = []
var _building_by_tile: Dictionary[Vector2i, Building] = {}


## `game_clock` defaults to a clock of its own because many tests make a World without a
## GameState; the game always passes its clock in.
func _init(seed_value: int, game_clock := GameClock.new()) -> void:
	world_seed = seed_value
	clock = game_clock
	soil = SoilMoisture.new(game_clock)
	_generator = WorldGenerator.new(seed_value)
	objects_changed.connect(_count_object_change)
	building_placed.connect(_count_building)
	building_removed.connect(_count_building)


static func is_chunk_in_bounds(chunk_coords: Vector2i) -> bool:
	var half := MAX_SIZE_CHUNKS / 2
	return (
		chunk_coords.x >= -half
		and chunk_coords.y >= -half
		and chunk_coords.x < half
		and chunk_coords.y < half
	)


static func is_in_bounds(world_pos: Vector2i) -> bool:
	return is_chunk_in_bounds(Chunk.world_to_chunk(world_pos))


## Adds (or replaces) a chunk, freshly generated, and applies the edits within its area on
## top. It must be inside the bounds. Replaying edits does not emit change signals: the
## caller draws the whole chunk anyway.
func add_chunk(chunk: Chunk) -> void:
	assert(is_chunk_in_bounds(chunk.coords), "Chunk out of bounds: %s" % chunk.coords)
	_chunks[chunk.coords] = chunk
	change_count += 1
	replay_edits(chunk)


## Applies the edits within the area of a freshly generated chunk to it: the terrain first, as
## objects may depend on the ground, then the objects (a removed one is gone, an edited one
## stands in the place of the generated one). The chunk need not be loaded: whoever reads a chunk
## that is not (see TravelMasks) replays them on a copy.
func replay_edits(chunk: Chunk) -> void:
	for pos: Vector2i in _terrain_edit_positions_by_chunk.get(chunk.coords, {}):
		chunk.set_terrain(Chunk.local_pos(pos), _terrain_edits[pos])
	for pos: Vector2i in _object_edit_positions_by_chunk.get(chunk.coords, {}):
		chunk.remove_object(Chunk.local_pos(pos))
		if _object_edits[pos] != null:
			chunk.add_object(_object_edits[pos])


## The edits within the area of a chunk, copied: `terrain` by world position to terrain, and
## `objects` by world position to the type of the object that stands there now (&"" where the
## generated one was taken off), each in the order made. Whoever replays them (`replay_snapshot`)
## may do so on another thread: nothing in it is shared with the world.
func edits_snapshot(chunk_coords: Vector2i) -> Dictionary:
	var terrain := {}
	for pos: Vector2i in _terrain_edit_positions_by_chunk.get(chunk_coords, {}):
		terrain[pos] = _terrain_edits[pos]
	var objects := {}
	for pos: Vector2i in _object_edit_positions_by_chunk.get(chunk_coords, {}):
		var object := _object_edits[pos]
		objects[pos] = &"" if object == null else object.type
	return {"terrain": terrain, "objects": objects}


## `replay_edits` from a snapshot (see `edits_snapshot`): the objects are made new, of the types.
static func replay_snapshot(chunk: Chunk, snapshot: Dictionary) -> void:
	var terrain: Dictionary = snapshot["terrain"]
	for pos: Vector2i in terrain:
		chunk.set_terrain(Chunk.local_pos(pos), terrain[pos])
	var objects: Dictionary = snapshot["objects"]
	for pos: Vector2i in objects:
		chunk.remove_object(Chunk.local_pos(pos))
		if objects[pos] != &"":
			chunk.add_object(WorldObject.new(objects[pos], pos))


func remove_chunk(chunk_coords: Vector2i) -> void:
	_chunks.erase(chunk_coords)
	change_count += 1


func is_chunk_loaded(chunk_coords: Vector2i) -> bool:
	return _chunks.has(chunk_coords)


func loaded_chunk_coords() -> Array[Vector2i]:
	return _chunks.keys()


## The loaded chunk, or null if it is not loaded.
func chunk_at(chunk_coords: Vector2i) -> Chunk:
	return _chunks.get(chunk_coords)


## The tile at a world position, or null if it is out of bounds or its chunk is not loaded.
func tile_at(world_pos: Vector2i) -> Tile:
	# Out-of-bounds chunks can never be loaded (add_chunk asserts the bounds), so they
	# end up here as null too.
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null:
		return null
	return chunk.tile_at(Chunk.local_pos(world_pos))


## The object that covers a tile (see WorldObject.tiles), or null if there is none, the chunk
## is not loaded or the object is dormant (see `is_dormant`): a dormant plant is not there for
## anything that walks, builds, targets or draws.
func object_at(world_pos: Vector2i) -> WorldObject:
	return object_on(world_pos, clock.day)


## Like `object_at`, as it is on the day `day`: which plants are dormant depends on it.
func object_on(world_pos: Vector2i, day: int) -> WorldObject:
	var object := _stored_object_at(world_pos)
	return null if object != null and is_dormant_on(object, day) else object


## Whether a hit object was taken down: its tile no longer holds it (the finishing hit
## removes it or leaves a stump or something else there). `object_hit` is emitted for every hit,
## the finishing one included, so listeners ask this to tell them apart.
func is_gone(object: WorldObject) -> bool:
	return object_at(object.pos) != object


## Whether a seasonal plant is dormant: it is out of its season, by the vegetation curve of its
## type and its own threshold. The one rule that the view, walking, building and targeting
## share. Nothing about it is saved.
func is_dormant(object: WorldObject) -> bool:
	return is_dormant_on(object, clock.day)


## Like `is_dormant`, on the day `day` instead of the clock's.
func is_dormant_on(object: WorldObject, day: int) -> bool:
	return (
		object.type_data().get("seasonal") == WorldObjectTypes.DORMANCY
		and not vegetation.is_present(object.type, world_seed, object.pos, day)
	)


## Whether a plant that bears fruit has none now: its season is over or has not begun. Picked
## or not, it then looks picked and can't be picked.
func is_bare(object: WorldObject) -> bool:
	return (
		object.type_data().get("seasonal") == WorldObjectTypes.FRUIT
		and not vegetation.is_present(object.type, world_seed, object.pos, clock.day)
	)


## Like `object_at`, but dormant plants are seen too. A big object is stored at its own tile
## only, so look back from the tile over the largest footprint: in its own chunk, and only
## near the chunk's top and left border in the neighbours. A big object whose own chunk is not
## loaded is not seen; that is safe because the player only acts on tiles well inside the
## loaded area (see ChunkResidency.LOAD_RADIUS and UNLOAD_RADIUS).
func _stored_object_at(world_pos: Vector2i) -> WorldObject:
	var own_chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	var local := Chunk.local_pos(world_pos)
	for y in WorldObjectTypes.MAX_FOOTPRINT.y:
		for x in WorldObjectTypes.MAX_FOOTPRINT.x:
			var origin_local := local - Vector2i(x, y)
			var chunk := own_chunk
			if not Chunk.is_local_in_range(origin_local):
				chunk = chunk_at(Chunk.world_to_chunk(world_pos - Vector2i(x, y)))
			if chunk == null:
				continue
			var object := chunk.object_at(Chunk.local_pos(world_pos - Vector2i(x, y)))
			if object != null and object.covers(world_pos):
				return object
	return null


## The sides a line object (a type that `connects`, see WorldObjectTypes) joins a neighbour on,
## as bits: bit i for CONNECTION_SIDES[i]. It joins the objects of the same `connects`. A side in
## a chunk that is not loaded counts what will stand there, so a line drawn at a chunk border
## runs on into the chunk before it loads.
func connections(object: WorldObject) -> int:
	var group: StringName = object.type_data()["connects"]
	var mask := 0
	for side in CONNECTION_SIDES.size():
		var type := type_standing_at(object.pos + CONNECTION_SIDES[side])
		if type != &"" and WorldObjectTypes.TYPES[type].get("connects") == group:
			mask |= 1 << side
	return mask


## The type of the object whose own tile this is, &"" for none: in a loaded chunk what stands
## there, elsewhere the edit or else what the generator puts there (the view asks it which ways lie
## beside a tile, see WayEdges).
func type_standing_at(world_pos: Vector2i) -> StringName:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	var object: WorldObject
	if chunk != null:
		object = chunk.object_at(Chunk.local_pos(world_pos))
	elif _object_edits.has(world_pos):
		object = _object_edits[world_pos]
	else:
		var terrain: Tile.Terrain = _terrain_edits.get(world_pos, _generator.terrain_at(world_pos))
		return _generator.object_type_at(world_pos, terrain)
	return &"" if object == null else object.type


## Changes the terrain of a loaded tile and remembers it as an edit, so it survives the
## chunk unloading. A dormant plant or clearable object on the tile is gone for good.
func set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	assert(chunk != null, "Chunk not loaded for tile at %s" % world_pos)
	_clear_removable(world_pos)
	chunk.set_terrain(Chunk.local_pos(world_pos), terrain)
	_edit_terrain(world_pos, terrain)
	change_count += 1
	if terrain == Tile.Terrain.SOIL:
		soil.start(world_pos)
		fallow.tend(world_pos)
	else:
		soil.forget(world_pos)
		fallow.forget(world_pos)
	# New ground starts unworn: a path that is tilled and later grassed over is grass.
	wear.forget(world_pos)
	tile_changed.emit(world_pos)


## How wet the soil of a tile is, 0 (dry) to 1 (soaked). Tiles never wetted or dried have the
## default of data/crops.cfg. Only tilled soil has moisture that means anything.
func moisture_at(world_pos: Vector2i) -> float:
	return soil.at(world_pos)


## Sets the moisture of a tilled tile (kept between 0 and 1) and remembers it, so it survives
## the chunk unloading.
func set_moisture(world_pos: Vector2i, moisture: float) -> void:
	soil.set_at(world_pos, moisture)
	soil_moisture_changed.emit(world_pos)
	_tend_soil(world_pos)


## Sees to the fallow soil for the nights counted since it was last seen to (see FallowSoil): a
## tilled tile whose untended days are up comes up in weeds, or is grass again, unless something
## stands on it, which tends it.
func settle_fallow_soil() -> void:
	while fallow.settled_nights < fallow.nights:
		for pos in fallow.settle_next_night():
			_settle_fallow_tile(pos)


## `settle_fallow_soil` spread over frames: it lets go of the frame every
## `Simulation.frame_budget_usec`, and goes on in the next. `await` it. `next_frame` is a Callable
## that gives the signal of the next frame.
func settle_fallow_soil_over_frames(next_frame: Callable) -> void:
	var frame_started := Time.get_ticks_usec()
	while fallow.settled_nights < fallow.nights:
		for pos in fallow.settle_next_night():
			if Time.get_ticks_usec() - frame_started > Simulation.frame_budget_usec:
				await next_frame.call()
				frame_started = Time.get_ticks_usec()
			_settle_fallow_tile(pos)


func _settle_fallow_tile(world_pos: Vector2i) -> void:
	# Over frames, a tile can stop being soil after its night's tiles were taken.
	if not is_tilled(world_pos):
		return
	# An object in a chunk that is not loaded is an edit: what the player put there.
	var is_in_use := (
		building_at(world_pos) != null
		or _object_edits.get(world_pos) != null
		or _stored_object_at(world_pos) != null
	)
	if is_in_use:
		fallow.tend_on_settled_night(world_pos)
	elif fallow.is_grown_over(world_pos):
		_grow_over(world_pos)
	elif is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		tile_changed.emit(world_pos)


## Tilled soil that has grown over is grass again, the one ground a hoe tills (see ToolUse), with
## the look of its place (lush, dry) as before.
func _grow_over(world_pos: Vector2i) -> void:
	if is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		set_terrain(world_pos, Tile.Terrain.GRASS)
		return
	_edit_terrain(world_pos, Tile.Terrain.GRASS)
	soil.forget(world_pos)
	fallow.forget(world_pos)


## Working a tilled tile (watering it, putting something on it or taking it off) tends it: its days
## of lying fallow count anew, and weeds on it are gone.
func _tend_soil(world_pos: Vector2i) -> void:
	if not is_tilled(world_pos):
		return
	var was_weedy := fallow.is_weedy(world_pos)
	fallow.tend(world_pos)
	if was_weedy and is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		tile_changed.emit(world_pos)


## Whether the player tilled a tile: it is soil by their hand.
func is_tilled(world_pos: Vector2i) -> bool:
	return _terrain_edits.get(world_pos) == Tile.Terrain.SOIL


## The tilled tiles, in loaded chunks or not.
func tilled_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for pos in _terrain_edits:
		if is_tilled(pos):
			tiles.append(pos)
	return tiles


## Puts an object on its tiles. The chunk of its own tile must be loaded and its tiles free,
## except for dormant plants and clearable objects, which are gone for good.
func add_object(object: WorldObject) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(object.pos))
	assert(chunk != null, "Chunk not loaded for object at %s" % object.pos)
	for tile in object.tiles():
		_clear_removable(tile)
	assert(
		object.tiles().all(func(tile: Vector2i) -> bool: return object_at(tile) == null),
		"Tiles already have an object: %s" % object.pos
	)
	chunk.add_object(object)
	_edit_object(object.pos, object)
	for tile in object.tiles():
		_tend_soil(tile)
		if is_way_at(tile):
			# What was worn beneath is not any more.
			if wear.forget(tile):
				tile_changed.emit(tile)
		objects_changed.emit(tile)


## Takes the object that covers a tile off the world and returns it, or returns null if there
## was none.
func remove_object(world_pos: Vector2i) -> WorldObject:
	var object := object_at(world_pos)
	if object != null:
		take_off(object)
	return object


## Puts `replacement` where `old` stands. Works for objects in unloaded chunks too: they are
## edits, so the replacement is drawn when the chunk loads.
func replace_object(old: WorldObject, replacement: WorldObject) -> void:
	assert(old.pos == replacement.pos and old.tiles() == replacement.tiles(), "Not in place")
	var chunk := chunk_at(Chunk.world_to_chunk(old.pos))
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(old.pos))
		chunk.add_object(replacement)
	_edit_object(old.pos, replacement)
	_emit_objects_changed(old)


## Hits an object that this does not finish, taking `power` hit points off it. The damage
## makes it an edit, so it outlives the chunk. Draws nothing new, but the view shakes it.
func hit_object(object: WorldObject, power: int) -> void:
	object.take_hit(power)
	_edit_object(object.pos, object)
	object_hit.emit(object)


## Records that an object's state changed, so it outlives its chunk, and has it redrawn.
func change_object(object: WorldObject) -> void:
	_edit_object(object.pos, object)
	_emit_objects_changed(object)


## The objects the player changed and that are still there, in loaded chunks or not (see
## `NightUpkeep`).
func edited_objects() -> Array[WorldObject]:
	var objects: Array[WorldObject] = []
	for object in _object_edits.values():
		if object != null:
			objects.append(object)
	return objects


## The scarecrows the player put down and that are still there, in loaded chunks or not.
func scarecrows() -> Array[WorldObject]:
	var scarecrows_put_down: Array[WorldObject] = []
	for pos in _scarecrow_positions:
		scarecrows_put_down.append(_object_edits[pos])
	return scarecrows_put_down


## The campfires, in loaded chunks or not (see CampfireUpkeep).
func campfires() -> Array[WorldObject]:
	var fires: Array[WorldObject] = []
	for pos in _campfire_positions:
		fires.append(_object_edits[pos])
	return fires


## The crops the player planted and that are still there, in loaded chunks or not.
func crops() -> Array[WorldObject]:
	var crops_planted: Array[WorldObject] = []
	for pos in _crop_positions:
		crops_planted.append(_object_edits[pos])
	return crops_planted


## Takes an object off its tiles, in an unloaded chunk too (the edit keeps it off).
func take_off(object: WorldObject) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(object.pos))
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(object.pos))
	_edit_object(object.pos, null)
	for tile in object.tiles():
		_tend_soil(tile)
		objects_changed.emit(tile)


## Removes from a tile what gives way to whatever is put there: a dormant plant (it would
## otherwise be back in the way when its season comes) and a clearable object (tall grass).
func _clear_removable(world_pos: Vector2i) -> void:
	var object := _stored_object_at(world_pos)
	if object != null and (is_dormant(object) or _is_clearable(object)):
		take_off(object)


## Whether an object is there, but gives way to what is tilled, planted or built on its tile.
## The one rule that `is_free_on`, `is_buildable` and `placement_blockers` share.
func _is_in_the_way(world_pos: Vector2i) -> bool:
	var object := object_at(world_pos)
	return object != null and not _is_clearable(object)


func _is_clearable(object: WorldObject) -> bool:
	return object.type_data().get("clearable", false)


# Unloaded tiles have nothing to redraw; they are drawn when their chunk loads.
func _emit_objects_changed(object: WorldObject) -> void:
	if is_chunk_loaded(Chunk.world_to_chunk(object.pos)):
		for tile in object.tiles():
			objects_changed.emit(tile)


## Whether a tile is tidal mud under the water of the tide right now.
func is_flooded(world_pos: Vector2i) -> bool:
	return is_flooded_at(world_pos, clock.total_minutes())


## Like `is_flooded`, at the game minute `minutes` (see `GameClock.total_minutes`).
func is_flooded_at(world_pos: Vector2i, minutes: int) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.terrain == Tile.Terrain.MUD
		and Tide.floods(world_pos, Tide.level(minutes))
	)


## Flooded and free of anything that blocks walking (see `GameMap.is_wadeable`).
func is_wadeable(world_pos: Vector2i) -> bool:
	var object := object_at(world_pos)
	return is_flooded(world_pos) and (object == null or not object.blocks_walking())


## Tile rules, and buildings: only their door can be walked on (none on one with no inside). Flooded
## mud can't be walked on, like the sea; only the player on foot may wade into it (see
## `PlayerState.can_stand_at`), and this is the one place that keeps everyone else out.
func is_ground_walkable(world_pos: Vector2i) -> bool:
	return _is_ground_walkable_at(world_pos, clock.total_minutes())


## `GameMap.is_walkable` as it is at the game minute `minutes`: the tide and the plants of the
## season are those of that time, not the clock's. A villager's search uses it for the time it
## expects to be there (see TravelView).
func is_walkable_at(world_pos: Vector2i, minutes: int) -> bool:
	var object := object_on(world_pos, GameClock.day_of(minutes))
	if object != null and object.type_data().get("deck", false):
		return true
	if not _is_ground_walkable_at(world_pos, minutes):
		return false
	return object == null or not object.blocks_walking()


func is_walkable(world_pos: Vector2i) -> bool:
	return is_walkable_at(world_pos, clock.total_minutes())


func _is_ground_walkable_at(world_pos: Vector2i, minutes: int) -> bool:
	if not super.is_ground_walkable(world_pos) or is_flooded_at(world_pos, minutes):
		return false
	var building := building_at(world_pos)
	return building == null or (building.door_tile() == world_pos and building.has_inside())


## Farm animals keep off the tiles of buildings, the door included (it is for the player, who
## walks in through it).
func is_walkable_for_animals(pos: Vector2i) -> bool:
	return super(pos) and building_at(pos) == null


## Must agree with placement_blockers: a tile is buildable if it would not block a building.
func is_buildable(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.is_buildable()
		and not _is_in_the_way(world_pos)
		and building_at(world_pos) == null
	)


## Whether a one tile object can be put on a tile: the rules of `placement_blockers` for one
## tile, and not the one in front of a door, which has to stay free to walk through.
func is_placeable(world_pos: Vector2i) -> bool:
	return is_buildable(world_pos) and not is_in_front_of_door(world_pos)


## Whether a tile is the one just below a building's door, which has to stay free to walk through.
func is_in_front_of_door(world_pos: Vector2i) -> bool:
	var building_above := building_at(world_pos + Vector2i.UP)
	return building_above != null and building_above.door_tile() == world_pos + Vector2i.UP


## Whether a tile has this terrain and neither an object (a clearable one doesn't count) nor a
## building.
func is_free_on(world_pos: Vector2i, terrain: Tile.Terrain) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.terrain == terrain
		and not _is_in_the_way(world_pos)
		and building_at(world_pos) == null
	)


# --- Buildings ---


## Whether a tile is on the land of the village (see Village), which is not the player's.
func is_village_land(world_pos: Vector2i) -> bool:
	return village != null and village.is_land(world_pos)


## Whether an object is one of the village's cobbles: a cobble way on its land, which is not the
## player's to take up (the lanes and the square are laid with them, see VillageBuilder).
func is_village_cobble(object: WorldObject) -> bool:
	return object.type == WorldObjectTypes.STONE_PATH and is_village_land(object.pos)


## Whether a building is one the village put up.
func is_village_building(building: Building) -> bool:
	return village != null and village.has_building(building)


func buildings() -> Array[Building]:
	return _buildings.duplicate()


## The tiles buildings cover, doors included, as keys of a copy that shares nothing with the world
## but the buildings themselves (see TravelSnapshot).
func building_tiles() -> Dictionary:
	return _building_by_tile.duplicate()


## The steps the tiles took today (see `wear_tile`), as a copy.
func wear_steps() -> Dictionary:
	return wear.steps_today.duplicate()


## The days of wear of the worn tiles (see `end_wear_day`), as a copy that is not changed (shared
## by every call until the wear changes).
func wear_days() -> Dictionary:
	return wear.days_copy()


## The building whose footprint covers a tile, or null.
func building_at(world_pos: Vector2i) -> Building:
	return _building_by_tile.get(world_pos)


## The footprint tiles that stop a building from being placed, with the reason for each.
## Empty if it can be placed. Must agree with is_buildable.
func placement_blockers(
	building_type: StringName, origin: Vector2i
) -> Dictionary[Vector2i, Blocked]:
	var blockers: Dictionary[Vector2i, Blocked] = {}
	for pos in Building.footprint_tiles(building_type, origin):
		var tile := tile_at(pos)
		if tile == null or not tile.is_buildable():
			blockers[pos] = Blocked.TERRAIN
		elif _is_in_the_way(pos) or building_at(pos) != null:
			blockers[pos] = Blocked.OCCUPIED
	# The player has to be able to stand in front of the door, to go in and to come out.
	var door_offset: Vector2i = BuildingTypes.TYPES[building_type]["door_offset"]
	var front := origin + door_offset + Vector2i.DOWN
	if not is_walkable(front):
		var is_blocked_by_object := tile_at(front) != null and tile_at(front).is_walkable()
		blockers[front] = Blocked.OCCUPIED if is_blocked_by_object else Blocked.TERRAIN
	return blockers


## Places a building in one of its styles and returns it, or returns null if any footprint
## tile is blocked.
func place_building(building_type: StringName, origin: Vector2i, style := &"") -> Building:
	if not placement_blockers(building_type, origin).is_empty():
		return null
	var building := Building.new(building_type, origin, style)
	for tile in building.tiles():
		_clear_removable(tile)
	_add_building(building)
	building_placed.emit(building)
	return building


## Takes a building off the land, with its interior. What it held is the caller's to give back
## (see GameState `take_down_building`).
func remove_building(building: Building) -> void:
	assert(_buildings.has(building), "Not a building of this world")
	_buildings.erase(building)
	for tile in building.tiles():
		_building_by_tile.erase(tile)
	building_removed.emit(building)


# --- Clay ---


## Whether a tile is a clay spot that still holds clay: grass (not tilled) on a generated spot
## (see WorldGenerator `is_clay_spot`) that was not dug in the last CLAY_SPENT_NIGHTS nights.
func has_clay(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.terrain == Tile.Terrain.GRASS
		and not _spent_clay_spots.has(world_pos)
		and _generator.is_clay_spot(world_pos)
	)


## Whether a tile lies in a forest as the world generated it (see WorldGenerator `is_forest`).
func is_in_woods(world_pos: Vector2i) -> bool:
	return _generator.is_forest(world_pos)


## Digs a clay spot out: it holds no clay for the next CLAY_SPENT_NIGHTS nights. What it gave is
## up to the caller.
func spend_clay_spot(world_pos: Vector2i) -> void:
	_spent_clay_spots[world_pos] = CLAY_SPENT_NIGHTS
	clay_spot_changed.emit(world_pos)


## Counts a night off every dug clay spot; those that recover hold clay again (see NightUpkeep).
func recover_clay_spots() -> void:
	for pos in _spent_clay_spots.keys():
		_spent_clay_spots[pos] -= 1
		if _spent_clay_spots[pos] <= 0:
			_spent_clay_spots.erase(pos)
			if is_chunk_loaded(Chunk.world_to_chunk(pos)):
				clay_spot_changed.emit(pos)


# --- Desire paths ---


## Counts `steps` onto a tile (one each time the player steps onto it). The tile only looks worn
## after the day (see `end_wear_day`).
func wear_tile(world_pos: Vector2i, steps := 1.0) -> void:
	if _wears_at(world_pos):
		wear.add_steps(world_pos, steps)


## `wear_tile` for a tile of a chunk that is not loaded, where the ground and the building cannot
## be asked: the caller knows that the grass there wears (see TravelMask `wears`) and that no
## building stands on it.
func wear_unloaded(world_pos: Vector2i, steps: float) -> void:
	wear.add_steps(world_pos, steps)


## Gives a tile `days` of wear at once, as if it had been walked on enough for that many days in
## a row (for the debug views, which make worn ground). The same ground wears as with `wear_tile`.
func set_wear_days(world_pos: Vector2i, days: int) -> void:
	if _wears_at(world_pos) and wear.set_days(world_pos, days):
		tile_changed.emit(world_pos)


## How worn the grass of a tile is (see PathRules).
func wear_stage(world_pos: Vector2i) -> PathRules.Stage:
	return wear.stage_of(world_pos)


## The day that has just ended counts for every tile that was walked on (see NightUpkeep), and the
## village's lanes and square are worn again. Emits `tile_changed` for tiles that look different.
func end_wear_day() -> void:
	var changed := wear.end_day()
	if village != null:
		changed.append_array(wear.keep_worn(village.kept_worn_tiles, _is_kept_tile_free_to_wear))
	# A kept tile that the quiet day changed and the keeping changed back is on the list twice.
	var emitted: Dictionary[Vector2i, bool] = {}
	for pos in changed:
		if not emitted.has(pos) and is_chunk_loaded(Chunk.world_to_chunk(pos)):
			emitted[pos] = true
			tile_changed.emit(pos)


## Whether a kept tile still wears, loaded or not: not tilled, not under a building or a way.
func _is_kept_tile_free_to_wear(world_pos: Vector2i) -> bool:
	var edit: WorldObject = _object_edits.get(world_pos)
	return (
		_terrain_edits.get(world_pos, Tile.Terrain.GRASS) == Tile.Terrain.GRASS
		and building_at(world_pos) == null
		and (edit == null or not edit.type_data().get("way", false))
	)


## Whether a tile can wear: only grass and the floodplain do (see `Tile.wears`), and not under a
## building, whose door is walked on too, or a way.
func _wears_at(world_pos: Vector2i) -> bool:
	var tile := tile_at(world_pos)
	return (
		tile != null
		and tile.wears()
		and building_at(world_pos) == null
		and not is_way_at(world_pos)
	)


## Whether the ground at a tile is mud: worn ground when the rain has made it so.
func is_muddy_at(world_pos: Vector2i) -> bool:
	return is_muddy and wear_stage(world_pos) != PathRules.Stage.UNWORN


## Makes worn ground mud or dry again (GameState decides by the weather). Emits `tile_changed` for
## every worn tile of the loaded chunks, to be drawn again.
func set_muddy(muddy: bool) -> void:
	if muddy == is_muddy:
		return
	is_muddy = muddy
	for pos: Vector2i in wear.days:
		if wear_stage(pos) != PathRules.Stage.UNWORN and is_chunk_loaded(Chunk.world_to_chunk(pos)):
			tile_changed.emit(pos)


# --- Ground items ---


func pile_seed() -> int:
	return world_seed


# --- Saving ---


## The seed and what the player changed. The chunks are not saved: they are generated again
## from the seed, with the edits replayed on top (see `add_chunk`).
func to_dict() -> Dictionary:
	return WorldSave.dict_of(snapshot())


## A copy of what `to_dict` writes, quick to take and in the types the world keeps it in, which
## shares nothing with the world: it is made into save data by `WorldSave.dict_of` (on a thread,
## while the game goes on), which takes most of the time. The soil is brought up to now first, and
## the fallow soil seen to.
func snapshot() -> Dictionary:
	soil.catch_up_all()
	settle_fallow_soil()
	var buildings_data: Array[Dictionary] = []
	for building in _buildings:
		buildings_data.append(building.to_dict())
	# The objects are the one thing that changes after the copy, so each is made data at once.
	var object_edits := []
	for object: WorldObject in _object_edits.values():
		object_edits.append(null if object == null else object.to_dict())
	return {
		"seed": world_seed,
		"ground_items": ground_items.snapshot(),
		"spent_clay_spots": _spent_clay_spots.duplicate(),
		"wear": wear.days.duplicate(),
		"wear_today": wear.steps_today.duplicate(),
		"terrain_edits": _terrain_edits.duplicate(),
		"soil_moisture": soil.snapshot(),
		"fallow_nights": fallow.nights,
		"fallow_soil": fallow.snapshot(),
		"object_edit_positions": _object_edits.keys(),
		"object_edits": object_edits,
		"buildings": buildings_data,
		"village": null if village == null else village.to_dict(),
	}


## A world with no chunks loaded; whoever shows it loads them.
static func from_dict(data: Dictionary, game_clock: GameClock) -> World:
	var world := World.new(int(data["seed"]), game_clock)
	for edit: Array in data["terrain_edits"]:
		world._edit_terrain(SaveCodec.vector_from_json(edit), SaveCodec.terrain_from_json(edit[2]))
	for entry: Array in data["soil_moisture"]:
		world.soil.load_entry(entry)
	world.fallow.load_array(int(data["fallow_nights"]), data["fallow_soil"])
	for entry: Array in data["spent_clay_spots"]:
		world._spent_clay_spots[SaveCodec.vector_from_json(entry)] = int(entry[2])
	for entry: Array in data["wear"]:
		world.wear.restore_days(SaveCodec.vector_from_json(entry), int(entry[2]))
	for entry: Array in data["wear_today"]:
		world.wear.steps_today[SaveCodec.vector_from_json(entry)] = float(entry[2])
	for edit: Dictionary in data["object_edits"]:
		var object_data: Variant = edit["object"]
		world._edit_object(
			SaveCodec.vector_from_json(edit["pos"]),
			null if object_data == null else WorldObject.from_dict(object_data)
		)
	# A save from before untilled soil forgot its moisture may still hold some; soil with none saved is
	# at the default.
	for pos in world.soil.tiles():
		if not world.is_tilled(pos):
			world.soil.forget(pos)
	for pos in world.tilled_tiles():
		world.soil.start(pos)
	for building_data: Dictionary in data["buildings"]:
		world._add_building(Building.from_dict(building_data))
	world.ground_items.load_array(data["ground_items"])
	if data["village"] != null:
		world.village = Village.from_dict(data["village"])
	return world


## The tilled tiles of a chunk, loaded or not.
func tilled_tiles_in_chunk(chunk_coords: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for pos: Vector2i in _terrain_edit_positions_by_chunk.get(chunk_coords, {}):
		if is_tilled(pos):
			tiles.append(pos)
	return tiles


func _edit_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	_terrain_edits[world_pos] = terrain
	_note_edited(_terrain_edit_positions_by_chunk, world_pos)
	edited.emit(Chunk.world_to_chunk(world_pos))


## `object` is null where the generated object was removed.
func _edit_object(world_pos: Vector2i, object: WorldObject) -> void:
	_object_edits[world_pos] = object
	if object != null and object.is_crop():
		_crop_positions[world_pos] = true
	else:
		_crop_positions.erase(world_pos)
	if object != null and object.type == WorldObjectTypes.SCARECROW:
		_scarecrow_positions[world_pos] = true
	else:
		_scarecrow_positions.erase(world_pos)
	if Campfire.is_campfire(object):
		_campfire_positions[world_pos] = true
	else:
		_campfire_positions.erase(world_pos)
	_note_edited(_object_edit_positions_by_chunk, world_pos)
	edited.emit(Chunk.world_to_chunk(world_pos))


func _note_edited(
	positions_by_chunk: Dictionary[Vector2i, Dictionary], world_pos: Vector2i
) -> void:
	var chunk_coords := Chunk.world_to_chunk(world_pos)
	if not positions_by_chunk.has(chunk_coords):
		positions_by_chunk[chunk_coords] = {}
	positions_by_chunk[chunk_coords][world_pos] = true


func _count_object_change(_world_pos: Vector2i) -> void:
	change_count += 1


func _count_building(_building: Building) -> void:
	change_count += 1


func _add_building(building: Building) -> void:
	_buildings.append(building)
	for pos in building.tiles():
		_building_by_tile[pos] = building
