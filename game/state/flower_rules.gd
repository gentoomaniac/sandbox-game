class_name FlowerRules
extends RefCounted
## Where the meadow flowers grow, read from data/flowers.cfg (see there for what each number
## means): in drifts by a slow noise, each habitat with its chance and its communities of
## species that bloom one after another. Pure functions of the noise values and a roll: the
## caller (DecorationView) samples the noises. `from_file` reports every key that is missing or
## wrong, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/flowers.cfg"

const DRIFT_KEYS := [
	"frequency", "mix_frequency", "start", "core", "stray_share", "thick_from", "small_margin"
]
const HABITATS := [
	"grass", "lush_grass", "dry_grass", "floodplain", "wetland", "salt_marsh", "woods"
]
const HABITAT_KEYS := ["chance", "communities"]

static var _default: FlowerRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> FlowerRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> FlowerRules:
	var rules := FlowerRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key: String in DRIFT_KEYS:
		if not _values.get("drifts", {}).has(key):
			found.append("[drifts] no %s" % key)
	for habitat: String in HABITATS:
		for key: String in HABITAT_KEYS:
			if not _values.get(habitat, {}).has(key):
				found.append("[%s] no %s" % [habitat, key])
	if not found.is_empty():
		return found
	if value("drifts", "core") <= value("drifts", "start"):
		found.append("[drifts] core must be above start")
	var species: Dictionary = Vegetation.KIND_SALTS["flowers"]
	for habitat: String in HABITATS:
		var communities: Array = _values[habitat]["communities"]
		if communities.is_empty():
			found.append("[%s] no community" % habitat)
		for community: Array in communities:
			if community.is_empty():
				found.append("[%s] an empty community" % habitat)
			for name: String in community:
				if not species.has(StringName(name)):
					found.append("[%s] no flower species %s" % [habitat, name])
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A number of the file, e.g. `value("drifts", "frequency")`.
func value(section: String, key: String) -> float:
	return float(_values[section][key])


## How deep in a drift a tile with this drift noise is: 0 at its edge (or outside it), 1 in
## its thick.
func drift_depth(drift: float) -> float:
	var start := value("drifts", "start")
	return clampf((drift - start) / (value("drifts", "core") - start), 0.0, 1.0)


## The species that grow on a tile of a habitat (the habitat "" grows none), in the order
## they take over through the year; an empty list on most tiles. `drift` and `mix` are the
## two noises at the tile, `roll` a fixed random number of the tile in [0, 1).
func flowers_at(habitat: String, drift: float, mix: float, roll: float) -> Array[StringName]:
	var flowers: Array[StringName] = []
	if habitat == "":
		return flowers
	var share := maxf(drift_depth(drift), value("drifts", "stray_share"))
	var chance := value(habitat, "chance") * share
	if roll >= chance:
		return flowers
	var communities: Array = _values[habitat]["communities"]
	# The mix noise lies mostly within -0.6..0.6: bands of it take turns, so every community
	# gets its share of the land.
	var band := floori((mix + 1.0) * communities.size())
	var community: Array = communities[posmod(band, communities.size())]
	for name: String in community:
		flowers.append(StringName(name))
	return flowers
