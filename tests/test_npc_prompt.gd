extends GutTest
## The prompt that asks a language model for a villager's answer (NpcPrompt, data/npc_talk.cfg):
## the shape of the user's example, who the villager is, the moment in words (date, time, part
## of the day, weather, place), the earlier lines of the chat, and the answer trimmed.

var _rules := NpcTalkRules.default_rules()
var _antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())


## 08:15 on the 12th day of Spring, year 1: light rain, 9 °C and a fresh wind from the west, by
## a kate.
func _moment() -> NpcMoment:
	var moment := NpcMoment.new()
	moment.clock.day = 12
	moment.clock.set_time(8, 15)
	moment.sunrise = 6 * 60
	moment.solar_noon = 12 * 60 + 30
	moment.sunset = 19 * 60
	moment.weather.rain = 0.2
	moment.weather.temperature = 9.2
	moment.weather.wind_speed = 6.0
	moment.weather.wind_direction = Vector2.RIGHT
	moment.building = "Kate"
	return moment


func _line(from_player: bool, text: String) -> Dictionary:
	return {"day": 12, "minute": 495, "from_player": from_player, "text": text}


func _no_history() -> Array[Dictionary]:
	return []


## The last message of the prompt for Antje, for `message` said after `history`.
func _last_turn(history: Array[Dictionary], message: String) -> String:
	return (
		NpcPrompt.reply_messages(_antje, history, message, _moment(), _rules, false)[-1]["content"]
	)


# --- The data file ---


func test_the_data_file_is_valid() -> void:
	assert_true(_rules.is_valid(), "problems: %s" % [_rules.problems()])


func test_missing_keys_are_reported() -> void:
	var problems := NpcTalkRules.new({"request": {"temperature": 0.7}}).problems()
	assert_has(problems, "[request] no max_tokens")
	assert_has(problems, "[prompt] no system")
	assert_does_not_have(problems, "[request] no temperature")


func test_values_of_the_wrong_type_are_reported() -> void:
	var values := DataFile.read_sections(NpcTalkRules.DEFAULT_PATH)
	values["prompt"]["system"] = 42
	values["request"]["reply_sentences"] = "eight"
	values["request"]["temperature"] = 1
	var problems := NpcTalkRules.new(values).problems()
	assert_has(problems, "[prompt] system is not a text")
	assert_has(problems, "[request] reply_sentences is not a whole number")
	assert_eq(problems.size(), 2, "a whole number is a number too: %s" % [problems])


func test_weather_lists_must_be_pairs_of_from_and_words() -> void:
	var values := DataFile.read_sections(NpcTalkRules.DEFAULT_PATH)
	values["weather"]["rain"] = [[0.05, "light rain"], ["heavy rain"]]
	values["weather"]["conditions"] = ["rain", "hail"]
	values["scripted"]["replies"] = []
	var problems := NpcTalkRules.new(values).problems()
	assert_has(problems, "[weather] rain is not a list of [from, words]")
	assert_has(problems, "[weather] conditions: hail is not a condition")
	assert_has(problems, "[weather] hail is not a list of [from, words]")
	assert_has(problems, "[scripted] replies is not a list of at least one")


func test_every_layer_a_villager_may_wear_has_its_words() -> void:
	for layer in NpcRules.default_rules().all_layers():
		assert_ne(_rules.look_words(layer.slot, layer.variant), "", str(layer))


# --- The messages ---


func test_the_prompt_has_the_shape_of_the_example() -> void:
	var messages := NpcPrompt.reply_messages(
		_antje, [], "Good morning! Is the dyke holding after the storm?", _moment(), _rules, false
	)
	assert_eq(messages.size(), 4)
	assert_eq(messages[0]["role"], "system")
	assert_string_starts_with(messages[0]["content"], "You write dialogue lines for one villager")
	assert_eq(
		messages[1],
		{
			"role": "user",
			"content":
			(
				"Villager: Hark Nissen, a blacksmith.\n"
				+ 'His neighbour says: "Fine weather for the hay today."\n'
				+ "Hark's reply:"
			),
		}
	)
	assert_eq(messages[2]["role"], "assistant")
	assert_string_starts_with(messages[2]["content"], "Fine for the hay, aye, but the forge")
	var last: String = messages[3]["content"]
	assert_eq(messages[3]["role"], "user")
	var lines := last.split("\n")
	assert_eq(lines.size(), 8, last)
	assert_eq(lines[0], "Villager: Antje Boysen, a farmer's wife.")
	assert_string_starts_with(lines[1], "Antje is 38 years old, a pale woman with blond hair")
	assert_string_ends_with(lines[1], "and clogs.")
	assert_eq(
		lines[2],
		(
			"It is the 12th day of Spring, year 1 (mid spring), 08:15 in the morning."
			+ " The weather: light rain, 9 °C, a fresh west wind. Antje is outside the kate."
		)
	)
	assert_eq(
		lines[3], "The neighbour is a newcomer to these parts; Antje does not know their name."
	)
	assert_eq(lines[4], "Antje has no strong feelings about this neighbour yet.")
	assert_eq(lines[5], 'Her neighbour says: "Good morning! Is the dyke holding after the storm?"')
	assert_eq(lines[6], "Antje answers in English.")
	assert_eq(lines[7], "Antje's reply in English:")


func test_the_request_carries_the_numbers_of_the_data_file() -> void:
	var request := NpcPrompt.reply_request(_antje, [], "Moin", _moment(), _rules, false)
	assert_eq(request["temperature"], 0.5)
	assert_eq(request["max_tokens"], 60)
	assert_eq(request["messages"].size(), 4)


func test_earlier_lines_go_in_as_turns_of_the_same_shape() -> void:
	var history: Array[Dictionary] = [_line(true, "Moin, Antje."), _line(false, "Moin! Wet one.")]
	var messages := NpcPrompt.reply_messages(_antje, history, "Aye.", _moment(), _rules, false)
	assert_eq(messages.size(), 6)
	assert_eq(
		messages[3]["content"],
		"Villager: Antje Boysen, a farmer's wife.\nHer neighbour says: \"Moin, Antje.\"\nAntje's reply:"
	)
	assert_eq(messages[4], {"role": "assistant", "content": "Moin! Wet one."})
	assert_string_contains(messages[5]["content"], 'Her neighbour says: "Aye."')


func test_every_line_of_the_history_is_told() -> void:
	var history: Array[Dictionary] = []
	for index in 30:
		history.append(_line(index % 2 == 0, "line %d" % index))
	var messages := NpcPrompt.reply_messages(_antje, history, "And?", _moment(), _rules, false)
	assert_eq(messages.size(), 3 + 30 + 1)
	assert_eq(messages[-2]["content"], "line 29")


func test_a_man_is_his_neighbour_s() -> void:
	var momme := Npc.create_villager("momme", Vector2.ZERO, VillagerRules.default_rules())
	var last: String = (
		NpcPrompt.reply_messages(momme, [], "Moin", _moment(), _rules, false)[-1]["content"]
	)
	assert_string_contains(last, 'His neighbour says: "Moin"')
	assert_string_contains(
		last, "a sun-tanned man with short grey hair, wearing a red knitted cap,"
	)
	assert_string_ends_with(last, 'Momme\'s reply (in the language of "Moin"):')


# --- The moment in words ---


func test_the_part_of_the_day_follows_the_sun() -> void:
	var moment := _moment()
	var expected := {
		"04:00": "night",
		"05:30": "dawn",
		"08:15": "morning",
		"12:00": "noon",
		"15:00": "afternoon",
		"19:20": "dusk",
		"21:00": "night",
	}
	for time: String in expected:
		moment.clock.set_time(int(time.get_slice(":", 0)), int(time.get_slice(":", 1)))
		assert_eq(NpcPrompt.part_of_day(moment, _rules), expected[time], time)


func test_the_season_is_early_mid_or_late() -> void:
	var moment := _moment()
	moment.clock.day = 1
	assert_eq(
		NpcPrompt.moment_words(moment, _rules)["date"],
		"the 1st day of Spring, year 1 (early spring)"
	)
	moment.clock.day = 30 + 30 + 30 + 28 + 120
	assert_eq(
		NpcPrompt.moment_words(moment, _rules)["date"],
		"the 28th day of Winter, year 2 (late winter)"
	)


func test_the_weather_in_words() -> void:
	var sample := WeatherSample.new()
	sample.temperature = 14.6
	sample.cloud_cover = 0.1
	assert_eq(NpcPrompt.weather_text(sample, _rules), "a clear sky, 15 °C, still air")
	sample.cloud_cover = 0.9
	sample.wind_speed = 2.0
	sample.wind_direction = Vector2.UP
	assert_eq(NpcPrompt.weather_text(sample, _rules), "overcast, 15 °C, a light south breeze")
	sample.temperature = -3.0
	sample.snow = 0.5
	sample.wind_speed = 20.0
	sample.wind_direction = Vector2(-1, 1).normalized()
	assert_eq(NpcPrompt.weather_text(sample, _rules), "snow, -3 °C, frost, a north-east gale")
	sample.storm = 0.6
	assert_string_starts_with(NpcPrompt.weather_text(sample, _rules), "a storm, -3 °C")


func test_the_place_is_a_building_else_a_fire_else_the_open() -> void:
	var moment := _moment()
	assert_eq(NpcPrompt.moment_words(moment, _rules)["place"], "outside the kate")
	moment.building = ""
	moment.is_by_fire = true
	assert_eq(NpcPrompt.moment_words(moment, _rules)["place"], "by the campfire")
	moment.is_by_fire = false
	assert_eq(NpcPrompt.moment_words(moment, _rules)["place"], "out in the open")


func test_the_moment_of_the_game_is_read_from_its_state() -> void:
	var state := GameState.new_game(7)
	state.clock.set_time(8, 15)
	var npc := Npc.create(1, state.player.position, NpcRules.default_rules())
	var moment := NpcMoment.of(state, npc, 8.0)
	assert_eq(moment.clock.minute_of_day, 8 * 60 + 15)
	assert_eq(moment.sunrise, state.sun.sunrise(state.clock.day))
	assert_eq(moment.weather.temperature, state.current_weather().temperature)
	assert_true(moment.is_by_fire, "the camp's fireplace")


# --- The answer ---


func test_the_repeated_label_of_the_last_turn_is_left_out_whatever_was_said() -> void:
	var cases := {
		"Moin": ['Antje\'s reply (in the language of "Moin"): Moin! Gut.', "Moin! Gut."],
		"Hmm (sure):": ['Antje\'s reply (in the language of "Hmm (sure):"): Aye.', "Aye."],
		"Wie?":
		['antje\'s reply (in the language of "wie?"):\nGut (ja): danke.', "Gut (ja): danke."],
		"Guten Tag! Wie geht es dir?": ["Antje's reply in German: Gut, danke.", "Gut, danke."],
		"Good morning! How are you?": ["Antje's reply in English:\nFine.", "Fine."],
	}
	for message: String in cases:
		var language := NpcLanguage.name_of(message, _no_history(), _rules)
		var label := NpcPrompt.last_reply_label(_antje, message, language, _rules)
		var answer: String = cases[message][0]
		assert_eq(NpcPrompt.trimmed_reply(answer, _antje, 2, label), cases[message][1], answer)


func test_the_last_turn_names_the_language_of_the_message() -> void:
	var cases := {
		"Guten Tag! Wie geht es dir heute?": "German",
		"Good morning! Is the dyke holding?": "English",
		"Goddag! Hvordan går det med fiskeriet?": "Danish",
	}
	for message: String in cases:
		var last := _last_turn(_no_history(), message)
		assert_string_contains(last, "Antje answers in %s." % cases[message])
		assert_string_ends_with(last, "Antje's reply in %s:" % cases[message])


func test_a_message_too_short_to_tell_takes_the_language_of_the_chat() -> void:
	var history: Array[Dictionary] = [
		_line(true, "Guten Morgen! Wie geht es dir?"), _line(false, "Gut, danke.")
	]
	var last := _last_turn(history, "Moin")
	assert_string_contains(last, "Antje answers in German.")
	assert_string_ends_with(last, "Antje's reply in German:")


func test_with_no_language_known_the_last_turn_says_it_generally() -> void:
	var last := _last_turn(_no_history(), "Moin")
	assert_string_contains(last, "Antje answers in the language the neighbour just spoke in.")
	assert_string_ends_with(last, 'Antje\'s reply (in the language of "Moin"):')


func test_the_answer_is_trimmed_to_what_the_villager_says() -> void:
	var cases := {
		"Aye, it held.": "Aye, it held.",
		'  "Aye, it held. Barely."  ': "Aye, it held. Barely.",
		"Antje's reply: Aye.": "Aye.",
		'Antje Boysen: "Aye, it did!"': "Aye, it did!",
		"Antje: Aye. It held. My Hinrich saw to it. And more.": "Aye. It held.",
		"Aye, it held\nNeighbour: Good.": "Aye, it held",
		"Well... it held? Thank the Lord.": "Well... it held? Thank the Lord.",
		"'Twas a wild night.": "'Twas a wild night.",
		"The hay's in, and the cows'": "The hay's in, and the cows'",
		"“Aye.”": "Aye.",
	}
	for text: String in cases:
		assert_eq(NpcPrompt.trimmed_reply(text, _antje, 2), cases[text], text)
