extends GutTest
## Who says a line in a bubble, when and what (NpcBubbles, [bubble] and [bubble_lines] of
## data/npc_talk.cfg): about one a minute, by a villager in view, about the moment or the player.

const HEAD := 62.0
const TILE := TerrainTileset.TILE_SIZE

var _rules := NpcTalkRules.default_rules()
var _villagers := VillagerRules.default_rules()
var _bubbles: NpcBubbles
var _antje: Npc
var _momme: Npc


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_bubbles = NpcBubbles.new(_rules, rng)
	_antje = Npc.create_villager("antje", Vector2(10, 10), _villagers)
	_momme = Npc.create_villager("momme", Vector2(30, 10), _villagers)


## The camera shows 20 by 12 tiles from the tile (5, 5).
func _region() -> Rect2:
	return Rect2(Vector2(5, 5) * TILE, Vector2(20, 12) * TILE)


## 08:15, a clear sky, light rain if `rain` is above 0.
func _moment(rain := 0.0) -> NpcMoment:
	var moment := NpcMoment.new()
	moment.clock.set_time(8, 15)
	moment.sunrise = 6 * 60
	moment.solar_noon = 12 * 60 + 30
	moment.sunset = 19 * 60
	moment.weather.rain = rain
	return moment


func test_the_data_file_has_lines_for_every_moment() -> void:
	assert_true(_rules.is_valid(), "problems: %s" % [_rules.problems()])


func test_a_line_that_is_too_long_or_a_missing_one_is_a_problem() -> void:
	var values := DataFile.read_sections(NpcTalkRules.DEFAULT_PATH)
	values["bubble_lines"] = {
		"weather": {"hail": ["Hail."]},
		"part_of_day": {"dawn": ["x".repeat(61)], "morning": []},
		"near_player": {"cold": ["Hm."]},
	}
	var problems := NpcTalkRules.new(values).problems()
	assert_has(problems, "[bubble_lines] weather: hail is not a condition")
	assert_has(problems, "[bubble_lines] part_of_day has no noon")
	assert_has(problems, "[bubble_lines] near_player has no warm")
	assert_has(problems, "[bubble_lines] part_of_day morning is not a list of at least one line")
	assert_eq(problems.filter(func(p: String) -> bool: return "dawn" in p).size(), 1)


func test_the_next_bubble_comes_about_a_minute_after_the_last() -> void:
	var waits: Array[float] = []
	for round in 20:
		_bubbles.restart_wait()
		var seconds := 0.0
		while not _bubbles.is_due():
			_bubbles.advance(1.0)
			seconds += 1.0
		waits.append(seconds)
	assert_between(waits.min(), 30.0, 90.0)
	assert_between(waits.max(), 30.0, 90.0)
	assert_gt(waits.max(), waits.min(), "the waits differ")


func test_a_bubble_is_not_due_before_its_time_and_stays_due_until_the_wait_restarts() -> void:
	_bubbles.restart_wait()
	_bubbles.advance(10.0)
	assert_false(_bubbles.is_due())
	_bubbles.advance(200.0)
	assert_true(_bubbles.is_due())
	_bubbles.advance(1.0)
	assert_true(_bubbles.is_due())
	_bubbles.restart_wait()
	assert_false(_bubbles.is_due())


func test_a_villager_is_in_view_only_with_feet_and_the_head_bubble_in_it() -> void:
	assert_true(NpcBubbles.is_in_view(Vector2(10, 10), HEAD, _region()))
	assert_false(NpcBubbles.is_in_view(Vector2(30, 10), HEAD, _region()), "out at the side")
	assert_false(NpcBubbles.is_in_view(Vector2(10, 5.5), HEAD, _region()), "head above the top")
	assert_false(NpcBubbles.is_in_view(Vector2(10, 17.5), HEAD, _region()), "feet below")


func test_only_a_villager_in_view_speaks() -> void:
	var npcs: Array[Npc] = [_antje, _momme]
	for round in 10:
		assert_eq(_bubbles.pick_speaker(npcs, _region(), HEAD), _antje)
	npcs = [_momme]
	assert_null(_bubbles.pick_speaker(npcs, _region(), HEAD))


func test_one_who_answers_the_player_does_not_speak() -> void:
	_antje.is_answering = true
	var npcs: Array[Npc] = [_antje]
	assert_null(_bubbles.pick_speaker(npcs, _region(), HEAD))


func test_the_speaker_is_drawn_among_those_in_view() -> void:
	_momme.position = Vector2(12, 10)
	var npcs: Array[Npc] = [_antje, _momme]
	var seen := {}
	for round in 30:
		seen[_bubbles.pick_speaker(npcs, _region(), HEAD)] = true
	assert_eq(seen.size(), 2)


func test_a_villager_far_from_the_player_speaks_of_the_moment() -> void:
	for round in 20:
		assert_eq(_bubbles.subject_for(_antje, Vector2(20, 10)), NpcBubbles.Subject.MOMENT)


func test_a_villager_near_the_player_speaks_of_them_now_and_then() -> void:
	var subjects := {}
	for round in 40:
		subjects[_bubbles.subject_for(_antje, Vector2(12, 10))] = true
	assert_has(subjects, NpcBubbles.Subject.PLAYER)
	assert_has(subjects, NpcBubbles.Subject.MOMENT)


func test_the_line_in_rain_is_about_the_rain() -> void:
	var rain_lines: Array = _rules.value("bubble_lines", "weather")["rain"]
	for round in 20:
		var line := _bubbles.scripted_line(_antje, _moment(0.3), NpcBubbles.Subject.MOMENT)
		assert_has(rain_lines, line)


func test_the_line_in_fair_weather_is_about_the_part_of_the_day() -> void:
	var morning_lines: Array = _rules.value("bubble_lines", "part_of_day")["morning"]
	for round in 20:
		var line := _bubbles.scripted_line(_antje, _moment(), NpcBubbles.Subject.MOMENT)
		assert_has(morning_lines, line)


func test_the_line_about_the_player_follows_what_the_villager_thinks_of_them() -> void:
	var lines: Dictionary = _rules.value("bubble_lines", "near_player")
	for opinion_and_word in [[-50, "cold"], [0, "neutral"], [50, "warm"]]:
		_antje.opinion = opinion_and_word[0]
		var line := _bubbles.scripted_line(_antje, _moment(0.3), NpcBubbles.Subject.PLAYER)
		assert_has(lines[opinion_and_word[1]], line)


func _asked(subject: NpcBubbles.Subject, full_sheets := false) -> String:
	var request := _bubbles.request(_antje, _moment(0.3), subject, full_sheets)
	return request["messages"][1]["content"]


func test_the_request_tells_the_sheet_the_moment_and_what_to_say_about_it() -> void:
	var request := _bubbles.request(_antje, _moment(0.3), NpcBubbles.Subject.MOMENT, false)
	assert_eq(request["messages"][0]["role"], "system")
	assert_eq(request["messages"][0]["content"], _rules.value("bubble", "system"))
	var asked := _asked(NpcBubbles.Subject.MOMENT)
	assert_string_contains(asked, NpcPrompt.sheet_text(_antje, false, _rules))
	assert_string_contains(asked, "light rain")
	assert_string_contains(asked, "in the morning")
	assert_string_contains(asked, "something about the weather")
	assert_true(asked.ends_with("Antje's remark:"), asked)
	assert_false(asked.contains("newcomer"))
	assert_eq(request["max_tokens"], _rules.value("bubble", "max_tokens"))
	assert_eq(request["temperature"], _rules.value("request", "temperature"))


func test_a_hosted_model_is_told_the_full_sheet() -> void:
	assert_string_contains(_asked(NpcBubbles.Subject.MOMENT, true), "Secrets, at most hinted at")
	assert_false(_asked(NpcBubbles.Subject.MOMENT).contains("Secrets, at most hinted at"))


func _story(day: int, place: String) -> Dictionary:
	return {
		"day": day,
		"minute": 600,
		"kind": GossipRules.FELLED,
		"count": 7,
		"place": place,
		"origin": "%d|felled|%s" % [day, place],
		"how": GossipRules.SEEN,
		"told_by": "",
		"seen_by": "Antje Boysen",
		"hops": 0,
		"learned_at": 0,
		"line": "",
		"is_judged": true,
		"weight": MemoryWeight.MEDIUM,
		"personal": false,
	}


func test_a_request_about_the_player_tells_the_opinion_and_the_newest_stories() -> void:
	_antje.opinion = 50
	for place in ["by the old ash", "by the mill", "by the dyke"]:
		_antje.stories.append(_story(12, place))
	var asked := _asked(NpcBubbles.Subject.PLAYER)
	assert_string_contains(asked, "does not know their name")
	assert_string_contains(asked, "thinks well of this neighbour")
	assert_string_contains(asked, "something about them")
	assert_false(asked.contains("by the old ash"))
	assert_string_contains(asked, "by the mill")
	assert_string_contains(asked, "by the dyke")
	assert_lt(asked.find("by the dyke"), asked.find("Antje's remark:"))


func test_the_line_of_an_answer_is_its_first_sentence_without_quotes_or_label() -> void:
	assert_eq(_bubbles.line_from_answer('"Rain again, aye."', _antje), "Rain again, aye.")
	assert_eq(_bubbles.line_from_answer("Antje's remark: Cold. Very cold.", _antje), "Cold.")
	assert_eq(_bubbles.line_from_answer("", _antje), "")


func test_an_answer_of_more_than_the_longest_line_is_dropped() -> void:
	var longest: int = _rules.value("bubble", "max_length")
	assert_ne(_bubbles.line_from_answer("x".repeat(longest), _antje), "")
	assert_eq(_bubbles.line_from_answer("x".repeat(longest + 1), _antje), "")
