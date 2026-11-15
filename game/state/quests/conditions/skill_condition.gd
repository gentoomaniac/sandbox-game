class_name SkillCondition
extends QuestCondition
## The player's `skill` (data/skills.cfg) is at least `at_least`.


func kind() -> String:
	return "skill"


func problems(fields: Dictionary, _quest_ids: Array[String]) -> Array[String]:
	var found := QuestFields.whole_number(fields, "at_least", 1)
	var skill: Variant = fields.get("skill")
	if not (skill is String and SkillRules.default_rules().has_skill(StringName(skill))):
		found.append("skill is no skill")
	return found
