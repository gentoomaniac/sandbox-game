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


func test_a_villager_who_saw_nothing_is_told_nothing_of_the_kind() -> void:
	assert_false(_last_turn().contains("you saw"))


func test_a_villager_is_told_what_they_saw_after_their_memories() -> void:
	_moment.clock.day = 3
	_antje.add_memory("A memory.", 2, MemoryWeight.MEDIUM, 20)
	var story := {"day": 3, "minute": 600, "kind": GossipRules.FELLED, "count": 7}
	story["place"] = "by Antje's house"
	_antje.stories.append(story)

	var last := _last_turn()

	assert_string_contains(last, "Today you saw the newcomer fell 7 trees by Antje's house.")
	assert_lt(last.find("A memory."), last.find("Today you saw"))
	assert_lt(last.find("Today you saw"), last.find("Moin!"))
