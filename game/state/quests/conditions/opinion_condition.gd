class_name OpinionCondition
extends QuestCondition
## A villager's opinion of the player, in points, is at least `at_least`. The villager is
## `villager`, or the giver of the quest when the field is left out.


func kind() -> String:
	return "opinion"


func problems(fields: Dictionary, _quest_ids: Array[String]) -> Array[String]:
	var found := QuestFields.whole_number(fields, "at_least", -1000)
	found.append_array(QuestFields.optional_villager(fields, "villager"))
	return found


func is_met(fields: Dictionary, giver: String, quests: Quests) -> bool:
	return quests.opinion_of(fields.get("villager", giver)) >= fields["at_least"]
