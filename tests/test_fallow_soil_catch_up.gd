extends GutTest
## A sleep over the night that the days of a field of fallow soil are up on: the skip sees to the
## soil at its end, a few tiles a frame within `Simulation.frame_budget_usec`, and ends as the
## same skip in one go and the same time played do (task 166).

const SEED := 7
const FIELD := Vector2i(6, 5)


## Asks at the end of every day, after the night's upkeep, whether the field is weedy yet.
class WeedsProbe:
	extends SimulationSystem
	var world: World
	var tile: Vector2i
	var weedy_at_midnight: Array[bool] = []

	func advance(_minutes: int, clock: GameClock) -> void:
		if is_day_end(clock):
			weedy_at_midnight.append(world.fallow.is_weedy(tile))


var _state: GameState
var _field: Array[Vector2i] = []


func before_each() -> void:
	Simulation.frame_budget_usec = 0
	_state = GameState.new_game(SEED)
	_field.clear()
	var corner := _state.player.tile() + Vector2i(2, 2)
	for y in FIELD.y:
		for x in FIELD.x:
			var pos := corner + Vector2i(x, y)
			if _state.world.is_free_on(pos, Tile.Terrain.GRASS):
				_state.world.set_terrain(pos, Tile.Terrain.SOIL)
				_field.append(pos)
	assert_gt(_field.size(), FIELD.x * FIELD.y / 2, "a field")


func after_each() -> void:
	Simulation.frame_budget_usec = Simulation.DEFAULT_FRAME_BUDGET_USEC


func _next_frame() -> Signal:
	return get_tree().process_frame


## Plays the game on to 22:00 of the evening before the night that `days` of lying fallow are up
## on.
func _play_to_the_evening_before(days: int) -> void:
	for _night in days - 1:
		_state.simulation.advance(_state.clock.minutes_until(0))
	_state.simulation.advance(_state.clock.minutes_until(22 * GameClock.MINUTES_PER_HOUR))


## The game saved and loaded, with its chunks.
func _reloaded() -> GameState:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _state.world.loaded_chunk_coords():
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	return restored


func test_the_weeds_of_a_sleep_come_up_over_frames_as_in_one_go_and_as_played() -> void:
	_play_to_the_evening_before(_state.world.fallow.weedy_days)
	var played := _reloaded()
	var in_one_go := _reloaded()
	var over_frames := _reloaded()
	var probe := WeedsProbe.new()
	probe.world = over_frames.world
	probe.tile = _field[0]
	over_frames.simulation.add_system(probe)
	var frame_before := Engine.get_process_frames()

	played.simulation.advance(8 * GameClock.MINUTES_PER_HOUR)
	in_one_go.simulation.skip(8 * GameClock.MINUTES_PER_HOUR)
	await over_frames.simulation.skip_over_frames(8 * GameClock.MINUTES_PER_HOUR, _next_frame)

	assert_eq(probe.weedy_at_midnight, [false], "the skip's midnight left the soil for its end")
	assert_gt(Engine.get_process_frames() - frame_before, _field.size(), "a tile a frame")
	for pos in _field:
		assert_true(over_frames.world.fallow.is_weedy(pos), str(pos))
	assert_eq(over_frames.to_dict()["world"], in_one_go.to_dict()["world"])
	assert_eq(over_frames.to_dict()["world"], played.to_dict()["world"])


func test_a_field_grows_over_in_a_sleep() -> void:
	_play_to_the_evening_before(_state.world.fallow.grass_days)
	var over_frames := _reloaded()

	await over_frames.simulation.skip_over_frames(8 * GameClock.MINUTES_PER_HOUR, _next_frame)

	for pos in _field:
		assert_eq(over_frames.world.tile_at(pos).terrain, Tile.Terrain.GRASS, str(pos))
	assert_false(over_frames.world.is_tilled(_field[0]))


func test_a_tile_that_is_no_soil_by_its_turn_over_frames_is_left_alone() -> void:
	var world := _state.world
	var last: Vector2i = _field.back()
	for _night in world.fallow.weedy_days:
		world.fallow.count_night(1)
	world.settle_fallow_soil_over_frames(_next_frame)
	world.set_terrain(last, Tile.Terrain.GRASS)
	world.add_object(WorldObject.new(WorldObjectTypes.STONE, last))
	await wait_process_frames(_field.size() + 2)

	assert_eq(world.fallow.settled_nights, world.fallow.nights, "all seen to")
	assert_true(world.fallow.is_weedy(_field[0]))
	assert_false(world.fallow.snapshot().has(last), "grass is not filed as fallow soil")
