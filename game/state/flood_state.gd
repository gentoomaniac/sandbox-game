class_name FloodState
extends RefCounted
## The water a storm surge leaves on the land behind the dykes (see design/world/storm-surge.md):
## the sea runs over the dykes that are lower than its level (and damages those it comes near to),
## fills the lower land from each breach tile by tile, stands for a day or two and drains again.
## The water is not terrain: a tile just has a depth here, which the rules (`World.is_flooded`) and
## the overlay read. The numbers are in the `[surge]` section of data/landscape.cfg.
##
## The fill and the drain are work on a budget of tiles per frame (`step`), never a scan of the
## world, so no frame stalls: a skip of time finishes the work at once (`settle`). The state holds
## no reference to the world; whoever drives it passes the world in, so the two don't keep each
## other alive.

## Some tiles of these chunks got more or less water (told once after each batch of work).
signal chunks_changed(chunk_coords: Array[Vector2i])
## The sea ran over `count` more dyke tiles.
signal breached(count: int)

enum Phase { IDLE, FILLING, STANDING, DRAINING }

## The land the water fills. The Warften, the foreshore, the water itself and the floors of houses
## stay out.
const FLOODABLE_TERRAINS: Array[Tile.Terrain] = [
	Tile.Terrain.GRASS, Tile.Terrain.SOIL, Tile.Terrain.WETLAND, Tile.Terrain.FLOODPLAIN
]
const METRES_TO_CM := 100.0
## Hash salts of the length of a flood's stay and of what happens to an item it washes over.
const STAY_SALT := 1032
const WASH_SALT := 1033

var phase := Phase.IDLE
## How high the water stands over mean high water, in metres.
var level := 0.0
## The game minute the water starts to drain.
var drain_minute := 0

## The depth in centimetres of each tile under water.
var _depth_cm: Dictionary[Vector2i, int] = {}
## The same by chunk, for the overlay's masks and the save: {chunk: {tile: true}}.
var _wet_by_chunk: Dictionary[Vector2i, Dictionary] = {}
## The tiles to fill, in order, and the depth each one gets; `_queue_head` is the next one.
var _queue: Array[Vector2i] = []
var _queue_depth_cm: Array[int] = []
var _queue_head := 0
## The piles of items this flood has washed already, so that one is not washed on and on.
var _washed: Dictionary[GroundItem, bool] = {}
## The tiles looked at in this fill, so that none is looked at twice.
var _seen: Dictionary[Vector2i, bool] = {}
## What is left to fill, in tile-metres (see `volume_per_breach`).
var _volume_left := 0.0
## The chunks whose dykes the sea has met already.
var _met_chunks: Dictionary[Vector2i, bool] = {}
## The days of salt each tile that stood under the sea still carries, and the days each that dried
## is still muddy.
var _salt_days: Dictionary[Vector2i, int] = {}
var _mud_days: Dictionary[Vector2i, int] = {}
## When the villagers mend each damaged dyke tile, as a game minute.
var _repair_minute: Dictionary[Vector2i, int] = {}
var _drain_order: Array[Vector2i] = []
var _drain_head := 0
## The tiles of work that `step` may do, as time passes (see `fill_tiles_per_second`).
var _credit := 0.0
var _dirty_chunks: Dictionary[Vector2i, bool] = {}
var _landscape: LandscapeRules


func _init(landscape := LandscapeRules.default_rules()) -> void:
	_landscape = landscape


## How deep the water stands on a tile, in metres; 0 on dry ground.
func depth_at(tile: Vector2i) -> float:
	return _depth_cm.get(tile, 0) / METRES_TO_CM


## The days of salt a tile still carries after it stood under the sea (0 for none).
func salt_days_at(tile: Vector2i) -> int:
	return _salt_days.get(tile, 0)


## Whether the dyke on a tile is torn: the sea damaged or broke it, and the villagers have not
## mended it yet.
func is_torn(tile: Vector2i) -> bool:
	return _repair_minute.has(tile)


## Whether a tile that dried is still muddy.
func is_muddy_at(tile: Vector2i) -> bool:
	return _mud_days.has(tile)


## Whether the water is too deep to walk on (it can be waded, see `World.is_wadeable`).
func is_deep_at(tile: Vector2i) -> bool:
	return depth_at(tile) > _landscape.value("surge", "wade_depth")


## The tiles of a chunk under water.
func wet_in_chunk(chunk_coords: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	tiles.assign(_wet_by_chunk.get(chunk_coords, {}).keys())
	return tiles


func wet_count() -> int:
	return _depth_cm.size()


## Whether a flood is on: filling, standing or draining.
func is_active() -> bool:
	return phase != Phase.IDLE


## Whether `step` has tiles left to fill or drain.
func has_work() -> bool:
	if phase == Phase.FILLING:
		return _queue_head < _queue.size() and _volume_left > 0.0
	return phase == Phase.DRAINING and _drain_head < _drain_order.size()


## The sea rises to `new_level` metres at game minute `now`, for the high water of `tide_number`:
## it breaks the dykes of the loaded chunks that are lower, damages those it comes near to, and
## starts to fill the land behind the breaches.
func begin(world: World, new_level: float, now: int, tide_number: int) -> void:
	phase = Phase.FILLING
	level = new_level
	_drain_order.clear()
	_drain_head = 0
	_queue.clear()
	_queue_depth_cm.clear()
	_queue_head = 0
	_volume_left = 0.0
	_seen.clear()
	_washed.clear()
	_met_chunks.clear()
	var stay_hours: float = _landscape.value("surge", "stay_hours")
	var spread: float = _landscape.value("surge", "stay_spread_hours")
	var roll := float(
		PositionHash.of(Vector2i(tide_number, 0), world.world_seed + STAY_SALT) % 1000
	)
	drain_minute = now + roundi((stay_hours + spread * (2.0 * roll / 1000.0 - 1.0)) * 60.0)
	_meet_new_chunks(world, now)


## The clock moved on to `now`: the water meets the dykes of chunks that were loaded since it
## rose, if the sea still stands at its height (`is_holding`), and starts to drain when its stay
## is over.
func advance(world: World, now: int, is_holding: bool) -> void:
	if phase == Phase.IDLE or phase == Phase.DRAINING:
		return
	if is_holding:
		_meet_new_chunks(world, now)
	if now >= drain_minute:
		_start_draining()


## A day has ended: the salt and the mud of the tiles lose a day, and the salt a day more for each
## hour of rain (`rain_hours`, see WeatherDay).
func end_day(rain_hours: float) -> void:
	var salt_lost := 1 + int(rain_hours)
	for tile in _salt_days.keys():
		_salt_days[tile] -= salt_lost
		if _salt_days[tile] <= 0:
			_salt_days.erase(tile)
	for tile in _mud_days.keys():
		_mud_days[tile] -= 1
		if _mud_days[tile] <= 0:
			_mud_days.erase(tile)


## The villagers mend the damaged dykes that are due at game minute `now`. A dyke in a chunk that
## is not loaded waits.
func mend(world: World, now: int) -> void:
	for tile in _repair_minute.keys():
		if _repair_minute[tile] > now:
			continue
		var dyke := world.object_at(tile)
		if dyke != null and dyke.type == WorldObjectTypes.DYKE:
			# Mended before it changes, so it is drawn whole.
			_repair_minute.erase(tile)
			world.dykes.restore(world, dyke)


## Does `delta` seconds of work: fills or drains at `fill_tiles_per_second`, at most
## `fill_tiles_per_step` tiles.
func step(world: World, delta: float) -> void:
	var most: float = _landscape.value("surge", "fill_tiles_per_step")
	_credit = minf(_credit + _landscape.value("surge", "fill_tiles_per_second") * delta, most)
	var tiles := int(_credit)
	_credit -= tiles
	step_tiles(world, tiles)


## Fills or drains up to `count` tiles.
func step_tiles(world: World, count: int) -> void:
	if phase == Phase.FILLING:
		_fill(world, count)
	elif phase == Phase.DRAINING:
		_drain(count)
	if _dirty_chunks.is_empty():
		return
	var changed: Array[Vector2i] = []
	changed.assign(_dirty_chunks.keys())
	_dirty_chunks.clear()
	chunks_changed.emit(changed)


## Does all the work that is left at once, for a skip of time.
func settle(world: World) -> void:
	var most: int = int(_landscape.value("surge", "fill_tiles_per_step"))
	while has_work():
		step_tiles(world, most)


## The flood as it is now, copied (see World `snapshot`): the standing water, its salt and mud and
## the dykes to mend. A flood still filling is saved as standing, as far as it got.
func snapshot() -> Dictionary:
	return {
		"phase": Phase.keys()[Phase.STANDING if phase == Phase.FILLING else phase].to_lower(),
		"level_cm": roundi(level * METRES_TO_CM),
		"drain_minute": drain_minute,
		"wet": _depth_cm.duplicate(),
		"salt": _salt_days.duplicate(),
		"mud": _mud_days.duplicate(),
		"repairs": _repair_minute.duplicate(),
		"met_chunks": _met_chunks.keys(),
	}


## The save data of a `snapshot`: the state, and a list of `[x, y, value]` for each of the tiles'
## values (`flood_wet`, `flood_salt`, `flood_mud`, `flood_repairs`) and a list of `[x, y]` of the
## chunks whose dykes the sea has met (`flood_met_chunks`), so a load does not break them again.
## Safe to call from a thread.
static func dict_of(snapshot_data: Dictionary) -> Dictionary:
	return {
		"flood":
		{
			"phase": snapshot_data["phase"],
			"level_cm": snapshot_data["level_cm"],
			"drain_minute": snapshot_data["drain_minute"],
		},
		"flood_wet": _entries_of(snapshot_data["wet"]),
		"flood_salt": _entries_of(snapshot_data["salt"]),
		"flood_mud": _entries_of(snapshot_data["mud"]),
		"flood_repairs": _entries_of(snapshot_data["repairs"]),
		"flood_met_chunks": snapshot_data["met_chunks"].map(SaveCodec.vector_to_json),
	}


## Takes the state of the world's save data (see `dict_of`).
func load_dict(data: Dictionary) -> void:
	var state: Dictionary = data["flood"]
	level = int(state["level_cm"]) / METRES_TO_CM
	drain_minute = int(state["drain_minute"])
	for entry: Array in data["flood_wet"]:
		_set_depth(SaveCodec.vector_from_json(entry), int(entry[2]))
	for entry: Array in data["flood_salt"]:
		_salt_days[SaveCodec.vector_from_json(entry)] = int(entry[2])
	for entry: Array in data["flood_mud"]:
		_mud_days[SaveCodec.vector_from_json(entry)] = int(entry[2])
	for entry: Array in data["flood_repairs"]:
		_repair_minute[SaveCodec.vector_from_json(entry)] = int(entry[2])
	for chunk_coords: Array in data["flood_met_chunks"]:
		_met_chunks[SaveCodec.vector_from_json(chunk_coords)] = true
	_dirty_chunks.clear()
	phase = Phase[str(state["phase"]).to_upper()] as Phase
	if phase == Phase.DRAINING:
		_start_draining()


static func _entries_of(values: Dictionary) -> Array[Array]:
	var entries: Array[Array] = []
	for tile: Vector2i in values:
		entries.append(SaveCodec.vector_to_json(tile) + [values[tile]])
	return entries


# The sea meets the sea dykes of the loaded chunks it has not met yet.
func _meet_new_chunks(world: World, now: int) -> void:
	for chunk_coords in world.loaded_chunk_coords():
		if _met_chunks.has(chunk_coords):
			continue
		_met_chunks[chunk_coords] = true
		for object in world.chunk_at(chunk_coords).objects():
			if object.type == WorldObjectTypes.DYKE and world.dykes.is_sea_dyke(object.pos):
				_meet_dyke(world, object, now)


func _meet_dyke(world: World, dyke: WorldObject, now: int) -> void:
	var height := world.dykes.height_of(dyke)
	var strength := world.dykes.strength_of(dyke)
	var weakness := 1.0 - strength
	var is_breach := level > height
	if not is_breach and level <= height - weakness * _landscape.value("surge", "damage_margin"):
		return
	# Torn before it changes, so it is drawn torn.
	_repair_minute[dyke.pos] = (
		now + int(_landscape.value("surge", "repair_days")) * GameClock.MINUTES_PER_DAY
	)
	if is_breach:
		world.dykes.change(world, dyke, _landscape.value("surge", "breach_height"), strength)
		_volume_left += _landscape.value("surge", "volume_per_breach")
		_enqueue(world, dyke.pos)
		breached.emit(1)
	else:
		var worn: float = height - weakness * _landscape.value("surge", "damage_height")
		world.dykes.change(world, dyke, worn, strength)


# Queues a tile for filling if it is land lower than the water, once per fill. A chunk that is
# loaded after the fill passed its edge stays dry: the fill does not come back for it.
func _enqueue(world: World, tile: Vector2i) -> void:
	if _seen.has(tile):
		return
	_seen[tile] = true
	var chunk := world.chunk_at(Chunk.world_to_chunk(tile))
	if chunk == null:
		return
	var local := Chunk.local_pos(tile)
	var terrain := chunk.terrain_at(local)
	if not FLOODABLE_TERRAINS.has(terrain) or world.building_at(tile) != null:
		return
	var object := chunk.object_at(local)
	var ground := (
		world.dykes.height_of(object)
		if object != null and object.type == WorldObjectTypes.DYKE
		else world.elevation.at(tile, terrain)
	)
	if ground >= level:
		return
	_queue.append(tile)
	_queue_depth_cm.append(roundi((level - ground) * METRES_TO_CM))


func _fill(world: World, count: int) -> void:
	var filled := 0
	while filled < count and has_work():
		var tile := _queue[_queue_head]
		var depth_cm := _queue_depth_cm[_queue_head]
		_queue_head += 1
		_set_depth(tile, depth_cm)
		_salt_days[tile] = int(_landscape.value("surge", "salt_days"))
		_mud_days.erase(tile)
		_wet_the_ground(world, tile, depth_cm / METRES_TO_CM)
		_volume_left -= depth_cm / METRES_TO_CM
		filled += 1
		for side in World.CONNECTION_SIDES:
			_enqueue(world, tile + side)
	if not has_work():
		_queue.clear()
		_queue_depth_cm.clear()
		_queue_head = 0
		_volume_left = 0.0
		phase = Phase.STANDING


# Tilled soil under the water is soaked, and the items lying on ground under deep water drift
# inland or are lost.
func _wet_the_ground(world: World, tile: Vector2i, depth: float) -> void:
	if world.is_tilled(tile):
		world.set_moisture(tile, 1.0)
	if depth <= _landscape.value("surge", "wash_depth"):
		return
	for pile in world.ground_items.near(Vector2(tile) + Vector2(0.5, 0.5), 0.71):
		if _washed.has(pile):
			continue
		_washed[pile] = true
		var roll := PositionHash.of(tile, world.world_seed + WASH_SALT)
		var is_lost := roll % 100 < _landscape.value("surge", "item_loss_chance") * 100.0
		if is_lost:
			world.ground_items.remove(pile)
		else:
			var tiles := 1 + roll / 100 % int(_landscape.value("surge", "wash_tiles"))
			world.ground_items.move(pile, pile.position + Vector2(tiles, 0))


func _start_draining() -> void:
	phase = Phase.DRAINING
	_queue.clear()
	_queue_depth_cm.clear()
	_queue_head = 0
	_volume_left = 0.0
	# The highest ground, where the water is shallowest, comes up first.
	_drain_order = _depth_cm.keys()
	_drain_order.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return _depth_cm[a] < _depth_cm[b]
	)
	_drain_head = 0
	if _drain_order.is_empty():
		phase = Phase.IDLE


func _drain(count: int) -> void:
	for _i in mini(count, _drain_order.size() - _drain_head):
		_set_depth(_drain_order[_drain_head], 0)
		_mud_days[_drain_order[_drain_head]] = int(_landscape.value("surge", "mud_days"))
		_drain_head += 1
	if _drain_head >= _drain_order.size():
		_drain_order.clear()
		_drain_head = 0
		phase = Phase.IDLE


# Sets the depth of a tile, in centimetres; 0 dries it.
func _set_depth(tile: Vector2i, depth_cm: int) -> void:
	var chunk_coords := Chunk.world_to_chunk(tile)
	if depth_cm > 0:
		_depth_cm[tile] = depth_cm
		if not _wet_by_chunk.has(chunk_coords):
			_wet_by_chunk[chunk_coords] = {}
		_wet_by_chunk[chunk_coords][tile] = true
	else:
		_depth_cm.erase(tile)
		_wet_by_chunk[chunk_coords].erase(tile)
		if _wet_by_chunk[chunk_coords].is_empty():
			_wet_by_chunk.erase(chunk_coords)
	_dirty_chunks[chunk_coords] = true
