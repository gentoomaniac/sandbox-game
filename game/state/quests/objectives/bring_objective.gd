class_name BringObjective
extends QuestObjective
## Bring the giver some of an item: `item` and `count`.


func kind() -> String:
	return "bring"


func problems(fields: Dictionary) -> Array[String]:
	var found := QuestFields.item(fields, "item")
	found.append_array(QuestFields.whole_number(fields, "count", 1))
	return found


func thing(fields: Dictionary) -> String:
	return ItemTypes.TYPES[StringName(fields["item"])]["name"].to_lower()


func progress(fields: Dictionary, _entry: Dictionary, quests: Quests) -> int:
	return quests.player().inventory.count_of(StringName(fields["item"]))


func goal(fields: Dictionary) -> int:
	return fields["count"]


## The item has to be in the hand, so that no one hands in what they carry by accident.
func is_offered(fields: Dictionary, quests: Quests) -> bool:
	return quests.player().inventory.held_item() == StringName(fields["item"])


func hand_over(fields: Dictionary, quests: Quests) -> void:
	quests.player().inventory.remove(StringName(fields["item"]), fields["count"])
