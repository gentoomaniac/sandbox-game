class_name YardRules
extends RefCounted
## The needs of the farm animals and how the player fills what meets them (task 122): the `[needs]`
## and `[yard]` sections of data/livestock.cfg and the needs of each species in its own section (see
## there for what each number means). `from_file` reports every missing key, and `is_valid` says
## whether there was one.

const DEFAULT_PATH := "res://data/livestock.cfg"

const NEEDS_KEYS := [
	"seek_at",
	"search_tiles",
	"drink_seconds",
	"eat_seconds",
	"retry_seconds",
	"graze_relief_per_second",
	"trip_seconds",
	"searches_per_update",
]
const YARD_KEYS := ["pour_units", "feed_items"]
const COOP_KEYS := ["building", "roosts", "call_tiles", "egg_chance", "nest_eggs"]
const SPECIES_KEYS := [
	"hunger_hours",
	"thirst_hours",
	"grazes_for_food",
	"eats_feed",
	"eat_units",
	"drink_units",
]

static var _default: YardRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> YardRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> YardRules:
	var rules := YardRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key: String in NEEDS_KEYS:
		if not _values.get("needs", {}).has(key):
			found.append("[needs] no %s" % key)
	for key: String in YARD_KEYS:
		if not _values.get("yard", {}).has(key):
			found.append("[yard] no %s" % key)
	for key: String in COOP_KEYS:
		if not _values.get("coop", {}).has(key):
			found.append("[coop] no %s" % key)
	for species in LivestockRules.SPECIES:
		for key: String in SPECIES_KEYS:
			if not _values.get(String(species), {}).has(key):
				found.append("[%s] no %s" % [species, key])
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A number of how the animals look for what they need (see [needs]).
func needs(key: String) -> float:
	return float(_values["needs"][key])


## The game minutes an animal of this species takes from fed to as hungry as it gets, or from
## watered to as thirsty as it gets (`need` is `hunger` or `thirst`).
func need_minutes(species: StringName, need: StringName) -> float:
	return float(_species(species, "%s_hours" % need)) * GameClock.MINUTES_PER_HOUR


## Whether grazing feeds the species.
func grazes_for_food(species: StringName) -> bool:
	return _species(species, "grazes_for_food")


## Whether the species eats the feed of a hay rack.
func eats_feed(species: StringName) -> bool:
	return _species(species, "eats_feed")


## What one meal or one drink of the species takes out of a stock (`need` is `hunger` or
## `thirst`).
func units_per_need(species: StringName, need: StringName) -> int:
	return int(_species(species, "eat_units" if need == &"hunger" else "drink_units"))


## A number or name of the chicken coop (see [coop]).
func coop(key: String) -> Variant:
	return _values["coop"][key]


## How much water one pour of the watering can puts into a trough, in units.
func pour_units() -> int:
	return int(_values["yard"]["pour_units"])


## How many units of feed one of this item puts into a hay rack; 0 for an item that is no feed.
func feed_units(item: StringName) -> int:
	return int(_values["yard"]["feed_items"].get(String(item), 0))


func _species(species: StringName, key: String) -> Variant:
	return _values[String(species)][key]
