extends GutTest
## Sleeping in a bed (Main): the game is saved in the background under the black screen, as when
## passing out: the sleep and the snapshot a frame apart, the write on a worker.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")
const SETTLE_SECONDS := 30.0
const SLEEP_SECONDS := 10.0

var _main: Node


## Sets something up once, at the first minute a skip walks through (the `advance` of that minute
## comes before the `walked_minute` of every system).
class WalkedMinuteProbe:
	extends SimulationSystem
	var is_held: Callable
	var setup: Callable
	var has_run := false

	func advance(_minutes: int, _clock: GameClock) -> void:
		if not has_run and is_held.call():
			has_run = true
			setup.call()


func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await wait_until(
		func() -> bool: return _main._view != null and _main._view.is_settled, SETTLE_SECONDS
	)


func after_each() -> void:
	_main._saves.wait()
	get_tree().auto_accept_quit = true
	_main.free()


func test_the_save_of_a_sleep_is_a_background_save_of_the_new_day_under_the_black_screen() -> void:
	var saves: SaveService = _main._saves
	var state: GameState = _main._state
	var was_black_at_start: Array[bool] = []
	var frames_of_sleep: Array[int] = []
	var frames_of_snapshot: Array[int] = []
	state.simulation.skipped.connect(
		func(_minutes: int) -> void: frames_of_sleep.append(Engine.get_process_frames())
	)
	saves.started.connect(
		func() -> void:
			was_black_at_start.append(_main._fade_screen.is_black())
			frames_of_snapshot.append(Engine.get_process_frames())
	)
	state.clock.set_time(22, 0)
	state.player.position = Vector2(state.player.home_bed) + Vector2(0.5, 0.5)
	var day_before := state.clock.day

	_main._try_sleep()
	await wait_until(func() -> bool: return not was_black_at_start.is_empty(), SLEEP_SECONDS)
	await wait_until(func() -> bool: return not _main._is_in_transition, SLEEP_SECONDS)

	assert_eq(was_black_at_start, [true] as Array[bool], "one save, begun on the black")
	assert_gt(frames_of_snapshot[0], frames_of_sleep[0], "the snapshot is a frame after the sleep")
	assert_true(saves.last_succeeded)
	assert_eq(state.clock.day, day_before + 1)
	assert_eq(SaveFile.read(_main._options.save_path).clock.day, day_before + 1)


## Puts the player in the bed they start with, at ten at night.
func _go_to_bed() -> void:
	var state: GameState = _main._state
	state.clock.set_time(22, 0)
	state.player.position = Vector2(state.player.home_bed) + Vector2(0.5, 0.5)


func test_quitting_in_the_middle_of_the_sleep_waits_and_saves_the_whole_morning() -> void:
	var state: GameState = _main._state
	_go_to_bed()
	_main._try_sleep()
	await wait_until(func() -> bool: return _main._is_making_up_time, SLEEP_SECONDS)

	var is_saved: bool = await _main._is_saved_for_quit()

	assert_true(is_saved)
	assert_false(_main._is_making_up_time, "it waited for the waking")
	var saved := SaveFile.read(_main._options.save_path)
	assert_eq(saved.clock.total_minutes(), state.clock.total_minutes())
	assert_eq(saved.player.position, state.player.position)
	assert_eq(saved.player.energy, state.player.energy)


func test_the_chunks_stay_as_they_are_over_the_frames_of_a_sleep() -> void:
	var state: GameState = _main._state
	var chunks_at_skip: Array[Array] = []
	var could_process_at_skip: Array[bool] = []
	state.simulation.skipped.connect(
		func(_minutes: int) -> void:
			chunks_at_skip.append(state.world.loaded_chunk_coords())
			could_process_at_skip.append(_main._view.can_process())
	)
	_go_to_bed()
	_main._try_sleep()
	await wait_until(func() -> bool: return _main._is_making_up_time, SLEEP_SECONDS)
	var chunks_at_start := state.world.loaded_chunk_coords()
	# The camera would stream chunks round a far focus.
	_main._residency.set_focus(state.player.tile() + Vector2i(320, 0))
	_main._residency.update()
	await wait_until(func() -> bool: return not _main._is_in_transition, SLEEP_SECONDS)

	assert_eq(could_process_at_skip, [false] as Array[bool])
	chunks_at_start.sort()
	chunks_at_skip[0].sort()
	assert_eq(chunks_at_skip[0], chunks_at_start)


func test_a_cat_beside_a_mouse_starts_no_hunt_over_the_frames_of_a_sleep() -> void:
	var state: GameState = _main._state
	state.livestock.spawn(LivestockRules.CAT, 1, state.player.position + Vector2(3, 0), state.world)
	var cat: FarmAnimal = state.livestock.all().back()
	# No hunt may start before the world is held (the fade to black takes half a second); the
	# rest is set back to none on each held frame below.
	cat.hunt_rest_seconds = 3600.0
	var cat_view: FarmAnimalView = _main._wildlife._farm_animals.get(cat)
	assert_not_null(cat_view, "the cat has a view")
	# The cat walks off its spawn spot: the mouse goes beside it where it stands.
	await wait_process_frames(30)
	_main._wildlife.place(
		WildlifeRules.MOUSE, (cat.position + Vector2(1.5, 0)) * WildlifeRules.TILE_SIZE
	)
	# At the first walked minute of the sleep the cat creeps within pounce reach of the mouse,
	# rested: the livestock that is stepped for those minutes must not pounce, nor look about.
	var mouse: Mouse = _main._wildlife._animals.back()
	var probe := WalkedMinuteProbe.new()
	probe.is_held = func() -> bool: return _main._is_making_up_time
	probe.setup = func() -> void:
		cat.hunt_rest_seconds = 0.0
		cat.position = mouse.prey.position - Vector2(1.0, 0.0)
		state.livestock.start_hunt(cat, mouse.prey)
		cat.activity = FarmAnimal.Activity.CREEP
	state.simulation.add_system(probe)
	_go_to_bed()
	_main._try_sleep()
	var activities := []
	var could_process: Array[bool] = []
	var is_done := func() -> bool:
		if not _main._is_making_up_time:
			return not activities.is_empty()
		could_process.append(cat_view.can_process())
		# What the livestock would turn into a hunt if it ran: an idle cat, rested, about to pick
		# what to do next, a mouse in sight.
		activities.append(cat.activity)
		cat.activity = FarmAnimal.Activity.IDLE
		cat.seconds_left = 0.0
		cat.hunt_rest_seconds = 0.0
		return false
	await wait_until(is_done, SLEEP_SECONDS)

	assert_gt(activities.size(), 1, "frames were held")
	assert_false(could_process.has(true), "the cat's view is held on every frame of the sleep")
	assert_false(activities.has(FarmAnimal.Activity.CROUCH), "the cat did not crouch")
	assert_false(activities.has(FarmAnimal.Activity.CREEP), "the cat did not creep")
	# The probe's lambdas hold the state, which holds the probe: let go, or the state leaks.
	probe.setup = Callable()
	probe.is_held = Callable()
	assert_true(probe.has_run, "the cat was set creeping at the first walked minute")
	assert_eq(mouse.prey.fate, Prey.Fate.NONE, "no pounce on the held mouse")
	assert_true(mouse.prey.is_about)
