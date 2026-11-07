extends SceneTree
## Writes the requests the game would send to the language model for a fixed set of scenarios,
## as JSON, for tools/llm/eval_prompts.py to send: the prompts come from NpcPrompt itself, so
## the evaluation never drifts from the game.
## Run: godot --headless --path . -s tools/llm/dump_requests.gd -- <out.json> [--full-sheets]
## The requests have the cut-down sheets a local model is sent, or with --full-sheets the full
## ones of a hosted model (see NpcDialogue `has_full_sheets`).

const FACT_CHAT := [
	[true, "Moin! I lost my red scarf at the dyke yesterday."],
	[false, "Ach, a red scarf. Look by the sluice, the wind drops things there."],
	[true, "Thanks. Is the hay coming in well?"],
	[false, "Aye, if the weather holds."],
	[true, "And how are the children?"],
	[false, "Loud as ever, and the eldest is out with the cows."],
]

const ENGLISH_CHAT := [
	[true, "Good morning! Is the dyke holding after the storm?"],
	[false, "Aye, barely. The sluice took the worst of it."],
	[true, "Glad to hear it. Will the boats go out today?"],
	[false, "If the wind drops, aye."],
]
const GERMAN_CHAT := [
	[true, "Guten Morgen! Hat der Deich den Sturm gut überstanden?"],
	[false, "Ach, gerade so. Die Schleuse hat das meiste abbekommen."],
	[true, "Das freut mich. Wie geht es deinem Mann?"],
	[false, "Der ist draußen auf der Marsch, wie immer."],
]
const DANISH_CHAT := [
	[true, "Godmorgen! Holder diget efter stormen?"],
	[false, "Ja, lige akkurat. Sluserne tog det værste."],
	[true, "Det er jeg glad for. Skal bådene ud i dag?"],
	[false, "Hvis vinden lægger sig."],
]

## Each: id, villager, the language of the player's last line, and either a `message` (with
## optional `history` of [from_player, text] pairs, `memories`, `weather` "fine" or "rain",
## `time` "morning" or "dusk", and `names`, of which a good answer names at least one) or
## `summarise`, the lines of a conversation to remember.
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
		"id": "german_after_english_chat",
		"villager": "momme",
		"language": "de",
		"message": "Wie ist das Wasser heute? Fängt man viel?",
		"history": ENGLISH_CHAT,
	},
	{
		"id": "danish_after_english",
		"villager": "antje",
		"language": "da",
		"message": "Goddag! Hvordan har du det i dag?",
		"history": [[true, "Good morning!"], [false, "Morning to you. Fine day for it."]],
	},
	{
		"id": "moin_after_german",
		"villager": "antje",
		"language": "de",
		"message": "Moin!",
		"history": GERMAN_CHAT,
	},
	{
		"id": "hej_after_danish",
		"villager": "momme",
		"language": "da",
		"message": "Hej!",
		"history": DANISH_CHAT,
	},
	{
		"id": "swedish",
		"villager": "antje",
		"language": "other",
		"message": "Tjena! Hur går det idag för dig?",
	},
	{
		"id": "family",
		"villager": "antje",
		"language": "en",
		"message": "Tell me about your family.",
		"names": ["Hinrich", "Boy"],
	},
	{
		"id": "family_momme",
		"villager": "momme",
		"language": "en",
		"message": "Do you have any children?",
		"names": ["Inken"],
	},
	{
		"id": "family_german",
		"villager": "antje",
		"language": "de",
		"message": "Erzähl mir von deiner Familie. Wer gehört dazu?",
		"names": ["Hinrich", "Boy"],
	},
	{
		"id": "husband_again",
		"villager": "antje",
		"language": "en",
		"message": "Sorry, what was your husband's name again?",
		"history": FACT_CHAT,
		"names": ["Hinrich"],
	},
	{
		"id": "other_villager",
		"villager": "antje",
		"language": "en",
		"message": "Do you know the miller's wife, Gesche?",
	},
	{
		"id": "pastor",
		"villager": "kerrin",
		"language": "en",
		"message": "Who is the pastor here, and is he any good?",
		"names": ["Martens"],
	},
	{
		"id": "deichgraf_german",
		"villager": "ocke",
		"language": "de",
		"message": "Wer ist hier eigentlich der Deichgraf?",
		"names": ["Momsen"],
	},
	{
		"id": "not_on_sheet",
		"villager": "momme",
		"language": "en",
		"message": "What is your sister's name, and where does she live?",
	},
	{
		"id": "not_on_sheet_german",
		"villager": "ocke",
		"language": "de",
		"message": "Wie heißt eigentlich dein Bruder?",
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
	var args := OS.get_cmdline_user_args()
	var full_sheets := args.has("--full-sheets")
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
			"names": scenario.get("names", []),
			"example_reply": rules.value("prompt", "example_reply"),
		}
		if scenario.has("summarise"):
			entry["request"] = NpcPrompt.memory_request(npc, _lines(scenario["summarise"]), rules)
			entry["sentences"] = 1
		else:
			var message: String = scenario["message"]
			var moment := _moment(scenario.get("weather", "fine"), scenario.get("time", "morning"))
			var history := _lines(scenario.get("history", []))
			entry["request"] = NpcPrompt.reply_request(
				npc, history, message, moment, rules, full_sheets
			)
			entry["label"] = NpcPrompt.last_reply_label(
				npc, message, NpcLanguage.name_of(message, history, rules), rules
			)
		entries.append(entry)
	var file := FileAccess.open(args[0], FileAccess.WRITE)
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
