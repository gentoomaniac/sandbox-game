extends GutTest
## What a villager is told of the deeds they saw (NpcPrompt `reply_messages`): the template line.

var _rules := NpcTalkRules.default_rules()
var _antje: Npc
var _moment: NpcMoment


func before_each() -> void:
	_antje = Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	_moment = NpcMoment.new()


func _last_turn() -> String:
	var messages := NpcPrompt.reply_messages(_antje, [], "Moin!", _moment, _rules, true)
	return messages[-1]["content"]


func _story(how: StringName, place: String) -> Dictionary:
	return {
		"day": 3,
		"minute": 600,
		"kind": GossipRules.FELLED,
		"count": 7,
		"place": place,
		"how": how,
		"told_by": "Moiken Jessen" if how == GossipRules.HEARD else "",
	}


func test_a_villager_who_saw_nothing_is_told_nothing_of_the_kind() -> void:
	assert_false(_last_turn().contains("you saw"))


func test_a_villager_is_told_what_they_saw_after_their_memories() -> void:
	_moment.clock.day = 3
	_antje.add_memory("A memory.", 2, MemoryWeight.MEDIUM, 20)
	_antje.stories.append(_story(GossipRules.SEEN, "by Antje's house"))

	var last := _last_turn()

	assert_string_contains(last, "Today you saw the newcomer fell 7 trees by Antje's house.")
	assert_lt(last.find("A memory."), last.find("Today you saw"))
	assert_lt(last.find("Today you saw"), last.find("Moin!"))


func test_a_villager_is_told_who_told_them_of_a_deed_they_heard() -> void:
	_moment.clock.day = 3
	_antje.stories.append(_story(GossipRules.HEARD, "by Antje's house"))

	assert_string_contains(
		_last_turn(),
		"Today Moiken told you that the newcomer was seen to fell 7 trees by Antje's house.",
	)
	assert_false(_last_turn().contains("you saw"))


func test_the_prompt_tells_knowledge_then_memories_then_stories_then_the_chat() -> void:
	_moment.clock.day = 3
	_antje.add_memory("A memory.", 2, MemoryWeight.MEDIUM, 20)
	_antje.stories.append(_story(GossipRules.SEEN, "here"))
	var history: Array[Dictionary] = [
		{"day": 3, "minute": 590, "from_player": true, "text": "Earlier line."}
	]

	var messages := NpcPrompt.reply_messages(_antje, history, "Moin!", _moment, _rules, true)
	var text := "\n".join(
		messages.map(func(message: Dictionary) -> String: return message["content"])
	)

	assert_lt(text.find("a farmer's wife"), text.find("Earlier line."), "the sheet first")
	assert_lt(text.find("Earlier line."), text.find("A memory."))
	assert_lt(text.find("A memory."), text.find("you saw the newcomer"))
