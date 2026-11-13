extends SaveValidationCase
## The long-term memories of a villager are saved with their day and weight; a save from before
## the weights (version 34) has them as plain lines, which load as medium.


func _saved_villager_with(memories: Array) -> Dictionary:
	var saved: Dictionary = JSON.parse_string(
		JSON.stringify(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict())
	)
	saved["memories"] = memories
	return saved


func test_a_version_34_save_loads_its_memories_as_medium() -> void:
	var game := _current_game()
	game["npcs"] = [_saved_villager_with(["On the 1st day: one.", "On the 2nd day: two."])]
	_write_save(34, game)

	var loaded := SaveFile.read(SAVE_PATH).npcs.all()[0]

	assert_eq(loaded.memories.size(), 2)
	assert_eq(loaded.memories[1]["text"], "On the 2nd day: two.")
	assert_eq(loaded.memories[1]["weight"], MemoryWeight.MEDIUM)


func test_a_memory_without_a_known_weight_or_day_is_refused() -> void:
	var game := _current_game()
	var memories := [{"day": 1, "text": "x", "weight": "huge"}, {"text": "y", "weight": "low"}]
	game["npcs"] = [_saved_villager_with(memories)]

	var problems: Array = _refusal_of(game).problems

	assert_true(problems.has("npcs 0 memories 0: unknown weight huge"), str(problems))
	assert_true(problems.has("npcs 0 memories 1: no day"), str(problems))
