class_name DayEntry
extends RefCounted
## One thing a villager does in a day, from `minute` of the day: an activity of data/activities.cfg
## for at most `minutes` (0: until the next entry of the day). A day is a list of them in time
## order, made by DefaultDay or planned by the language model.

## An activity of ActivityRules.
var activity: String
## The minute of the day it starts at, 0 to 1439.
var minute: int
## How long it lasts at the most; 0 for until the next entry starts.
var minutes: int
## Why, in the words of the model for the console; "" for a default entry.
var why := ""


func _init(entry_activity: String, start_minute: int, most_minutes := 0, reason := "") -> void:
	activity = entry_activity
	minute = start_minute
	minutes = most_minutes
	why = reason


## The entry that is on at `now` (a minute of the day) in the entries of a day, `today`, with
## those of the day before, `yesterday`, whose last entry may run over midnight (sleep does); null
## when none is on: the last one's length has run out, or there are no entries. Both lists are in
## time order.
static func on(today: Array[DayEntry], yesterday: Array[DayEntry], now: int) -> DayEntry:
	var started: DayEntry
	var started_minute := 0
	for entry in today:
		if entry.minute <= now:
			started = entry
			started_minute = entry.minute
		else:
			break
	if started == null and not yesterday.is_empty():
		started = yesterday.back()
		started_minute = started.minute - GameClock.MINUTES_PER_DAY
	if started == null:
		return null
	var is_over := started.minutes > 0 and now >= started_minute + started.minutes
	return null if is_over else started
