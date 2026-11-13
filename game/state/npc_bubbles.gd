class_name NpcBubbles
extends RefCounted
## Who says a line in a bubble over their head, when and what (see design/villagers/gossip.md,
## Bubbles): about one a minute, by a villager in view of the player, about the moment or, near
## the player, about them. This chooses; NpcSpeech draws it and asks the language model.

## What a line is about: the weather and the part of the day, or the player.
enum Subject { MOMENT, PLAYER }

var rules: NpcTalkRules
var rng: RandomNumberGenerator
var _seconds_left := 0.0


func _init(
	talk_rules := NpcTalkRules.default_rules(), random := RandomNumberGenerator.new()
) -> void:
	rules = talk_rules
	rng = random
	restart_wait()


## Whether the villager at `feet` (in tiles) and the bubble over their head, `head_pixels` above
## their feet, are in `region`, the part of the world the camera shows, in art pixels.
static func is_in_view(feet: Vector2, head_pixels: float, region: Rect2) -> bool:
	var feet_pixels := feet * TerrainTileset.TILE_SIZE
	return region.has_point(feet_pixels) and region.has_point(feet_pixels - Vector2(0, head_pixels))


## Waits for the next bubble: `interval_seconds`, give or take `interval_spread` of it.
func restart_wait() -> void:
	var spread := float(rules.value("bubble", "interval_spread"))
	_seconds_left = (
		float(rules.value("bubble", "interval_seconds"))
		* rng.randf_range(1.0 - spread, 1.0 + spread)
	)


## Lets `seconds` pass in the wait for the next bubble.
func advance(seconds: float) -> void:
	_seconds_left -= seconds


func is_due() -> bool:
	return _seconds_left <= 0.0


## The villager of `npcs` who speaks: one at random out of those in `region` (see `is_in_view`)
## that are not answering the player; null if there is none.
func pick_speaker(npcs: Array[Npc], region: Rect2, head_pixels: float) -> Npc:
	var in_view: Array[Npc] = []
	for npc in npcs:
		if not npc.is_answering and is_in_view(npc.position, head_pixels, region):
			in_view.append(npc)
	return in_view[rng.randi_range(0, in_view.size() - 1)] if not in_view.is_empty() else null


## What the villager's line is about: the player if they are near, with the chance of
## [bubble] chance_about_player, else the moment.
func subject_for(npc: Npc, player_feet: Vector2) -> Subject:
	var is_near := (
		npc.position.distance_to(player_feet) <= float(rules.value("bubble", "near_tiles"))
	)
	var is_about_player := rng.randf() < float(rules.value("bubble", "chance_about_player"))
	return Subject.PLAYER if is_near and is_about_player else Subject.MOMENT


## A line for the villager without a language model: about the player by what the villager thinks
## of them, else about the weather if something falls or hangs in the air, else the part of the
## day.
func scripted_line(npc: Npc, moment: NpcMoment, subject: Subject) -> String:
	var list: Array
	if subject == Subject.PLAYER:
		var opinion := GossipRules.default_rules().opinion_word(npc.opinion)
		list = rules.value("bubble_lines", "near_player")[opinion]
	else:
		list = _weather_lines(moment.weather)
		if list.is_empty():
			list = rules.value("bubble_lines", "part_of_day")[NpcPrompt.part_of_day(moment, rules)]
	return list[rng.randi_range(0, list.size() - 1)]


## The request for the villager's line from a language model: {messages, temperature,
## max_tokens}. The villager's sheet (in full if `full_sheets`, else cut down), the moment, and
## for a line about the player what the villager thinks of them and their newest stories.
func request(npc: Npc, moment: NpcMoment, subject: Subject, full_sheets: bool) -> Dictionary:
	var words := NpcPrompt.moment_words(moment, rules)
	words["first_name"] = npc.name.get_slice(" ", 0)
	var turn: Array[String] = [
		NpcPrompt.sheet_text(npc, full_sheets, rules),
		"",
		rules.value("prompt", "moment").format(words),
	]
	if subject == Subject.PLAYER:
		turn.append(rules.value("prompt", "neighbour").format(words))
		var opinion := GossipRules.default_rules().opinion_word(npc.opinion)
		turn.append(rules.value("prompt", "opinion_" + opinion).format(words))
		var newest := npc.stories.slice(-int(rules.value("bubble", "stories_told")))
		turn.append_array(GossipRules.default_rules().story_lines(newest, moment.clock.day))
		turn.append(rules.value("bubble", "about_player").format(words))
	else:
		turn.append(rules.value("bubble", "about_moment").format(words))
	turn.append(rules.value("bubble", "label").format(words))
	return {
		"messages":
		[
			{"role": "system", "content": rules.value("bubble", "system")},
			{"role": "user", "content": "\n".join(turn)},
		],
		"temperature": float(rules.value("request", "temperature")),
		"max_tokens": int(rules.value("bubble", "max_tokens")),
	}


## The line in the model's `answer` as the villager says it in a bubble: one sentence without
## quotes, "" if the model gave none or one of more than [bubble] max_length characters.
func line_from_answer(answer: String, npc: Npc) -> String:
	var label: String = rules.value("bubble", "label").format(
		{"first_name": npc.name.get_slice(" ", 0)}
	)
	var line := NpcPrompt.trimmed_reply(answer, npc, 1, label)
	return line if line.length() <= int(rules.value("bubble", "max_length")) else ""


## The lines for what falls or hangs in the air (the first of [weather] conditions that is there),
## none if the sky is only sky.
func _weather_lines(sample: WeatherSample) -> Array:
	for condition: String in rules.value("weather", "conditions"):
		if rules.words_for(condition, sample.get(condition)) != "":
			return rules.value("bubble_lines", "weather").get(condition, [])
	return []
