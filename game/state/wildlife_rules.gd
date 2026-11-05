class_name WildlifeRules
extends RefCounted
## Where and when ambient wildlife appears, and when it reacts to the player: the plain logic
## behind the animals (the view nodes are in game/scenes/wildlife). The numbers are in
## data/wildlife.cfg (see there for what each one means). `from_file` reports every missing
## key, and `is_valid` says whether any was.

enum Phase { DAY, TWILIGHT, NIGHT }
enum Reaction { NONE, ALERT, FLEE }

const DEFAULT_PATH := "res://data/wildlife.cfg"

const BIRD := &"bird"
const RABBIT := &"rabbit"
const SQUIRREL := &"squirrel"
const DEER := &"deer"
const BEE := &"bee"
const BUTTERFLY := &"butterfly"
## Not an animal but a group of birds high in the sky.
const FLOCK := &"flock"
const KINDS: Array[StringName] = [BIRD, RABBIT, SQUIRREL, DEER, BEE, BUTTERFLY, FLOCK]

const GENERAL_KEYS := [
	"twilight_minutes",
	"max_total",
	"spawn_inset_tiles",
	"spawn_margin_tiles",
	"despawn_margin_tiles",
	"min_spawn_distance_tiles",
	"tick_seconds",
]
const KIND_KEYS := [
	"cap",
	"spawn_chance",
	"terrains",
	"trees_radius",
	"min_trees",
	"needs_flowers",
	"season_factors",
	"phase_weights",
	"rain_limit",
	"fog_limit",
	"storm_limit",
	"alert_tiles",
	"flee_tiles",
]
## What squirrels and deer call a forest.
const TREE_TYPES: Array[StringName] = [
	WorldObjectTypes.OAK, WorldObjectTypes.SPRUCE, WorldObjectTypes.PINE
]
## World pixels per tile, for the ring around the view.
const TILE_SIZE := 16
## Tries to find a point in the ring before settling for one on its left side.
const RING_TRIES := 12

static var _default: WildlifeRules

## Gives the times of dawn and dusk. The game sets its own, which follows the day length
## setting.
var sun: Sun
## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary, day_sun := Sun.new()) -> void:
	_values = values
	sun = day_sun


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> WildlifeRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> WildlifeRules:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var values := {}
	for section in file.get_sections():
		values[section] = {}
		for key in file.get_section_keys(section):
			values[section][key] = file.get_value(section, key)
	var rules := WildlifeRules.new(values)
	for missing in rules.missing_keys():
		push_error("%s: no %s" % [path, missing])
	return rules


## How many of the tree types stand within `radius` tiles (a square) of a tile.
static func count_trees(map: GameMap, centre: Vector2i, radius: int) -> int:
	var count := 0
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var object := map.object_at(Vector2i(x, y))
			if object != null and TREE_TYPES.has(object.type):
				count += 1
	return count


## The required keys the rules lack, as "[section] key".
func missing_keys() -> Array[String]:
	var missing: Array[String] = []
	for key: String in GENERAL_KEYS:
		if not _values.get("general", {}).has(key):
			missing.append("[general] %s" % key)
	for kind in KINDS:
		for key: String in KIND_KEYS:
			if not _values.get(String(kind), {}).has(key):
				missing.append("[%s] %s" % [kind, key])
	return missing


func is_valid() -> bool:
	return missing_keys().is_empty()


func general(key: String) -> float:
	return float(_values["general"][key])


func cap(kind: StringName) -> int:
	return int(_value(kind, "cap"))


func trees_radius(kind: StringName) -> int:
	return int(_value(kind, "trees_radius"))


func alert_tiles(kind: StringName) -> float:
	return _value(kind, "alert_tiles")


func flee_tiles(kind: StringName) -> float:
	return _value(kind, "flee_tiles")


func needs_flowers(kind: StringName) -> bool:
	return _value(kind, "needs_flowers")


## The part of the day: dawn and dusk reach `twilight_minutes` either side of sunrise and
## sunset.
func phase(day: int, minute: int) -> Phase:
	var twilight := general("twilight_minutes")
	var sunrise := sun.sunrise(day)
	var sunset := sun.sunset(day)
	if absf(minute - sunrise) <= twilight or absf(minute - sunset) <= twilight:
		return Phase.TWILIGHT
	return Phase.DAY if minute > sunrise and minute < sunset else Phase.NIGHT


## How active a kind is, from 0 (none about) to 1: the season times the part of the day, and
## 0 while the weather has it in hiding.
func activity(kind: StringName, day: int, minute: int, weather: WeatherSample) -> float:
	if is_hiding(kind, weather):
		return 0.0
	var season := (day - 1) % GameClock.DAYS_PER_YEAR / GameClock.DAYS_PER_SEASON
	var season_factors: Array = _value(kind, "season_factors")
	var phase_weights: Array = _value(kind, "phase_weights")
	return float(season_factors[season]) * float(phase_weights[phase(day, minute)])


## Whether the weather is too much for a kind: rain, a storm or dense fog.
func is_hiding(kind: StringName, weather: WeatherSample) -> bool:
	return (
		weather.rain >= _value(kind, "rain_limit")
		or weather.fog >= _value(kind, "fog_limit")
		or weather.storm >= _value(kind, "storm_limit")
	)


## How many of a kind there should be near the player now.
func target_count(kind: StringName, day: int, minute: int, weather: WeatherSample) -> int:
	return roundi(cap(kind) * activity(kind, day, minute, weather))


## The chance per second that a missing animal of a kind appears.
func spawn_chance(kind: StringName, day: int, minute: int, weather: WeatherSample) -> float:
	return float(_value(kind, "spawn_chance")) * activity(kind, day, minute, weather)


## Whether a kind lives on a terrain with this many trees around (see `trees_radius`).
func is_habitat(kind: StringName, terrain: Tile.Terrain, tree_count: int) -> bool:
	var terrains: Array = _value(kind, "terrains")
	var is_terrain_right := terrains.is_empty() or terrains.has(_terrain_name(terrain))
	return is_terrain_right and tree_count >= int(_value(kind, "min_trees"))


## How a kind reacts to the player at a distance in tiles: it runs off when the player is as near as
## `flee_tiles`, looks up when as near as `alert_tiles`, and else takes no notice.
func reaction(kind: StringName, distance_tiles: float) -> Reaction:
	var flee_tiles: float = _value(kind, "flee_tiles")
	var alert_tiles: float = _value(kind, "alert_tiles")
	if flee_tiles > 0.0 and distance_tiles <= flee_tiles:
		return Reaction.FLEE
	if alert_tiles > 0.0 and distance_tiles <= alert_tiles:
		return Reaction.ALERT
	return Reaction.NONE


## Whether animals may appear at a point (in world pixels): in the ring around the view, and
## not on the player. The ring reaches from `spawn_inset_tiles` inside the view's edge to
## `spawn_margin_tiles` outside it.
func is_spawn_point(point: Vector2, view: Rect2, player: Vector2) -> bool:
	var inner := view.grow(-general("spawn_inset_tiles") * TILE_SIZE)
	var outer := view.grow(general("spawn_margin_tiles") * TILE_SIZE)
	var min_distance := general("min_spawn_distance_tiles") * TILE_SIZE
	return (
		outer.has_point(point)
		and not inner.has_point(point)
		and point.distance_to(player) >= min_distance
	)


## A random point of the spawn ring around the view (see `is_spawn_point`; the player is
## not considered).
func random_ring_point(view: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var outer := view.grow(general("spawn_margin_tiles") * TILE_SIZE)
	var inner := view.grow(-general("spawn_inset_tiles") * TILE_SIZE)
	for _try in RING_TRIES:
		var point := Vector2(
			rng.randf_range(outer.position.x, outer.end.x),
			rng.randf_range(outer.position.y, outer.end.y)
		)
		if not inner.has_point(point):
			return point
	return Vector2(outer.position.x, rng.randf_range(outer.position.y, outer.end.y))


## Whether an animal at a point is far enough from the view to vanish.
func is_beyond_view(point: Vector2, view: Rect2) -> bool:
	return not view.grow(general("despawn_margin_tiles") * TILE_SIZE).has_point(point)


func _value(kind: StringName, key: String) -> Variant:
	return _values[String(kind)][key]


func _terrain_name(terrain: Tile.Terrain) -> String:
	return Tile.Terrain.find_key(terrain).to_lower()
