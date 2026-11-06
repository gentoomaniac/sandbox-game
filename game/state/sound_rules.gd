class_name SoundRules
extends RefCounted
## What every sound event plays and how, read from data/sounds.cfg (see there for what each
## key means). `from_file` reports every problem (a missing key, a file that doesn't exist, a
## missing event), and `is_valid` says whether there was any. It also makes the random choices of
## a play: which variant, and which pitch.

const DEFAULT_PATH := "res://data/sounds.cfg"

const REQUIRED_KEYS: Array[String] = ["files", "volume_db", "pitch_min", "pitch_max", "bus"]
## The volume buses an event can belong to.
const BUSES: Array[String] = ["effects", "ambience", "ui"]
## Every event the game plays; the generator (tools/audio/generate.py) writes the files of each.
const EVENTS: Array[StringName] = [
	&"step_grass",
	&"step_soil",
	&"step_sand",
	&"step_wetland",
	&"step_ice",
	&"step_snow",
	&"step_wood",
	&"axe_chop",
	&"tree_fall",
	&"pickaxe_hit",
	&"stone_break",
	&"scythe_swish",
	&"shovel_dig",
	&"hoe_till",
	&"water_pour",
	&"plant",
	&"pick_bush",
	&"item_pickup",
	&"build_place",
	&"denied",
	&"ui_click",
	&"ui_open",
	&"ui_close",
	&"hotbar_select",
	&"chest_open",
	&"chest_close",
	&"rain_loop",
	&"wind_loop",
	&"wind_gust",
	&"thunder",
	&"bird_chirp",
	&"frog_croak",
	&"deer_snort",
	&"deer_hooves",
	&"rabbit_rustle",
	&"squirrel_chatter",
	&"bee_buzz_loop",
]

static var _default: SoundRules

## {event: {key: value}}, in the order of the file.
var _events: Dictionary
var _problems: Array[String] = []


func _init(events: Dictionary) -> void:
	_events = events
	for event in EVENTS:
		if not _events.has(str(event)):
			_problems.append("no [%s]" % event)
	for event: String in _events:
		_check_event(event)


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> SoundRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> SoundRules:
	var rules := SoundRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	return _problems


func is_valid() -> bool:
	return _problems.is_empty()


func has_event(event_id: StringName) -> bool:
	return _events.has(str(event_id))


## The event's values, as in the file.
func event(event_id: StringName) -> Dictionary:
	return _events[str(event_id)]


## The path of a random variant of the event.
func pick_file(event_id: StringName, rng: RandomNumberGenerator) -> String:
	var files: Array = event(event_id)["files"]
	return files[rng.randi_range(0, files.size() - 1)]


## A random pitch factor within the event's range.
func pick_pitch(event_id: StringName, rng: RandomNumberGenerator) -> float:
	var values := event(event_id)
	return rng.randf_range(values["pitch_min"], values["pitch_max"])


func _check_event(event_id: String) -> void:
	var values: Dictionary = _events[event_id]
	var problems_before := _problems.size()
	for key in REQUIRED_KEYS:
		if not values.has(key):
			_problems.append("[%s] no %s" % [event_id, key])
	if _problems.size() > problems_before:
		return
	if not values["files"] is Array or values["files"].is_empty():
		_problems.append("[%s] files must be a list with at least one file" % event_id)
	else:
		for path in values["files"]:
			if not ResourceLoader.exists(str(path)):
				_problems.append("[%s] file %s does not exist" % [event_id, path])
	if values["pitch_min"] <= 0.0 or values["pitch_min"] > values["pitch_max"]:
		_problems.append("[%s] pitch_min must be above 0 and at most pitch_max" % event_id)
	if not BUSES.has(values["bus"]):
		_problems.append("[%s] bus must be one of %s" % [event_id, BUSES])
