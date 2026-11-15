class_name RoutineReport
extends RefCounted
## What the console's `routine` says about a villager's day: where they are going and why, what
## comes next and when they leave for it, and what the weather says to the activity. `day` lists
## every entry of the day.

const DOINGS := {"stand": "standing", "walk_about": "strolling", "work": "at work"}


## The lines about `npc` for the day of the game in `state`.
static func lines(state: GameState, npc: Npc, is_whole_day := false) -> Array[String]:
	var upkeep := state.activities
	var clock := state.clock
	var head := "%s: " % npc.name
	if npc.house == null:
		return [
			(
				head
				+ (
					"no house: keeps near its anchor (%.1f, %.1f), default day"
					% [npc.anchor.x, npc.anchor.y]
				)
			)
		]
	var weekday: String = GameClock.WEEKDAY_NAMES[GameClock.weekday_of(clock.day)]
	var source := _source_text(npc, clock.day)
	var lines: Array[String] = [head + "today, %s, %s" % [weekday, source]]
	if is_whole_day:
		lines.append_array(_day_lines(upkeep.entries_of(npc, clock.day), upkeep.entry_on(npc)))
		return lines
	var on := upkeep.entry_on(npc)
	var why := "" if on == null or on.why.is_empty() else '. Why: "%s"' % on.why
	lines.append("now: %s%s" % [_now_text(npc), why])
	var next := upkeep.next_step_of(npc)
	lines.append("next: %s" % ("nothing" if next == null else _next_text(next)))
	var activity := "" if npc.current_step == null else npc.current_step.activity
	var shelter := upkeep.shelter_of(npc, activity)
	lines.append("shelter: %s" % ("none" if shelter == "" else shelter))
	lines.append("trip: %s" % (NpcTravel.text_of(npc) if npc.is_travelling() else "none"))
	return lines


## "default day", why the model has not planned it, or when and for how much of the day it did.
static func _source_text(npc: Npc, today: int) -> String:
	var plan: DayPlan = npc.day_plans.get(today)
	if plan == null:
		match npc.asked_plans.get(today):
			DayPlan.WAITING:
				return "default day: the model is asked"
			DayPlan.FAILED:
				return "default day: the model gave no plan in time, or none the game could use"
		return "default day"
	var made_on := GameClock.day_of(plan.made_at)
	var when := "today" if made_on == today else "yesterday"
	var time := Sun.time_text(plan.made_at % GameClock.MINUTES_PER_DAY)
	var part := "" if plan.is_whole_day else " for the rest of the day"
	return "planned by the model%s at %s %s" % [part, time, when]


## Every entry of the day, a line each, the one that is on marked.
static func _day_lines(entries: Array[DayEntry], on: DayEntry) -> Array[String]:
	var lines: Array[String] = []
	var rules := ActivityRules.default_rules()
	for entry in entries:
		var data := rules.activity(entry.activity)
		var marker := "> " if entry == on else "  "
		var time := Sun.time_text(entry.minute)
		var length := "" if entry.minutes == 0 else ", up to %d min" % entry.minutes
		var why := "" if entry.why.is_empty() else ': "%s"' % entry.why
		lines.append("%s%s %s (%s)%s%s" % [marker, time, data["verb"], data["target"], length, why])
	if lines.is_empty():
		lines.append("  no entries")
	return lines


## What they were sent to do last, where, since when, and how it stands with the way there.
static func _now_text(npc: Npc) -> String:
	var step := npc.current_step
	if step == null:
		return "nothing yet"
	var text := _step_text(step)
	if step.minute >= 0:
		text += " since %s" % Sun.time_text(step.minute)
	if not step.has_place():
		return text + ": no place for it, skipped"
	text += ", %s" % DOINGS[step.doing]
	if step.shelter != "":
		text += ", at home for the %s" % step.shelter
	if step.is_given_up:
		text += ", no way found: given up, at home"
	if step.is_arrived:
		return text + "; there"
	if step.blocked_since >= 0:
		return (
			text + "; blocked since %s: no way for now" % Sun.time_text(step.blocked_since % 1440)
		)
	return text + "; on its way"


## "dinner at home, 12:00; leaves 11:41 (about 19 min walk)".
static func _next_text(step: ActivityStep) -> String:
	if not step.has_place():
		return "%s, %s; no place for it" % [_step_text(step), Sun.time_text(step.minute)]
	return (
		"%s, %s; leaves %s (about %d min walk)"
		% [
			_step_text(step),
			Sun.time_text(step.minute),
			Sun.time_text(step.leaves_at % GameClock.MINUTES_PER_DAY),
			ceili(step.walk_minutes),
		]
	)


## "work (workplace)", or the yard of their home for the time between entries.
static func _step_text(step: ActivityStep) -> String:
	if step.activity == "":
		return "keeping to the yard of their home"
	var data := ActivityRules.default_rules().activity(step.activity)
	return "%s (%s)" % [data["verb"], data["target"]]
