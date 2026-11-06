class_name Vegetation
extends RefCounted
## How much of each kind of plant there is on a day of the year, read from
## data/vegetation.cfg (see there for the curves). Every spot or plant has a fixed threshold
## in [0, 1) from the seed and its position, and shows while the density of its kind is above
## it, so plants come and go one by one. Pure functions of seed, position and day: nothing is
## saved. `from_file` reports every missing curve, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/vegetation.cfg"

## The kinds with a curve, per section of the data file, each with the salt that keeps its
## thresholds independent of the others'. Decoration kinds are those of
## TerrainTileset.DECORATION_KINDS, object kinds the types with a `seasonal` entry in
## WorldObjectTypes.
const KIND_SALTS := {
	"decorations": {&"tuft": 1, &"flower": 2, &"small_plant": 3, &"leaves": 4},
	"objects": {&"fern_bush": 11, &"berry_bush": 12, &"tall_grass": 13},
}

static var _default: Vegetation

## {kind: Array of Vector2(day of the year, density)}, sorted by day.
var _curves := {}
var _missing: Array[String] = []
## {kind: [day, density]} of the last `density` call for each kind: the view asks for the same
## day thousands of times in a row.
var _last_density := {}


## The curves of the data file, loaded the first time they are asked for.
static func default_vegetation() -> Vegetation:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> Vegetation:
	var sections := DataFile.read_sections(path)
	var vegetation := Vegetation.new()
	for section: String in KIND_SALTS:
		for kind: StringName in KIND_SALTS[section]:
			if sections.get(section, {}).has(str(kind)):
				vegetation._curves[kind] = sections[section][str(kind)]
			else:
				vegetation._missing.append("[%s] %s" % [section, kind])
	for missing in vegetation._missing:
		push_error("%s: no %s" % [path, missing])
	return vegetation


## Vegetation with the curves given directly: {kind: Array of Vector2(day, density)}.
static func from_curves(curves: Dictionary) -> Vegetation:
	var vegetation := Vegetation.new()
	vegetation._curves = curves
	return vegetation


## The curves the data file lacks, as "[section] kind".
func missing_keys() -> Array[String]:
	return _missing


func is_valid() -> bool:
	return _missing.is_empty()


## The density of a kind on a game day, in 0..1.
func density(kind: StringName, day: int) -> float:
	var last: Array = _last_density.get(kind, [])
	if not last.is_empty() and last[0] == day:
		return last[1]
	var density := _density_on(_curves[kind], day)
	_last_density[kind] = [day, density]
	return density


func _density_on(anchors: Array, day: int) -> float:
	var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
	# Before the first anchor the day belongs to the segment that leads from the last anchor
	# of the year before.
	if year_day < anchors[0].x:
		year_day += GameClock.DAYS_PER_YEAR
	for i in anchors.size():
		var from: Vector2 = anchors[i]
		var to: Vector2 = (
			anchors[i + 1]
			if i + 1 < anchors.size()
			else anchors[0] + Vector2(GameClock.DAYS_PER_YEAR, 0)
		)
		if year_day < to.x:
			return lerpf(from.y, to.y, smoothstep(from.x, to.x, year_day))
	assert(false, "Unreachable: the last segment ends after any day")
	return 0.0


## The fixed threshold of a spot or plant, in [0, 1).
func threshold(kind: StringName, world_seed: int, pos: Vector2i) -> float:
	return PositionHash.of(pos, world_seed + _salt(kind)) % 10000 / 10000.0


## Whether the spot or plant shows on this day.
func is_present(kind: StringName, world_seed: int, pos: Vector2i, day: int) -> bool:
	return shows(kind, threshold(kind, world_seed, pos), day)


## Whether something with this threshold shows on this day: the rule behind `is_present`, for
## callers that keep thresholds they asked for before.
func shows(kind: StringName, threshold_of_spot: float, day: int) -> bool:
	return density(kind, day) > threshold_of_spot


func _salt(kind: StringName) -> int:
	for kinds: Dictionary in KIND_SALTS.values():
		if kinds.has(kind):
			return kinds[kind]
	assert(false, "No vegetation kind: %s" % kind)
	return 0
