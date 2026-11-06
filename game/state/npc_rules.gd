class_name NpcRules
extends RefCounted
## The villagers' rules, read from data/npcs.cfg (see there for what each key means): how they
## behave, and the names, clothes and background a new one is given (`pick_name`, `pick_look`,
## `pick_background`).

const DEFAULT_PATH := "res://data/npcs.cfg"

const MALE := &"male"
const FEMALE := &"female"
const SEXES: Array[StringName] = [MALE, FEMALE]

const BEHAVIOUR_KEYS: Array[String] = [
	"anchor_radius",
	"anchor_search",
	"walk_speed",
	"idle_seconds",
	"walk_seconds",
	"walk_chance",
	"personal_space",
	"linger_seconds",
	"rest_minutes_after_sunset",
	"up_minutes_after_sunrise",
]
## The lists every villager draws from, and those drawn by sex.
const EVERYONE_KEYS: Array[String] = ["skins", "hair_colours", "feet", "surnames"]
const SEX_KEYS: Array[String] = [
	"first_names",
	"hair_styles",
	"clothes",
	"legs",
	"aprons",
	"coats",
	"heads",
	"trades",
	"families"
]
## The lists of [background] (its `ages` is a range).
const BACKGROUND_KEYS: Array[String] = ["personalities", "worries", "habits"]
## The Appearance slot of each list of layer variants (hair is put together from two lists).
const SLOT_OF_KEY := {
	"skins": Appearance.BODY,
	"legs": Appearance.LEGS,
	"feet": Appearance.FEET,
	"clothes": Appearance.CLOTHES,
	"aprons": Appearance.APRON,
	"coats": Appearance.COAT,
	"heads": Appearance.HEAD,
}

static var _default: NpcRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> NpcRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> NpcRules:
	var rules := NpcRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key in BEHAVIOUR_KEYS:
		if not _values.get("behaviour", {}).has(key):
			found.append("[behaviour] no %s" % key)
	var lists := {"everyone": EVERYONE_KEYS, "background": BACKGROUND_KEYS}
	for sex in SEXES:
		lists[str(sex)] = SEX_KEYS
	for section: String in lists:
		for key: String in lists[section]:
			var list: Variant = _values.get(section, {}).get(key)
			if not list is Array or list.is_empty():
				found.append("[%s] %s is not a list of at least one" % [section, key])
	var ages: Variant = _values.get("background", {}).get("ages")
	var is_range: bool = ages is Array and ages.size() == 2 and ages[0] is int and ages[1] is int
	if not is_range or ages[1] < ages[0]:
		found.append("[background] ages is not [youngest, oldest]")
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A number of [behaviour].
func behaviour(key: String) -> float:
	return float(_values["behaviour"][key])


## A time drawn between the shortest and the longest of a [behaviour] range, such as
## `idle_seconds`.
func pick_seconds(key: String, rng: RandomNumberGenerator) -> float:
	var range_seconds: Array = _values["behaviour"][key]
	return rng.randf_range(range_seconds[0], range_seconds[1])


## A first name for the sex and a surname, such as "Antje Boysen".
func pick_name(sex: StringName, rng: RandomNumberGenerator) -> String:
	return "%s %s" % [_pick(str(sex), "first_names", rng), _pick("everyone", "surnames", rng)]


## The layers of a villager of that sex: skin, hair and clothes drawn from the lists.
func pick_look(sex: StringName, rng: RandomNumberGenerator) -> Appearance:
	var look := Appearance.new()
	look.layers.clear()
	for key: String in SLOT_OF_KEY:
		var section := "everyone" if EVERYONE_KEYS.has(key) else str(sex)
		var variant := _pick(section, key, rng)
		if variant != "":
			look.wear(SLOT_OF_KEY[key], variant)
	var hair_style := _pick(str(sex), "hair_styles", rng)
	look.wear(Appearance.HAIR, "%s_%s" % [hair_style, _pick("everyone", "hair_colours", rng)])
	return look


## Who a villager of that sex made up from the tables is, as the fields of the same names of
## Npc: `age`, `trade`, `personality`, `background` (family and a worry) and `habits`.
func pick_background(sex: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var ages: Array = _values["background"]["ages"]
	var other_sex := FEMALE if sex == MALE else MALE
	var family := _pick(str(sex), "families", rng).format(
		{"spouse": _pick(str(other_sex), "first_names", rng)}
	)
	return {
		"age": rng.randi_range(ages[0], ages[1]),
		"trade": _pick(str(sex), "trades", rng),
		"personality": _pick("background", "personalities", rng),
		"background": "%s %s" % [family, _pick("background", "worries", rng)],
		"habits": _pick("background", "habits", rng),
	}


## Every layer a villager may wear, as {slot, variant}: to check that each has its pictures.
func all_layers() -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	for key: String in SLOT_OF_KEY:
		for section: String in ["everyone", str(MALE), str(FEMALE)]:
			for variant: String in _values[section].get(key, []):
				if variant != "":
					layers.append({slot = SLOT_OF_KEY[key], variant = variant})
	for sex in SEXES:
		for style: String in _values[str(sex)]["hair_styles"]:
			for colour: String in _values["everyone"]["hair_colours"]:
				layers.append({slot = Appearance.HAIR, variant = "%s_%s" % [style, colour]})
	return layers


func _pick(section: String, key: String, rng: RandomNumberGenerator) -> String:
	var list: Array = _values[section][key]
	return list[rng.randi_range(0, list.size() - 1)]
