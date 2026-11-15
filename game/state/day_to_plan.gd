class_name DayToPlan
extends RefCounted
## What the language model is told of a day it plans for one villager (see NpcPrompt
## `plan_request`), and what the answer is checked against (see DayPlanAnswer): which day, from
## when, the sky and the sun of it, the activities they may be given with their places resolved
## for them, and what yesterday was like. Made when the villager's turn in the queue comes (see
## DayPlanner), so it is the world of that moment.

## The game day it is asked on, and the one to plan: tomorrow in the evening, today for a villager
## who has none.
var today := 1
var day := 1
## The minute of the day the plan starts from: DayPlanAnswer.EARLIEST_MINUTE for the whole day,
## else the time it was asked.
var from_minute := DayPlanAnswer.EARLIEST_MINUTE
## Minutes of the day, for the activities that need light.
var sunrise := 0.0
var sunset := 0.0
## The weather of the day in words (see WeatherDay `words`).
var weather_words := ""
## The activities on offer, each `{id, walk_minutes}`: how long the walk from home to the place of
## the activity takes, as ActivityRules `walk_minutes` has it.
var activities: Array[Dictionary] = []
## The entries of the day before, in a line: "05:30 have breakfast, 06:30 work"; "" if none.
var yesterday := ""


func is_whole_day() -> bool:
	return from_minute <= DayPlanAnswer.EARLIEST_MINUTE


## The ids of the activities on offer: all the answer may use.
func offered_ids() -> Array[String]:
	var ids: Array[String] = []
	for offer in activities:
		ids.append(offer["id"])
	return ids
