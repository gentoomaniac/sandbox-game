extends SaveValidationCase
## The deed log and the stories of the villagers are saved; saves from before their later
## changes are upgraded.


func _state_with_a_deed_seen_by_antje() -> GameState:
	var state := GameState.new_game(7)
	var antje := Npc.create_villager("antje", Vector2(3.5, 4.5), state.npcs.villagers)
	state.npcs.add(antje)
	state.clock.day = 4
	state.clock.minute_of_day = 745
	state.report(ActionOutcome.BREAK, Vector2i(3, 4), WorldObjectTypes.OAK, {})
	state.report(ActionOutcome.BREAK, Vector2i(3, 4), WorldObjectTypes.OAK, {})
	return state


func test_the_deed_log_and_the_stories_are_kept() -> void:
	var state := _state_with_a_deed_seen_by_antje()
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH)

	assert_eq(loaded.deeds.entries.size(), 1)
	var entry := loaded.deeds.entries[0]
	assert_eq(entry, state.deeds.entries[0])
	assert_eq(entry["kind"], GossipRules.FELLED)
	assert_eq(entry["count"], 2)
	assert_eq(loaded.npcs.all()[0].stories, state.npcs.all()[0].stories)


func test_a_story_heard_is_kept_with_who_told_it() -> void:
	var state := _state_with_a_deed_seen_by_antje()
	var antje := state.npcs.all()[0]
	var momme := Npc.create_villager("momme", antje.position + Vector2.RIGHT, state.npcs.villagers)
	state.npcs.add(momme)
	state.clock.advance(3 * GameClock.MINUTES_PER_HOUR)
	var spread := GossipSpread.new(state.npcs, state.deeds)
	spread.rules = SpreadRules.default_rules()
	spread.rng.seed = 3
	for _hour in 24:
		spread.advance(60, state.clock)
		state.clock.advance(60)
	assert_eq(momme.stories.size(), 1, "told within a day")
	assert_true(SaveFile.write(state, SAVE_PATH))

	var heard := SaveFile.read(SAVE_PATH).npcs.all()[1].stories[0]

	assert_eq(heard, momme.stories[0])
	assert_eq([heard["how"], heard["told_by"], heard["hops"]], [GossipRules.HEARD, antje.name, 1])


func test_a_story_without_an_origin_or_a_minute_learned_is_refused() -> void:
	var game: Dictionary = JSON.parse_string(
		JSON.stringify(_state_with_a_deed_seen_by_antje().to_dict())
	)
	game["npcs"][0]["stories"][0].erase("origin")
	game["npcs"][0]["stories"][0]["learned_at"] = "yesterday"

	var problems: Array = _refusal_of(game).problems

	assert_true(problems.has("npcs 0 stories 0: no origin"), str(problems))
	assert_eq(problems.size(), 2, str(problems))


func test_a_deed_of_an_unknown_kind_or_without_a_place_is_refused() -> void:
	var state := _state_with_a_deed_seen_by_antje()
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	game["deeds"][0]["kind"] = "pilfered"
	game["npcs"][0]["stories"][0].erase("place")
	game["npcs"][0]["stories"][0]["weight"] = "huge"

	var problems: Array = _refusal_of(game).problems

	assert_true(problems.has("deeds 0: unknown deed pilfered"), str(problems))
	assert_true(problems.has("npcs 0 stories 0: no place"), str(problems))
	assert_true(problems.has("npcs 0 stories 0: unknown weight huge"), str(problems))


func test_a_story_not_judged_yet_is_still_in_the_queue_after_loading() -> void:
	var state := _state_with_a_deed_seen_by_antje()
	var antje := state.npcs.all()[0]
	var felled := state.judge.next_in_queue()
	assert_false(felled["story"]["is_judged"])
	state.judge.settle(antje, felled["story"], state.judge.fixed_verdict(felled["story"]))
	state.report(ActionOutcome.TILL, Vector2i(3, 4), &"", {})
	assert_true(SaveFile.write(state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH)

	var queued := loaded.judge.next_in_queue()
	assert_eq(queued["story"]["kind"], GossipRules.TILLED, "the felled trees were judged")
	assert_false(queued["story"]["is_judged"])
	assert_true(loaded.npcs.all()[0].stories[0]["is_judged"])
	assert_eq(loaded.npcs.all()[0].opinion, antje.opinion)


func test_a_story_without_the_mark_that_it_is_judged_is_refused() -> void:
	var game: Dictionary = JSON.parse_string(
		JSON.stringify(_state_with_a_deed_seen_by_antje().to_dict())
	)
	game["npcs"][0]["stories"][0].erase("is_judged")

	var problems: Array = _refusal_of(game).problems

	assert_eq(problems, ["npcs 0 stories 0: no is_judged"])
