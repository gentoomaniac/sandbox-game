class_name ActivityRules
extends RefCounted
## What villagers do in a day, read from data/activities.cfg (see there for what each key means):
## the activities with their default times, the numbers they share, and the sets that say who has
## which. `from_file` reports everything wrong with the file, and `is_valid` says whether anything
## was.

const DEFAULT_PATH := "res://data/activities.cfg"
## The sections that are not activities.
const RULES_SECTION := "rules"
const SETS_SECTION := "sets"
const RULES_KEYS: Array[String] = [
	"detour_factor",
	"arrive_margin_minutes",
	"spread_minutes",
	"rain_hour_limit",
	"search_tiles",
	"max_entries",
	"min_gap_minutes",
	"feasts",
]
## The targets that are looked for within `search_tiles` of the villager's home.
const SEARCH_KINDS: Array[String] = ["field", "church", "meeting", "friend", "wild"]
## The activity every day has (see DefaultDay), and the set everybody has.
const SLEEP := "sleep"
const BASE_SET := "base"

## Where an activity is done, relative to the villager (see ActivityPlaces).
const TARGETS: Array[String] = ["home", "workplace", "field", "church", "meeting", "friend", "wild"]
## How they stand there: still, strolling within the radius, or at work.
const DOINGS: Array[String] = ["stand", "walk_about", "work"]
## The kinds of a day an activity can be planned for: Monday to Friday, Saturday, Sunday, and the
## feasts, which are Sundays too.
const DAY_KINDS: Array[String] = ["weekday", "saturday", "sunday", "feast"]
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const REQUIRED_KEYS: Array[String] = ["verb", "target", "doing"]
const TEXT_KEYS: Array[String] = ["verb"]
const FLAG_KEYS: Array[String] = ["needs_daylight", "needs_dry"]

static var _default: ActivityRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> ActivityRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> ActivityRules:
	var rules := ActivityRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## The minute of the day of a time such as "06:30", or -1 if the text is not one.
static func minute_of(time_text: Variant) -> int:
	if not time_text is String:
		return -1
	var parts: PackedStringArray = time_text.split(":")
	if parts.size() != 2 or parts[0].length() != 2 or parts[1].length() != 2:
		return -1
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	var hour := int(parts[0])
	var minute := int(parts[1])
	if hour > 23 or minute > 59:
		return -1
	return hour * GameClock.MINUTES_PER_HOUR + minute


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	for key in RULES_KEYS:
		if not _values.get(RULES_SECTION, {}).has(key):
			found.append("[%s] no %s" % [RULES_SECTION, key])
	found.append_array(_rules_problems())
	for id in ids():
		found.append_array(_activity_problems(id))
	found.append_array(_set_problems())
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The activities, in the order of the file.
func ids() -> Array[String]:
	var found: Array[String] = []
	for section: String in _values:
		if section != RULES_SECTION and section != SETS_SECTION:
			found.append(section)
	return found


func has(id: String) -> bool:
	return ids().has(id)


## The activity as written: {verb, target, doing} and the optional keys that are there.
func activity(id: String) -> Dictionary:
	return _values[id]


## A key of [rules] that is a number.
func number(key: String) -> float:
	return float(_values[RULES_SECTION][key])


## How many tiles from home `kind` ("field", "church", ...) is looked for.
func search_tiles(kind: String) -> float:
	return float(_values[RULES_SECTION]["search_tiles"][kind])


## The day of the year of a feast ("easter", "christmas").
func feast_days() -> Array:
	return _values[RULES_SECTION]["feasts"].values()


## The default starts of an activity, each `{minute, minutes}`: the minute of the day it starts at
## and the most minutes it lasts. None for one that has no default time.
func default_starts(id: String) -> Array[Dictionary]:
	var starts: Array[Dictionary] = []
	for pair: Array in _values[id].get("at", []):
		starts.append({"minute": minute_of(pair[0]), "minutes": int(pair[1])})
	return starts


## The kinds of day (DAY_KINDS) a game day is: Monday to Friday, Saturday or Sunday, and a feast
## when it is the day of the year of one.
func day_kinds(day: int) -> Array[String]:
	var kinds: Array[String] = []
	match GameClock.weekday_of(day):
		5:
			kinds.append("saturday")
		6:
			kinds.append("sunday")
		_:
			kinds.append("weekday")
	if feast_days().has(GameClock.day_of_year_of(day)):
		kinds.append("feast")
	return kinds


## Whether the activity can be planned on `day`: its `days` and `seasons`, which hold always when
## the activity has none.
func fits_day(id: String, day: int) -> bool:
	var days: Array = _values[id].get("days", DAY_KINDS)
	return (
		fits_season(id, day) and day_kinds(day).any(func(kind: String) -> bool: return kind in days)
	)


func fits_season(id: String, day: int) -> bool:
	var seasons: Array = _values[id].get("seasons", SEASONS)
	return SEASONS[GameClock.season_of(day)] in seasons


## Whether the activity has its default starts on `day`: it can be planned then, and `at_days`
## holds.
func has_default_on(id: String, day: int) -> bool:
	if not fits_day(id, day):
		return false
	var at_days: Array = _values[id].get("at_days", DAY_KINDS)
	return day_kinds(day).any(func(kind: String) -> bool: return kind in at_days)


## How long a walk from `from` to `to` takes, in game minutes, by the estimate of the plan: the
## tiles along x plus the tiles along y, times `detour_factor`.
func walk_minutes(from: Vector2, to: Vector2, tiles_per_minute: float) -> float:
	var tiles := absf(to.x - from.x) + absf(to.y - from.y)
	return tiles * number("detour_factor") / tiles_per_minute


## The minute of the day to leave at, to be there at `start_minute` after a walk of `walk`
## minutes, with the margin of the rules. Before midnight is negative.
func leaving_minute(start_minute: int, walk: float) -> int:
	return start_minute - ceili(walk) - int(number("arrive_margin_minutes"))


func set_names() -> Array[String]:
	var found: Array[String] = []
	found.assign(_values.get(SETS_SECTION, {}).keys())
	return found


func has_set(set_name: String) -> bool:
	return _values.get(SETS_SECTION, {}).has(set_name)


## The activities of a set, in the order of the file.
func set_activities(set_name: String) -> Array[String]:
	var found: Array[String] = []
	found.assign(_values[SETS_SECTION][set_name])
	return found


func _rules_problems() -> Array[String]:
	var found: Array[String] = []
	var section: Dictionary = _values.get(RULES_SECTION, {})
	for key in RULES_KEYS:
		if not section.has(key) or key in ["search_tiles", "feasts"]:
			continue
		# No spread is fine: they all start at once.
		if float(section[key]) < 0 or float(section[key]) == 0 and key != "spread_minutes":
			found.append("[%s] %s must be above 0" % [RULES_SECTION, key])
	if section.has("search_tiles"):
		var tiles: Variant = section["search_tiles"]
		var is_tiles: bool = (
			tiles is Dictionary
			and tiles.keys().size() == SEARCH_KINDS.size()
			and SEARCH_KINDS.all(func(kind: String) -> bool: return float(tiles.get(kind, 0)) > 0)
		)
		if not is_tiles:
			found.append(
				(
					"[%s] search_tiles is not tiles above 0 for each of %s"
					% [RULES_SECTION, SEARCH_KINDS]
				)
			)
	if section.has("feasts"):
		var feasts: Variant = section["feasts"]
		var is_day_of_year := func(day: Variant) -> bool:
			return day is int and day >= 1 and day <= GameClock.DAYS_PER_YEAR
		if not feasts is Dictionary or not feasts.values().all(is_day_of_year):
			found.append("[%s] feasts is not days of the year" % RULES_SECTION)
	return found


func _activity_problems(id: String) -> Array[String]:
	var found: Array[String] = []
	var values: Dictionary = _values[id]
	for key in REQUIRED_KEYS:
		if not values.has(key):
			found.append("[%s] no %s" % [id, key])
	for key in TEXT_KEYS:
		if values.has(key) and not (values[key] is String and not values[key].is_empty()):
			found.append("[%s] %s is not a text" % [id, key])
	if values.has("target") and values["target"] not in TARGETS:
		found.append("[%s] target is not one of %s" % [id, TARGETS])
	if values.has("doing") and values["doing"] not in DOINGS:
		found.append("[%s] doing is not one of %s" % [id, DOINGS])
	if values.has("radius") and not float(values["radius"]) > 0.0:
		found.append("[%s] radius must be above 0" % id)
	for key in FLAG_KEYS:
		if values.has(key) and not values[key] is bool:
			found.append("[%s] %s is not true or false" % [id, key])
	if values.has("priority") and not values["priority"] is int:
		found.append("[%s] priority is not a whole number" % id)
	found.append_array(_list_problems(id, values, "days", DAY_KINDS))
	found.append_array(_list_problems(id, values, "at_days", DAY_KINDS))
	found.append_array(_list_problems(id, values, "seasons", SEASONS))
	found.append_array(_start_problems(id, values))
	return found


## What is wrong with the list of `key`, which may only hold the `allowed` words.
func _list_problems(
	id: String, values: Dictionary, key: String, allowed: Array[String]
) -> Array[String]:
	if not values.has(key):
		return []
	var list: Variant = values[key]
	if (
		not list is Array
		or list.is_empty()
		or list.any(func(word: Variant) -> bool: return word not in allowed)
	):
		return ["[%s] %s is not a list of some of %s" % [id, key, allowed]]
	return []


## What is wrong with the `at` of an activity: times "HH:MM" of the day, with lengths in minutes
## that are more than 0 and at most a day.
func _start_problems(id: String, values: Dictionary) -> Array[String]:
	if not values.has("at"):
		if values.has("at_days"):
			return ["[%s] at_days without at" % id]
		return []
	var is_start := func(pair: Variant) -> bool:
		return (
			pair is Array
			and pair.size() == 2
			and minute_of(pair[0]) >= 0
			and pair[1] is int
			and pair[1] > 0
			and pair[1] <= GameClock.MINUTES_PER_DAY
		)
	var starts: Variant = values["at"]
	if not starts is Array or starts.is_empty() or not starts.all(is_start):
		return ['[%s] at is not a list of ["HH:MM", minutes]' % id]
	return []


## What is wrong with the sets: they name activities that are in the file, `base` is there and has
## `sleep`, and every activity is in some set.
func _set_problems() -> Array[String]:
	var found: Array[String] = []
	var sets: Dictionary = _values.get(SETS_SECTION, {})
	if not sets.has(BASE_SET):
		found.append("[%s] no %s" % [SETS_SECTION, BASE_SET])
	var used := {}
	for set_name: String in sets:
		var members: Variant = sets[set_name]
		if not members is Array or members.is_empty():
			found.append("[%s] %s is not a list of activities" % [SETS_SECTION, set_name])
			continue
		for id: Variant in members:
			if not id is String or not has(id):
				found.append(
					"[%s] %s names %s, which is no activity" % [SETS_SECTION, set_name, id]
				)
			used[id] = true
	if sets.has(BASE_SET) and not SLEEP in sets[BASE_SET]:
		found.append("[%s] %s has no %s" % [SETS_SECTION, BASE_SET, SLEEP])
	for id in ids():
		if not used.has(id):
			found.append("[%s] is in no set" % id)
	return found
