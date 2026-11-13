class_name AmbienceRules
extends RefCounted
## When the weather and the animals make their sounds, read from data/ambience.cfg (see there
## for what every key means): the levels of the rain and wind loops and of the frogs' chorus,
## and the chances of birdsong, frogs and the sounds of animals. Pure
## functions of the weather, the season and the part of the day; the random rolls and the
## playing are AmbienceSounds'.

const DEFAULT_PATH := "res://data/ambience.cfg"

const REQUIRED_KEYS := {
	"loops":
	[
		"rain_max_level",
		"wind_calm_speed",
		"wind_full_speed",
		"wind_max_level",
		"min_level",
		"fade_seconds",
		"gust_front_from",
		"gust_soft_level",
		"gust_swell",
		"gust_seconds",
		"gust_fade_seconds",
	],
	"indoors":
	[
		"outside_db",
		"fire_level",
		"fire_small_room_tiles",
		"fire_small_reach_tiles",
		"fire_big_reach_tiles",
		"fire_fade_seconds",
	],
	"paused": ["fade_seconds"],
	"birds":
	["chirp_chance", "radius_tiles", "tries", "season_factors", "phase_weights", "rain_limit"],
	"frogs":
	[
		"croak_chance",
		"radius_tiles",
		"tries",
		"season_factors",
		"phase_weights",
		"cold_temperature",
		"warm_temperature",
	],
	"frog_chorus": ["level", "full_frogs", "fade_seconds", "season_factors", "phase_weights"],
	"deer": ["idle_chance"],
	"rabbit": ["idle_chance"],
	"squirrel": ["idle_chance"],
	"cow": ["idle_chance"],
	"sheep": ["idle_chance"],
	"chicken": ["idle_chance"],
	"dog": ["idle_chance"],
	"cat": ["idle_chance"],
	"horse": ["idle_chance"],
	"geese": ["idle_chance"],
	"flying_geese": ["idle_chance"],
	"crows": ["idle_chance"],
	"bees": ["max_loops", "level", "hear_tiles"],
}
const SEASON_COUNT := 4
## Day, dawn and dusk, night.
const PHASE_COUNT := 3
## Frogs sit at the water's edge too.
const FROG_TERRAINS: Array[Tile.Terrain] = [Tile.Terrain.WATER, Tile.Terrain.WETLAND]

static var _default: AmbienceRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> AmbienceRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> AmbienceRules:
	var rules := AmbienceRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what". The values are only checked once every key is
## there.
func problems() -> Array[String]:
	var bad: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				bad.append("[%s] no %s" % [section, key])
	if not bad.is_empty():
		return bad
	if value("loops", "wind_full_speed") <= value("loops", "wind_calm_speed"):
		bad.append("[loops] wind_full_speed must be above wind_calm_speed")
	if value("loops", "wind_max_level") <= 0.0:
		bad.append("[loops] wind_max_level must be above 0")
	if value("indoors", "outside_db") > 0.0:
		bad.append("[indoors] outside_db must not be above 0")
	for key in ["fire_small_reach_tiles", "fire_big_reach_tiles"]:
		if value("indoors", key) <= 0.0:
			bad.append("[indoors] %s must be above 0" % key)
	if value("paused", "fade_seconds") <= 0.0:
		bad.append("[paused] fade_seconds must be above 0")
	if value("frog_chorus", "full_frogs") <= 0.0:
		bad.append("[frog_chorus] full_frogs must be above 0")
	if value("bees", "hear_tiles") <= 0.0:
		bad.append("[bees] hear_tiles must be above 0")
	if value("frogs", "warm_temperature") <= value("frogs", "cold_temperature"):
		bad.append("[frogs] warm_temperature must be above cold_temperature")
	for section in ["birds", "frogs", "frog_chorus"]:
		if _values[section]["season_factors"].size() != SEASON_COUNT:
			bad.append("[%s] season_factors must have %d entries" % [section, SEASON_COUNT])
		if _values[section]["phase_weights"].size() != PHASE_COUNT:
			bad.append("[%s] phase_weights must have %d entries" % [section, PHASE_COUNT])
	return bad


func is_valid() -> bool:
	return problems().is_empty()


func value(section: String, key: String) -> float:
	return float(_values[section][key])


## How far a fire's crackle reaches, in tiles, in a room of this size (its whole map): a small
## room hears it all through, a big one only near the fire.
func fire_reach(room_size: Vector2i) -> float:
	var is_small := room_size.x * room_size.y <= value("indoors", "fire_small_room_tiles")
	return value("indoors", "fire_small_reach_tiles" if is_small else "fire_big_reach_tiles")


## How loud the rain loop is for this weather.
func rain_level(weather: WeatherSample) -> float:
	return clampf(weather.rain, 0.0, 1.0) * value("loops", "rain_max_level")


## How loud the wind loop is for this weather, before any gust.
func wind_level(weather: WeatherSample) -> float:
	var calm := value("loops", "wind_calm_speed")
	var share := (weather.wind_speed - calm) / (value("loops", "wind_full_speed") - calm)
	return clampf(share, 0.0, 1.0) * value("loops", "wind_max_level")


## Whether a gust front, `front` (0 to 1, AmbientMotion.gust_front), is over the player closely
## enough to be heard as a gust.
func is_gust(front: float) -> bool:
	return front >= value("loops", "gust_front_from")


## How loud a gust is (a share of the sound's volume) in gusts of this `strength` (0 to 1,
## AmbientMotion.gust_for): a soft rustle where gusts only begin to show, full in a storm.
func gust_level(strength: float) -> float:
	var soft := value("loops", "gust_soft_level")
	return soft + (1.0 - soft) * strength


## The chance per second that a bird chirps: by season and part of the day, and less in rain.
func bird_chance(
	season: GameClock.Season, phase: WildlifeRules.Phase, weather: WeatherSample
) -> float:
	var dryness := 1.0 - clampf(weather.rain / value("birds", "rain_limit"), 0.0, 1.0)
	return value("birds", "chirp_chance") * _activity("birds", season, phase) * dryness


## The chance per second that a frog croaks at water this many tiles from the player: by season,
## part of the day and temperature, and the nearer the more. 0 beyond the radius.
func frog_chance(
	season: GameClock.Season, phase: WildlifeRules.Phase, temperature: float, distance_tiles: float
) -> float:
	var nearness := clampf(1.0 - distance_tiles / value("frogs", "radius_tiles"), 0.0, 1.0)
	return (
		value("frogs", "croak_chance")
		* _activity("frogs", season, phase)
		* _frog_warmth(temperature)
		* nearness
	)


## How loud the frogs' chorus loop is with this many frogs about: by season and part of the day
## (spring and summer evenings), as warm as the croaks need it, and fuller with more frogs, up to
## `full_frogs`.
func chorus_level(
	season: GameClock.Season, phase: WildlifeRules.Phase, temperature: float, frogs: int
) -> float:
	var fullness := minf(frogs / value("frog_chorus", "full_frogs"), 1.0)
	return (
		value("frog_chorus", "level")
		* _activity("frog_chorus", season, phase)
		* _frog_warmth(temperature)
		* fullness
	)


## From 0 below the frogs' `cold_temperature` to 1 from their `warm_temperature` on.
func _frog_warmth(temperature: float) -> float:
	var cold := value("frogs", "cold_temperature")
	return clampf((temperature - cold) / (value("frogs", "warm_temperature") - cold), 0.0, 1.0)


## The chance per second that an animal of a kind (`deer`, `rabbit`, `squirrel`, `geese`,
## `flying_geese`, and the farm animals `cow`, `sheep`, `chicken`, `dog`, `cat`, `horse`) makes a
## sound of its own accord.
func idle_chance(kind: StringName) -> float:
	return value(String(kind), "idle_chance")


func _activity(section: String, season: GameClock.Season, phase: WildlifeRules.Phase) -> float:
	var season_factors: Array = _values[section]["season_factors"]
	var phase_weights: Array = _values[section]["phase_weights"]
	return float(season_factors[season]) * float(phase_weights[phase])
