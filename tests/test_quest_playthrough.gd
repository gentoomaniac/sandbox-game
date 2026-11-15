extends GutTest
## The first days of a new game in the village, with the real quests of data/quests/ (the play-test
## of #12 as a test): the starter of day 1 is posted, taken, handed in and paid; a quest a day comes
## after it, never above the limits; one that is not taken goes away; and the fence quest is done by
## putting fence up by the giver's home.

const DAY := GameClock.MINUTES_PER_DAY

var _state: GameState
var _quests: Quests


func before_each() -> void:
	_state = GameState.new_game(1, true)
	_quests = _state.quests
	_state.player.inventory = Inventory.new()
	_state.player.position = Vector2(_state.world.village.meeting_spot) + Vector2(0.5, 0.5)


func _giver_of(entry: Dictionary) -> Npc:
	return _state.npcs.find(entry["giver"])


## Gives the player what a bring quest asks for, in hand.
func _bring_what_is_asked(entry: Dictionary) -> void:
	var objective: Dictionary = _quests.rules.quest(entry["id"])["objective"]
	var item := StringName(objective["item"])
	_state.player.inventory.add(item, objective["count"])
	_state.player.inventory.hold(item)


func test_day_one_posts_a_starter_that_is_taken_handed_in_and_paid() -> void:
	var entry := _quests.open_entries()[0]
	var id: String = entry["id"]
	var giver := _giver_of(entry)
	assert_true(_quests.rules.is_starter(id))
	assert_eq(entry["posted_day"], 1)
	assert_eq(BoardNotices.lines(_state).size(), 1, "the board has its notice")
	assert_true(QuestRows.of(_state).is_empty(), "not in the list before it is taken")

	assert_eq(QuestTalk.greet_and_say(_state, giver), "")
	assert_eq(QuestRows.of(_state).size(), 1, "taken: it is in the list")
	var dialogue: Array = _quests.rules.quest(id)["dialogue"]
	assert_eq(
		giver.chat_history.map(func(line: Dictionary) -> String: return line["text"]), dialogue
	)

	_bring_what_is_asked(entry)
	var seeds_before := _state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS)
	QuestTalk.greet_and_say(_state, giver)

	assert_true(_quests.is_done(id))
	assert_false(_quests.is_open(id))
	assert_gt(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), seeds_before)
	assert_eq(_state.deeds.entries[0]["kind"], GossipRules.HELPED)
	var story := giver.stories[0]
	_state.judge.settle(giver, story, _state.judge.fixed_verdict(story))
	assert_eq(giver.opinion, 10, "one step")


func test_a_quest_a_day_within_the_limits_and_a_missed_one_goes_away() -> void:
	var posted_on := {}
	for entry in _quests.open_entries():
		posted_on[entry["id"]] = entry["posted_day"]
	for day in range(2, 26):
		_state.clock.advance(DAY)
		var posted_today := 0
		for entry in _quests.open_entries():
			assert_true(_quests.rules.last_day_of(entry) >= _state.clock.day, "no stale quest")
			if entry["posted_day"] == _state.clock.day:
				posted_today += 1
			posted_on[entry["id"]] = entry["posted_day"]
		assert_lte(posted_today, 1, "day %d" % day)
		assert_lte(_quests.open_entries().size(), _quests.rules.max_open())

	assert_gt(posted_on.size(), 1, "more than the first came")
	var starter: String = posted_on.keys()[0]
	assert_false(_quests.is_open(starter), "the one nobody took has gone")
	assert_false(_quests.is_done(starter))


func test_the_fence_quest_is_done_by_putting_up_fence_by_the_home() -> void:
	var rules := _quests.rules
	_quests.clear()
	_state.clock.day = 12
	var giver := _state.npcs.find("gesche")
	assert_not_null(giver.house, "she has a house in the village")
	assert_eq(_quests.post("wattle_for_the_garden", "gesche"), "")
	QuestTalk.greet_and_say(_state, giver)
	var door := giver.house.door_tile()
	var chunk_coords := Chunk.world_to_chunk(door)
	_state.world.add_chunk(WorldGenerator.new(1).generate_chunk(chunk_coords))
	for index in 6:
		var tile := door + Vector2i(index, 2)
		_state.world.remove_object(tile)
		var fence := WorldObject.new(WorldObjectTypes.WATTLE_FENCE, tile)
		fence.state["placed_day"] = 12
		_state.world.add_object(fence)
	giver.chat_history.clear()

	QuestTalk.greet_and_say(_state, giver)

	assert_true(_quests.is_done("wattle_for_the_garden"))
	assert_eq(_state.player.inventory.count_of(ItemTypes.WAX), 2)
	assert_eq(
		giver.chat_history.size(), (rules.quest("wattle_for_the_garden")["turn_in"] as Array).size()
	)
