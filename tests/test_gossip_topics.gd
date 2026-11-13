extends GutTest
## The topics of the village pass between villagers who meet (GossipSpread): a villager who knows
## one teaches it to one who lacks it, one a meeting, in the order of the data file.

var _state: GameState
var _spread: GossipSpread
var _topics: Array[String]


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.clock.day = 3
	_spread = GossipSpread.new(_state.npcs, _state.deeds)
	_spread.rng.seed = 1
	_topics = VillageSheet.default_sheet().topic_names()
	_set_topic_chance(1.0)


func _set_topic_chance(chance: float) -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["meetings"]["chance_topic"] = chance
	_spread.rules = SpreadRules.new(values)


func _local(x: float) -> Npc:
	var npc := Npc.create_villager("antje", Vector2(x, 0.0), _state.npcs.villagers)
	_state.npcs.add(npc)
	return npc


func _newcomer(x: float) -> Npc:
	var npc := Npc.create(x as int + 42, Vector2(x, 0.0), _state.npcs.rules)
	_state.npcs.add(npc)
	return npc


func _meet_now() -> void:
	_spread.advance(1, _state.clock)


func test_a_local_teaches_a_newcomer_one_topic_a_meeting_in_the_order_of_the_file() -> void:
	_local(0.0)
	var newcomer := _newcomer(2.0)

	_meet_now()

	assert_eq(newcomer.topics, [_topics[0]] as Array[String])

	_state.clock.advance(_spread.rules.pair_wait_minutes())
	_meet_now()

	assert_eq(newcomer.topics, [_topics[0], _topics[1]] as Array[String])


func test_the_dice_decide_whether_a_topic_is_taught() -> void:
	_set_topic_chance(0.0)
	_local(0.0)
	var newcomer := _newcomer(2.0)

	_meet_now()

	assert_true(newcomer.topics.is_empty())


func test_a_newcomer_who_has_learned_a_topic_teaches_it_to_another() -> void:
	var first := _newcomer(0.0)
	var second := _newcomer(2.0)
	first.topics.assign([_topics[2], _topics[3]])

	_meet_now()

	assert_eq(second.topics, [_topics[2]] as Array[String])
	assert_eq(first.topics, [_topics[2], _topics[3]] as Array[String])


func test_two_newcomers_who_know_none_teach_nothing_and_two_locals_nothing_more() -> void:
	var first := _newcomer(0.0)
	var second := _newcomer(2.0)
	var local := _local(20.0)
	var other_local := _local(22.0)

	_meet_now()

	assert_true(first.topics.is_empty() and second.topics.is_empty())
	assert_eq(local.topics, _topics)
	assert_eq(other_local.topics, _topics)


func test_a_topic_is_not_taught_across_the_village() -> void:
	_local(0.0)
	var newcomer := _newcomer(10.0)

	_meet_now()

	assert_true(newcomer.topics.is_empty())


func test_a_topic_is_knowledge_not_a_story() -> void:
	var local := _local(0.0)
	var newcomer := _newcomer(2.0)

	_meet_now()

	assert_true(local.stories.is_empty())
	assert_true(newcomer.stories.is_empty())
	assert_true(_state.judge.next_in_queue().is_empty())
