class_name Attributes
extends RefCounted
## What the character is made of: a level per attribute of data/attributes.cfg, and the numbers
## the game reads from them (`max_energy`, `max_health`, `carry_capacity`). Anything that needs
## one of those asks here, so a new attribute or a new source of bonus changes this class and the
## data, not its callers. The character window shows them.
##
## An attribute's `value` is its level plus the bonuses on it (food, a worn item, a spell later):
## a bonus belongs to a source, lasts until that source removes it, and is not saved, so the
## source adds it again when the game loads. The derived numbers use the value.

signal changed

const STRENGTH := &"strength"
const AGILITY := &"agility"
const STAMINA := &"stamina"
const HP := &"hp"

var rules: AttributeRules

## Attribute id -> its level; one entry per attribute of the rules.
var _levels: Dictionary[StringName, int] = {}
## Source -> {attribute id -> bonus}.
var _bonuses: Dictionary[StringName, Dictionary] = {}


func _init(attribute_rules := AttributeRules.default_rules()) -> void:
	rules = attribute_rules
	for attribute in rules.attribute_ids():
		_levels[attribute] = rules.base_level(attribute)


func level(attribute: StringName) -> int:
	return _levels[attribute]


## Sets a level, within the lowest and highest the rules allow.
func set_level(attribute: StringName, new_level: int) -> void:
	_levels[attribute] = clampi(new_level, rules.min_level(), rules.max_level())
	changed.emit()


## What counts: the level and every bonus on it.
func value(attribute: StringName) -> int:
	return _levels[attribute] + bonus(attribute)


## The bonuses on an attribute, all sources together.
func bonus(attribute: StringName) -> int:
	var sum := 0
	for source in _bonuses:
		sum += _bonuses[source].get(attribute, 0)
	return sum


## Puts a bonus on an attribute for `source`, replacing what that source gave it before.
func add_bonus(source: StringName, attribute: StringName, amount: int) -> void:
	if not _bonuses.has(source):
		_bonuses[source] = {}
	_bonuses[source][attribute] = amount
	changed.emit()


## Takes away every bonus of `source`.
func remove_bonus(source: StringName) -> void:
	if _bonuses.erase(source):
		changed.emit()


## The most energy the player can have, before a debuff (see GameState `energy_cap`).
func max_energy() -> float:
	return value(STAMINA) * rules.energy_per_stamina()


func max_health() -> float:
	return value(HP) * rules.health_per_hp()


## The kilograms the player carries before the load costs more energy.
func carry_capacity() -> float:
	return value(STRENGTH) * rules.free_kg_per_strength()


## A derived number as text: whole when it is, else with one decimal.
static func number_text(number: float) -> String:
	return str(roundi(number)) if is_equal_approx(number, roundf(number)) else "%.1f" % number


## Only the levels are saved.
func to_dict() -> Dictionary:
	var saved := {}
	for attribute in _levels:
		saved[str(attribute)] = _levels[attribute]
	return {"levels": saved}


static func from_dict(data: Dictionary) -> Attributes:
	var attributes := Attributes.new()
	for attribute in attributes._levels:
		attributes._levels[attribute] = int(data["levels"][str(attribute)])
	return attributes
