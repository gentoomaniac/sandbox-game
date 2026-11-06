class_name Skills
extends RefCounted
## What the player is good at: points per skill of data/skills.cfg, from 0 up to the cap of one
## skill. Crafting a recipe that has a skill practises it (see `practise`), and a recipe's level
## is the points it needs (see Crafting). The skills tab shows them.

signal changed

## Points are counted in whole tenths, so the points the tab shows add up exactly.
const TENTHS := 10

var rules: SkillRules

## Skill id -> its points in tenths; a skill not in it has none.
var _tenths: Dictionary[StringName, int] = {}


func _init(skill_rules := SkillRules.default_rules()) -> void:
	rules = skill_rules


func points(skill: StringName) -> float:
	return _tenths.get(skill, 0) / float(TENTHS)


## Sets a skill's points, within 0 and the cap of one skill (the console's `skill`).
func set_points(skill: StringName, value: float) -> void:
	_tenths[skill] = clampi(roundi(value * TENTHS), 0, _cap_tenths())
	changed.emit()


## What a craft of a recipe of `level` would teach the skill now (see SkillRules `gain`).
func gain_at(skill: StringName, level: float) -> float:
	return _gain_tenths(skill, level) / float(TENTHS)


## One craft of a recipe of `level`: the skill grows by what it teaches. Returns the points gained.
func practise(skill: StringName, level: float) -> float:
	var gained := _gain_tenths(skill, level)
	if gained > 0:
		_tenths[skill] = _tenths.get(skill, 0) + gained
		changed.emit()
	return gained / float(TENTHS)


func to_dict() -> Dictionary:
	var saved := {}
	for skill in _tenths:
		saved[str(skill)] = points(skill)
	return {"points": saved}


static func from_dict(data: Dictionary) -> Skills:
	var skills := Skills.new()
	for skill: String in data["points"]:
		skills._tenths[StringName(skill)] = roundi(float(data["points"][skill]) * TENTHS)
	return skills


func _gain_tenths(skill: StringName, level: float) -> int:
	# A hand-edited save may hold more than the cap: that teaches nothing, it takes nothing away.
	var room: int = maxi(_cap_tenths() - _tenths.get(skill, 0), 0)
	return mini(roundi(rules.gain(points(skill), level) * TENTHS), room)


func _cap_tenths() -> int:
	return roundi(rules.skill_cap() * TENTHS)
