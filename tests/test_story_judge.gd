extends GutTest
## What a villager makes of a story (StoryJudge): the queue of stories not judged yet, the verdict
## of a model's reply or the fixed one, and what settling it does to the story and to the opinion
## of the player (the daily cap and the share for what was only heard: test_npc_opinion.gd).

var _state: GameState
var _judge: StoryJudge
var _antje: Npc
var _rules := GossipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.clock.day = 3
	_judge = _state.judge
	_antje = Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_antje)


## A story of 7 felled trees that `_antje` came to know at the game minute `learned_at`.
func _story(how: StringName, learned_at := 0, is_judged := false) -> Dictionary:
	var story := {
		"day": 3,
		"minute": 600,
		"kind": GossipRules.FELLED,
		"count": 7,
		"place": "by Antje's house",
		"origin": "3|felled|by Antje's house",
		"how": how,
		"told_by": "Moiken Ketels" if how == GossipRules.HEARD else "",
		"seen_by": "Moiken Ketels",
		"hops": 0 if how == GossipRules.SEEN else 1,
		"learned_at": learned_at,
		"line": "",
		"is_judged": is_judged,
		"weight": MemoryWeight.LOW,
		"personal": false,
	}
	_antje.stories.append(story)
	return story


func _verdict(change: int, is_personal := false) -> Dictionary:
	return {"line": "I saw it.", "change": change, "personal": is_personal}


func test_the_queue_is_the_stories_not_judged_the_one_learned_first_first() -> void:
	_story(GossipRules.SEEN, 500, true)
	var later := _story(GossipRules.SEEN, 900)
	var earlier := _story(GossipRules.HEARD, 700)
	assert_eq(_judge.next_in_queue(), {"npc": _antje, "story": earlier})
	earlier["is_judged"] = true
	assert_eq(_judge.next_in_queue(), {"npc": _antje, "story": later})
	later["is_judged"] = true
	assert_eq(_judge.next_in_queue(), {})


func test_the_fixed_verdict_is_the_change_of_the_kind_with_no_line() -> void:
	assert_eq(
		_judge.fixed_verdict(_story(GossipRules.SEEN)),
		{"line": "", "change": _rules.opinion_change(GossipRules.FELLED), "personal": false}
	)


func test_a_reply_in_json_is_the_verdict() -> void:
	var reply := '{"line": "I saw the newcomer fell the ash.", "change": -2, "personal": true}'
	assert_eq(
		StoryJudge.parse_verdict(reply, _antje, 2),
		{"line": "I saw the newcomer fell the ash.", "change": -2, "personal": true}
	)


func test_a_verdict_is_found_in_a_code_fence_and_among_words() -> void:
	var json := '{"line": "Moiken told me.", "change": 1.0, "personal": false}'
	var reply := "Here you are:\n```json\n%s\n```" % json
	assert_eq(
		StoryJudge.parse_verdict(reply, _antje, 2),
		{"line": "Moiken told me.", "change": 1, "personal": false}
	)


func test_the_line_of_a_verdict_is_cut_to_its_sentences() -> void:
	var reply := '{"line": "One. Two. Three.", "change": 0, "personal": false}'
	assert_eq(StoryJudge.parse_verdict(reply, _antje, 2)["line"], "One. Two.")


func test_a_reply_that_is_no_verdict_is_empty() -> void:
	var replies := [
		"",
		"I think well of it.",
		"{not json}",
		"[1, 2]",
		'{"line": "Aye.", "change": 3, "personal": false}',
		'{"line": "Aye.", "change": -3, "personal": false}',
		'{"line": "Aye.", "change": 1.5, "personal": false}',
		'{"line": "Aye.", "change": "1", "personal": false}',
		'{"line": "Aye.", "change": true, "personal": false}',
		'{"line": "Aye.", "change": 1, "personal": "yes"}',
		'{"line": "Aye.", "change": 1}',
		'{"change": 1, "personal": false}',
		'{"line": "", "change": 1, "personal": false}',
		'{"line": 7, "change": 1, "personal": false}',
	]
	for reply: String in replies:
		assert_eq(StoryJudge.parse_verdict(reply, _antje, 2), {}, reply)


func test_settling_a_verdict_judges_the_story_and_moves_the_opinion_by_the_change() -> void:
	var story := _story(GossipRules.SEEN)
	_judge.settle(_antje, story, _verdict(-1))
	assert_true(story["is_judged"])
	assert_eq(story["line"], "I saw it.")
	assert_eq(_antje.opinion, -_rules.opinion_points(1, GossipRules.SEEN))
	assert_eq(_antje.opinion, -10)


func test_what_was_only_heard_moves_the_opinion_by_half() -> void:
	_judge.settle(_antje, _story(GossipRules.HEARD), _verdict(1))
	assert_eq(_antje.opinion, 5)


func test_the_opinion_moves_on_the_day_of_the_clock_up_to_its_cap() -> void:
	for _each in 5:
		_judge.settle(_antje, _story(GossipRules.SEEN), _verdict(2))
	assert_eq(_antje.opinion, _rules.opinion_daily_cap())
	_state.clock.day = 4
	_judge.settle(_antje, _story(GossipRules.SEEN), _verdict(2))
	assert_eq(_antje.opinion, _rules.opinion_daily_cap() + 20)


func test_a_personal_story_weighs_high_and_one_that_was_high_stays_so() -> void:
	var personal := _story(GossipRules.SEEN)
	_judge.settle(_antje, personal, _verdict(0, true))
	assert_eq([personal["personal"], personal["weight"]], [true, MemoryWeight.HIGH])
	var plain := _story(GossipRules.SEEN)
	plain["weight"] = MemoryWeight.HIGH
	_judge.settle(_antje, plain, _verdict(0))
	assert_eq(plain["weight"], MemoryWeight.HIGH)
	var light := _story(GossipRules.HEARD)
	_judge.settle(_antje, light, _verdict(0))
	assert_eq([light["personal"], light["weight"]], [false, MemoryWeight.LOW])


func test_a_story_in_its_own_words_is_told_by_that_line() -> void:
	var story := _story(GossipRules.HEARD)
	var template := _rules.story_line(story, 0)
	assert_string_contains(template, "Moiken told you")
	_judge.settle(_antje, story, _verdict(0))
	assert_eq(_rules.story_line(story, 0), 'Today, in your own words: "I saw it."')
	assert_eq(_rules.story_line(story, 1), 'Yesterday, in your own words: "I saw it."')
	assert_eq(_rules.story_line(story, 5), '5 days ago, in your own words: "I saw it."')
	assert_eq(_rules.memory_line(story), "On day 3: I saw it.")


func test_the_opinion_points_are_the_steps_of_the_data_file_in_full_or_by_half() -> void:
	assert_eq(_rules.opinion_points(2, GossipRules.SEEN), 20)
	assert_eq(_rules.opinion_points(-2, GossipRules.HEARD), -10)
	assert_eq(_rules.opinion_points(0, GossipRules.SEEN), 0)
