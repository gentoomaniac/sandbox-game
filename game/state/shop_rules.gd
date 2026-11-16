class_name ShopRules
extends RefCounted
## What the shopkeepers sell and take, read from data/shops.cfg (see there for what each key means):
## the percentages that make a price and a value of the worths of Prices, and how much she has and
## takes. `from_file` reports everything wrong with the file, and `is_valid` says
## whether anything was.

const DEFAULT_PATH := "res://data/shops.cfg"
const SHOP_PREFIX := "shop"
const SELLS := "sells"
const TAKES := "takes"
const SHOP_KEYS: Array[String] = ["keeper", "sell_percent", "take_percent"]
const SELLS_KEYS: Array[String] = ["max", "restock"]
const TAKES_KEYS: Array[String] = ["room"]
## A good she takes pays at least 1 at `take_percent`, rounded down; see data/prices.cfg.
const LEAST_TAKEN_WORTH := 2

static var _default: ShopRules

## {section: {key: value}}, as in the file.
var _values: Dictionary
var _prices: Prices


func _init(values: Dictionary, prices := Prices.default_prices()) -> void:
	_values = values
	_prices = prices


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> ShopRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> ShopRules:
	var rules := ShopRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	var keepers := {}
	for shop in shop_ids():
		found.append_array(_shop_problems(shop))
		var keeper: Variant = _values[_section(shop)].get("keeper")
		if keepers.has(keeper):
			found.append("[%s] keeper %s keeps another shop too" % [_section(shop), keeper])
		keepers[keeper] = true
	for section: String in _values:
		var parts := section.split(".")
		if not _is_known_section(parts):
			found.append("[%s] is no shop, no good of a shop and not under a shop" % section)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The ids of the shops, in the order of the file.
func shop_ids() -> Array[String]:
	var found: Array[String] = []
	for section: String in _values:
		var parts := section.split(".")
		if parts.size() == 2 and parts[0] == SHOP_PREFIX:
			found.append(parts[1])
	return found


## The shop the villager keeps, or "" if they keep none.
func shop_of_keeper(keeper: String) -> String:
	for shop in shop_ids():
		if _values[_section(shop)].get("keeper") == keeper:
			return shop
	return ""


func keeper_of(shop: String) -> String:
	return _values[_section(shop)]["keeper"]


## The goods she sells, in the order of the file.
func sold(shop: String) -> Array[StringName]:
	return _goods(shop, SELLS)


## The goods she takes, in the order of the file.
func taken(shop: String) -> Array[StringName]:
	return _goods(shop, TAKES)


func is_sold(shop: String, item: StringName) -> bool:
	return _values.has(_good_section(shop, SELLS, item))


func is_taken(shop: String, item: StringName) -> bool:
	return _values.has(_good_section(shop, TAKES, item))


## What she asks of the player for one of the item, in Schilling: its worth at `sell_percent`,
## rounded up. `standing_percent` is the share of that price the player pays by their
## friendship with her (see ShopStanding), a whole percent. The worth is that of the `season` (see
## Prices `worth_in`), so the percents are applied once and the price is rounded once.
func price(shop: String, item: StringName, standing_percent := 100, season := Prices.FLAT) -> int:
	var percent: int = _values[_section(shop)]["sell_percent"]
	return ceili(_prices.worth_in(item, season) * percent * standing_percent / 10000.0)


## Whether the item is one of her best wares (`best` of its section), which she sells only to
## those whose friendship has her `best_wares` benefit.
func is_best(shop: String, item: StringName) -> bool:
	return _values[_good_section(shop, SELLS, item)].get("best", false)


## What one of the item the player gives is worth to her, in Schilling: its worth at `take_percent`,
## rounded down, of the worth in the `season`.
func value(shop: String, item: StringName, season := Prices.FLAT) -> int:
	var percent: int = _values[_section(shop)]["take_percent"]
	return floori(_prices.worth_in(item, season, LEAST_TAKEN_WORTH) * percent / 100.0)


## The most of the item she has at once.
func most_stock(shop: String, item: StringName) -> int:
	return _values[_good_section(shop, SELLS, item)]["max"]


## How many of the item come back to her stock each day.
func restock(shop: String, item: StringName) -> int:
	return _values[_good_section(shop, SELLS, item)]["restock"]


## How many of the item she takes in a day.
func most_room(shop: String, item: StringName) -> int:
	return _values[_good_section(shop, TAKES, item)]["room"]


static func _section(shop: String) -> String:
	return "%s.%s" % [SHOP_PREFIX, shop]


static func _good_section(shop: String, kind: String, item: StringName) -> String:
	return "%s.%s.%s.%s" % [SHOP_PREFIX, shop, kind, item]


func _goods(shop: String, kind: String) -> Array[StringName]:
	var found: Array[StringName] = []
	var prefix := "%s.%s.%s." % [SHOP_PREFIX, shop, kind]
	for section: String in _values:
		if section.begins_with(prefix):
			found.append(StringName(section.trim_prefix(prefix)))
	return found


## Whether the parts of a section name make a shop, or a good under a shop that is there.
func _is_known_section(parts: PackedStringArray) -> bool:
	if parts[0] != SHOP_PREFIX:
		return false
	if parts.size() == 2:
		return true
	return parts.size() == 4 and parts[2] in [SELLS, TAKES] and _values.has(_section(parts[1]))


func _shop_problems(shop: String) -> Array[String]:
	var found: Array[String] = []
	var section := _section(shop)
	var values: Dictionary = _values[section]
	for key in SHOP_KEYS:
		if not values.has(key):
			found.append("[%s] no %s" % [section, key])
	if values.has("keeper") and not VillagerRules.default_rules().has(str(values["keeper"])):
		found.append("[%s] keeper %s is no villager" % [section, values["keeper"]])
	for key in ["sell_percent", "take_percent"]:
		if values.has(key) and not (values[key] is int and values[key] > 0):
			found.append("[%s] %s is not a whole number above 0" % [section, key])
	if sold(shop).is_empty() and taken(shop).is_empty():
		found.append("[%s] sells and takes nothing" % section)
	for item in sold(shop):
		found.append_array(_good_problems(shop, SELLS, item, SELLS_KEYS))
		if is_taken(shop, item):
			found.append("[%s] %s is both sold and taken" % [section, item])
	for item in taken(shop):
		found.append_array(_good_problems(shop, TAKES, item, TAKES_KEYS))
	return found


func _good_problems(
	shop: String, kind: String, item: StringName, keys: Array[String]
) -> Array[String]:
	var found: Array[String] = []
	var section := _good_section(shop, kind, item)
	var values: Dictionary = _values[section]
	if not ItemTypes.TYPES.has(item):
		found.append("[%s] %s is no item" % [section, item])
	elif not _prices.has_worth(item):
		found.append("[%s] %s has no worth in data/prices.cfg" % [section, item])
	elif kind == TAKES and _prices.worth(item) < LEAST_TAKEN_WORTH:
		found.append("[%s] %s is worth less than %d" % [section, item, LEAST_TAKEN_WORTH])
	for key in keys:
		if not values.has(key):
			found.append("[%s] no %s" % [section, key])
		elif not (values[key] is int and values[key] >= 1):
			found.append("[%s] %s is not a whole number from 1" % [section, key])
	if kind == SELLS and not values.get("best", false) is bool:
		found.append("[%s] best is not true or false" % section)
	var is_stock := values.get("restock") is int and values.get("max") is int
	if is_stock and values["restock"] > values["max"]:
		found.append("[%s] restock is more than max" % section)
	return found
