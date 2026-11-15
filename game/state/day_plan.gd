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


## The entries of the day with this plan: its own, with the entries of `default_day` before it if
## it is for the rest of the day. `fixed` are the default entries the plan may not move or drop:
## they are put back, and the plan's entries that start while one is on are left out.
func over(default_day: Array[DayEntry], fixed: Array[DayEntry]) -> Array[DayEntry]:
	var merged: Array[DayEntry] = []
	if not is_whole_day:
		for entry in default_day:
			if entry.minute < entries[0].minute:
				merged.append(entry)
	for entry in entries:
		var is_in_fixed := fixed.any(
			func(kept: DayEntry) -> bool:
				return entry.minute >= kept.minute and entry.minute < kept.minute + kept.minutes
		)
		if not is_in_fixed:
			merged.append(entry)
	for entry in fixed:
		if not merged.has(entry):
			merged.append(entry)
	merged.sort_custom(_is_earlier)
	return merged


static func _is_earlier(first: DayEntry, second: DayEntry) -> bool:
	return first.minute < second.minute


## The plan as save data: `{"day", "whole_day", "made_at", "entries": [[activity, minute, why]]}`.
## A planned entry has no length (`minutes` is 0), so none is saved.
func to_dict() -> Dictionary:
	return {
		"day": day,
		"whole_day": is_whole_day,
		"made_at": made_at,
		"entries":
		entries.map(
			func(entry: DayEntry) -> Array: return [entry.activity, entry.minute, entry.why]
		),
	}


static func from_dict(data: Dictionary) -> DayPlan:
	var plan_entries: Array[DayEntry] = []
	for saved: Array in data["entries"]:
		plan_entries.append(DayEntry.new(saved[0], int(saved[1]), 0, saved[2]))
	return DayPlan.new(int(data["day"]), plan_entries, data["whole_day"], int(data["made_at"]))
