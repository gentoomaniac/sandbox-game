extends CropRaidCase
## The console's `crows`, `spawn crows` and `killall crows`, and the raids in a game's time.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_crows_with_no_flocks_says_so_and_what_they_ate() -> void:
	assert_eq(_console.run("crows")[0], "No crow flocks")
	assert_string_contains(_console.run("crows")[1], "Today the crows ate 0 of")


func test_spawn_and_killall_crows_go_to_the_wildlife_of_the_view() -> void:
	var asked := []
	_console.wildlife_spawner = func(kind: StringName, count: int) -> int:
		asked.append(["spawn", kind, count])
		return count
	_console.wildlife_clearer = func(kind: StringName) -> int:
		asked.append(["clear", kind])
		return 2
	assert_eq(_console.run("spawn crows 2"), ["Spawned 2 of 2 crows"] as Array[String])
	assert_string_contains(_console.run("killall crows")[0], "Removed 2 crows")
	assert_eq(asked, [["spawn", WildlifeRules.CROWS, 2], ["clear", WildlifeRules.CROWS]])


func test_crows_raid_lets_the_flocks_raid_with_the_player_by() -> void:
	_plant_row(&"turnip", 0)
	_state.crop_raids.add_flock(_tile)
	var lines := _console.run("crows raid")
	assert_lt(_crops_left(), FIELD_WIDTH)
	assert_string_contains(lines[0], "Flock 1 at")
	assert_string_contains(lines[1], "Today the crows ate")


func test_a_flock_does_not_raid_by_itself_while_the_player_stands_by() -> void:
	_plant_row(&"turnip", 0)
	_state.crop_raids.add_flock(_tile)
	_state.simulation.advance(GameClock.MINUTES_PER_HOUR * 6)
	assert_eq(_crops_left(), FIELD_WIDTH)


func test_crows_takes_only_raid() -> void:
	assert_string_contains(_console.run("crows eat")[0], "Usage: crows [raid]")


func test_the_hours_of_the_game_let_a_flock_far_from_the_player_raid() -> void:
	_plant_row(&"turnip", 0)
	_state.player.position += Vector2(60.0, 0.0)
	_state.crop_raids.add_flock(_tile)
	_state.simulation.advance(GameClock.MINUTES_PER_HOUR * 24)
	assert_lt(_crops_left(), FIELD_WIDTH)
