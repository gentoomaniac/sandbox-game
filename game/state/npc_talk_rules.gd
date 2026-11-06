class_name NpcTalkRules
extends RefCounted
## How villagers talk through a language model, read from data/npc_talk.cfg (see there for what
## each key means): the numbers of a request and the words a prompt is made of (see NpcPrompt).

const DEFAULT_PATH := "res://data/npc_talk.cfg"

## The keys each section must have.
const KEYS := {
	"request": ["temperature", "max_tokens", "history_lines", "reply_sentences"],
	"prompt":
	["system", "example", "example_reply", "villager", "about", "moment", "says", "reply"],
	"female": ["their", "person"],
	"male": ["their", "person"],
	"looks": ["sentence", "body", "hair_styles", "hair_colours", "worn"],
	"moment":
	["date", "season_parts", "dawn_minutes", "noon_minutes", "dusk_minutes", "parts_of_day"],
	"weather": ["conditions", "sky", "temperature", "frost", "wind", "directions"],
	"place": ["reach", "building", "fireplace", "open"],
}
const PARTS_OF_DAY: Array[String] = ["dawn", "morning", "noon", "afternoon", "dusk", "night"]

static var _default: NpcTalkRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> NpcTalkRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> NpcTalkRules:
	var rules := NpcTalkRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what". Every layer a villager may wear (see NpcRules)
## must have its words.
func problems() -> Array[String]:
	var found: Array[String] = []
	for section: String in KEYS:
		for key: String in KEYS[section]:
			if not _values.get(section, {}).has(key):
				found.append("[%s] no %s" % [section, key])
	if not found.is_empty():
		return found
	for key: String in _values["weather"]["conditions"] + ["sky", "wind"]:
		if not _values["weather"].get(key) is Array or _values["weather"][key].is_empty():
			found.append("[weather] %s is not a list of [from, words]" % key)
	for part in PARTS_OF_DAY:
		if not _values["moment"]["parts_of_day"].has(part):
			found.append("[moment] parts_of_day has no %s" % part)
	for layer in NpcRules.default_rules().all_layers():
		if look_words(layer.slot, layer.variant).is_empty():
			found.append("[looks] no words for %s %s" % [layer.slot, layer.variant])
	return found


func is_valid() -> bool:
	return problems().is_empty()


## A value of the file, such as `value("prompt", "system")`.
func value(section: String, key: String) -> Variant:
	return _values[section][key]


## The words of a layer a villager wears, such as "a white coif"; "" if it has none, or if it is
## not told (the body and hair are told on their own).
func look_words(slot: StringName, variant: String) -> String:
	var looks: Dictionary = _values["looks"]
	if slot == Appearance.HAIR:
		var style := variant.get_slice("_", 0)
		var colour := variant.get_slice("_", 1)
		if not looks["hair_styles"].has(style) or not looks["hair_colours"].has(colour):
			return ""
		return looks["hair_styles"][style].format({"colour": looks["hair_colours"][colour]})
	return looks.get(str(slot), {}).get(variant, "")


## The words of a [from, words] list of [weather] for `amount`: those of the highest `from` it
## reaches, or "" below the first.
func words_for(key: String, amount: float) -> String:
	var words := ""
	for level: Array in _values["weather"][key]:
		if amount >= level[0]:
			words = level[1]
	return words
