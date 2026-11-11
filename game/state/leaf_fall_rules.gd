class_name LeafFallRules
extends RefCounted
## How often trees shed leaves and how the leaves fly, read from data/leaf_fall.cfg (see there
## for what every key means). Pure functions of the foliage, the day and the wind; the random
## rolls and the drawing are FallingLeaves'.

const DEFAULT_PATH := "res://data/leaf_fall.cfg"

const REQUIRED_KEYS := {
	"shedding":
	[
		"tries_per_second",
		"radius_tiles",
		"max_leaves",
		"shed_chance",
		"calm_speed",
		"full_speed",
		"gust_gain",
	],
	"season": ["autumn_share", "late_summer_share", "late_summer_from_day", "needle_share"],
	"fall": ["spread", "fall_speed", "sideways", "sway", "life"],
	"carried": ["chance", "drift_per_wind", "fall_speed", "sway", "tumble", "life"],
}

static var _default: LeafFallRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> LeafFallRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> LeafFallRules:
	var rules := LeafFallRules.new(DataFile.read_sections(path))
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
	if value("shedding", "full_speed") <= value("shedding", "calm_speed"):
		bad.append("[shedding] full_speed must be above calm_speed")
	if value("shedding", "max_leaves") < 0.0:
		bad.append("[shedding] max_leaves must not be below 0")
	for section in ["fall", "carried"]:
		if value(section, "life") <= 0.0:
			bad.append("[%s] life must be above 0" % section)
	return bad


func is_valid() -> bool:
	return problems().is_empty()


## A number of the file.
func value(section: String, key: String) -> float:
	return float(_values[section][key])


## A vector of the file.
func vector(section: String, key: String) -> Vector2:
	return _values[section][key]


## How much of the wind the leaves feel: 0 at the calm speed and below, 1 at the full speed.
func wind_share(wind_speed: float) -> float:
	var calm := value("shedding", "calm_speed")
	return clampf((wind_speed - calm) / (value("shedding", "full_speed") - calm), 0.0, 1.0)


## How much a tree sheds by what it has, as a share of the full chance: the leaves of `kind` (what
## a hit on the tree would throw, see HitEffect) on the day, given the look of its foliage
## without frost.
func foliage_share(kind: HitEffect.Kind, look: SeasonBlend.Look, day: int) -> float:
	match kind:
		HitEffect.Kind.LEAVES_AUTUMN:
			return value("season", "autumn_share")
		HitEffect.Kind.LEAVES_GREEN:
			var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
			var is_late_summer := (
				look == SeasonBlend.Look.SUMMER
				and year_day >= value("season", "late_summer_from_day")
			)
			return value("season", "late_summer_share") if is_late_summer else 0.0
		HitEffect.Kind.NEEDLES:
			return value("season", "needle_share")
	return 0.0


## The chance that a tree picked at random sheds now, by its foliage, the wind (m/s) and how
## much a gust front is over it (0 to 1, in the wind's gusts already).
func shed_chance(
	kind: HitEffect.Kind, look: SeasonBlend.Look, day: int, wind_speed: float, gust: float
) -> float:
	var chance := value("shedding", "shed_chance") * foliage_share(kind, look, day)
	chance *= wind_share(wind_speed) * (1.0 + value("shedding", "gust_gain") * gust)
	return clampf(chance, 0.0, 1.0)


## The chance that a leaf that is shed is carried off by the wind instead of dropping.
func carried_chance(wind_speed: float) -> float:
	return value("carried", "chance") * wind_share(wind_speed)
