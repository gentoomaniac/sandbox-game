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


## What to tell about `day` for a villager with a house in the game of `state`, to plan from
## `from_minute` of the day on.
static func of(
	state: GameState,
	npc: Npc,
	day: int,
	from_minute: int,
	activity_rules := ActivityRules.default_rules()
) -> DayToPlan:
	var to_plan := DayToPlan.new()
	to_plan.today = state.clock.day
	to_plan.day = day
	to_plan.from_minute = from_minute
	to_plan.sunrise = state.sun.sunrise(day)
	to_plan.sunset = state.sun.sunset(day)
	var weather := state.weather.day_summary(npc.tile(), day)
	to_plan.weather_words = weather.words(activity_rules.number("rain_hour_limit"))
	to_plan.activities = state.activities.offers_of(npc, day)
	if day > 1:
		var lines: Array[String] = []
		for entry in state.activities.entries_of(npc, day - 1):
			var verb: String = activity_rules.activity(entry.activity)["verb"]
			lines.append("%s %s" % [Sun.time_text(entry.minute), verb])
		to_plan.yesterday = ", ".join(lines)
	return to_plan
