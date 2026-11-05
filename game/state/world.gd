# gdlint: disable=max-public-methods
# (World is the one entry point for map changes; splitting off the object edits is a
# TASKS.md follow-up.)
class_name World
extends GameMap
## The world: a seed, fixed bounds and the chunks that are currently loaded.
##
## The world is centred on the origin: with MAX_SIZE_CHUNKS = 64, chunk coordinates run
## from -32 to 31 on both axes, so world tile positions run from -1024 to 1023.

## An object was added or removed at this world tile position: one signal for each tile it
## covers.
signal objects_changed(world_pos: Vector2i)
## A tile's terrain was changed (see `set_terrain`).
signal tile_changed(world_pos: Vector2i)
## The moisture of a tilled tile changed (see `set_moisture`).
signal soil_moisture_changed(world_pos: Vector2i)
## A tool hit an object (see `hit_object`). The finishing hit emits it too, after the object
## is removed or replaced by what it leaves.
signal object_hit(object: WorldObject)
## A clay spot was dug, or has recovered (see `spend_clay_spot`).
signal clay_spot_changed(world_pos: Vector2i)
## A building was placed.
signal building_placed(building: Building)
## A pile of items was put on the ground, or taken off it (see `drop_items`).
signal ground_item_added(ground_item: GroundItem)
signal ground_item_removed(ground_item: GroundItem)
## What one `drop_items` call put on the ground, after `ground_item_added` for each pile: the
## view lets them hop out of `source` (nothing about it is saved).
signal ground_items_dropped(source: Vector2i, piles: Array[GroundItem])

## Why a footprint tile can't be built on.
enum Blocked {
	## Water, wetland or floodplain, or the tile is not loaded.
	TERRAIN,
	## A world object or a building is on it.
	OCCUPIED,
}

## Dropped items lie on the free tiles within this many tiles of their source; the second
## range is for a source that has no free tile around it.
const SCATTER_RANGES := [1, 2]
## How long dropped piles wait before they can be pulled: the longest hop with its stagger,
## after a falling tree lands (about 1.3 s), with a little to spare.
const DROP_SETTLE_SECONDS := 1.4
## Where on its tile a dropped pile lies, as a fraction of the tile, so the piles of one drop
## don't line up on the tile centres.
const PILE_MARGIN := 0.25

## A dug clay spot has no clay for this many nights.
const CLAY_SPENT_NIGHTS := 5

## The only place that defines the world size. Must be even so the world is centred.
const MAX_SIZE_CHUNKS := 64

var world_seed: int
## The game's clock: what the seasonal plants follow (see `is_dormant`). Whoever owns the
## clock shares it here.
var clock := GameClock.new()
var vegetation := Vegetation.default_vegetation()
var _generator: WorldGenerator
var _chunks: Dictionary[Vector2i, Chunk] = {}
## What the player changed, kept outside the chunks so it survives their unloading: per world
## position the object that stands there now, or null where the generated object was
## removed. Together with the seed this is the whole world (the future save format).
var _object_edits: Dictionary[Vector2i, WorldObject] = {}
## Terrain the player changed (e.g. grass tilled to soil), by world position. Replayed on
## chunks before the objects, which may depend on the ground.
var _terrain_edits: Dictionary[Vector2i, Tile.Terrain] = {}
## The moisture (0 to 1) of tilled tiles that differs from the default (see `moisture_at`), by
## world position.
var _soil_moisture: Dictionary[Vector2i, float] = {}
## Buildings are the player's work and must outlive the chunks they stand on, and one can
## cross a chunk border, so they live here and not in chunks.
var _buildings: Array[Building] = []
var _building_by_tile: Dictionary[Vector2i, Building] = {}
## The clay spots that were dug, with the nights left until they hold clay again.
var _spent_clay_spots: Dictionary[Vector2i, int] = {}
## What lies on the ground: dropped by whatever the player harvested, until collected.
var _ground_items: Array[GroundItem] = []


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_generator = WorldGenerator.new(seed_value)


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
	for pos in _terrain_edits:
		if Chunk.world_to_chunk(pos) == chunk.coords:
			chunk.set_terrain(Chunk.local_pos(pos), _terrain_edits[pos])
	for pos in _object_edits:
		if Chunk.world_to_chunk(pos) != chunk.coords:
			continue
		chunk.remove_object(Chunk.local_pos(pos))
		if _object_edits[pos] != null:
			chunk.add_object(_object_edits[pos])


func remove_chunk(chunk_coords: Vector2i) -> void:
	_chunks.erase(chunk_coords)


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
	var object := _stored_object_at(world_pos)
	return null if object != null and is_dormant(object) else object


## Whether a seasonal plant is dormant: it is out of its season, by the vegetation curve of its
## type and its own threshold. The one rule that the view, walking, building and targeting
## share. Nothing about it is saved.
func is_dormant(object: WorldObject) -> bool:
	return (
		object.type_data().get("seasonal") == WorldObjectTypes.DORMANCY
		and not vegetation.is_present(object.type, world_seed, object.pos, clock.day)
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
## loaded area (see WorldView.LOAD_RADIUS and UNLOAD_RADIUS).
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


## Changes the terrain of a loaded tile and remembers it as an edit, so it survives the
## chunk unloading. A dormant plant or clearable object on the tile is gone for good.
func set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(world_pos))
	assert(chunk != null, "Chunk not loaded for tile at %s" % world_pos)
	_clear_removable(world_pos)
	chunk.set_terrain(Chunk.local_pos(world_pos), terrain)
	_terrain_edits[world_pos] = terrain
	tile_changed.emit(world_pos)


## How wet the soil of a tile is, 0 (dry) to 1 (soaked). Tiles never wetted or dried have the
## default of data/crops.cfg. Only tilled soil has moisture that means anything.
func moisture_at(world_pos: Vector2i) -> float:
	return _soil_moisture.get(world_pos, CropRules.default_rules().farming("default_moisture"))


## Sets the moisture of a tilled tile (kept between 0 and 1) and remembers it, so it survives
## the chunk unloading.
func set_moisture(world_pos: Vector2i, moisture: float) -> void:
	_soil_moisture[world_pos] = clampf(moisture, 0.0, 1.0)
	soil_moisture_changed.emit(world_pos)


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
	_object_edits[object.pos] = object
	for tile in object.tiles():
		objects_changed.emit(tile)


## Takes the object that covers a tile off the world and returns it, or returns null if there
## was none.
func remove_object(world_pos: Vector2i) -> WorldObject:
	var object := object_at(world_pos)
	if object != null:
		_take_off(object)
	return object


## Puts `replacement` where `old` stands. Works for objects in unloaded chunks too: they are
## edits, so the replacement is drawn when the chunk loads.
func replace_object(old: WorldObject, replacement: WorldObject) -> void:
	assert(old.pos == replacement.pos and old.tiles() == replacement.tiles(), "Not in place")
	var chunk := chunk_at(Chunk.world_to_chunk(old.pos))
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(old.pos))
		chunk.add_object(replacement)
	_object_edits[old.pos] = replacement
	_emit_objects_changed(old)


## Hits an object that this does not finish, taking `power` hit points off it. The damage
## makes it an edit, so it outlives the chunk. Draws nothing new, but the view shakes it.
func hit_object(object: WorldObject, power: int) -> void:
	object.take_hit(power)
	_object_edits[object.pos] = object
	object_hit.emit(object)


## Records that an object's state changed, so it outlives its chunk, and has it redrawn.
func change_object(object: WorldObject) -> void:
	_object_edits[object.pos] = object
	_emit_objects_changed(object)


## Lets a night pass over everything the player changed, in unloaded chunks too: the soil
## dries and rain wets it, crops live through the day that ended (in the weather of their
## tile), cut reeds grow back by it, damage heals, picked bushes bear again, saplings grow up and
## stumps rot away. Only edits change like this (a hit, a tilling or a planting makes one), so
## they are all in the edits.
## A sapling does not turn into a tree on a tile in `occupied_tiles`: it waits a day.
func pass_night(occupied_tiles: Array[Vector2i], weather: Weather) -> void:
	_dry_and_wet_soil(weather)
	_recover_clay_spots()
	for object: WorldObject in _object_edits.values():
		if object == null:
			continue
		var has_changed := false
		if object.is_crop():
			var day := weather.day_summary(object.pos, clock.day - 1)
			has_changed = CropLife.live_through_day(object, day, moisture_at(object.pos))
		elif ReedLife.is_reeds(object):
			var day := weather.day_summary(object.pos, clock.day - 1)
			has_changed = ReedLife.live_through_day(object, day)
		else:
			has_changed = object.pass_night()
		if has_changed:
			_emit_objects_changed(object)
		if object.is_mature():
			var next := object.matured()
			if not (next.blocks_walking() and occupied_tiles.has(next.pos)):
				replace_object(object, next)
		elif object.has_rotted():
			var sapling := object.rotted(clock.day)
			if sapling == null:
				_take_off(object)
			else:
				replace_object(object, sapling)


## Counts a night off every dug clay spot; those that recover hold clay again.
func _recover_clay_spots() -> void:
	for pos in _spent_clay_spots.keys():
		_spent_clay_spots[pos] -= 1
		if _spent_clay_spots[pos] <= 0:
			_spent_clay_spots.erase(pos)
			if is_chunk_loaded(Chunk.world_to_chunk(pos)):
				clay_spot_changed.emit(pos)


## Rain wets the tilled soil and the day dries it, as the weather of the day that ended says.
func _dry_and_wet_soil(weather: Weather) -> void:
	var rules := CropRules.default_rules()
	for pos in tilled_tiles():
		var day := weather.day_summary(pos, clock.day - 1)
		var drying := (
			rules.farming("drying_base")
			+ rules.farming("drying_per_degree") * maxf(day.mean_temperature, 0.0)
			+ rules.farming("drying_per_sun_hour") * day.sunlight_hours
			+ rules.farming("drying_per_wind") * day.max_wind_speed
		)
		set_moisture(pos, moisture_at(pos) + rules.farming("rain_wets") * day.rain_hours - drying)


## Takes an object off its tiles, in an unloaded chunk too (the edit keeps it off).
func _take_off(object: WorldObject) -> void:
	var chunk := chunk_at(Chunk.world_to_chunk(object.pos))
	if chunk != null:
		chunk.remove_object(Chunk.local_pos(object.pos))
	_object_edits[object.pos] = null
	for tile in object.tiles():
		objects_changed.emit(tile)


## Removes from a tile what gives way to whatever is put there: a dormant plant (it would
## otherwise be back in the way when its season comes) and a clearable object (tall grass).
func _clear_removable(world_pos: Vector2i) -> void:
	var object := _stored_object_at(world_pos)
	if object != null and (is_dormant(object) or _is_clearable(object)):
		_take_off(object)


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


## Tile and object rules, and buildings: only their door can be walked on.
func is_walkable(world_pos: Vector2i) -> bool:
	if not super(world_pos):
		return false
	var building := building_at(world_pos)
	return building == null or building.door_tile() == world_pos


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
	var building_above := building_at(world_pos + Vector2i.UP)
	var is_in_front_of_door := (
		building_above != null and building_above.door_tile() == world_pos + Vector2i.UP
	)
	return is_buildable(world_pos) and not is_in_front_of_door


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


func buildings() -> Array[Building]:
	return _buildings.duplicate()


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
		var is_blocked_by_thing := tile_at(front) != null and tile_at(front).is_walkable()
		blockers[front] = Blocked.OCCUPIED if is_blocked_by_thing else Blocked.TERRAIN
	return blockers


## Places a building and returns it, or returns null if any footprint tile is blocked.
func place_building(building_type: StringName, origin: Vector2i) -> Building:
	if not placement_blockers(building_type, origin).is_empty():
		return null
	var building := Building.new(building_type, origin)
	for tile in building.tiles():
		_clear_removable(tile)
	_add_building(building)
	building_placed.emit(building)
	return building


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


## Digs a clay spot out: it holds no clay for the next CLAY_SPENT_NIGHTS nights. What it gave is
## up to the caller.
func spend_clay_spot(world_pos: Vector2i) -> void:
	_spent_clay_spots[world_pos] = CLAY_SPENT_NIGHTS
	clay_spot_changed.emit(world_pos)


# --- Ground items ---


func ground_items() -> Array[GroundItem]:
	return _ground_items.duplicate()


## The piles whose position is within `radius` tiles of `position`.
func ground_items_near(position: Vector2, radius: float) -> Array[GroundItem]:
	return _ground_items.filter(
		func(ground_item: GroundItem) -> bool:
			return ground_item.position.distance_to(position) <= radius
	)


## How many of an item lie on the ground, in all piles.
func ground_count_of(item: StringName) -> int:
	var total := 0
	for ground_item in _ground_items:
		if ground_item.item == item:
			total += ground_item.count
	return total


## Puts items (item id to count) on the ground around a tile: each kind is split into piles of
## about the same size over the free walkable tiles near `source`, in an order that depends on
## the tile and the kind only. The one entry point for whatever gives items to the world.
## Call it after the source was removed or replaced, so its own tile counts if it is free now.
func drop_items(source: Vector2i, drops: Dictionary) -> void:
	var kind_index := 0
	var dropped: Array[GroundItem] = []
	for item: StringName in drops:
		var tiles := _scatter_tiles(source, kind_index)
		var total: int = drops[item]
		var piles := mini(total, tiles.size())
		for pile in piles:
			var count := total / piles + (1 if pile < total % piles else 0)
			var offset := Vector2(
				_hash_fraction(tiles[pile], 2 * kind_index),
				_hash_fraction(tiles[pile], 2 * kind_index + 1)
			)
			var ground_item := GroundItem.new(item, count, Vector2(tiles[pile]) + offset)
			ground_item.settle_seconds = DROP_SETTLE_SECONDS
			add_ground_item(ground_item)
			dropped.append(ground_item)
		kind_index += 1
	ground_items_dropped.emit(source, dropped)


## Takes a pile off the ground (it was collected).
func remove_ground_item(ground_item: GroundItem) -> void:
	_ground_items.erase(ground_item)
	ground_item_removed.emit(ground_item)


## The free walkable tiles near `source`, in the order the piles of the `kind_index`th kind of
## a drop go to them. With none free, the source itself.
func _scatter_tiles(source: Vector2i, kind_index: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for scatter_range: int in SCATTER_RANGES:
		for y in range(-scatter_range, scatter_range + 1):
			for x in range(-scatter_range, scatter_range + 1):
				if is_walkable(source + Vector2i(x, y)):
					tiles.append(source + Vector2i(x, y))
		if not tiles.is_empty():
			break
	if tiles.is_empty():
		return [source]
	var salt := PositionHash.of(source, kind_index)
	tiles.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return PositionHash.of(a, salt) < PositionHash.of(b, salt)
	)
	return tiles


## A value from PILE_MARGIN to 1 - PILE_MARGIN, always the same for the same tile and salt.
func _hash_fraction(tile: Vector2i, salt: int) -> float:
	var fraction := float(PositionHash.of(tile, salt + world_seed)) / (PositionHash.MASK + 1)
	return PILE_MARGIN + fraction * (1.0 - 2.0 * PILE_MARGIN)


## Lays a pile at an exact position (`drop_items` scatters instead).
func add_ground_item(ground_item: GroundItem) -> void:
	_ground_items.append(ground_item)
	ground_item_added.emit(ground_item)


# --- Saving ---


## The seed and what the player changed. The chunks are not saved: they are generated again
## from the seed, with the edits replayed on top (see `add_chunk`).
func to_dict() -> Dictionary:
	var terrain_edits: Array[Array] = []
	for pos in _terrain_edits:
		terrain_edits.append(
			SaveCodec.vector_to_json(pos) + [SaveCodec.terrain_to_json(_terrain_edits[pos])]
		)
	# A removed object is saved as `{"pos": [x, y], "object": null}`.
	var object_edits: Array[Dictionary] = []
	for pos in _object_edits:
		var object := _object_edits[pos]
		(
			object_edits
			. append(
				{
					"pos": SaveCodec.vector_to_json(pos),
					"object": null if object == null else object.to_dict(),
				}
			)
		)
	var buildings_data: Array[Dictionary] = []
	for building in _buildings:
		buildings_data.append(building.to_dict())
	var soil_moisture: Array[Array] = []
	for pos in _soil_moisture:
		soil_moisture.append(SaveCodec.vector_to_json(pos) + [_soil_moisture[pos]])
	var ground_items_data: Array[Dictionary] = []
	for ground_item in _ground_items:
		ground_items_data.append(ground_item.to_dict())
	var spent_clay_spots: Array[Array] = []
	for pos in _spent_clay_spots:
		spent_clay_spots.append(SaveCodec.vector_to_json(pos) + [_spent_clay_spots[pos]])
	return {
		"seed": world_seed,
		"ground_items": ground_items_data,
		"spent_clay_spots": spent_clay_spots,
		"terrain_edits": terrain_edits,
		"soil_moisture": soil_moisture,
		"object_edits": object_edits,
		"buildings": buildings_data,
	}


## A world with no chunks loaded; whoever shows it loads them.
static func from_dict(data: Dictionary) -> World:
	var world := World.new(int(data["seed"]))
	for edit: Array in data["terrain_edits"]:
		world._terrain_edits[SaveCodec.vector_from_json(edit)] = SaveCodec.terrain_from_json(
			edit[2]
		)
	# Saves from before moisture have none: all the soil is as default.
	for entry: Array in data.get("soil_moisture", []):
		world._soil_moisture[SaveCodec.vector_from_json(entry)] = float(entry[2])
	# Saves from before clay have no spent spots.
	for entry: Array in data.get("spent_clay_spots", []):
		world._spent_clay_spots[SaveCodec.vector_from_json(entry)] = int(entry[2])
	for edit: Dictionary in data["object_edits"]:
		var object_data: Variant = edit["object"]
		world._object_edits[SaveCodec.vector_from_json(edit["pos"])] = (
			null if object_data == null else WorldObject.from_dict(object_data)
		)
	for building_data: Dictionary in data["buildings"]:
		world._add_building(Building.from_dict(building_data))
	for ground_item_data: Dictionary in data["ground_items"]:
		world._ground_items.append(GroundItem.from_dict(ground_item_data))
	return world


func _add_building(building: Building) -> void:
	_buildings.append(building)
	for pos in building.tiles():
		_building_by_tile[pos] = building
