extends LivestockCase
## A big herd that skips a long time (sleeping) is caught up a few animals to a frame, within
## `Simulation.frame_budget_usec`, and ends as the same skip in one go does.

const HERD := 60


func before_each() -> void:
	super()
	Simulation.frame_budget_usec = 0


func after_each() -> void:
	Simulation.frame_budget_usec = Simulation.DEFAULT_FRAME_BUDGET_USEC


func _next_frame() -> Signal:
	return get_tree().process_frame


## The game saved and loaded, with its chunks.
func _reloaded() -> GameState:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _world.loaded_chunk_coords():
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	return restored


func test_a_big_thirsty_herd_skips_over_frames_a_few_animals_a_frame_and_ends_the_same() -> void:
	_livestock.spawn(LivestockRules.COW, HERD, _pen_middle(), _world)
	for animal in _livestock.all():
		animal.thirst = 0.9
		animal.hunger = 0.9
	_state.clock.day = DAY
	_state.clock.set_time(12, 0)
	var in_one_go := _reloaded()
	var over_frames := _reloaded()
	var frame_before := Engine.get_process_frames()

	in_one_go.simulation.skip(8 * GameClock.MINUTES_PER_HOUR)
	await over_frames.simulation.skip_over_frames(8 * GameClock.MINUTES_PER_HOUR, _next_frame)

	assert_gt(Engine.get_process_frames() - frame_before, 10, "spread over frames")
	assert_eq(over_frames.to_dict(), in_one_go.to_dict())
	assert_eq(over_frames.livestock.rng.state, in_one_go.livestock.rng.state, "the dice")
	for animal in over_frames.livestock.all():
		assert_lt(animal.thirst, 0.5, "every one drank in the skip")
