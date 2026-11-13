class_name NpcTalkRules
extends RefCounted
## How villagers talk through a language model, read from data/npc_talk.cfg (see there for what
## each key means): the numbers of a request and the words a prompt is made of (see NpcPrompt).

const DEFAULT_PATH := "res://data/npc_talk.cfg"

## The keys each section must have, with the type of their value. TYPE_FLOAT is any number.
const KEYS := {
	"request":
	{
		"temperature": TYPE_FLOAT,
		"max_tokens": TYPE_INT,
		"reply_sentences": TYPE_INT,
		"timeout_seconds": TYPE_FLOAT,
		"models_timeout_seconds": TYPE_FLOAT,
		"models_delay_seconds": TYPE_FLOAT,
		"notice_repeat_seconds": TYPE_FLOAT,
		"notice_detail_length": TYPE_INT,
	},
	"claude":
	{
		"api_version": TYPE_STRING,
		"max_tokens": TYPE_INT,
		"effort": TYPE_STRING,
		"fallback_models": TYPE_ARRAY,
		"fallback_beta": TYPE_STRING,
	},
	"prompt":
	{
		"system": TYPE_STRING,
		"example": TYPE_STRING,
		"example_reply": TYPE_STRING,
		"village": TYPE_STRING,
		"sheet": TYPE_STRING,
		"sheet_short": TYPE_STRING,
		"person": TYPE_STRING,
		"person_short": TYPE_STRING,
		"people": TYPE_STRING,
		"no_people": TYPE_STRING,
		"villager": TYPE_STRING,
		"about": TYPE_STRING,
		"memory": TYPE_STRING,
		"moment": TYPE_STRING,
		"neighbour": TYPE_STRING,
		"opinion_cold": TYPE_STRING,
		"opinion_neutral": TYPE_STRING,
		"opinion_warm": TYPE_STRING,
		"says": TYPE_STRING,
		"reply": TYPE_STRING,
		"language": TYPE_STRING,
		"language_unknown": TYPE_STRING,
		"last_reply": TYPE_STRING,
		"last_reply_unknown": TYPE_STRING,
	},
	"language":
	{
		"names": TYPE_DICTIONARY,
		"words": TYPE_DICTIONARY,
		"letters": TYPE_DICTIONARY,
		"letter_score": TYPE_INT,
		"min_score": TYPE_INT,
	},
	"female": {"their": TYPE_STRING, "person": TYPE_STRING},
	"male": {"their": TYPE_STRING, "person": TYPE_STRING},
	"looks":
	{
		"sentence": TYPE_STRING,
		"body": TYPE_DICTIONARY,
		"hair_styles": TYPE_DICTIONARY,
		"hair_colours": TYPE_DICTIONARY,
		"worn": TYPE_ARRAY,
	},
	"moment":
	{
		"date": TYPE_STRING,
		"season_parts": TYPE_ARRAY,
		"dawn_minutes": TYPE_FLOAT,
		"noon_minutes": TYPE_FLOAT,
		"dusk_minutes": TYPE_FLOAT,
		"parts_of_day": TYPE_DICTIONARY,
	},
	"weather":
	{
		"conditions": TYPE_ARRAY,
		"sky": TYPE_ARRAY,
		"temperature": TYPE_STRING,
		"frost": TYPE_STRING,
		"wind": TYPE_ARRAY,
		"directions": TYPE_ARRAY,
	},
	"place":
	{
		"reach": TYPE_FLOAT,
		"building": TYPE_STRING,
		"fireplace": TYPE_STRING,
		"open": TYPE_STRING,
	},
	"scripted": {"thinking_seconds": TYPE_FLOAT, "replies": TYPE_ARRAY},
	"bubble":
	{
		"interval_seconds": TYPE_FLOAT,
		"interval_spread": TYPE_FLOAT,
		"show_seconds": TYPE_FLOAT,
		"max_length": TYPE_INT,
		"near_tiles": TYPE_FLOAT,
		"chance_about_player": TYPE_FLOAT,
		"stories_told": TYPE_INT,
		"max_tokens": TYPE_INT,
		"system": TYPE_STRING,
		"about_moment": TYPE_STRING,
		"about_player": TYPE_STRING,
		"label": TYPE_STRING,
	},
	"bubble_lines":
	{"weather": TYPE_DICTIONARY, "part_of_day": TYPE_DICTIONARY, "near_player": TYPE_DICTIONARY},
	"judge":
	{
		"system": TYPE_STRING,
		"story": TYPE_STRING,
		"temperature": TYPE_FLOAT,
		"max_tokens": TYPE_INT,
	},
	"memory":
	{
		"system": TYPE_STRING,
		"conversation": TYPE_STRING,
		"neighbour_line": TYPE_STRING,
		"villager_line": TYPE_STRING,
		"temperature": TYPE_FLOAT,
		"max_tokens": TYPE_INT,
		"plain": TYPE_STRING,
		"plain_length": TYPE_INT,
		"dated": TYPE_STRING,
	},
}
## The type names of KEYS, for the problems.
const TYPE_NAMES := {
	TYPE_FLOAT: "a number",
	TYPE_INT: "a whole number",
	TYPE_STRING: "a text",
	TYPE_DICTIONARY: "a dictionary",
	TYPE_ARRAY: "a list",
}
const PARTS_OF_DAY: Array[String] = ["dawn", "morning", "noon", "afternoon", "dusk", "night"]
const OPINION_WORDS: Array[String] = ["cold", "neutral", "warm"]

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


## What is missing or wrong, as "[section] what": a key missing or of the wrong type, a weather
## list that is not of [from, words] pairs, a list that is empty. Every layer a villager may wear
## (see NpcRules) must have its words.
func problems() -> Array[String]:
	var found: Array[String] = []
	for section: String in KEYS:
		for key: String in KEYS[section]:
			if not _values.get(section, {}).has(key):
				found.append("[%s] no %s" % [section, key])
			elif not _is_of_type(_values[section][key], KEYS[section][key]):
				found.append("[%s] %s is not %s" % [section, key, TYPE_NAMES[KEYS[section][key]]])
	if not found.is_empty():
		return found
	var weather: Dictionary = _values["weather"]
	for condition: Variant in weather["conditions"]:
		if not WeatherSample.CONDITIONS.has(StringName(str(condition))):
			found.append("[weather] conditions: %s is not a condition" % condition)
	for key: Variant in weather["conditions"] + ["sky", "wind"]:
		var levels: Variant = weather.get(key)
		if not levels is Array or levels.is_empty() or not levels.all(_is_level):
			found.append("[weather] %s is not a list of [from, words]" % key)
	for section_and_key: Array in [
		["moment", "season_parts"], ["scripted", "replies"], ["weather", "directions"]
	]:
		var section: String = section_and_key[0]
		var key: String = section_and_key[1]
		if _values[section][key].is_empty():
			found.append("[%s] %s is not a list of at least one" % [section, key])
	for slot: Variant in _values["looks"]["worn"]:
		if not _values["looks"].get(slot) is Dictionary:
			found.append("[looks] %s is not a dictionary of words" % slot)
	if not found.is_empty():
		return found
	for code: Variant in _values["language"]["names"]:
		if not _values["language"]["words"].has(code):
			found.append("[language] words has no list for %s" % code)
	for part in PARTS_OF_DAY:
		if not _values["moment"]["parts_of_day"].has(part):
			found.append("[moment] parts_of_day has no %s" % part)
	for layer in NpcRules.default_rules().all_layers():
		if look_words(layer.slot, layer.variant).is_empty():
			found.append("[looks] no words for %s %s" % [layer.slot, layer.variant])
	found.append_array(_bubble_line_problems())
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


## What is wrong with [bubble_lines]: every part of the day and every opinion word needs lines, a
## weather with lines must be one of [weather] conditions, and a line must be a text within
## [bubble] max_length.
func _bubble_line_problems() -> Array[String]:
	var found: Array[String] = []
	var lines: Dictionary = _values["bubble_lines"]
	var max_length: int = _values["bubble"]["max_length"]
	for key in lines["weather"]:
		if not _values["weather"]["conditions"].has(key):
			found.append("[bubble_lines] weather: %s is not a condition" % key)
	for key: String in PARTS_OF_DAY:
		if not lines["part_of_day"].has(key):
			found.append("[bubble_lines] part_of_day has no %s" % key)
	for key: String in OPINION_WORDS:
		if not lines["near_player"].has(key):
			found.append("[bubble_lines] near_player has no %s" % key)
	for key: String in ["weather", "part_of_day", "near_player"]:
		for name: String in lines[key]:
			var list: Variant = lines[key][name]
			if not list is Array or list.is_empty():
				found.append(
					"[bubble_lines] %s %s is not a list of at least one line" % [key, name]
				)
				continue
			for line: Variant in list:
				if not line is String or line.length() > max_length:
					found.append(
						(
							'[bubble_lines] %s %s: "%s" is not a text of %d at most'
							% [key, name, line, max_length]
						)
					)
	return found


static func _is_of_type(value: Variant, type: Variant.Type) -> bool:
	if type == TYPE_FLOAT:
		return value is float or value is int
	return typeof(value) == type


## Whether a value of a [weather] list is a [from, words] pair.
static func _is_level(level: Variant) -> bool:
	return (
		level is Array
		and level.size() == 2
		and _is_of_type(level[0], TYPE_FLOAT)
		and level[1] is String
	)
