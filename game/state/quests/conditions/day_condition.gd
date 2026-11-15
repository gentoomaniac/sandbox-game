class_name DayCondition
extends QuestCondition
## The game day is from `at_least` and/or up to `at_most`.


func kind() -> String:
	return "day"


func problems(fields: Dictionary, _quest_ids: Array[String]) -> Array[String]:
	var found: Array[String] = []
	if not (fields.has("at_least") or fields.has("at_most")):
		found.append("has neither at_least nor at_most")
	for key in ["at_least", "at_most"]:
		if fields.has(key):
			found.append_array(QuestFields.whole_number(fields, key, 1))
	return found
