extends SaveValidationCase
## The long-term memories of a villager are saved with their day and weight.


func _saved_villager_with(memories: Array) -> Dictionary:
	var saved: Dictionary = JSON.parse_string(
		JSON.stringify(Npc.create(42, Vector2.ZERO, NpcRules.default_rules()).to_dict())
	)
	saved["memories"] = memories
	return saved


func test_a_memory_without_a_known_weight_or_day_is_refused() -> void:
	var game := _current_game()
	var memories := [{"day": 1, "text": "x", "weight": "huge"}, {"text": "y", "weight": "low"}]
	game["npcs"] = [_saved_villager_with(memories)]

	var problems: Array = _refusal_of(game).problems

	assert_true(problems.has("npcs 0 memories 0: unknown weight huge"), str(problems))
	assert_true(problems.has("npcs 0 memories 1: no day"), str(problems))
