class_name WeatherRules
extends RefCounted
## The numbers of the weather, read from data/weather.cfg (see there for what each one means).
## Rules the game can't do without are listed in REQUIRED_KEYS (and SEASON_KEYS for every
## season): `from_file` reports every one that is missing, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/weather.cfg"

## The keys every season has.
const SEASON_KEYS := [
	"temperature_mean",
	"temperature_spread",
	"temperature_swing",
	"humidity_mean",
	"humidity_spread",
	"wind_mean",
	"wind_spread",
	"cloudiness",
]
const REQUIRED_KEYS := {
	"sun":
	[
		"longest_day",
		"day_length_swing_hours",
		"midsummer_noon",
		"midwinter_noon",
		"lowest_noon_height",
	],
	"daily":
	[
		"humidity_swing",
		"fog_before_sunrise_hours",
		"fog_after_sunrise_hours",
		"fog_fade_hours",
		"fog_other_hours",
	],
	"temperature":
	["peak_at", "sunset_level", "cloud_damping", "length_effect_min", "length_effect_max"],
	"thaw": ["start_day", "anchor_day", "anchor_temperature"],
	"frost": ["floor_outside_winter", "winter_floor", "ramp_days", "softness"],
	"clouds": ["humidity_from", "humidity_full", "overcast_sunlight"],
	"precipitation": ["humidity_from", "humidity_full", "rain_from_temperature"],
	"fog": ["humidity_from", "humidity_full", "calm_wind"],
	"wind": ["strong_from", "strong_full"],
	"thunder":
	[
		"temperature_from",
		"temperature_full",
		"humidity_from",
		"humidity_full",
		"wind_from",
		"wind_full",
		"lightning_per_minute",
	],
}

static var _default: WeatherRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> WeatherRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> WeatherRules:
	var rules := WeatherRules.new(DataFile.read_sections(path))
	for missing in rules.missing_keys():
		push_error("%s: no %s" % [path, missing])
	return rules


## The required keys the rules lack, as "[section] key".
func missing_keys() -> Array[String]:
	var required := REQUIRED_KEYS.duplicate()
	for season_name: String in GameClock.SEASON_NAMES:
		required[season_name.to_lower()] = SEASON_KEYS
	var missing: Array[String] = []
	for section: String in required:
		for key: String in required[section]:
			if not _values.get(section, {}).has(key):
				missing.append("[%s] %s" % [section, key])
	return missing


func is_valid() -> bool:
	return missing_keys().is_empty()


## A required value; `from_file` has reported it already if it is missing.
func value(section: String, key: String) -> float:
	return float(_values.get(section, {}).get(key, 0.0))


## A value of a season's baseline (one of SEASON_KEYS).
func season_value(season: GameClock.Season, key: String) -> float:
	return value(GameClock.SEASON_NAMES[season].to_lower(), key)
