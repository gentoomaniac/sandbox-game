class_name Prices
extends RefCounted
## What a thing is worth, in whole Schilling, read from data/prices.cfg (see there for what each
## section means). One table for the shops, and later for barter and the player's stall.
## `from_file` reports everything wrong with the file, and `is_valid` says whether anything was.

const DEFAULT_PATH := "res://data/prices.cfg"
const WORTH := "worth"
const PURSE := "purse"
const KIND := "kind"
const SEASONS_PREFIX := "seasons."
## `season` of a worth that no season changes.
const FLAT := -1
const SEASON_KEYS: Array[String] = ["spring", "summer", "autumn", "winter"]

static var _default: Prices

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The prices of the data file, loaded the first time they are asked for.
static func default_prices() -> Prices:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> Prices:
	var prices := Prices.new(DataFile.read_sections(path))
	for problem in prices.problems():
		push_error("%s: %s" % [path, problem])
	return prices


## What is wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for section: String in [WORTH, PURSE]:
		if not _values.has(section):
			found.append("[%s] is missing" % section)
	for section: String in _values:
		if not (section in [WORTH, PURSE, KIND] or section.begins_with(SEASONS_PREFIX)):
			found.append("[%s] is not a section of the file" % section)
	var start: Variant = _values.get(PURSE, {}).get("start")
	if _values.has(PURSE) and not (start is int and start >= 0):
		found.append("[%s] start is not a whole number from 0" % PURSE)
	for item: String in _values.get(WORTH, {}):
		var worth: Variant = _values[WORTH][item]
		if not ItemTypes.TYPES.has(StringName(item)):
			found.append("[%s] %s is no item" % [WORTH, item])
		elif not (worth is int and worth >= 1):
			found.append("[%s] %s is not a whole number from 1" % [WORTH, item])
	found.append_array(_season_problems())
	return found


func is_valid() -> bool:
	return problems().is_empty()


func has_worth(item: StringName) -> bool:
	return _values.get(WORTH, {}).has(String(item))


## What the item is worth. Ask only for an item that `has_worth`.
func worth(item: StringName) -> int:
	return _values[WORTH][String(item)]


## The Schilling a new game starts with.
func start_purse() -> int:
	return _values[PURSE]["start"]


## What the item is worth in the season (a GameClock.Season; FLAT for none): its worth at the
## percent of its kind in that season, rounded to the nearest whole and at least `least`. A good of
## no kind is flat: it keeps its worth.
func worth_in(item: StringName, season := FLAT, least := 1) -> int:
	var kind: Variant = _values.get(KIND, {}).get(String(item))
	if kind == null or season == FLAT:
		return worth(item)
	var percent: int = _values[SEASONS_PREFIX + kind][SEASON_KEYS[season]]
	return maxi(roundi(worth(item) * percent / 100.0), least)


## What is wrong with the kinds of the goods and the percents of the seasons.
func _season_problems() -> Array[String]:
	var found: Array[String] = []
	for item: String in _values.get(KIND, {}):
		var kind: Variant = _values[KIND][item]
		if not has_worth(StringName(item)):
			found.append("[%s] %s has no worth" % [KIND, item])
		elif not (kind is String and _values.has(SEASONS_PREFIX + kind)):
			found.append("[%s] %s: %s has no [%s%s]" % [KIND, item, kind, SEASONS_PREFIX, kind])
	for section: String in _values:
		if not section.begins_with(SEASONS_PREFIX):
			continue
		for season in SEASON_KEYS:
			var percent: Variant = _values[section].get(season)
			if not (percent is int and percent >= 1):
				found.append("[%s] %s is not a whole percent from 1" % [section, season])
	return found
