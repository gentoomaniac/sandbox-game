extends GutTest
## The simulation owns the passing of game time.

var _state: GameState


func before_each() -> void:
	_state = GameState.new_game(7)


func test_advancing_moves_the_clock() -> void:
	_state.clock.set_time(23, 30)
	var day := _state.clock.day
	_state.simulation.advance(90)
	assert_eq(_state.clock.day, day + 1)
	assert_eq(_state.clock.time_text(), "01:00")


func test_a_span_passes_as_the_same_time_in_steps() -> void:
	var stepped := GameState.new_game(7)
	_state.simulation.advance(3 * GameClock.MINUTES_PER_DAY + 137)
	for _i in 3 * GameClock.MINUTES_PER_DAY + 137:
		stepped.simulation.advance(1)
	assert_eq(_state.clock.to_dict(), stepped.clock.to_dict())


func test_every_midnight_crossed_is_told() -> void:
	watch_signals(_state.clock)
	_state.simulation.advance(2 * GameClock.MINUTES_PER_DAY)
	assert_signal_emit_count(_state.clock, "new_day", 2)


func test_a_span_is_cut_at_every_full_hour() -> void:
	var clock := SpanSpyClock.new()
	clock.set_time(10, 30)
	Simulation.new(clock).advance(150)
	assert_eq(clock.spans, [30, 60, 60])


class SpanSpyClock:
	extends GameClock
	var spans: Array[int] = []

	func advance(minutes: int) -> void:
		spans.append(minutes)
		super.advance(minutes)


func test_a_game_that_is_let_go_of_is_freed_with_its_simulation() -> void:
	var state := GameState.new_game(7)
	var watcher: WeakRef = weakref(state)
	state = null
	assert_null(watcher.get_ref(), "no system of the simulation holds on to the game")
