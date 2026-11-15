class_name QuestDoneCondition
extends QuestCondition
## The quest `quest` was done earlier.


func kind() -> String:
	return "quest_done"


func problems(fields: Dictionary, quest_ids: Array[String]) -> Array[String]:
	if quest_ids.has(fields.get("quest")):
		return []
	return ["quest is no quest"]
