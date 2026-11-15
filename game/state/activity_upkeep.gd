class_name ActivityUpkeep
extends SimulationSystem
## Executes the day of each villager (see DefaultDay and DayEntry): once a game minute it looks for
## the entry that is on, sends the villager there in time (`Npcs.walk_to`), and when they arrive
## makes the place their anchor and the activity's radius the circle they keep to. It runs from the
## clock, not from a frame, so it goes on while the player is inside a building.
##
## A villager leaves so as to be there at the entry's time: the entry's time less the walk (the
## tiles along x plus those along y, with a detour, see ActivityRules `walk_minutes`) and a margin.
## One who is late is late; nothing is made up. Rain and the dark change what is on, not the plan:
## an activity that needs light or dry weather is replaced by standing at home while it is dark or
## wet. A way that stays blocked is given up after `blocked_give_up_minutes`. A villager with no
## house is not sent anywhere: the anchor rule of Npcs keeps them where they are.

## A villager this near the spot of a step that is for standing is there already.
const ARRIVED_TILES := 1.5

## What the rain of an hour is asked of; the tests put a weather of their own in its place.
var weather: Weather
## Where the activities are done; the tests count what it is asked.
var places: ActivityPlaces

var _world: World
var _npcs: Npcs
var _sun: Sun
var _clock: GameClock
var _rules: ActivityRules
## {Npc: {day: entries}}: the days of the villagers, made when asked for.
var _days_of_npc := {}
## {Npc: ActivityStep}: the next entry of a villager, with the minute they leave for it.
var _next_step_of_npc := {}
## A skip's rest is not played minute by minute (see `skip_begins`).
var _is_in_skip := false


func _init(
	world: World,
	npcs: Npcs,
	homes: Households,
	sun: Sun,
	world_weather: Weather,
	clock: GameClock,
	rules := ActivityRules.default_rules()
) -> void:
	_world = world
	_npcs = npcs
	places = ActivityPlaces.new(world, npcs, rules)
	_sun = sun
	weather = world_weather
	_clock = clock
	_rules = rules
	npcs.trip_arrived.connect(_on_trip_arrived)
	npcs.removed.connect(forget)
	homes.changed.connect(_on_place_changed)


func advance(_minutes: int, _clock_at_end: GameClock) -> void:
	if _is_in_skip:
		return
	for npc in _npcs.all():
		_follow_day(npc)


func skip_begins(_minutes: int) -> void:
	_is_in_skip = true


func skipped(_minutes: int, _clock_at_end: GameClock) -> void:
	_is_in_skip = false


## The entries of a villager's day, made once and kept for the days around the one asked for: a
## field tilled or a church built later shows in the days made after it, not in one already kept.
## A wild spot counts as found, as it is only looked for (in the loaded land) when the entry is on.
func entries_of(npc: Npc, day: int) -> Array[DayEntry]:
	var days: Dictionary = _days_of_npc.get(npc, {})
	if not days.has(day):
		for kept_day: int in days.keys():
			if absi(kept_day - day) > 2:
				days.erase(kept_day)
		var activities := VillagerActivities.of(npc, _npcs.villagers, _npcs.rules, _rules)
		var has_place := func(activity: String) -> bool:
			var target: String = _rules.activity(activity)["target"]
			return target == "wild" or places.spot_of(npc, target, day) != ActivityPlaces.NOWHERE
		days[day] = DefaultDay.of(npc, activities, day, _world.world_seed, _rules, has_place)
		_days_of_npc[npc] = days
	return days[day]


## The entry of the villager's day that is on now, or null.
func entry_on(npc: Npc) -> DayEntry:
	var yesterday: Array[DayEntry] = []
	if _clock.day > 1:
		yesterday = entries_of(npc, _clock.day - 1)
	return DayEntry.on(entries_of(npc, _clock.day), yesterday, _clock.minute_of_day)


## Why the activity is not done now, "rain" or "dark", or "" if it can be.
func shelter_of(npc: Npc, activity: String) -> String:
	if activity == "":
		return ""
	var data := _rules.activity(activity)
	var minute := _clock.minute_of_day
	if data.get("needs_daylight", false):
		if minute < _sun.sunrise(_clock.day) or minute >= _sun.sunset(_clock.day):
			return "dark"
	if data.get("needs_dry", false):
		var hour := minute / GameClock.MINUTES_PER_HOUR
		if weather.rain_in_hour(npc.tile(), _clock.day, hour) >= _rules.number("rain_hour_limit"):
			return "rain"
	return ""


## Forgets what is kept of a villager: their days and their next step. `Households` changing, or a
## plan arriving, is the cause.
func forget(npc: Npc) -> void:
	_days_of_npc.erase(npc)
	_next_step_of_npc.erase(npc)


## Sends the villager where their day has them be now, if that is not where they were sent last.
func _follow_day(npc: Npc) -> void:
	if npc.house == null:
		npc.current_step = null
		npc.keep_radius = 0.0
		npc.is_staying_put = false
		return
	var step := _due_step_of(npc)
	var current := npc.current_step
	if current != null and current.is_same_as(step):
		_give_up_blocked_way(npc, current)
		return
	_send(npc, step)


## What the villager is to do now: the next entry once they have to leave for it, else the one
## that is on, else keeping to the yard of their home; at home instead for the day's rain or dark.
func _due_step_of(npc: Npc) -> ActivityStep:
	var next := _next_step_of(npc)
	var is_next_due := next != null and _clock.total_minutes() >= next.leaves_at
	var entry: DayEntry = null if is_next_due else entry_on(npc)
	var activity := ""
	var minute := -1
	if is_next_due:
		activity = next.activity
		minute = next.minute
	elif entry != null:
		activity = entry.activity
		minute = entry.minute
	var shelter := shelter_of(npc, activity)
	# The place is looked for once for an entry, not every minute it is on.
	var current := npc.current_step
	if current != null and current.matches(activity, minute, shelter):
		return current
	var step := next.copy() if is_next_due else ActivityStep.new(activity, minute)
	if not is_next_due:
		_resolve(npc, step, _clock.day)
	step.shelter = shelter
	if shelter != "":
		_stay_home(npc, step)
	return step


## The first entry that starts after now (today's, else tomorrow's first), with its spot and the
## game minute the villager leaves for it; null with none to come. It is kept until it starts.
func _next_step_of(npc: Npc) -> ActivityStep:
	var total := _clock.total_minutes()
	var kept: ActivityStep = _next_step_of_npc.get(npc)
	if kept != null and kept.starts_at > total:
		return kept
	var timeline := _timeline_of(npc)
	var index := 0
	while index < timeline.size() and timeline[index]["starts_at"] <= total:
		index += 1
	if index == timeline.size():
		return null
	var next: DayEntry = timeline[index]["entry"]
	var starts_at: int = timeline[index]["starts_at"]
	var step := ActivityStep.new(next.activity, next.minute)
	step.starts_at = starts_at
	_resolve(npc, step, GameClock.day_of(starts_at))
	var walk := _rules.walk_minutes(_place_before(npc), step.spot, _tiles_per_minute())
	step.leaves_at = _rules.leaving_minute(starts_at, walk)
	# Not before the entry before starts: a way longer than it lasts is walked all of it.
	if index > 0:
		step.leaves_at = maxi(step.leaves_at, timeline[index - 1]["starts_at"])
	_next_step_of_npc[npc] = step
	return step


## The entries of yesterday, today and tomorrow in order, each `{entry, starts_at}`, with
## `starts_at` in game minutes (see GameClock `total_minutes`).
func _timeline_of(npc: Npc) -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	for day in range(maxi(_clock.day - 1, 1), _clock.day + 2):
		var day_start := (day - 1) * GameClock.MINUTES_PER_DAY
		for entry in entries_of(npc, day):
			timeline.append({"entry": entry, "starts_at": day_start + entry.minute})
	return timeline


## Fills in where the step is done and how, for the villager on game day `day`.
func _resolve(npc: Npc, step: ActivityStep, day: int) -> void:
	if step.activity == "":
		_stay_home(npc, step)
		return
	var data := _rules.activity(step.activity)
	step.spot = places.spot_of(npc, data["target"], day)
	step.doing = data["doing"]
	step.radius = data.get("radius", 0.0)


func _stay_home(npc: Npc, step: ActivityStep) -> void:
	step.spot = npc.house.yard()
	step.doing = "stand" if step.shelter != "" or step.is_given_up else "walk_about"
	step.radius = 0.0


## Sends the villager to the step's spot, or just makes it their anchor if they are there.
func _send(npc: Npc, step: ActivityStep) -> void:
	npc.current_step = step
	if not step.has_place():
		return
	if npc.position.distance_to(step.spot) <= maxf(step.radius, ARRIVED_TILES):
		_npcs.cancel_trip(npc)
		_arrive(npc, step)
	else:
		_npcs.walk_to(npc, step.tile(), _world)


func _arrive(npc: Npc, step: ActivityStep) -> void:
	step.is_arrived = true
	step.blocked_since = -1
	npc.anchor = step.spot
	npc.keep_radius = step.radius
	npc.is_staying_put = step.doing == "stand"


## A villager whose way has been blocked for `blocked_give_up_minutes` stays at home for the rest
## of the entry; if the way home is blocked too they stay where they are.
func _give_up_blocked_way(npc: Npc, step: ActivityStep) -> void:
	if npc.trip == null or npc.trip.state != NpcTrip.State.BLOCKED:
		step.blocked_since = -1
		return
	var total := _clock.total_minutes()
	if step.blocked_since < 0:
		step.blocked_since = total
	elif total - step.blocked_since >= _rules.number("blocked_give_up_minutes"):
		if step.is_given_up:
			_npcs.cancel_trip(npc)
			return
		step.is_given_up = true
		step.blocked_since = -1
		_stay_home(npc, step)
		_send(npc, step)


func _on_trip_arrived(npc: Npc) -> void:
	var step := npc.current_step
	if step != null and step.has_place() and not step.is_arrived and npc.tile() == step.tile():
		_arrive(npc, step)


func _on_place_changed(npc: Npc) -> void:
	forget(npc)
	npc.current_step = null
	_follow_day(npc)


## Where the villager is, or is going: the place of the entry before the one to come.
func _place_before(npc: Npc) -> Vector2:
	var step := npc.current_step
	return npc.position if step == null or not step.has_place() else step.spot


## The pace of a villager, in tiles a game minute.
func _tiles_per_minute() -> float:
	return _npcs.rules.behaviour("walk_speed") / GameClock.GAME_MINUTES_PER_REAL_SECOND
