class_name VillagePlan
extends RefCounted
## The plan of the village Wehlsbüll, read from data/village_plan.cfg (see there for what each key
## means and design/world/wehlsbuell.md for why): its buildings, Warften, lanes, fences, fields and
## things, in the village's own frame of tiles `u` (east of the sea dyke) and `v` (south of the
## middle row), which VillageSite turns into world tiles. `from_file` reports everything that is
## missing or wrong, and `problems` also checks the layout: no overlaps, every door has its free
## tile and a walk to the main lane, no field is shut in, the square is free.

const DEFAULT_PATH := "res://data/village_plan.cfg"

const MAIN_LANE := "sielweg"
## The kinds of wall or fence of a ring, and the object each is.
const RING_OBJECTS := {"wall": WorldObjectTypes.STONE_WALL, "fence": WorldObjectTypes.WATTLE_FENCE}
## The village's objects that stand on the town square, which is free but for them.
const SQUARE_OBJECTS: Array[StringName] = [
	WorldObjectTypes.MARKET_STALL, WorldObjectTypes.NOTICE_BOARD
]
## The sections of the file, by their first part of the name.
const SECTION_KINDS := ["warft", "pond", "building", "lane", "fence", "field", "objects"]

static var _default: VillagePlan

var village_name := ""
## The village's land.
var area := Rect2i()
var inland_from_u := 0
var marsh_end_u := 0
var square := Rect2i()
var meeting_spot := Vector2i.ZERO
var mill_spot := Rect2i()
## The tile of each spot a villager's sheet names as their workplace (`workplace_spot`), by name.
var workplace_spots: Dictionary = {}
## The Sielzug: from the dyke (its first column) to the last tile of the ditch.
var siel := Rect2i()
## {id, centre: Vector2, radii: Vector2, is_on_salt_marsh: bool} of each Warft.
var warften: Array[Dictionary] = []
var ponds: Array[Rect2i] = []
## {id, type: StringName, style: StringName, origin: Vector2i, name: String, residents:
## Array[String]} of each building: the ids of the villagers of data/villagers.cfg who live there.
var buildings: Array[Dictionary] = []
## {id, points: Array[Vector2i]} of each lane.
var lanes: Array[Dictionary] = []
## {id, kind: String (a key of RING_OBJECTS), rect: Rect2i, gaps: Array[Vector2i]} of each ring.
var fences: Array[Dictionary] = []
## {id, rect: Rect2i, gaps: Array[Vector2i]} of each field.
var fields: Array[Dictionary] = []
## {id, type: StringName, tiles: Array[Vector2i]} of each kind of thing that stands on the ground.
var objects: Array[Dictionary] = []

var _parse_problems: Array[String] = []


## The plan of the data file, loaded the first time it is asked for.
static func default_plan() -> VillagePlan:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> VillagePlan:
	var plan := VillagePlan.new()
	plan._read(DataFile.read_sections(path))
	for problem in plan.problems():
		push_error("%s: %s" % [path, problem])
	return plan


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	if not _parse_problems.is_empty():
		return _parse_problems
	var found: Array[String] = []
	found.append_array(_type_problems())
	if found.is_empty():
		found.append_array(_layout_problems())
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The last tile of the main lane, where the worn track from the camp ends.
func main_lane_end() -> Vector2i:
	for lane in lanes:
		if lane["id"] == MAIN_LANE:
			return lane["points"][-1]
	return Vector2i.ZERO


## The tile in the middle of a field, inside its boundary, where a villager goes to tend it.
func field_spot(field: Dictionary) -> Vector2i:
	var rect: Rect2i = field["rect"]
	return rect.position + rect.size / 2


## The tiles a building covers.
func building_tiles(building: Dictionary) -> Array[Vector2i]:
	return Building.footprint_tiles(building["type"], building["origin"])


## The free tile below a building's door.
func door_front(building: Dictionary) -> Vector2i:
	var door_offset: Vector2i = BuildingTypes.TYPES[building["type"]]["door_offset"]
	return building["origin"] + door_offset + Vector2i.DOWN


## The tiles of a Warft: those whose middle is inside its oval.
func warft_tiles(warft: Dictionary) -> Array[Vector2i]:
	var centre: Vector2 = warft["centre"]
	var radii: Vector2 = warft["radii"]
	var tiles: Array[Vector2i] = []
	for v in range(floori(centre.y - radii.y), ceili(centre.y + radii.y) + 1):
		for u in range(floori(centre.x - radii.x), ceili(centre.x + radii.x) + 1):
			var from_middle := (Vector2(u, v) + Vector2(0.5, 0.5) - centre) / radii
			if from_middle.length() < 1.0:
				tiles.append(Vector2i(u, v))
	return tiles


## The tiles of a lane: every tile of the lines between its corners.
func lane_tiles(lane: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var points: Array[Vector2i] = lane["points"]
	for index in points.size() - 1:
		var from := points[index]
		var to := points[index + 1]
		for v in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for u in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
				if not tiles.has(Vector2i(u, v)):
					tiles.append(Vector2i(u, v))
	return tiles


## The tiles of every lane.
func all_lane_tiles() -> Dictionary[Vector2i, bool]:
	var tiles: Dictionary[Vector2i, bool] = {}
	for lane in lanes:
		for tile in lane_tiles(lane):
			tiles[tile] = true
	return tiles


## The tiles of a wall or fence ring or a field's boundary, but for its gaps.
func ring_tiles(ring: Dictionary) -> Array[Vector2i]:
	var rect: Rect2i = ring["rect"]
	var gaps: Array[Vector2i] = ring["gaps"]
	var tiles: Array[Vector2i] = []
	for v in range(rect.position.y, rect.end.y):
		for u in range(rect.position.x, rect.end.x):
			var is_on_ring := (
				u == rect.position.x
				or u == rect.end.x - 1
				or v == rect.position.y
				or v == rect.end.y - 1
			)
			if is_on_ring and not gaps.has(Vector2i(u, v)):
				tiles.append(Vector2i(u, v))
	return tiles


## The tiles of the Sielzug that are not under a lane: a lane over the ditch is a culvert, and the
## tile stays land.
func siel_tiles() -> Array[Vector2i]:
	var lane_tile_set := all_lane_tiles()
	var tiles: Array[Vector2i] = []
	for v in range(siel.position.y, siel.end.y):
		for u in range(siel.position.x, siel.end.x):
			if not lane_tile_set.has(Vector2i(u, v)):
				tiles.append(Vector2i(u, v))
	return tiles


## The tiles of every pond.
func pond_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for pond in ponds:
		tiles.append_array(_tiles_of(pond))
	return tiles


## The tiles an object covers: its footprint from its own tile.
func object_tiles(type: StringName, origin: Vector2i) -> Array[Vector2i]:
	var size: Vector2i = WorldObjectTypes.TYPES[type]["footprint"]
	return _tiles_of(Rect2i(origin, size))


## The tiles of the rect `rect`, a Rect2i of tiles.
func _tiles_of(rect: Rect2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for v in range(rect.position.y, rect.end.y):
		for u in range(rect.position.x, rect.end.x):
			tiles.append(Vector2i(u, v))
	return tiles


# --- Reading ---


func _read(sections: Dictionary) -> void:
	var village: Dictionary = sections.get("village", {})
	if village.is_empty():
		_parse_problems.append("[village] is missing")
	village_name = _value(village, "village", "name", TYPE_STRING, "")
	area = _value(village, "village", "area", TYPE_RECT2I, Rect2i())
	inland_from_u = _value(village, "village", "inland_from_u", TYPE_INT, 0)
	marsh_end_u = _value(village, "village", "marsh_end_u", TYPE_INT, 0)
	square = _value(village, "village", "square", TYPE_RECT2I, Rect2i())
	meeting_spot = _value(village, "village", "meeting_spot", TYPE_VECTOR2I, Vector2i.ZERO)
	mill_spot = _value(village, "village", "mill_spot", TYPE_RECT2I, Rect2i())
	workplace_spots = _value(village, "village", "workplace_spots", TYPE_DICTIONARY, {})
	siel = _value(village, "village", "siel", TYPE_RECT2I, Rect2i())
	for section: String in sections:
		var parts := section.split(".", true, 1)
		if section != "village" and not (parts.size() == 2 and parts[0] in SECTION_KINDS):
			_parse_problems.append("[%s] is not a section of the plan" % section)
			continue
		var id := parts[1] if parts.size() == 2 else ""
		_read_section(parts[0], id, section, sections[section])


func _read_section(kind: String, id: String, section: String, values: Dictionary) -> void:
	match kind:
		"warft":
			var warft := {
				"id": id,
				"centre": _value(values, section, "centre", TYPE_VECTOR2, Vector2.ZERO),
				"radii": _value(values, section, "radii", TYPE_VECTOR2, Vector2.ONE),
				"is_on_salt_marsh": values.get("is_on_salt_marsh", false),
			}
			warften.append(warft)
		"pond":
			ponds.append(_value(values, section, "rect", TYPE_RECT2I, Rect2i()))
		"building":
			var residents: Array[String] = []
			residents.assign(values.get("residents", []))
			var building := {
				"id": id,
				"residents": residents,
				"type": StringName(_value(values, section, "type", TYPE_STRING, "")),
				"style": StringName(values.get("style", "")),
				"origin": _value(values, section, "origin", TYPE_VECTOR2I, Vector2i.ZERO),
				"name": _value(values, section, "name", TYPE_STRING, ""),
			}
			buildings.append(building)
		"lane":
			var points: Array[Vector2i] = []
			points.assign(_value(values, section, "points", TYPE_ARRAY, []))
			lanes.append({"id": id, "points": points})
		"fence":
			fences.append(_ring(id, section, values, {"kind": values.get("kind", "")}))
		"field":
			fields.append(_ring(id, section, values, {}))
		"objects":
			var tiles: Array[Vector2i] = []
			tiles.assign(_value(values, section, "tiles", TYPE_ARRAY, []))
			var group := {
				"id": id,
				"type": StringName(_value(values, section, "type", TYPE_STRING, "")),
				"tiles": tiles,
			}
			objects.append(group)


func _ring(id: String, section: String, values: Dictionary, more: Dictionary) -> Dictionary:
	var gaps: Array[Vector2i] = []
	gaps.assign(_value(values, section, "gaps", TYPE_ARRAY, []))
	var ring := {
		"id": id, "rect": _value(values, section, "rect", TYPE_RECT2I, Rect2i()), "gaps": gaps
	}
	ring.merge(more)
	return ring


## The value of a key, or `fallback` where it is missing or of another type (a problem is noted).
func _value(
	values: Dictionary, section: String, key: String, type: int, fallback: Variant
) -> Variant:
	if not values.has(key):
		_parse_problems.append("[%s] no %s" % [section, key])
		return fallback
	if typeof(values[key]) != type:
		_parse_problems.append("[%s] %s is not a %s" % [section, key, type_string(type)])
		return fallback
	return values[key]


# --- Checking ---


## The types the plan names that do not exist, and the kinds of ring it does not know.
func _type_problems() -> Array[String]:
	var found: Array[String] = []
	for building in buildings:
		var section := "building.%s" % building["id"]
		if not BuildingTypes.TYPES.has(building["type"]):
			found.append("[%s] %s is not a building type" % [section, building["type"]])
		elif not BuildingTypes.STYLES[building["type"]].has(building["style"]):
			found.append("[%s] %s has no style %s" % [section, building["type"], building["style"]])
	for group in objects:
		if not WorldObjectTypes.TYPES.has(group["type"]):
			found.append("[objects.%s] %s is not an object type" % [group["id"], group["type"]])
	for fence in fences:
		if not RING_OBJECTS.has(fence["kind"]):
			found.append("[fence.%s] kind must be one of %s" % [fence["id"], RING_OBJECTS.keys()])
	if not lanes.any(func(lane: Dictionary) -> bool: return lane["id"] == MAIN_LANE):
		found.append("[lane.%s] is missing" % MAIN_LANE)
	return found


func _layout_problems() -> Array[String]:
	var found: Array[String] = []
	var covered: Dictionary[Vector2i, String] = {}
	for building in buildings:
		for tile in building_tiles(building):
			if covered.has(tile):
				found.append("%s overlaps %s at %s" % [building["id"], covered[tile], tile])
			covered[tile] = building["id"]
	var fence_tile_set: Dictionary[Vector2i, bool] = {}
	for fence in fences:
		for tile in ring_tiles(fence):
			fence_tile_set[tile] = true
			if covered.has(tile):
				found.append("fence.%s is in %s at %s" % [fence["id"], covered[tile], tile])
	var lane_tile_set := all_lane_tiles()
	for tile in lane_tile_set:
		if covered.has(tile) or fence_tile_set.has(tile):
			found.append("a lane runs through %s" % tile)
	var blocked := _blocked_tiles(covered, fence_tile_set)
	found.append_array(_ground_problems(covered, fence_tile_set, lane_tile_set))
	found.append_array(_reach_problems(blocked))
	found.append_array(_square_problems(blocked))
	found.append_array(_area_problems())
	return found


## The tiles nobody walks over: buildings, fences, field boundaries, the things that block, and
## water (but for the lanes' culverts, which `siel_tiles` leaves out).
func _blocked_tiles(
	covered: Dictionary[Vector2i, String], fence_tile_set: Dictionary[Vector2i, bool]
) -> Dictionary[Vector2i, bool]:
	var blocked: Dictionary[Vector2i, bool] = {}
	for tile in covered:
		blocked[tile] = true
	blocked.merge(fence_tile_set)
	for field in fields:
		for tile in ring_tiles(field):
			blocked[tile] = true
	for tile in siel_tiles() + pond_tiles():
		blocked[tile] = true
	for group in objects:
		if WorldObjectTypes.TYPES[group["type"]]["blocks_walking"]:
			for origin: Vector2i in group["tiles"]:
				for tile in object_tiles(group["type"], origin):
					blocked[tile] = true
	return blocked


## What is put on the ground (things, field boundaries, water) is not on a building, a fence or a
## lane, nor on one another.
func _ground_problems(
	covered: Dictionary[Vector2i, String],
	fence_tile_set: Dictionary[Vector2i, bool],
	lane_tile_set: Dictionary[Vector2i, bool]
) -> Array[String]:
	var found: Array[String] = []
	for field in fields:
		for tile in ring_tiles(field):
			if covered.has(tile) or fence_tile_set.has(tile) or lane_tile_set.has(tile):
				found.append("field.%s is in the way at %s" % [field["id"], tile])
	for tile in siel_tiles() + pond_tiles():
		if covered.has(tile) or fence_tile_set.has(tile):
			found.append("water is in the way at %s" % tile)
	var taken: Dictionary[Vector2i, String] = {}
	for group in objects:
		for origin: Vector2i in group["tiles"]:
			for tile in object_tiles(group["type"], origin):
				if covered.has(tile) or fence_tile_set.has(tile) or lane_tile_set.has(tile):
					found.append("objects.%s is in the way at %s" % [group["id"], tile])
				elif taken.has(tile):
					found.append("objects.%s overlaps %s at %s" % [group["id"], taken[tile], tile])
				taken[tile] = group["id"]
	return found


## Every door and every field's gap has a walk to the end of the main lane.
func _reach_problems(blocked: Dictionary[Vector2i, bool]) -> Array[String]:
	var found: Array[String] = []
	var reached := _tiles_reached_from(main_lane_end(), blocked)
	for building in buildings:
		var front := door_front(building)
		if blocked.has(front):
			found.append("the door of %s is blocked at %s" % [building["id"], front])
		elif not reached.has(front):
			found.append("nobody can walk from %s to the %s" % [building["id"], MAIN_LANE])
	for field in fields:
		var gaps: Array[Vector2i] = field["gaps"]
		if not gaps.any(func(gap: Vector2i) -> bool: return reached.has(gap)):
			found.append("the field %s is shut in" % field["id"])
	return found


## The square and the mill's spot are free, but for the market stall and the notice board that
## stand on the square.
func _square_problems(blocked: Dictionary[Vector2i, bool]) -> Array[String]:
	var found: Array[String] = []
	var on_the_square: Array[Vector2i] = []
	for group in objects:
		if SQUARE_OBJECTS.has(group["type"]):
			for origin: Vector2i in group["tiles"]:
				on_the_square.append_array(object_tiles(group["type"], origin))
	for tile in _tiles_of(square) + _tiles_of(mill_spot):
		if blocked.has(tile) and not on_the_square.has(tile):
			found.append("the square or the mill's spot is not free at %s" % tile)
	for spot: Vector2i in [meeting_spot] + workplace_spots.values():
		if blocked.has(spot):
			found.append("the spot %s is blocked" % spot)
	return found


## Everything the plan puts down is inside the village's land.
func _area_problems() -> Array[String]:
	var found: Array[String] = []
	var tiles: Array[Vector2i] = []
	for building in buildings:
		tiles.append_array(building_tiles(building))
	for ring in fences + fields:
		tiles.append_array(ring_tiles(ring))
	for warft in warften:
		tiles.append_array(warft_tiles(warft))
	for group in objects:
		tiles.append_array(group["tiles"])
	tiles.append_array(all_lane_tiles().keys())
	tiles.append_array(siel_tiles() + pond_tiles())
	for tile in tiles:
		if not area.has_point(tile):
			found.append("%s is outside the village's land" % tile)
	return found


## The tiles that can be walked to from `start` without crossing `blocked`, inside the land.
func _tiles_reached_from(
	start: Vector2i, blocked: Dictionary[Vector2i, bool]
) -> Dictionary[Vector2i, bool]:
	var reached: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for direction: Vector2i in PathSearch.STEPS:
			var next := tile + direction
			if area.has_point(next) and not blocked.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached
