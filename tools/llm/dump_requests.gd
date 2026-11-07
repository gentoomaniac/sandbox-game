extends SceneTree
## Writes the requests the game would send to the language model for a fixed set of scenarios,
## as JSON, for tools/llm/eval_prompts.py to send: the prompts come from NpcPrompt itself, so
## the evaluation never drifts from the game.
## Run: godot --headless --path . -s tools/llm/dump_requests.gd -- <out.json>

const FACT_CHAT := [
	[true, "Moin! I lost my red scarf at the dyke yesterday."],
	[false, "Ach, a red scarf. Look by the sluice, the wind drops things there."],
	[true, "Thanks. Is the hay coming in well?"],
	[false, "Aye, if the weather holds."],
	[true, "And how are the children?"],
	[false, "Loud as ever, and the eldest is out with the cows."],
]

## Each: id, villager, the language of the player's last line, and either a `message` (with
## optional `history` of [from_player, text] pairs, `memories`, `weather` "fine" or "rain" and
## `time` "morning" or "dusk") or `summarise`, the lines of a conversation to remember.
const SCENARIOS := [
	{"id": "greeting", "villager": "antje", "language": "en", "message": "Good morning!"},
	{
		"id": "rain_dusk",
		"villager": "momme",
		"language": "en",
		"message": "What do you make of this weather?",
		"weather": "rain",
		"time": "dusk",
	},
	{
		"id": "german_after_english",
		"villager": "antje",
		"language": "de",
		"message": "Guten Tag! Wie geht es dir heute?",
		"history": [[true, "Good morning!"], [false, "Morning to you. Fine day for it."]],
	},
	{
		"id": "danish",
		"villager": "momme",
		"language": "da",
		"message": "Goddag! Hvordan går det med fiskeriet?",
	},
	{
		"id": "english_after_german",
		"villager": "antje",
		"language": "en",
		"message": "Good day to you! Is that your cow over there?",
		"history": [[true, "Guten Morgen!"], [false, "Moin, Nachbar. Schönes Wetter heute."]],
	},
	{
		"id": "family",
		"villager": "antje",
		"language": "en",
		"message": "Tell me about your family.",
	},
	{
		"id": "family_momme",
		"villager": "momme",
		"language": "en",
		"message": "Do you have any children?",
	},
	{
		"id": "phone",
		"villager": "antje",
		"language": "en",
		"message": "Can I borrow your phone to call my friend?",
	},
	{
		"id": "car",
		"villager": "momme",
		"language": "en",
		"message": "Is there a petrol station nearby for my car?",
	},
	{
		"id": "rude",
		"villager": "antje",
		"language": "en",
		"message": "You stink, old woman. Get out of my way.",
	},
	{
		"id": "remember_fact",
		"villager": "antje",
		"language": "en",
		"message": "Did you see where I might have lost my scarf?",
		"history": FACT_CHAT,
	},
	{
		"id": "with_memories",
		"villager": "momme",
		"language": "en",
		"message": "Hello again. Do you remember me?",
		"memories":
		[
			(
				"On the 10th day of Spring: The neighbour asked for the best fishing spot,"
				+ " and I told them the creek behind the dyke."
			)
		],
	},
	{
		"id": "memory_summary",
		"villager": "antje",
		"language": "en",
		"summarise":
		[
			[true, "Do you sell butter?"],
			[false, "Aye, a good pat for three shillings."],
			[true, "I'll take two. Is your husband around?"],
			[false, "My Hinrich is out on the marsh with the scythe."],
		],
	},
]


func _init() -> void:
	var rules := NpcTalkRules.default_rules()
	var villagers := VillagerRules.default_rules()
	var entries: Array[Dictionary] = []
	for scenario: Dictionary in SCENARIOS:
		var npc := Npc.create_villager(scenario["villager"], Vector2.ZERO, villagers)
		for memory: String in scenario.get("memories", []):
			npc.add_memory(memory)
		var entry := {
			"id": scenario["id"],
			"villager": npc.name,
			"language": scenario["language"],
			"sentences": int(rules.value("request", "reply_sentences")),
			"label": "",
			"message": scenario.get("message", ""),
			"example_reply": rules.value("prompt", "example_reply"),
		}
		if scenario.has("summarise"):
			entry["request"] = NpcPrompt.memory_request(npc, _lines(scenario["summarise"]), rules)
			entry["sentences"] = 1
		else:
			var message: String = scenario["message"]
			var moment := _moment(scenario.get("weather", "fine"), scenario.get("time", "morning"))
			var history := _lines(scenario.get("history", []))
			entry["request"] = NpcPrompt.reply_request(npc, history, message, moment, rules)
			entry["label"] = NpcPrompt.last_reply_label(npc, message, rules)
		entries.append(entry)
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(entries, "\t"))
	quit()


## [from_player, text] pairs as lines of a chat.
func _lines(pairs: Array) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for pair: Array in pairs:
		lines.append({"day": 12, "minute": 495, "from_player": pair[0], "text": pair[1]})
	return lines


## The 12th day of Spring at 08:15, or at dusk (18:40) if `time` says so, by a kate.
func _moment(weather: String, time: String) -> NpcMoment:
	var moment := NpcMoment.new()
	moment.clock.day = 12
	if time == "dusk":
		moment.clock.set_time(18, 40)
	else:
		moment.clock.set_time(8, 15)
	moment.sunrise = 6 * 60
	moment.solar_noon = 12 * 60 + 30
	moment.sunset = 19 * 60
	moment.weather.temperature = 9.2
	moment.weather.wind_speed = 6.0
	moment.weather.wind_direction = Vector2.RIGHT
	if weather == "rain":
		moment.weather.rain = 0.5
	moment.building = "Kate"
	return moment
