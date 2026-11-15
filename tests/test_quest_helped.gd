extends QuestsCase
## What the village makes of a quest that is handed in (the deed `helped`): it is written down, the
## giver and whoever is near see it, and the judge's fixed verdict moves their opinion of them.

const NOON := 12 * GameClock.MINUTES_PER_HOUR

var _antje: Npc
var _gesche: Npc


func before_each() -> void:
	super.before_each()
	_antje = _state.npcs.find(ANTJE)
	_gesche = _state.npcs.find(GESCHE)
	_state.player.position = Vector2(2.5, 2.5)
	_state.clock.minute_of_day = NOON


func _complete_a_quest_worth(steps: int) -> void:
	_use_rules({"a": {"reward": {"items": {"wax": 1}, "opinion_steps": steps}}})
	_quests.post("a", ANTJE)
	QuestTalk.complete(_state, _quests.entry_of("a"))


func _verdict_of(npc: Npc) -> int:
	var story := npc.stories[0]
	_state.judge.settle(npc, story, _state.judge.fixed_verdict(story))
	return npc.opinion


func test_handing_in_writes_the_deed_down_as_seen_by_the_giver() -> void:
	_complete_a_quest_worth(1)

	var entry := _state.deeds.entries[0]

	assert_eq(entry["kind"], GossipRules.HELPED)
	assert_eq(entry["place"], "by Antje's house")
	assert_eq(entry["witnesses"], ["Antje Boysen", "Gesche Hansen"], "Gesche stood near")
	assert_eq(_antje.stories[0]["kind"], GossipRules.HELPED)
	assert_eq(_antje.stories[0]["how"], GossipRules.SEEN)


func test_a_villager_out_of_sight_does_not_see_it_but_the_giver_always_does() -> void:
	_gesche.position = Vector2(500.0, 500.0)
	_antje.position = Vector2(500.0, 500.0)

	_complete_a_quest_worth(1)

	assert_eq(_state.deeds.entries[0]["witnesses"], ["Antje Boysen"])
	assert_true(_gesche.stories.is_empty())


func test_one_step_is_the_fixed_change_of_one() -> void:
	_complete_a_quest_worth(1)

	assert_eq(_antje.stories[0]["kind"], GossipRules.HELPED)
	assert_eq(_verdict_of(_antje), 10, "one step is 10 points")


func test_two_steps_are_the_fixed_change_of_two() -> void:
	_complete_a_quest_worth(2)

	assert_eq(_antje.stories[0]["kind"], GossipRules.HELPED_MUCH)
	assert_eq(_verdict_of(_antje), 20, "two steps are 20 points, the day's cap")


func test_a_quest_with_no_opinion_reward_is_no_deed() -> void:
	_use_rules({"a": {"reward": {"items": {"wax": 1}}}})
	_quests.post("a", ANTJE)

	QuestTalk.complete(_state, _quests.entry_of("a"))

	assert_true(_state.deeds.entries.is_empty())
	assert_true(_antje.stories.is_empty())


func test_the_helped_deeds_are_known_kinds_with_words() -> void:
	var rules := GossipRules.default_rules()

	assert_eq(rules.problems(), [] as Array[String])
	assert_eq(GossipRules.help_kind(1), GossipRules.HELPED)
	assert_eq(GossipRules.help_kind(2), GossipRules.HELPED_MUCH)
	assert_eq(rules.deed_words(GossipRules.HELPED, 1), "help a neighbour with an errand")
	assert_eq(rules.opinion_change(GossipRules.HELPED_MUCH), 2)
