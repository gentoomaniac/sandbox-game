class_name SaveWorldChecks
extends RefCounted
## The checks of the world and what the other parts of a save refer to in it: the clock, the land
## with its edits, objects, buildings and village, what the player has explored, and the map the
## game is in. It collects the buildings of the world for the references of villagers (see
## SaveContext).

## The highest the sea or the water on the land may stand in a save, in centimetres.
const MAX_LEVEL_CM := 1000

var _ctx: SaveContext
var _objects: SaveObjectChecks


func _init(context: SaveContext) -> void:
	_ctx = context
	_objects = SaveObjectChecks.new(context)


func check_clock(game: Dictionary) -> void:
	var clock: Variant = _ctx.field(game, "clock", SaveContext.Kind.DICT, "")
	if clock != null:
		_check_clock(clock)


func check_world(game: Dictionary) -> void:
	var world: Variant = _ctx.field(game, "world", SaveContext.Kind.DICT, "")
	if world != null:
		_check_world(world)


func _check_clock(clock: Dictionary) -> void:
	_ctx.field(clock, "day", SaveContext.Kind.WHOLE, "clock")
	var minute: Variant = _ctx.field(clock, "minute_of_day", SaveContext.Kind.WHOLE, "clock")
	if minute != null and (minute < 0 or minute >= GameClock.MINUTES_PER_DAY):
		_ctx.report("clock", "minute_of_day %d is not in the day" % minute)


func _check_world(world: Dictionary) -> void:
	_ctx.field(world, "seed", SaveContext.Kind.WHOLE, "world")
	_ctx.check_entries(world, "terrain_edits", SaveContext.Kind.TEXT)
	_ctx.check_entries(world, "soil_moisture", SaveContext.Kind.NUMBER)
	_ctx.field(world, "fallow_nights", SaveContext.Kind.WHOLE, "world")
	_ctx.check_entries(world, "fallow_soil", SaveContext.Kind.WHOLE)
	_ctx.check_entries(world, "spent_clay_spots", SaveContext.Kind.WHOLE)
	_ctx.check_entries(world, "wear", SaveContext.Kind.WHOLE)
	_ctx.check_entries(world, "wear_today", SaveContext.Kind.NUMBER)
	var terrain_edits: Variant = world.get("terrain_edits")
	if terrain_edits is Array:
		for index in terrain_edits.size():
			var edit: Variant = terrain_edits[index]
			if edit is Array and edit.size() == 3 and not Tile.Terrain.has(str(edit[2])):
				_ctx.report("world terrain_edits %d" % index, "unknown terrain %s" % edit[2])
	_check_surge(world)
	_objects.check_ground_items(world, "world")
	var object_edits: Variant = _ctx.field(world, "object_edits", SaveContext.Kind.LIST, "world")
	if object_edits != null:
		for index in object_edits.size():
			_check_object_edit(object_edits[index], "world object_edits %d" % index)
	var buildings: Variant = _ctx.field(world, "buildings", SaveContext.Kind.LIST, "world")
	if buildings != null:
		for index in buildings.size():
			_check_building(buildings[index], "world buildings %d" % index)
	if not world.has("village"):
		_ctx.report("world", "no village")
	elif world["village"] != null:
		_check_village(world["village"])


## The surge and the water it left: whole numbers in range, and a known phase.
func _check_surge(world: Dictionary) -> void:
	var surge: Variant = _ctx.field(world, "surge", SaveContext.Kind.DICT, "world")
	if surge != null:
		for key in ["level_cm", "peak_minute", "hold_minutes", "last_rolled_tide"]:
			_ctx.field(surge, key, SaveContext.Kind.WHOLE, "world surge")
		_ctx.check_between(surge.get("level_cm"), 0, MAX_LEVEL_CM, "world surge", "level_cm")
	var flood: Variant = _ctx.field(world, "flood", SaveContext.Kind.DICT, "world")
	if flood != null:
		for key in ["level_cm", "drain_minute"]:
			_ctx.field(flood, key, SaveContext.Kind.WHOLE, "world flood")
		_ctx.check_between(flood.get("level_cm"), 0, MAX_LEVEL_CM, "world flood", "level_cm")
		var phase: Variant = _ctx.field(flood, "phase", SaveContext.Kind.TEXT, "world flood")
		if phase != null and not str(phase).to_upper() in FloodState.Phase:
			_ctx.report("world flood", "unknown phase %s" % phase)
	for key in ["flood_wet", "flood_salt", "flood_mud", "flood_repairs"]:
		_ctx.check_entries(world, key, SaveContext.Kind.WHOLE)
	var met: Variant = _ctx.field(world, "flood_met_chunks", SaveContext.Kind.LIST, "world")
	if met != null and not met.all(_ctx.is_vector):
		_ctx.report("world flood_met_chunks", "should be a list of [x, y]")
	var wet: Variant = world.get("flood_wet")
	if wet is Array:
		for index in wet.size():
			if (
				wet[index] is Array
				and wet[index].size() == 3
				and _ctx.is_kind(wet[index][2], SaveContext.Kind.WHOLE)
			):
				_ctx.check_between(
					wet[index][2], 1, MAX_LEVEL_CM, "world flood_wet %d" % index, "depth"
				)


## The land the player has seen: the bits of each chunk, base64 of a byte array of a whole size.
func check_explored(game: Dictionary) -> void:
	var entries: Variant = _ctx.field(game, "explored", SaveContext.Kind.LIST, "")
	if entries == null:
		return
	for index in entries.size():
		var path := "explored %d" % index
		var entry: Variant = entries[index]
		if not entry is Dictionary:
			_ctx.report(path, "should be a dictionary")
			continue
		var coords: Variant = _ctx.field(entry, "chunk", SaveContext.Kind.VECTOR, path)
		if coords != null and not World.is_chunk_in_bounds(SaveCodec.vector_from_json(coords)):
			_ctx.report(path, "chunk %s is outside the world" % [coords])
		var seen: Variant = _ctx.field(entry, "seen", SaveContext.Kind.TEXT, path)
		if seen != null and Marshalls.base64_to_raw(seen).size() != Exploration.BYTES_PER_CHUNK:
			_ctx.report(path, "seen is not %d bytes" % Exploration.BYTES_PER_CHUNK)


## The record of the village: its land with the square, the meeting spot and the mill's spot
## inside it, and the buildings it names, which stand.
func _check_village(village: Variant) -> void:
	var path := "world village"
	if not village is Dictionary:
		_ctx.report(path, "should be null or a dictionary")
		return
	_ctx.field(village, "name", SaveContext.Kind.TEXT, path)
	_ctx.field(village, "is_populated", SaveContext.Kind.BOOL, path)
	var area: Variant = _ctx.field(village, "area", SaveContext.Kind.RECT, path)
	var square: Variant = _ctx.field(village, "square", SaveContext.Kind.RECT, path)
	var mill_spot: Variant = _ctx.field(village, "mill_spot", SaveContext.Kind.RECT, path)
	var meeting_spot: Variant = _ctx.field(village, "meeting_spot", SaveContext.Kind.VECTOR, path)
	if area != null:
		var land := SaveCodec.rect_from_json(area)
		if land.size.x <= 0 or land.size.y <= 0:
			_ctx.report(path, "the area is empty")
		if square != null and not land.encloses(SaveCodec.rect_from_json(square)):
			_ctx.report(path, "the square is not inside the area")
		if mill_spot != null and not land.encloses(SaveCodec.rect_from_json(mill_spot)):
			_ctx.report(path, "the mill's spot is not inside the area")
		if meeting_spot != null and not land.has_point(SaveCodec.vector_from_json(meeting_spot)):
			_ctx.report(path, "the meeting spot is not inside the area")
	var field_spots: Variant = _ctx.field(village, "field_spots", SaveContext.Kind.LIST, path)
	if field_spots != null and not field_spots.all(_ctx.is_vector):
		_ctx.report(path, "field_spots should be a list of [x, y]")
	var origins: Variant = _ctx.field(village, "building_origins", SaveContext.Kind.LIST, path)
	if origins != null:
		for index in origins.size():
			var origin: Variant = origins[index]
			if not _ctx.is_kind(origin, SaveContext.Kind.VECTOR):
				_ctx.report(path, "building_origins %d should be [x, y]" % index)
			elif not _ctx.has_building_at(SaveCodec.vector_from_json(origin)):
				_ctx.report(path, "building_origins %d is no building of the world" % index)


func _check_object_edit(edit: Variant, path: String) -> void:
	if not edit is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	_ctx.field(edit, "pos", SaveContext.Kind.VECTOR, path)
	if not edit.has("object"):
		_ctx.report(path, "no object")
	# A removed generated object is saved as null.
	elif edit["object"] != null:
		# Dropped, the tile is left empty: even a generated object that stood there is gone.
		_objects.check_object(
			edit["object"], path + " object", func() -> void: edit["object"] = null
		)


func _check_building(building: Variant, path: String) -> void:
	if not building is Dictionary:
		_ctx.report(path, "should be a dictionary")
		return
	var type: Variant = _ctx.field(building, "type", SaveContext.Kind.TEXT, path)
	var origin: Variant = _ctx.field(building, "origin", SaveContext.Kind.VECTOR, path)
	_ctx.field(building, "style", SaveContext.Kind.TEXT, path)
	if type != null and not BuildingTypes.TYPES.has(StringName(type)):
		_ctx.report(path, "unknown building %s" % type)
	if not building.has("interior"):
		_ctx.report(path, "no interior")
		return
	if origin != null:
		_ctx.add_building(SaveCodec.vector_from_json(origin), building["interior"] != null)
	if building["interior"] != null:
		_check_interior(building["interior"], path + " interior")


func _check_interior(interior: Variant, path: String) -> void:
	if not interior is Dictionary:
		_ctx.report(path, "should be a dictionary or null")
		return
	_ctx.field(interior, "size", SaveContext.Kind.VECTOR, path)
	_ctx.field(interior, "exit_tile", SaveContext.Kind.VECTOR, path)
	var tiles: Variant = _ctx.field(interior, "tiles", SaveContext.Kind.LIST, path)
	if tiles != null:
		for index in tiles.size():
			var tile: Variant = tiles[index]
			var is_tile: bool = (
				tile is Array
				and tile.size() == 3
				and _ctx.is_kind(tile.slice(0, 2), SaveContext.Kind.VECTOR)
				and Tile.Terrain.has(str(tile[2]))
			)
			if not is_tile:
				_ctx.report("%s tiles %d" % [path, index], "should be [x, y, terrain]")
	_objects.check_ground_items(interior, path)
	var objects: Variant = _ctx.field(interior, "objects", SaveContext.Kind.LIST, path)
	if objects != null:
		for index in objects.size():
			_objects.check_object(
				objects[index],
				"%s objects %d" % [path, index],
				_ctx.removing(objects, objects[index])
			)


## The map of `game[key]`: the world, or the inside of a building of the world that has one.
func check_map_reference(game: Dictionary, key: String) -> void:
	var map_reference: Variant = _ctx.field(game, key, SaveContext.Kind.DICT, "")
	if map_reference == null:
		return
	var kind: Variant = _ctx.field(map_reference, "kind", SaveContext.Kind.TEXT, key)
	if kind == "interior":
		var building: Variant = _ctx.field(map_reference, "building", SaveContext.Kind.VECTOR, key)
		if building != null and not _ctx.has_interior_at(SaveCodec.vector_from_json(building)):
			_ctx.report(
				key, "no building with an inside at %s" % SaveCodec.vector_from_json(building)
			)
	elif kind != null and kind != "world":
		_ctx.report(key, "unknown kind of map %s" % kind)
