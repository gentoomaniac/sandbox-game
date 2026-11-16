class_name BarterRules
extends RefCounted
## What the villagers barter, read from data/barter.cfg (see there for what each key means): the
## goods each gives and takes, and the most a deal may be worth. `from_file` reports everything
## wrong with the file, and `is_valid` says whether anything was.

const DEFAULT_PATH := "res://data/barter.cfg"
const DEAL := "deal"

static var _default: BarterRules

## {section: {key: value}}, as in the file.
var _values: Dictionary
var _prices: Prices


func _init(values: Dictionary, prices := Prices.default_prices()) -> void:
	_values = values
	_prices = prices


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> BarterRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> BarterRules:
	var rules := BarterRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	var cap: Variant = _values.get(DEAL, {}).get("cap")
	if not (cap is int and cap >= 1):
		found.append("[%s] cap is not a whole number from 1" % DEAL)
	for section: String in _values:
		if section == DEAL:
			continue
		if not VillagerRules.default_rules().has(section):
			found.append("[%s] is no villager" % section)
			continue
		var offers := _goods_problems(section, "offers", found)
		var wants := _goods_problems(section, "wants", found)
		for item in offers:
			if wants.has(item):
				found.append("[%s] %s is both offered and wanted" % [section, item])
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The most a deal may be worth to either side, in Schilling.
func cap() -> int:
	return _values[DEAL]["cap"]


## Whether the villager barters at all (when the player's friendship lets them, see Barter).
func has(villager: String) -> bool:
	return villager != DEAL and _values.has(villager)


## The goods the villager gives, in the order of the file.
func offers(villager: String) -> Array[StringName]:
	return _goods(villager, "offers")


## The goods the villager takes, in the order of the file.
func wants(villager: String) -> Array[StringName]:
	return _goods(villager, "wants")


func _goods(villager: String, key: String) -> Array[StringName]:
	var found: Array[StringName] = []
	if has(villager):
		for item: String in _values[villager][key]:
			found.append(StringName(item))
	return found


## The goods of a list of the section, adding what is wrong with it to `found`.
func _goods_problems(section: String, key: String, found: Array[String]) -> Array[String]:
	var listed: Variant = _values[section].get(key)
	if not (listed is Array and not listed.is_empty()):
		found.append("[%s] %s is not a list of goods" % [section, key])
		return []
	var items: Array[String] = []
	for item: Variant in listed:
		items.append(str(item))
		if not ItemTypes.TYPES.has(StringName(str(item))):
			found.append("[%s] %s: %s is no item" % [section, key, item])
		elif not _prices.has_worth(StringName(str(item))):
			found.append("[%s] %s: %s has no worth in data/prices.cfg" % [section, key, item])
	return items
