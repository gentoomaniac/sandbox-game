# gdlint: disable=max-public-methods
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
## A white stork hunting on wet ground, and one that comes to stand on a roof.
const STORK := &"stork"
const ROOF_STORK := &"roof_stork"
## A flock of greylag geese grazing, and a skein of them flying over in a V.
const GEESE := &"geese"
const FLYING_GEESE := &"flying_geese"
## Small ones: a mouse by the fields and the houses, a frog by the water.
const MOUSE := &"mouse"
const FROG := &"frog"
## Glow-worms flying at dusk: small lights that blink.
const FIREFLY := &"firefly"
## The birds of the coast: oystercatchers and dunlin probing the tidal mud in flocks, herring
## gulls on the mud, the salt marsh and the sea, and common terns fishing over the sea.
const OYSTERCATCHER := &"oystercatcher"
const DUNLIN := &"dunlin"
const GULL := &"gull"
const TERN := &"tern"
## A flock of crows (carrion and hooded crows, rooks) on the meadows and the fields; what they do to
## the crops is in CropRaids.
const CROWS := &"crows"
## The kinds that wade: the flooded mud is theirs to stand on until it is water to them (see
## WildlifeView `can_stand`).
const WADERS: Array[StringName] = [OYSTERCATCHER, DUNLIN]
const KINDS: Array[StringName] = [
	BIRD,
	RABBIT,
	SQUIRREL,
	DEER,
	BEE,
	BUTTERFLY,
	FIREFLY,
	FLOCK,
	STORK,
	ROOF_STORK,
	GEESE,
	FLYING_GEESE,
	CROWS,
	MOUSE,
	FROG,
	OYSTERCATCHER,
	DUNLIN,
	GULL,
	TERN,
]
## The wild animals that walk the ground (task 173): each carries a friendship with the player, 0
## for now (see Animal `friendship`). The birds, bees, butterflies and fireflies have none. The tame
## rabbit of the livestock is another animal with the same name (see LivestockRules `pettable`).
const GROUND_KINDS: Array[StringName] = [RABBIT, SQUIRREL, DEER, MOUSE, FROG]

const GENERAL_KEYS := [
	"twilight_minutes",
	"max_total",
	"spawn_inset_tiles",
	"spawn_margin_tiles",
	"despawn_margin_tiles",
	"min_spawn_distance_tiles",
	"tick_seconds",
	"flooded_tide",
]
const KIND_KEYS := [
	"cap",
	"spawn_chance",
	"terrains",
	"trees_radius",
	"min_trees",
	"water_radius",
	"farm_radius",
	"flowers_per_animal",
	"season_factors",
	"phase_weights",
	"rain_limit",
	"fog_limit",
	"storm_limit",
	"alert_tiles",
	"flee_tiles",
]
## Optional keys, which only some kinds have (the value of a kind without them is the default):
##   edge_radius          it needs a tree, a hedge or open water within this many tiles (0: none)
##   after_sunset_minutes it is only about from the dusk until this long after sunset (0: all day)
##   wind_limit           it hides at this much wind (0 to 1; default: never)
##   min_temperature      it hides below this many degrees Celsius (default: never)
##   building_tiles       it doesn't appear or settle within this many tiles of a building (a whole
##                        number; default 0: it may, as the mice do, who live by the houses)
##   return_gap_minutes   after one of it has left (flown off, sent away by the weather or the
##                        hour), no other appears or settles for this many game minutes (a whole
##                        number; default 0: another may come at once, as the common kinds do)
##   ignores_villagers    true: villagers don't scare it and it appears and settles near them, as
##                        the mice do (default: a villager within `alert_tiles` or `flee_tiles`
##                        scares it as the player does, and it doesn't appear within `flee_tiles`)
##   fade_days            its season factor fades over this many days either side of a season
##                        boundary instead of stepping (default: it steps)
##   migration_days       it flies south in autumn and north in spring, within
##                        `migration_spread_degrees` of due south or north (default: any way);
##                        in the middle `migration_days` of those seasons it comes
##                        `migration_boost` times as often
const NO_LIMIT := 1000.0
## What squirrels and deer call a forest.
const TREE_TYPES: Array[StringName] = [
	WorldObjectTypes.OAK, WorldObjectTypes.SPRUCE, WorldObjectTypes.PINE
]
## What marks the edge of a meadow for the fireflies: the woods and the hedges, and water.
const EDGE_OBJECTS: Array[StringName] = [
	WorldObjectTypes.OAK,
	WorldObjectTypes.SPRUCE,
	WorldObjectTypes.PINE,
	WorldObjectTypes.BEECH,
	WorldObjectTypes.BIRCH,
	WorldObjectTypes.ALDER,
	WorldObjectTypes.WILLOW,
	WorldObjectTypes.KNICK,
]
## The field boundaries mice live in: hedge banks and fieldstone walls.
const FIELD_BANKS: Array[StringName] = [WorldObjectTypes.KNICK, WorldObjectTypes.STONE_WALL]
## World pixels per tile, for the ring around the view: TerrainTileset.TILE_SIZE, which the
## state does not know (a test checks that they agree).
const TILE_SIZE := 32
## Tries to find a point in the ring before settling for one on its left side.
const RING_TRIES := 12

static var _default: WildlifeRules

## Gives the times of dawn and dusk. A game's own (see `for_session`), which follows the day
## length setting.
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


## The rules of the data file for a game whose day is that of `day_sun`. The file's values are
## shared, the sun is this game's own: the default rules stay as they were loaded.
static func for_session(day_sun: Sun) -> WildlifeRules:
	return WildlifeRules.new(default_rules()._values, day_sun)


static func from_file(path: String) -> WildlifeRules:
	var rules := WildlifeRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
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


## Whether there is open water (fresh or the sea's) within `radius` tiles (a square) of a tile. It
## stops at the first.
static func has_water_near(map: GameMap, centre: Vector2i, radius: int) -> bool:
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var tile := map.tile_at(Vector2i(x, y))
			if (
				tile != null
				and (tile.terrain == Tile.Terrain.WATER or tile.terrain == Tile.Terrain.SEA)
			):
				return true
	return false


## Whether a tree, a hedge or open water stands within `radius` tiles (a square) of a tile (see
## EDGE_OBJECTS). It stops at the first.
static func has_edge_near(world: World, centre: Vector2i, radius: int) -> bool:
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var object := world.object_at(Vector2i(x, y))
			if object != null and EDGE_OBJECTS.has(object.type):
				return true
	return has_water_near(world, centre, radius)


## Whether there is farmland within `radius` tiles (a square) of a tile: tilled soil, a crop, a
## Knick or a wall (see FIELD_BANKS), or a building with its hay and its stores. It stops at the
## first.
static func has_farm_near(world: World, centre: Vector2i, radius: int) -> bool:
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var pos := Vector2i(x, y)
			var tile := world.tile_at(pos)
			if tile != null and tile.terrain == Tile.Terrain.SOIL:
				return true
			var object := world.object_at(pos)
			if object != null and (FIELD_BANKS.has(object.type) or object.is_crop()):
				return true
			if world.building_at(pos) != null:
				return true
	return false


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var missing: Array[String] = []
	for key: String in GENERAL_KEYS:
		if not _values.get("general", {}).has(key):
			missing.append("[general] no %s" % key)
	for kind in KINDS:
		for key: String in KIND_KEYS:
			if not _values.get(String(kind), {}).has(key):
				missing.append("[%s] no %s" % [kind, key])
		var section: Dictionary = _values.get(String(kind), {})
		var building_tiles: Variant = section.get("building_tiles", 0)
		if not building_tiles is int or building_tiles < 0:
			missing.append("[%s] building_tiles is not a whole number from 0" % kind)
		var return_gap: Variant = section.get("return_gap_minutes", 0)
		if not return_gap is int or return_gap < 0:
			missing.append("[%s] return_gap_minutes is not a whole number from 0" % kind)
		if not section.get("ignores_villagers", false) is bool:
			missing.append("[%s] ignores_villagers is not true or false" % kind)
	return missing


func is_valid() -> bool:
	return problems().is_empty()


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


## How far from a building a kind appears and settles, in tiles.
func building_tiles(kind: StringName) -> int:
	return _optional(kind, "building_tiles", 0)


## How long, in game minutes, after one of a kind has left no other comes.
func return_gap_minutes(kind: StringName) -> int:
	return _optional(kind, "return_gap_minutes", 0)


## Whether a kind takes no notice of villagers: the mice, who live by the houses.
func ignores_villagers(kind: StringName) -> bool:
	return _optional(kind, "ignores_villagers", false)


## Whether a kind lives only at flowers in bloom.
func needs_flowers(kind: StringName) -> bool:
	return int(_value(kind, "flowers_per_animal")) > 0


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
	if not _is_in_hours(kind, day, minute):
		return 0.0
	var phase_weights: Array = _value(kind, "phase_weights")
	return season_factor(kind, day) * float(phase_weights[phase(day, minute)])


## How much of its best a kind is about on a day, from 0 to 1: its factor of the season. Within
## its `fade_days` of a season boundary the factor draws from the neighbouring season's towards
## the boundary, where it is the mean of the two, instead of stepping there.
func season_factor(kind: StringName, day: int) -> float:
	var season_factors: Array = _value(kind, "season_factors")
	var season: int = GameClock.season_of(day)
	var factor := float(season_factors[season])
	var fade_days := float(_optional(kind, "fade_days", 0))
	# Days from the boundary to the middle of this day.
	var since_start := GameClock.day_of_season_of(day) - 0.5
	var until_end := GameClock.DAYS_PER_SEASON - since_start
	if since_start < fade_days:
		var before := float(season_factors[posmod(season - 1, 4)])
		return lerpf(before, factor, 0.5 + since_start / (2.0 * fade_days))
	if until_end < fade_days:
		var after := float(season_factors[(season + 1) % 4])
		return lerpf(after, factor, 0.5 + until_end / (2.0 * fade_days))
	return factor


## Whether a day is in the migration weeks of a kind that migrates: the middle
## `migration_days` of spring and of autumn.
func is_migrating(kind: StringName, day: int) -> bool:
	var migration_days: int = _optional(kind, "migration_days", 0)
	var season := GameClock.season_of(day)
	if season != GameClock.Season.SPRING and season != GameClock.Season.AUTUMN:
		return false
	var first := (GameClock.DAYS_PER_SEASON - migration_days) / 2 + 1
	return GameClock.day_of_season_of(day) in range(first, first + migration_days)


## The way a migrating kind flies on a day, or ZERO if it flies any way: south in autumn and
## north in spring, up to `migration_spread_degrees` off. The map has north up.
func migration_heading(kind: StringName, day: int, rng: RandomNumberGenerator) -> Vector2:
	var way := Vector2.ZERO
	match GameClock.season_of(day):
		GameClock.Season.SPRING:
			way = Vector2.UP
		GameClock.Season.AUTUMN:
			way = Vector2.DOWN
	if way == Vector2.ZERO or not _values[String(kind)].has("migration_days"):
		return Vector2.ZERO
	var spread := deg_to_rad(float(_value(kind, "migration_spread_degrees")))
	return way.rotated(rng.randf_range(-spread, spread))


## Whether the weather is too much for a kind: rain, a storm, dense fog, and for the kinds that
## have those limits strong wind and cold.
func is_hiding(kind: StringName, weather: WeatherSample) -> bool:
	return (
		weather.rain >= _value(kind, "rain_limit")
		or weather.fog >= _value(kind, "fog_limit")
		or weather.storm >= _value(kind, "storm_limit")
		or weather.wind >= _optional(kind, "wind_limit", NO_LIMIT)
		or weather.temperature < _optional(kind, "min_temperature", -NO_LIMIT)
	)


## How many of a kind there should be near the player now. `flower_tiles` is how many tiles
## of flowers are in bloom in and around the view: a kind that needs flowers has one animal for
## every `flowers_per_animal` of them at most, so none where there are none.
func target_count(
	kind: StringName, day: int, minute: int, weather: WeatherSample, flower_tiles := 0
) -> int:
	var count := roundi(cap(kind) * activity(kind, day, minute, weather))
	if needs_flowers(kind):
		count = mini(count, flower_tiles / int(_value(kind, "flowers_per_animal")))
	return count


## The chance per second that a missing animal of a kind appears.
func spawn_chance(kind: StringName, day: int, minute: int, weather: WeatherSample) -> float:
	var boost := float(_optional(kind, "migration_boost", 1.0)) if is_migrating(kind, day) else 1.0
	return float(_value(kind, "spawn_chance")) * activity(kind, day, minute, weather) * boost


## Whether a kind lives on a terrain with this many trees around, and water and farmland near or
## not (see `trees_radius`, `water_radius` and `farm_radius`).
func is_habitat(
	kind: StringName,
	terrain: Tile.Terrain,
	tree_count: int,
	is_by_water: bool,
	is_by_farm := false,
	is_by_edge := false
) -> bool:
	return (
		_lives_on(kind, terrain)
		and (_water_radius(kind) == 0 or is_by_water)
		and (_farm_radius(kind) == 0 or is_by_farm)
		and (_edge_radius(kind) == 0 or is_by_edge)
		and tree_count >= int(_value(kind, "min_trees"))
	)


## Whether a kind lives on a tile of the world: its terrain first, then the trees, the water and
## the farmland around it, which take longer to look at.
func is_habitat_at(kind: StringName, world: World, tile: Vector2i) -> bool:
	var ground := world.tile_at(tile)
	if ground == null or not _lives_on(kind, ground.terrain):
		return false
	var trees := trees_radius(kind)
	var tree_count := count_trees(world, tile, trees) if trees > 0 else 0
	var water := _water_radius(kind)
	var is_by_water := water > 0 and has_water_near(world, tile, water)
	var farm := _farm_radius(kind)
	var is_by_farm := farm > 0 and has_farm_near(world, tile, farm)
	var edge := _edge_radius(kind)
	var is_by_edge := edge > 0 and has_edge_near(world, tile, edge)
	return is_habitat(kind, ground.terrain, tree_count, is_by_water, is_by_farm, is_by_edge)


func _lives_on(kind: StringName, terrain: Tile.Terrain) -> bool:
	var terrains: Array = _value(kind, "terrains")
	return terrains.is_empty() or terrains.has(_terrain_name(terrain))


func _water_radius(kind: StringName) -> int:
	return int(_value(kind, "water_radius"))


func _farm_radius(kind: StringName) -> int:
	return int(_value(kind, "farm_radius"))


func _edge_radius(kind: StringName) -> int:
	return int(_optional(kind, "edge_radius", 0))


## Whether the time is in the hours a kind keeps to: from the start of the dusk until
## `after_sunset_minutes` after sunset, if it keeps to any.
func _is_in_hours(kind: StringName, day: int, minute: int) -> bool:
	var after_sunset: float = _optional(kind, "after_sunset_minutes", 0.0)
	if after_sunset == 0.0:
		return true
	var dusk := sun.sunset(day) - general("twilight_minutes")
	var minutes_since_dusk := fposmod(minute - dusk, GameClock.MINUTES_PER_DAY)
	return minutes_since_dusk <= general("twilight_minutes") + after_sunset


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


## The points where an animal that lives at flowers may appear: the middles of the tiles of
## `flowers` (flowers in bloom) that lie in the spawn ring (see `is_spawn_point`).
func flower_spawn_points(flowers: Array[Vector2i], view: Rect2, player: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for tile in flowers:
		var point := (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE
		if is_spawn_point(point, view, player):
			points.append(point)
	return points


## Whether an animal at a point is far enough from the view to vanish.
func is_beyond_view(point: Vector2, view: Rect2) -> bool:
	return not view.grow(general("despawn_margin_tiles") * TILE_SIZE).has_point(point)


func _value(kind: StringName, key: String) -> Variant:
	return _values[String(kind)][key]


func _optional(kind: StringName, key: String, default: Variant) -> Variant:
	return _values[String(kind)].get(key, default)


func _terrain_name(terrain: Tile.Terrain) -> String:
	return Tile.Terrain.find_key(terrain).to_lower()
