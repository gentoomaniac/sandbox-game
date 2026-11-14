class_name VillagerRules
extends RefCounted
## The villagers written by hand, read from data/villagers.cfg (see there for what each key
## means): one section each, named by the id that spawns them (`spawn npc antje`, see Npcs).
## Their family and friends are villagers of the file too, and the file must agree with itself
## about them (see `problems`).

const DEFAULT_PATH := "res://data/villagers.cfg"
## The keys of a villager whose values are text.
const TEXT_KEYS: Array[String] = [
	"name",
	"trade",
	"personality",
	"background",
	"home",
	"speech",
	"likes",
	"wants",
	"day",
	"habits",
	"avoids",
	"secrets",
]
## The keys a sheet may add, none or one of the two workplaces: where they live and work as a
## building type (the nearest one that stands gets them, see Npcs), or the name of a spot where
## there is no building to work in.
const HOME_BUILDING_KEY := "home_building"
const WORKPLACE_BUILDING_KEY := "workplace_building"
const WORKPLACE_SPOT_KEY := "workplace_spot"
## A villager's sample lines: the cut-down sheet tells this many.
const MIN_SAMPLES := 2
## The kinds of people a villager may name in `people`: the sex of the one named ("" for
## either), and the kinds that one may name the villager by in turn.
const KINDS := {
	"husband": {"sex": "male", "back": ["wife"]},
	"wife": {"sex": "female", "back": ["husband"]},
	"father": {"sex": "male", "back": ["son", "daughter"]},
	"mother": {"sex": "female", "back": ["son", "daughter"]},
	"son": {"sex": "male", "back": ["father", "mother"]},
	"daughter": {"sex": "female", "back": ["father", "mother"]},
	"brother": {"sex": "male", "back": ["brother", "sister"]},
	"sister": {"sex": "female", "back": ["brother", "sister"]},
	"uncle": {"sex": "male", "back": ["nephew", "niece"]},
	"aunt": {"sex": "female", "back": ["nephew", "niece"]},
	"nephew": {"sex": "male", "back": ["uncle", "aunt"]},
	"niece": {"sex": "female", "back": ["uncle", "aunt"]},
	"sweetheart": {"sex": "", "back": ["sweetheart"]},
	"friend": {"sex": "", "back": ["friend"]},
}
## The kinds that live in one house: a couple and their children (see Households).
const HOUSEHOLD_KINDS: Array[String] = ["husband", "wife", "father", "mother", "son", "daughter"]
## A father or mother is at least this many years older than their child.
const MIN_PARENT_AGE := 15

static var _default: VillagerRules

## {id: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The villagers of the data file, loaded the first time they are asked for.
static func default_rules() -> VillagerRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> VillagerRules:
	var rules := VillagerRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[id] what". A look may only wear the layers NpcRules offers,
## which are those with pictures. A `home_building` is a type that has room for residents, a
## `workplace_building` a type, and a sheet names one workplace at most. Each of a villager's
## `people` is a villager of the file who names them back (see KINDS), a parent is older than
## their child by MIN_PARENT_AGE or more, and a married couple has the same home.
func problems() -> Array[String]:
	var found: Array[String] = []
	if _values.is_empty():
		found.append("no villagers")
	var layers := NpcRules.default_rules().all_layers()
	for id: String in _values:
		var villager: Dictionary = _values[id]
		for key in TEXT_KEYS:
			if not villager.get(key) is String or villager[key].is_empty():
				found.append("[%s] %s is not a text" % [id, key])
		if not NpcRules.SEXES.has(StringName(str(villager.get("sex")))):
			found.append("[%s] sex is not one of %s" % [id, NpcRules.SEXES])
		if not villager.get("age") is int or villager["age"] <= 0:
			found.append("[%s] age is not a whole number of years" % id)
		var samples: Variant = villager.get("samples")
		if not samples is Array or samples.size() < MIN_SAMPLES or not samples.all(_is_text):
			found.append("[%s] samples is not a list of %d or more lines" % [id, MIN_SAMPLES])
		var people: Variant = villager.get("people")
		if not people is Dictionary or not people.values().all(_is_kind_and_text):
			found.append("[%s] people is not a dictionary of [kind, what they think]" % id)
		found.append_array(_place_problems(id, villager))
		var look: Variant = villager.get("look")
		if not look is Dictionary or not look.has(str(Appearance.BODY)):
			found.append("[%s] look has no body" % id)
			continue
		for slot: String in look:
			if not layers.has({slot = StringName(slot), variant = str(look[slot])}):
				found.append("[%s] look: no %s %s" % [id, slot, look[slot]])
	if not found.is_empty():
		return found
	for id: String in _values:
		for other: String in _values[id]["people"]:
			found.append_array(_relation_problems(id, other))
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The ids, in the order of the file.
func ids() -> Array[String]:
	var found: Array[String] = []
	found.assign(_values.keys())
	return found


func has(id: String) -> bool:
	return _values.has(id)


## The villager of that id as written: {name, sex, age, trade, look, personality, background,
## home, speech, samples, people, likes, wants, day, habits, avoids, secrets}.
func villager(id: String) -> Dictionary:
	return _values[id]


## What is wrong with villager `id` naming villager `other` among their people.
func _relation_problems(id: String, other: String) -> Array[String]:
	var kind: String = _values[id]["people"][other][0]
	var where := "[%s] people: %s" % [id, other]
	if not _values.has(other) or other == id:
		return ["%s is not another villager" % where]
	var found: Array[String] = []
	var named: Dictionary = _values[other]
	if KINDS[kind]["sex"] not in ["", named["sex"]]:
		found.append("%s is not of the sex of a %s" % [where, kind])
	var back: Array = named["people"].get(id, [""])
	if not KINDS[kind]["back"].has(back[0]):
		found.append("%s does not name %s back as one of %s" % [where, id, KINDS[kind]["back"]])
	if kind in ["father", "mother"] and named["age"] < _values[id]["age"] + MIN_PARENT_AGE:
		found.append("%s is not %d years older than their child" % [where, MIN_PARENT_AGE])
	if kind in ["husband", "wife"]:
		if named["home"] != _values[id]["home"]:
			found.append(
				"%s does not have the same home as their %s" % [where, KINDS[kind]["back"][0]]
			)
		if named.get(HOME_BUILDING_KEY, "") != _values[id].get(HOME_BUILDING_KEY, ""):
			found.append(
				(
					"%s does not have the same %s as their %s"
					% [where, HOME_BUILDING_KEY, KINDS[kind]["back"][0]]
				)
			)
	return found


## What is wrong with the building types and the spot a sheet names for home and workplace.
func _place_problems(id: String, villager: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var home: Variant = villager.get(HOME_BUILDING_KEY)
	if (
		home != null
		and not (
			home is String
			and BuildingTypes.TYPES.has(StringName(home))
			and BuildingTypes.TYPES[StringName(home)]["residents"] > 0
		)
	):
		found.append("[%s] %s is not a building with room for residents" % [id, HOME_BUILDING_KEY])
	var workplace: Variant = villager.get(WORKPLACE_BUILDING_KEY)
	if (
		workplace != null
		and not (workplace is String and BuildingTypes.TYPES.has(StringName(workplace)))
	):
		found.append("[%s] %s is not a building" % [id, WORKPLACE_BUILDING_KEY])
	var spot: Variant = villager.get(WORKPLACE_SPOT_KEY)
	if spot != null and not _is_text(spot):
		found.append("[%s] %s is not a text" % [id, WORKPLACE_SPOT_KEY])
	if workplace != null and spot != null:
		found.append(
			"[%s] has both a %s and a %s" % [id, WORKPLACE_BUILDING_KEY, WORKPLACE_SPOT_KEY]
		)
	return found


static func _is_text(value: Variant) -> bool:
	return value is String and not value.is_empty()


static func _is_kind_and_text(value: Variant) -> bool:
	return value is Array and value.size() == 2 and KINDS.has(value[0]) and _is_text(value[1])
