extends EnergyCase
## The console's `reset` command: back to the bed the player wakes in.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_reset_puts_the_player_in_the_camp_bed_from_anywhere_outside() -> void:
	_state.player.position += Vector2(9, 4)
	assert_eq(_console.run("reset"), ["Back in bed"] as Array[String])
	assert_eq(_state.player.bed_lying_in, _bed())
	assert_true(_bed().covers(_state.player.tile()))
	assert_false(_state.is_inside())


func test_reset_takes_the_player_into_the_house_whose_bed_is_home() -> void:
	var bed := _make_a_house_home()
	assert_false(_state.is_inside())
	_console.run("reset")
	assert_true(_state.is_inside())
	assert_eq(_state.player.bed_lying_in, bed)


func test_reset_takes_the_player_out_of_a_house_to_a_home_in_the_world() -> void:
	var camp_bed := _bed()
	_make_a_house_home()
	_state.pass_out()
	assert_true(_state.is_inside())
	_state.player.home_map = _world
	_state.player.home_bed = camp_bed.pos
	_console.run("reset")
	assert_false(_state.is_inside())
	assert_eq(_state.player.bed_lying_in, camp_bed)


func test_reset_frees_a_player_who_stands_in_the_bed_of_a_house() -> void:
	_make_a_house_home()
	_console.run("reset")
	_state.player.move(_state.current_map, Vector2.DOWN, 0.4)
	_console.run("reset")
	assert_not_null(_state.player.bed_lying_in)


func test_help_lists_reset() -> void:
	assert_string_contains("\n".join(_console.run("help")), "reset")


func test_reset_finds_the_camp_bed_when_its_chunk_is_not_loaded() -> void:
	var camp_bed := _bed()
	var camp_chunk := Chunk.world_to_chunk(camp_bed.pos)
	_world.remove_chunk(camp_chunk)
	assert_false(_world.is_chunk_loaded(camp_chunk))
	_state.player.position = Vector2(Chunk.CHUNK_SIZE * 6, 0)
	_console.run("reset")
	assert_not_null(_state.player.bed_lying_in)
	assert_true(camp_bed.covers(_state.player.tile()))
