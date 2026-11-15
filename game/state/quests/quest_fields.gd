class_name QuestFields
extends RefCounted
## What the kinds of objective and prerequisite check in the fields a quest file gives them: each
## returns what is wrong with one field, as a list that is empty when it is fine.


static func whole_number(fields: Dictionary, key: String, from: int) -> Array[String]:
	var value: Variant = fields.get(key)
	if value is int and value >= from:
		return []
	return ["%s is not a whole number from %d" % [key, from]]


static func item(fields: Dictionary, key: String) -> Array[String]:
	var value: Variant = fields.get(key)
	if value is String and ItemTypes.TYPES.has(StringName(value)):
		return []
	return ["%s is no item" % key]


static func villager(fields: Dictionary, key: String) -> Array[String]:
	var value: Variant = fields.get(key)
	if value is String and VillagerRules.default_rules().has(value):
		return []
	return ["%s is no villager" % key]


## An optional field: fine when absent.
static func optional_villager(fields: Dictionary, key: String) -> Array[String]:
	return [] if not fields.has(key) else villager(fields, key)
