class_name NpcPrompt
extends RefCounted
## What a language model is asked for a villager's answer: the request of the OpenAI chat API,
## made of the words of data/npc_talk.cfg (NpcTalkRules), who the villager is and the moment.
## Pure functions: the same villager, chat and moment always give the same request.
##
## The shape is the user's working example of TASKS.md 86: a system line, one example exchange,
## the earlier lines of the chat as user and assistant turns, and last what the player says. The
## system line carries the sheets the villager keeps to: the village's (VillageSheet) and their
## own, in full for a hosted model or cut down for a local one (`full_sheets`). The last turn:
##   Villager: Antje Boysen, a farmer's wife.
##   Antje is 38 years old, a pale woman with ... (and, if any, what she remembers)
##   It is the 12th day of Spring, year 1 (mid spring), 08:15 in the morning. The weather: ...
##   The neighbour is a newcomer to these parts; Antje does not know their name.
##   Antje has no strong feelings about this neighbour yet.
##   Her neighbour says: "Good morning! Is the dyke holding after the storm?"
##   Antje's reply:

## The quotes a model may put round the line it answers: straight, curly and single.
const QUOTE_PAIRS: Array[String] = ['""', "“”", "''"]
## The cut-down sheet tells this many of the villager's sample lines.
const SHORT_SAMPLES := 1


## The request for the villager's answer to `message`, said after the lines of `history` (as
## Npc `chat_history`): {messages, temperature, max_tokens}. `full_sheets` tells the whole of the
## village's and the villager's sheets, else the cut-down for a small local model.
static func reply_request(
	npc: Npc,
	history: Array[Dictionary],
	message: String,
	moment: NpcMoment,
	rules: NpcTalkRules,
	full_sheets: bool
) -> Dictionary:
	return {
		"messages": reply_messages(npc, history, message, moment, rules, full_sheets),
		"temperature": float(rules.value("request", "temperature")),
		"max_tokens": int(rules.value("request", "max_tokens")),
	}


static func reply_messages(
	npc: Npc,
	history: Array[Dictionary],
	message: String,
	moment: NpcMoment,
	rules: NpcTalkRules,
	full_sheets: bool
) -> Array[Dictionary]:
	var messages: Array[Dictionary] = [
		_message("system", system_text(npc, full_sheets, rules)),
		_message("user", rules.value("prompt", "example")),
		_message("assistant", rules.value("prompt", "example_reply")),
	]
	var words := _words_of(npc, rules)
	for line in history:
		if line["from_player"]:
			var turn: Array[String] = [_said(rules, "villager", words)]
			turn.append_array(_neighbour_says(line["text"], words, rules))
			messages.append(_message("user", "\n".join(turn)))
		else:
			messages.append(_message("assistant", line["text"]))
	words["age"] = npc.age
	words["looks"] = looks_text(npc, rules)
	words.merge(moment_words(moment, rules))
	var last: Array[String] = [_said(rules, "villager", words), _said(rules, "about", words)]
	if not npc.memories.is_empty():
		words["memories"] = " ".join(
			npc.memories.map(func(memory: Dictionary) -> String: return memory["text"])
		)
		last.append(_said(rules, "memory", words))
	last.append_array(GossipRules.default_rules().story_lines(npc.stories, moment.clock.day))
	last.append(_said(rules, "moment", words))
	last.append(_said(rules, "neighbour", words))
	var opinion_word := GossipRules.default_rules().opinion_word(npc.opinion)
	last.append(_said(rules, "opinion_" + opinion_word, words))
	last.append(_said(rules, "says", _with_message(words, message)))
	var language := NpcLanguage.name_of(message, history, rules)
	last.append(_said_in(rules, "language", _with_message(words, message), language))
	last.append(last_reply_label(npc, message, language, rules))
	messages.append(_message("user", "\n".join(last)))
	return messages


## The system line of a reply: the rules of the answer, the village's sheet and the villager's,
## all of them if `full_sheets`, else cut down to what a small local model needs most.
static func system_text(npc: Npc, full_sheets: bool, rules: NpcTalkRules) -> String:
	var words := _words_of(npc, rules)
	words["village"] = VillageSheet.default_sheet().text(full_sheets)
	words["age"] = npc.age
	words["personality"] = npc.personality
	words["background"] = npc.background
	words["home"] = npc.home
	words["people"] = people_text(npc, full_sheets, rules)
	words["speech"] = npc.speech
	var samples := npc.samples if full_sheets else npc.samples.slice(0, SHORT_SAMPLES)
	words["samples"] = " ".join(samples.map(func(line: String) -> String: return '"%s"' % line))
	words["likes"] = npc.likes
	words["wants"] = npc.wants
	words["day"] = npc.day
	words["habits"] = npc.habits
	words["avoids"] = npc.avoids
	words["secrets"] = npc.secrets
	var sheet_lines := _said(rules, "sheet" if full_sheets else "sheet_short", words).split("\n")
	# A line with nothing to tell (see `people_text`) is left out.
	var sheet := "\n".join(Array(sheet_lines).filter(func(line: String) -> bool: return line != ""))
	return "\n\n".join([rules.value("prompt", "system"), _said(rules, "village", words), sheet])


## The line of the villager's family and friends (Npc `people`) by the names, kinds and ages of
## their sheets, with what the villager thinks of each if `full_sheets`: "Family and friends:
## Hinrich Boysen, husband, 42: Steady ...". Those no longer in data/villagers.cfg are left out,
## and if none is left the line is "": better nothing than "none" against a background that
## names them. A villager without people (a made-up one) has `no_people`.
static func people_text(npc: Npc, full_sheets: bool, rules: NpcTalkRules) -> String:
	if npc.people.is_empty():
		return _said(rules, "no_people", _words_of(npc, rules))
	var villagers := VillagerRules.default_rules()
	var told: Array[String] = []
	for id: String in npc.people:
		if not villagers.has(id):
			continue
		var person := villagers.villager(id)
		var kind_and_thought: Array = npc.people[id]
		var words := {
			"name": person["name"],
			"kind": kind_and_thought[0],
			"age": person["age"],
			"thought": kind_and_thought[1],
		}
		told.append(_said(rules, "person" if full_sheets else "person_short", words))
	if told.is_empty():
		return ""
	var joined := " ".join(told) if full_sheets else ", ".join(told)
	return _said(rules, "people", {"people": joined})


## The request that sums up the `lines` of a conversation (as Npc `chat_history`) in one line
## for the villager to remember: {messages, temperature, max_tokens}.
static func memory_request(npc: Npc, lines: Array[Dictionary], rules: NpcTalkRules) -> Dictionary:
	var words := _words_of(npc, rules)
	var told: Array[String] = []
	for line in lines:
		var key := "neighbour_line" if line["from_player"] else "villager_line"
		var with_text := words.duplicate()
		with_text["text"] = line["text"]
		told.append(rules.value("memory", key).format(with_text))
	words["lines"] = "\n".join(told)
	return {
		"messages":
		[
			_message("system", rules.value("memory", "system")),
			_message("user", rules.value("memory", "conversation").format(words)),
		],
		"temperature": float(rules.value("memory", "temperature")),
		"max_tokens": int(rules.value("memory", "max_tokens")),
	}


## What a villager remembers of the `lines` of a conversation without a model to sum them up:
## the start of what the player said.
static func plain_memory(lines: Array[Dictionary], rules: NpcTalkRules) -> String:
	var said: Array[String] = []
	for line in lines:
		if line["from_player"]:
			said.append(line["text"])
	var length := int(rules.value("memory", "plain_length"))
	var text := " ".join(said)
	if text.length() > length:
		text = text.left(length).strip_edges() + "..."
	return rules.value("memory", "plain").format({"said": text})


## A memory as it is kept: the summary with the day of `clock`.
static func dated_memory(summary: String, clock: GameClock, rules: NpcTalkRules) -> String:
	return rules.value("memory", "dated").format(
		{"date": date_text(clock, rules), "summary": summary}
	)


## The villager's look in words: "a pale woman with blond hair in a bun, wearing a white coif,
## a red bodice, a white apron, a blue skirt and clogs".
static func looks_text(npc: Npc, rules: NpcTalkRules) -> String:
	var worn_by_slot := {}
	var skin := ""
	var hair := ""
	for layer in npc.appearance.layers:
		var words := rules.look_words(layer.slot, layer.variant)
		match layer.slot:
			Appearance.BODY:
				skin = words
			Appearance.HAIR:
				hair = words
			_:
				worn_by_slot[str(layer.slot)] = words
	var worn: Array[String] = []
	for slot: String in rules.value("looks", "worn"):
		if worn_by_slot.has(slot):
			worn.append(worn_by_slot[slot])
	return (
		rules
		. value("looks", "sentence")
		. format(
			{
				"skin": skin,
				"person": rules.value(str(npc.sex), "person"),
				"hair": hair,
				"worn": _listed(worn),
			}
		)
	)


## The words of the moment, by the placeholders of [prompt] `moment`: date, time, part_of_day,
## weather and place.
static func moment_words(moment: NpcMoment, rules: NpcTalkRules) -> Dictionary:
	var clock := moment.clock
	var place: String = rules.value("place", "open")
	if moment.building != "":
		place = rules.value("place", "building").format({"building": moment.building.to_lower()})
	elif moment.is_by_fire:
		place = rules.value("place", "fireplace")
	return {
		"date": date_text(clock, rules),
		"time": clock.time_text(),
		"part_of_day": rules.value("moment", "parts_of_day")[part_of_day(moment, rules)],
		"weather": weather_text(moment.weather, rules),
		"place": place,
	}


## The day of `clock` as the clock shows it, with how far into the season it is: "the 12th day
## of Spring, year 1 (mid spring)".
static func date_text(clock: GameClock, rules: NpcTalkRules) -> String:
	var parts: Array = rules.value("moment", "season_parts")
	var season := GameClock.SEASON_NAMES[clock.season()] as String
	var part_index := (clock.day_of_season() - 1) * parts.size() / GameClock.DAYS_PER_SEASON
	var words := {
		"day": GameClock.ordinal(clock.day_of_season()),
		"season": season,
		"season_lower": season.to_lower(),
		"season_part": parts[part_index],
		"year": clock.year(),
	}
	return rules.value("moment", "date").format(words)


## One of NpcTalkRules.PARTS_OF_DAY, by the sun: dawn, morning, noon, afternoon, dusk or night.
static func part_of_day(moment: NpcMoment, rules: NpcTalkRules) -> String:
	var minute := moment.clock.minute_of_day
	var dawn := float(rules.value("moment", "dawn_minutes"))
	var noon := float(rules.value("moment", "noon_minutes"))
	var dusk := float(rules.value("moment", "dusk_minutes"))
	if minute < moment.sunrise - dawn or minute >= moment.sunset + dusk:
		return "night"
	if minute < moment.sunrise + dawn:
		return "dawn"
	if minute < moment.solar_noon - noon:
		return "morning"
	if minute < moment.solar_noon + noon:
		return "noon"
	if minute < moment.sunset - dusk:
		return "afternoon"
	return "dusk"


## The weather in words: "light rain, 9 °C, a fresh west wind". What falls or hangs in the air
## (else the sky), the temperature with frost below 0 °C, and the wind.
static func weather_text(sample: WeatherSample, rules: NpcTalkRules) -> String:
	var parts: Array[String] = []
	for condition: String in rules.value("weather", "conditions"):
		var words := rules.words_for(condition, sample.get(condition))
		if words != "":
			parts.append(words)
			break
	if parts.is_empty():
		parts.append(rules.words_for("sky", sample.cloud_cover))
	parts.append(
		rules.value("weather", "temperature").format({"degrees": roundi(sample.temperature)})
	)
	if sample.temperature < 0.0:
		parts.append(rules.value("weather", "frost"))
	var directions: Array = rules.value("weather", "directions")
	var from := -sample.wind_direction
	var direction_index := posmod(roundi(from.angle() / TAU * directions.size()), directions.size())
	parts.append(
		rules.words_for("wind", sample.wind_speed).format({"from": directions[direction_index]})
	)
	return ", ".join(parts)


## The model's answer as the villager says it: its first line without quotes or the name in
## front ("Antje's reply:", "Antje:"), and of that at most `sentences` sentences.
static func trimmed_reply(text: String, npc: Npc, sentences: int, label := "") -> String:
	var said := text.strip_edges()
	# The label of the last turn repeated, as it was (see `last_reply_label`), maybe on a line
	# of its own.
	if label != "" and said.to_lower().begins_with(label.to_lower()):
		said = said.substr(label.length()).strip_edges()
	var line := said.get_slice("\n", 0)
	var first_name := npc.name.get_slice(" ", 0)
	for prefix in ["%s's reply:" % first_name, "%s:" % npc.name, "%s:" % first_name]:
		if line.to_lower().begins_with(prefix.to_lower()):
			line = line.substr(prefix.length()).strip_edges()
	# Only quotes that come as a pair: "'Twas" and "the cows'" keep their apostrophes.
	for quotes: String in QUOTE_PAIRS:
		if line.length() > 1 and line.begins_with(quotes[0]) and line.ends_with(quotes[1]):
			line = line.substr(1, line.length() - 2).strip_edges()
	# A sentence ends at ".", "!" or "?" before a space or the end, but not at "...".
	var sentence_ends := RegEx.create_from_string("([!?]+|(?<!\\.)\\.)[\"”']?(\\s|$)")
	var end := 0
	for found in sentence_ends.search_all(line).slice(0, sentences):
		end = found.get_end()
	return line.substr(0, end).strip_edges() if end > 0 else line


## The placeholders every line of a prompt about the villager may use: name, first_name, trade
## and their (Her or His).
static func _words_of(npc: Npc, rules: NpcTalkRules) -> Dictionary:
	return {
		"name": npc.name,
		"first_name": npc.name.get_slice(" ", 0),
		"trade": npc.trade,
		"their": rules.value(str(npc.sex), "their"),
	}


static func _neighbour_says(
	message: String, words: Dictionary, rules: NpcTalkRules
) -> Array[String]:
	return [_said(rules, "says", _with_message(words, message)), _said(rules, "reply", words)]


static func _with_message(words: Dictionary, message: String) -> Dictionary:
	var with_message := words.duplicate()
	with_message["message"] = message
	return with_message


## The label the last turn ends with, which names the `language` of `message` ("" if unknown, see
## NpcLanguage): the model may repeat it before its answer (see `trimmed_reply`).
static func last_reply_label(
	npc: Npc, message: String, language: String, rules: NpcTalkRules
) -> String:
	return _said_in(rules, "last_reply", _with_message(_words_of(npc, rules), message), language)


## The line `key` of [prompt] for the `language` the player speaks, or its `_unknown` line if that
## is not known (""); `words` has the placeholders of both.
static func _said_in(
	rules: NpcTalkRules, key: String, words: Dictionary, language: String
) -> String:
	if language == "":
		return _said(rules, key + "_unknown", words)
	var with_language := words.duplicate()
	with_language["language"] = language
	return _said(rules, key, with_language)


## A line of [prompt] with its placeholders filled in.
static func _said(rules: NpcTalkRules, key: String, words: Dictionary) -> String:
	return rules.value("prompt", key).format(words)


static func _message(role: String, content: String) -> Dictionary:
	return {"role": role, "content": content}


## "a", "a and b", "a, b and c".
static func _listed(words: Array[String]) -> String:
	if words.size() <= 1:
		return "".join(words)
	return "%s and %s" % [", ".join(words.slice(0, -1)), words[-1]]
