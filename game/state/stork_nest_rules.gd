class_name StorkNestRules
extends RefCounted
## The numbers of the stork nests (see StorkNests), the `[stork_nest]` section of
## data/wildlife.cfg (see there for what each one means). Nests are not a kind of animal, so they
## are not in WildlifeRules. `from_file` reports every missing key, and `is_valid` says whether
## any was.

const SECTION := "stork_nest"
const KEYS := [
	"building_types",
	"nest_chance",
	"arrival_day",
	"arrival_spread_days",
	"incubation_days",
	"incubation_spread_days",
	"fledging_days",
	"fledging_spread_days",
	"first_leaves_days",
	"leaving_gap_days",
	"min_young",
	"max_young",
	"brood_guard_days",
	"trip_hours",
	"trip_chance_pair",
	"trip_chance_brood",
]

static var _default: StorkNestRules

## {key: value}, as in the file's section.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> StorkNestRules:
	if _default == null:
		_default = from_file(WildlifeRules.DEFAULT_PATH)
	return _default


static func from_file(path: String) -> StorkNestRules:
	var rules := StorkNestRules.new(DataFile.read_sections(path).get(SECTION, {}))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing, as "[stork_nest] no key".
func problems() -> Array[String]:
	var missing: Array[String] = []
	for key: String in KEYS:
		if not _values.has(key):
			missing.append("[%s] no %s" % [SECTION, key])
	return missing


func is_valid() -> bool:
	return problems().is_empty()


func value(key: String) -> Variant:
	return _values[key]
