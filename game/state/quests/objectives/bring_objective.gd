class_name BringObjective
extends QuestObjective
## Bring the giver some of an item: `item` and `count`.


func kind() -> String:
	return "bring"


func problems(fields: Dictionary) -> Array[String]:
	var found := QuestFields.item(fields, "item")
	found.append_array(QuestFields.whole_number(fields, "count", 1))
	return found
