class_name DayPlanAnswer
extends RefCounted
## Checks what the language model answers when asked to plan a villager's day, which is JSON only:
##
##     {"day": [{"activity": "breakfast", "at": "05:30", "why": "before the milking"}, ...]}
##
## The model never moves anyone, and what it says is checked first: anything invalid is dropped and
## the rest stands. Pure, so that it is tested without a model.

## The earliest and the latest a planned entry may start at, in minutes of the day.
const EARLIEST_MINUTE := 4 * GameClock.MINUTES_PER_HOUR
const LATEST_MINUTE := 23 * GameClock.MINUTES_PER_HOUR + 30
## The longest a `why` is, in characters; the console shows it.
const MAX_WHY_LENGTH := 60
## An answer with fewer valid entries is no answer: the default day stays.
const MIN_ENTRIES_OF_DAY := 3
const MIN_ENTRIES_OF_REST_OF_DAY := 1


## The valid entries of an answer in time order, none when there is no answer (it does not parse,
## or has too few valid entries). `offered` are the activities the villager may be given that day:
## theirs, with their days and seasons holding and their place found. `sunrise` and `sunset` are
## minutes of the day, for the activities that need light. `from_minute` is EARLIEST_MINUTE to plan
## the whole day, or the time of day it was asked to plan the rest of it from: no entry starts
## before. A whole day always has a `sleep`.
static func parse(
	text: String,
	offered: Array[String],
	sunrise: float,
	sunset: float,
	from_minute: int,
	rules: ActivityRules
) -> Array[DayEntry]:
	var data: Variant = _json_in(text)
	if not data is Dictionary or not data.get("day") is Array:
		return []
	var starts: Array[DayEntry] = []
	for item: Variant in data["day"]:
		var entry := _entry_of(item, offered, sunrise, sunset, from_minute, rules)
		if entry != null:
			starts.append(entry)
	starts.sort_custom(_is_earlier)
	var entries := _spaced(starts, int(rules.number("min_gap_minutes")))
	var is_whole_day := from_minute <= EARLIEST_MINUTE
	var minimum := MIN_ENTRIES_OF_DAY if is_whole_day else MIN_ENTRIES_OF_REST_OF_DAY
	if entries.size() < minimum:
		return []
	var most := int(rules.number("max_entries"))
	var has_sleep := entries.any(_is_sleep)
	if is_whole_day and not has_sleep:
		entries = entries.slice(0, most - 1)
		entries.append(_sleep_after(entries.back(), rules))
	return entries.slice(0, most)


## What is between the first `{` and the last `}` of the text, parsed: a model wraps its JSON in
## words or fences.
static func _json_in(text: String) -> Variant:
	var first := text.find("{")
	var last := text.rfind("}")
	if first < 0 or last < first:
		return null
	var json := JSON.new()
	return json.data if json.parse(text.substr(first, last - first + 1)) == OK else null


## The entry an item of the answer is, or null if it is not a valid one.
static func _entry_of(
	item: Variant,
	offered: Array[String],
	sunrise: float,
	sunset: float,
	from_minute: int,
	rules: ActivityRules
) -> DayEntry:
	if not item is Dictionary or not item.get("activity") is String:
		return null
	var activity: String = item["activity"]
	var minute := ActivityRules.minute_of(item.get("at"))
	if not offered.has(activity) or not rules.has(activity):
		return null
	if minute < maxi(EARLIEST_MINUTE, from_minute) or minute > LATEST_MINUTE:
		return null
	var needs_daylight: bool = rules.activity(activity).get("needs_daylight", false)
	if needs_daylight and (minute < sunrise or minute >= sunset):
		return null
	var why: Variant = item.get("why", "")
	var reason: String = why.strip_edges().left(MAX_WHY_LENGTH) if why is String else ""
	return DayEntry.new(activity, minute, 0, reason)


## The entries that start at least `min_gap` minutes after the one kept before them; `entries` are
## in time order.
static func _spaced(entries: Array[DayEntry], min_gap: int) -> Array[DayEntry]:
	var kept: Array[DayEntry] = []
	for entry in entries:
		if kept.is_empty() or entry.minute - kept.back().minute >= min_gap:
			kept.append(entry)
	return kept


## A sleep at its default time, or as soon after the last entry as the gap allows.
static func _sleep_after(last: DayEntry, rules: ActivityRules) -> DayEntry:
	var usual: int = rules.default_starts(ActivityRules.SLEEP)[0]["minute"]
	var earliest := last.minute + int(rules.number("min_gap_minutes"))
	return DayEntry.new(ActivityRules.SLEEP, maxi(usual, earliest))


static func _is_earlier(first: DayEntry, second: DayEntry) -> bool:
	return first.minute < second.minute


static func _is_sleep(entry: DayEntry) -> bool:
	return entry.activity == ActivityRules.SLEEP
