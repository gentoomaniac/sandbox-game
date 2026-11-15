extends ActivityCase
## The console's `routine` says where a villager is going and why, what comes next, and with `day`
## their whole day.

var _console: Console


func before_each() -> void:
	super()
	_console = Console.new(_state)


func test_a_villager_with_no_house_says_so() -> void:
	var npc := _resident("hinrich")
	npc.house = null
	npc.anchor = Vector2(12.5, 8.5)
	assert_eq(
		_console.run("routine hinrich"),
		(
			["Hinrich Boysen: no house: keeps near its anchor (12.5, 8.5), default day"]
			as Array[String]
		)
	)


func test_it_says_what_they_are_doing_and_what_comes_next() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 5, 50)
	_pass_minutes(1)
	var lines := _console.run("routine hinrich")
	assert_eq(lines[0], "Hinrich Boysen: today, Thursday, default day")
	assert_string_contains(lines[1], "now: have breakfast (home) since 05:")
	assert_string_contains(lines[1], "standing; there")
	assert_string_contains(lines[2], "next: work (workplace), 06:")
	assert_string_contains(lines[2], "; leaves 06:")
	assert_string_contains(lines[2], "(about 0 min walk)")
	assert_eq(lines[3], "shelter: none")
	assert_eq(lines[4], "trip: none")
	assert_eq(npc.current_step.activity, "breakfast")


func test_a_villager_on_the_way_says_so_and_names_the_trip() -> void:
	_build_warm_road()
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the landing", _road_tile(40))
	_set_time(DAY, 5)
	assert_true(_pass_minutes(120, func() -> bool: return npc.trip != null))
	var lines := _console.run("routine hinrich")
	assert_string_contains(lines[1], "work (workplace)")
	assert_string_contains(lines[1], "; on its way")
	assert_string_contains(lines[4], "trip: path Hinrich:")


func test_a_blocked_way_is_told_with_the_time_it_began() -> void:
	var npc := _resident("hinrich")
	npc.workplace = Workplace.of_spot("the sea", _middle + Vector2i(YARD_RADIUS + 3, 0))
	_set_time(DAY, 6)
	var is_blocked := func() -> bool:
		return npc.trip != null and npc.trip.state == NpcTrip.State.BLOCKED
	assert_true(_pass_minutes(60, is_blocked))
	_pass_minutes(1)
	assert_string_contains(_console.run("routine hinrich")[1], "; blocked since 0")
	assert_string_contains(_console.run("routine hinrich")[1], ": no way for now")


## A tilled tile near the house, so that the villager has a field to water.
func _till_a_field() -> void:
	_world.set_terrain(Vector2i(_house.yard().floor()) + Vector2i(0, 5), Tile.Terrain.SOIL)


func test_rain_is_told() -> void:
	_till_a_field()
	var weather := RainyWeather.new(SEED)
	weather.rain = 0.9
	_upkeep.weather = weather
	_resident("hinrich")
	_set_time(DAY, 17, 30)
	_pass_minutes(1)
	var lines := _console.run("routine hinrich")
	assert_string_contains(lines[1], "at home for the rain")
	assert_eq(lines[3], "shelter: rain")


func test_day_lists_every_entry_and_marks_the_one_that_is_on() -> void:
	_till_a_field()
	_resident("hinrich")
	_set_time(DAY, 12, 30)
	var lines := _console.run("routine hinrich day")
	assert_eq(lines[0], "Hinrich Boysen: today, Thursday, default day")
	assert_eq(lines.size(), 9, "the head and the eight entries of a summer weekday")
	assert_string_contains(lines[1], "have breakfast (home), up to 45 min")
	var marked := lines.filter(func(line: String) -> bool: return line.begins_with("> "))
	assert_eq(marked.size(), 1)
	assert_string_contains(marked[0], "have dinner (home)")


func test_a_villager_who_was_not_sent_yet_says_so() -> void:
	_resident("hinrich")
	assert_eq(_console.run("routine hinrich")[1], "now: nothing yet")


func test_a_wrong_usage_or_name_is_told() -> void:
	var usage := ["Usage: routine <villager> [day]"] as Array[String]
	for line in ["routine", "routine hinrich week", "routine hinrich day more"]:
		assert_eq(_console.run(line), usage, line)
	assert_eq(_console.run("routine nobody")[0], "Unknown villager: nobody")


func test_the_help_and_the_completion_know_it() -> void:
	assert_true(Console.COMMANDS.has("routine"))
	assert_eq(_console.complete("routine hinrich d"), "routine hinrich day ")
	assert_eq(_console.complete("routine hin"), "routine hinrich ")


func test_a_planned_day_says_who_planned_it_when_and_why() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 12, 30)
	var entries: Array[DayEntry] = [
		DayEntry.new("rest", 12 * 60, 0, "tired of the heat"), DayEntry.new("sleep", 21 * 60)
	]
	_upkeep.set_plan(npc, DayPlan.new(DAY, entries, true, (DAY - 2) * 1440 + 19 * 60 + 40))
	var lines := _console.run("routine hinrich")
	assert_eq(lines[0], "Hinrich Boysen: today, Thursday, planned by the model at 19:40 yesterday")
	assert_string_contains(lines[1], "now: rest (home) since 12:00")
	assert_string_contains(lines[1], '. Why: "tired of the heat"')
	var day_lines := _console.run("routine hinrich day")
	assert_eq(day_lines[1], '> 12:00 rest (home): "tired of the heat"')
	assert_eq(day_lines[2], "  21:00 sleep (home)")


func test_a_plan_for_the_rest_of_the_day_is_told_as_such() -> void:
	var npc := _resident("hinrich")
	_set_time(DAY, 14, 30)
	var entries: Array[DayEntry] = [DayEntry.new("rest", 14 * 60 + 30)]
	_upkeep.set_plan(npc, DayPlan.new(DAY, entries, false, (DAY - 1) * 1440 + 14 * 60 + 20))
	assert_eq(
		_console.run("routine hinrich")[0],
		"Hinrich Boysen: today, Thursday, planned by the model for the rest of the day at 14:20 today"
	)
