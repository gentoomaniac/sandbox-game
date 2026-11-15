class_name DayPlanner
extends Node
## Has the language model plan the days of the villagers nearest the player, in the background (see
## design/villagers/routines.md, "Who is planned and when"). In the evening, at `plan_hour`, it
## queues the villagers within `plan_radius_tiles` of the player who have no plan for tomorrow,
## nearest first, up to `max_per_night`. Once a game minute it looks for villagers who have come
## into the radius with no plan for today, and queues them for the rest of today, behind the
## evening's, up to `max_per_day` a game day: the plan is there when they come into view, if the
## model is quick enough. It asks the model one villager and one request at a time, quietly, like
## the judge of the stories (see StoryJudging), and sets the plan that comes back
## (ActivityUpkeep `set_plan`), which takes over from that minute. The villager has the default
## day until then. No new query starts while a chat reply is awaited (one already out is not
## cancelled, so a reply may wait behind it on a one-slot model), and without a model, or with the
## profile's day plans switched off (see LanguageModelProfiles `uses_model_for`), nothing is asked
## but by the console's `replan`.
##
## An answer that does not come in time, with an error, or that can't be used is no plan: the day
## stays the default day and the villager is not asked for it again (Npc `asked_plans`).

## What a queued query is for, which is also how soon it is asked: the console's `replan` first,
## then the evening's, then a villager who has come near during the day.
enum Reason { CONSOLE, EVENING, DAY }

## How often (in real seconds) the clock and the queue are looked at.
const LOOK_SECONDS := 0.5
## No query for tomorrow starts after this minute of the day; one that is out may still come in.
const LAST_START_FOR_TOMORROW := 23 * GameClock.MINUTES_PER_HOUR + 50

var rules := NpcTalkRules.default_rules()
var _dialogue: NpcDialogue
var _state: GameState
var _activity_rules := ActivityRules.default_rules()
## What waits to be asked, each `{npc, day, reason, distance}`: `distance` is looked at again when
## the next one is taken.
var _queue: Array[Dictionary] = []
var _is_asking := false
var _seconds_since_look := 0.0
## The game day the evening's queue was made on.
var _evening_day := 0
## The game minute of the last look for villagers come near (see `queue_newcomers`), and how many
## it has queued on the game day `_newcomers_day`.
var _newcomers_minute := -1
var _newcomers_day := 0
var _newcomers_queued := 0


func _init(dialogue: NpcDialogue, state: GameState) -> void:
	_dialogue = dialogue
	_state = state
	_state.npcs.removed.connect(_forget)
	# Like the model's answers, it goes on while the game is paused, as it is during a chat.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_seconds_since_look += delta
	if _seconds_since_look >= LOOK_SECONDS:
		_seconds_since_look = 0.0
		queue_evening()
		queue_newcomers()
		ask_queue()


## Queues the evening's villagers, once a day, when it is `plan_hour` or later.
func queue_evening() -> void:
	var clock := _state.clock
	var is_evening := clock.minute_of_day >= int(rules.value("plan", "plan_hour")) * 60
	if not is_evening or clock.day == _evening_day or not _dialogue.has_model_for(&"day_plans"):
		return
	_evening_day = clock.day
	var tomorrow := clock.day + 1
	var most := int(rules.value("plan", "max_per_night"))
	for npc in _nearest_without_plan(tomorrow).slice(0, most):
		_enqueue(npc, tomorrow, Reason.EVENING)


## Once a game minute, queues the villagers who have come into the radius and have no plan for
## today, nearest first, as far as `max_per_day` allows for the day.
func queue_newcomers() -> void:
	var clock := _state.clock
	var minute := clock.total_minutes()
	if minute == _newcomers_minute or not _dialogue.has_model_for(&"day_plans"):
		return
	_newcomers_minute = minute
	if clock.day != _newcomers_day:
		_newcomers_day = clock.day
		_newcomers_queued = 0
	var has_time_left := clock.minute_of_day < DayPlanAnswer.LATEST_MINUTE
	var room := int(rules.value("plan", "max_per_day")) - _newcomers_queued
	if not has_time_left or room <= 0:
		return
	for npc in _nearest_without_plan(clock.day).slice(0, room):
		_enqueue(npc, clock.day, Reason.DAY)
		_newcomers_queued += 1


## Has the villager's rest of today planned at once, ahead of everything queued: the console's
## `replan`. Returns what to tell.
func replan(npc: Npc) -> String:
	if npc.house == null:
		return "%s has no house: default day" % npc.name
	if not _dialogue.has_model():
		return "No model set: default day"
	var day := _state.clock.day
	_forget(npc)
	npc.asked_plans.erase(day)
	_enqueue(npc, day, Reason.CONSOLE)
	var told := "Asking the model for the rest of the day of %s" % npc.name
	if not _dialogue.has_model_for(&"day_plans"):
		told += " (day plans are switched off in the profile: asked anyway, as a test)"
	return told


## Asks the model for every query of the queue, one after the other; a call while the queue is
## being asked leaves it to the one at work.
func ask_queue() -> void:
	if _is_asking:
		return
	_is_asking = true
	var next := _take_next()
	while not next.is_empty():
		await _ask(next["npc"], next["day"])
		next = _take_next()
	_is_asking = false


func _enqueue(npc: Npc, day: int, reason: Reason) -> void:
	npc.asked_plans[day] = DayPlan.WAITING
	_queue.append({"npc": npc, "day": day, "reason": reason, "distance": 0.0})


## The villagers within the radius of the player with a house and no plan or query for `day`,
## nearest first.
func _nearest_without_plan(day: int) -> Array[Npc]:
	var near: Array[Npc] = []
	for npc in _state.npcs.all():
		var is_planned := npc.day_plans.has(day) or npc.asked_plans.has(day)
		if npc.house != null and not is_planned and _is_near_player(npc):
			near.append(npc)
	near.sort_custom(
		func(first: Npc, second: Npc) -> bool:
			return _distance_to_player(first) < _distance_to_player(second)
	)
	return near


## The query to ask next, taken from the queue, or empty if there is none or a chat reply is
## awaited. Queries that are no use now are dropped first.
func _take_next() -> Dictionary:
	if _state.npcs.all().any(func(npc: Npc) -> bool: return npc.is_answering):
		return {}
	var kept: Array[Dictionary] = []
	for query in _queue:
		if _is_still_wanted(query):
			query["distance"] = _distance_to_player(query["npc"])
			kept.append(query)
		else:
			query["npc"].asked_plans.erase(query["day"])
	_queue = kept
	_queue.sort_custom(_is_asked_before)
	return {} if _queue.is_empty() else _queue.pop_front()


## Whether a query still makes sense: tomorrow's only until its time is out, today's only today, and
## the villager is still near (the console's query is asked wherever they are).
func _is_still_wanted(query: Dictionary) -> bool:
	var clock := _state.clock
	if query["npc"].house == null:
		return false
	if query["reason"] == Reason.EVENING:
		var is_in_time := clock.minute_of_day < LAST_START_FOR_TOMORROW
		return query["day"] == clock.day + 1 and is_in_time and _is_near_player(query["npc"])
	if query["day"] != clock.day:
		return false
	return query["reason"] == Reason.CONSOLE or _is_near_player(query["npc"])


static func _is_asked_before(first: Dictionary, second: Dictionary) -> bool:
	if first["reason"] != second["reason"]:
		return first["reason"] < second["reason"]
	return first["distance"] < second["distance"]


func _ask(npc: Npc, day: int) -> void:
	var clock := _state.clock
	var from_minute := DayPlanAnswer.EARLIEST_MINUTE
	if day == clock.day:
		from_minute = maxi(clock.minute_of_day, DayPlanAnswer.EARLIEST_MINUTE)
	var to_plan := DayToPlan.of(_state, npc, day, from_minute, _activity_rules)
	var request := NpcPrompt.plan_request(
		npc, to_plan, _activity_rules, rules, _dialogue.has_full_sheets()
	)
	var answer := await _dialogue.ask(
		_dialogue.request_at_chat_temperature(request),
		true,
		float(rules.value("plan", "timeout_seconds"))
	)
	_settle(npc, to_plan, answer)


## Sets the plan in the model's `answer` if it is a usable one for a day that is not over, from this
## minute on; else the day stays the default day.
func _settle(npc: Npc, to_plan: DayToPlan, answer: String) -> void:
	var is_gone := not _state.npcs.all().has(npc)
	if is_gone or to_plan.day < _state.clock.day:
		return
	var entries := DayPlanAnswer.parse(
		answer,
		to_plan.offered_ids(),
		to_plan.sunrise,
		to_plan.sunset,
		to_plan.from_minute,
		_activity_rules
	)
	if entries.is_empty():
		npc.asked_plans[to_plan.day] = DayPlan.FAILED
		return
	npc.asked_plans.erase(to_plan.day)
	var plan := DayPlan.new(
		to_plan.day, entries, to_plan.is_whole_day(), _state.clock.total_minutes()
	)
	_state.activities.set_plan(npc, plan)


## Takes a villager who is gone out of the queue.
func _forget(npc: Npc) -> void:
	_queue = _queue.filter(func(query: Dictionary) -> bool: return query["npc"] != npc)


func _is_near_player(npc: Npc) -> bool:
	return _distance_to_player(npc) <= float(rules.value("plan", "plan_radius_tiles"))


func _distance_to_player(npc: Npc) -> float:
	return npc.position.distance_to(Vector2(_state.outdoor_tile()))
