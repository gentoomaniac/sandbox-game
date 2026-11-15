class_name BuildObjective
extends QuestObjective
## Put up `count` pieces of the world object `object` within `radius` tiles of the giver's home
## (`near` is "home", the only place so far). Only pieces the player put down on or after the day
## the quest was posted count, and only those that still stand: an old fence is no cheat, and a
## piece taken down is gone. The player does not hand anything over: speaking to the giver counts
## what stands.

const HOME := "home"


func kind() -> String:
	return "build"


func problems(fields: Dictionary) -> Array[String]:
	var found := QuestFields.whole_number(fields, "count", 1)
	found.append_array(QuestFields.whole_number(fields, "radius", 1))
	var object: Variant = fields.get("object")
	if not (object is String and ItemTypes.item_placing(StringName(object)) != &""):
		found.append("object is no object that an item puts down")
	if fields.get("near") != HOME:
		found.append("near is not %s" % HOME)
	return found


func thing(fields: Dictionary) -> String:
	return ItemTypes.TYPES[ItemTypes.item_placing(StringName(fields["object"]))]["name"].to_lower()


func placed_object(fields: Dictionary) -> StringName:
	return StringName(fields["object"])


func progress(fields: Dictionary, entry: Dictionary, quests: Quests) -> int:
	return quests.count_placed_near_home(
		entry["giver"], placed_object(fields), entry["posted_day"], fields["radius"]
	)


func goal(fields: Dictionary) -> int:
	return fields["count"]
