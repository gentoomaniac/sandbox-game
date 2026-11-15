class_name DayPlan
extends RefCounted
## What the language model planned for one villager's day: the entries of that day, for all of it
## or for the rest of it from the time the model was asked. A day without one has the default
## day (see DefaultDay).

## How the asking of the model for a day's plan stands (see Npc `asked_plans`): it is queued or its
## answer awaited, or it came to nothing.
const WAITING := &"waiting"
const FAILED := &"failed"

## The game day it is for.
var day: int
## In time order, at least one. They have no length: each lasts until the next starts.
var entries: Array[DayEntry] = []
## Planned from the day's start, or only from `entries[0]` on, which is how a plan made during the
## day is (the entries of the default day before it stay).
var is_whole_day := true
## The game minute (see GameClock `total_minutes`) it came at.
var made_at := 0


func _init(plan_day: int, plan_entries: Array[DayEntry], whole_day: bool, minute_made: int) -> void:
	day = plan_day
	entries = plan_entries
	is_whole_day = whole_day
	made_at = minute_made


## The entries of the day with this plan: its own, with the entries of `default_day` before them if
## it is for the rest of the day.
func over(default_day: Array[DayEntry]) -> Array[DayEntry]:
	if is_whole_day:
		return entries
	var merged: Array[DayEntry] = []
	for entry in default_day:
		if entry.minute < entries[0].minute:
			merged.append(entry)
	merged.append_array(entries)
	return merged
