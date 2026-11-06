extends GutTest
## What villagers say back: for now always the stub's line, after a moment, to be awaited.


func test_a_villager_answers_the_stub_line() -> void:
	var npc := Npc.create(1, Vector2.ZERO, NpcRules.default_rules())
	var answer: String = await NpcDialogue.reply(npc, npc.chat_history, "Good morning")
	assert_eq(answer, NpcDialogue.STUB_REPLY)


func test_the_answer_comes_later_while_the_game_is_paused() -> void:
	var npc := Npc.create(1, Vector2.ZERO, NpcRules.default_rules())
	get_tree().paused = true
	var start := Time.get_ticks_msec()
	var answer: String = await NpcDialogue.reply(npc, [], "Is the dyke holding?")
	get_tree().paused = false
	assert_eq(answer, NpcDialogue.STUB_REPLY)
	assert_gte(Time.get_ticks_msec() - start, int(NpcDialogue.THINKING_SECONDS * 900))
