class_name Skills
extends RefCounted
## What the player is good at: points per skill of data/skills.cfg, from 0 up to the cap of one
## skill. Crafting a recipe that has a skill practises it (see `practise`), and a recipe's level
## is the points it needs (see Crafting). The skills tab shows them.
##
## All skills together have a total cap, so only one can reach its own cap. At the total cap a
## skill only grows by taking the points from a skill the player marked to fade (`set_fading`);
## without one it does not grow. Nothing ever fades on its own.

signal changed

## Points are counted in whole tenths, so the points the tab shows add up exactly.
const TENTHS := 10

var rules: SkillRules

## Skill id -> its points in tenths; a skill not in it has none.
var _tenths: Dictionary[StringName, int] = {}
## The skills the player let fade: they give their points to a growing skill at the total cap.
var _fading: Dictionary[StringName, bool] = {}


func _init(skill_rules := SkillRules.default_rules()) -> void:
	rules = skill_rules


func points(skill: StringName) -> float:
	return _tenths.get(skill, 0) / float(TENTHS)


## All skills' points together.
func total() -> float:
	return _total_tenths() / float(TENTHS)


func is_fading(skill: StringName) -> bool:
	return _fading.has(skill)


func set_fading(skill: StringName, is_on: bool) -> void:
	if is_on:
		_fading[skill] = true
	else:
		_fading.erase(skill)
	changed.emit()


## Sets a skill's points, within 0 and the cap of one skill (the console's `skill`; it ignores
## the total cap).
func set_points(skill: StringName, value: float) -> void:
	_tenths[skill] = clampi(roundi(value * TENTHS), 0, _cap_tenths())
	changed.emit()


## What a craft of a recipe of `level` would teach the skill now (see SkillRules `gain`), before
## the total cap.
func gain_at(skill: StringName, level: float) -> float:
	return _gain_tenths(skill, level) / float(TENTHS)


## One craft of a recipe of `level`: the skill grows by what it teaches, as far as the total cap
## and the fading skills (in the order of the file) allow. Returns the points gained.
func practise(skill: StringName, level: float) -> float:
	var wanted := _gain_tenths(skill, level)
	# Above the total cap (the console's `skill`, a hand-edited save) there is no free room, but
	# the fading skills still give what is wanted, no more.
	var gained := mini(wanted, maxi(_total_cap_tenths() - _total_tenths(), 0))
	for fading in rules.skill_ids():
		if gained == wanted:
			break
		if not is_fading(fading) or fading == skill:
			continue
		var given := mini(wanted - gained, _tenths.get(fading, 0))
		_tenths[fading] = _tenths.get(fading, 0) - given
		gained += given
	if gained > 0:
		_tenths[skill] = _tenths.get(skill, 0) + gained
		changed.emit()
	return gained / float(TENTHS)


func to_dict() -> Dictionary:
	var saved := {}
	for skill in _tenths:
		saved[str(skill)] = points(skill)
	var fading: Array[String] = []
	for skill in _fading:
		fading.append(str(skill))
	return {"points": saved, "fading": fading}


static func from_dict(data: Dictionary) -> Skills:
	var skills := Skills.new()
	for skill: String in data["points"]:
		skills._tenths[StringName(skill)] = roundi(float(data["points"][skill]) * TENTHS)
	for skill: String in data["fading"]:
		skills._fading[StringName(skill)] = true
	return skills


func _gain_tenths(skill: StringName, level: float) -> int:
	# A hand-edited save may hold more than the cap: that teaches nothing, it takes nothing away.
	var room: int = maxi(_cap_tenths() - _tenths.get(skill, 0), 0)
	return mini(roundi(rules.gain(points(skill), level) * TENTHS), room)


func _total_tenths() -> int:
	var sum := 0
	for skill in _tenths:
		sum += _tenths[skill]
	return sum


func _cap_tenths() -> int:
	return roundi(rules.skill_cap() * TENTHS)


func _total_cap_tenths() -> int:
	return roundi(rules.total_cap() * TENTHS)
