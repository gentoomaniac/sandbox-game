class_name WildSeeds
extends RefCounted
## The seeds a plant picked by hand may also give, read from data/wild_seeds.cfg (see there for what
## each key means). `from_file` reports everything wrong with the file, and `is_valid` says whether
## anything was.

const DEFAULT_PATH := "res://data/wild_seeds.cfg"
const KEYS: Array[String] = ["seasons", "chance"]
## In the order of GameClock.Season.
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]

static var _default: WildSeeds

## {section: {key: value}} in the order of the file, a section being "<plant>.<seed>".
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


static func default_rules() -> WildSeeds:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> WildSeeds:
	var rules := WildSeeds.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	var crop_seeds := CropRules.default_rules().crop_ids().map(
		func(crop: StringName) -> String: return CropRules.default_rules().crop(crop)["seed"]
	)
	for section: String in _values:
		var parts := section.split(".")
		if parts.size() != 2:
			found.append("[%s] is not named <plant>.<seed>" % section)
			continue
		var plant := StringName(parts[0])
		if not _is_picked_by_hand(plant):
			found.append("[%s] %s is no plant picked by hand" % [section, plant])
		if not crop_seeds.has(parts[1]):
			found.append("[%s] %s is the seed of no crop" % [section, parts[1]])
		found.append_array(_value_problems(section))
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The seeds picking the plant at `pos` on `day` also gives, item id to count: the ones whose
## season it is and that roll true. The same plant on the same day always gives the same.
func found(plant: StringName, pos: Vector2i, day: int) -> Dictionary:
	var season := SEASONS[GameClock.season_of(day)]
	var seeds := {}
	var index := 0
	for section: String in _values:
		index += 1
		var parts := section.split(".")
		if parts[0] != plant or not _values[section]["seasons"].has(season):
			continue
		# Each seed of a plant rolls with a salt of its own, and so does each day.
		if PositionHash.rolls(pos, day * _values.size() + index, _values[section]["chance"]):
			seeds[StringName(parts[1])] = 1
	return seeds


static func _is_picked_by_hand(plant: StringName) -> bool:
	var plant_type: Dictionary = WorldObjectTypes.TYPES.get(plant, {})
	return plant_type.has("drops") and not plant_type.has("hp") and not plant_type.has("tool")


func _value_problems(section: String) -> Array[String]:
	var found_problems: Array[String] = []
	var values: Dictionary = _values[section]
	for key in KEYS:
		if not values.has(key):
			found_problems.append("[%s] no %s" % [section, key])
	var seasons: Variant = values.get("seasons", [])
	if not (seasons is Array and not seasons.is_empty()):
		found_problems.append("[%s] seasons is not a list of seasons" % section)
	else:
		for season: Variant in seasons:
			if not SEASONS.has(season):
				found_problems.append("[%s] %s is no season" % [section, season])
	var chance: Variant = values.get("chance", 0.0)
	if not (chance is float and chance > 0.0 and chance <= 1.0):
		found_problems.append("[%s] chance is not a number above 0 and up to 1" % section)
	return found_problems
