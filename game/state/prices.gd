class_name Prices
extends RefCounted
## What a thing is worth, in whole Schilling, read from data/prices.cfg (see there for what each
## section means). One table for the shops, and later for barter and the player's stall.
## `from_file` reports everything wrong with the file, and `is_valid` says whether anything was.

const DEFAULT_PATH := "res://data/prices.cfg"
const WORTH := "worth"
const PURSE := "purse"

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
		if not section in [WORTH, PURSE]:
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
