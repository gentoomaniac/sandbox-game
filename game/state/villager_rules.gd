class_name VillagerRules
extends RefCounted
## The villagers written by hand, read from data/villagers.cfg (see there for what each key
## means): one section each, named by the id that spawns them (`spawn npc antje`, see Npcs).

const DEFAULT_PATH := "res://data/villagers.cfg"
## The keys of a villager whose values are text.
const TEXT_KEYS: Array[String] = ["name", "trade", "personality", "background", "habits"]

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
## which are those with pictures.
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
		var look: Variant = villager.get("look")
		if not look is Dictionary or not look.has(str(Appearance.BODY)):
			found.append("[%s] look has no body" % id)
			continue
		for slot: String in look:
			if not layers.has({slot = StringName(slot), variant = str(look[slot])}):
				found.append("[%s] look: no %s %s" % [id, slot, look[slot]])
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
## habits}.
func villager(id: String) -> Dictionary:
	return _values[id]
