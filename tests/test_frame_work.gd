extends GutTest
## The work of a frame of play (GameState `frame_work`): the flood fills in real seconds, and the
## console's freeze and a skip spread over frames hold it (design/world/storm-surge.md).

const SEED := CoastWorld.SEED
const NOW := 1000
const STRONGEST_LEVEL := 3.4
## Real seconds of a 60 fps frame.
const FRAME := 1.0 / 60.0

var _state: GameState
var _flood: FloodState
var _wet_at_frames: Array[int] = []


func before_each() -> void:
	_state = _new_game_on_the_coast()
	_flood = _state.world.flood


# The new game with the chunks of the sea dyke (see CoastWorld) loaded, and the clock at NOW.
func _new_game_on_the_coast() -> GameState:
	var state := GameState.new_game(SEED)
	var generator := WorldGenerator.new(SEED)
	for y in range(CoastWorld.CHUNK_ROWS.x, CoastWorld.CHUNK_ROWS.y):
		for x in range(CoastWorld.CHUNK_COLUMNS.x, CoastWorld.CHUNK_COLUMNS.y):
			if state.world.chunk_at(Vector2i(x, y)) == null:
				state.world.add_chunk(generator.generate_chunk(Vector2i(x, y)))
	state.clock.advance(NOW)
	return state


func _begin_flood() -> void:
	_flood.begin(_state.world, STRONGEST_LEVEL, NOW, 1)


func _play_seconds(seconds: float) -> void:
	for _frame in roundi(seconds / FRAME):
		_state.frame_work(FRAME)


func test_the_frames_fill_the_flood_at_the_designed_rate() -> void:
	_begin_flood()
	assert_eq(_flood.wet_count(), 0, "a flood begins dry, the frames fill it")
	var per_second: float = LandscapeRules.default_rules().value("surge", "fill_tiles_per_second")
	_play_seconds(1.0)
	assert_almost_eq(float(_flood.wet_count()), per_second, 2.0)


func test_a_frame_fills_no_more_than_the_tile_budget() -> void:
	_begin_flood()
	var most: float = LandscapeRules.default_rules().value("surge", "fill_tiles_per_step")
	_state.frame_work(10.0)
	assert_lte(float(_flood.wet_count()), most)


func test_the_frames_end_with_the_same_water_as_a_settle() -> void:
	_begin_flood()
	_play_seconds(120.0)
	var settled := _new_game_on_the_coast()
	settled.world.flood.begin(settled.world, STRONGEST_LEVEL, NOW, 1)
	settled.world.flood.settle(settled.world)
	assert_gt(_flood.wet_count(), 0)
	assert_eq(_flood.wet_count(), settled.world.flood.wet_count())


func test_the_console_freeze_holds_the_flood() -> void:
	_begin_flood()
	_state.cheats.is_time_stopped = true
	_play_seconds(1.0)
	assert_eq(_flood.wet_count(), 0)
	_state.cheats.is_time_stopped = false
	_play_seconds(1.0)
	assert_gt(_flood.wet_count(), 0)


func test_the_flood_goes_on_while_the_player_is_indoors() -> void:
	var building := _state.world.place_building(BuildingTypes.SHACK, _open_origin())
	_state.player.position = Vector2(building.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	_begin_flood()
	_play_seconds(1.0)
	assert_gt(_flood.wet_count(), 0)


func _open_origin() -> Vector2i:
	for x in range(-24, 25):
		var origin := _state.player.tile() + Vector2i(x, 0)
		if _state.world.placement_blockers(BuildingTypes.SHACK, origin).is_empty():
			return origin
	fail_test("no room for a shack near the camp")
	return Vector2i.ZERO


func test_a_skip_over_frames_holds_the_frames_and_the_flood_is_settled_at_its_end() -> void:
	_begin_flood()
	_wet_at_frames.clear()
	await _state.simulation.skip_over_frames(90, _next_frame)
	assert_eq(_wet_at_frames[0], 0, "the frames of the skip fill nothing")
	var settled := _new_game_on_the_coast()
	settled.world.flood.begin(settled.world, STRONGEST_LEVEL, NOW, 1)
	settled.world.flood.settle(settled.world)
	assert_gt(_flood.wet_count(), 0)
	assert_eq(_flood.wet_count(), settled.world.flood.wet_count())


# The play loop keeps calling `frame_work` meanwhile, as Main does.
func _next_frame() -> Signal:
	_state.frame_work(FRAME)
	_wet_at_frames.append(_flood.wet_count())
	return get_tree().process_frame
