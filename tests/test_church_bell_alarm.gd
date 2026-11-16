extends ResourceCase
## The church bell that rings the storm surge's alarm: GameSounds tolls `church_bell_alarm` when
## the surge tells it to (SurgeEvent `bell_rung`).

var _audio: AudioService
var _sounds: GameSounds
var _events: Array[StringName] = []


func before_each() -> void:
	super.before_each()
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(
		func(event: StringName, _position: Variant) -> void: _events.append(event)
	)
	var player_view := PlayerView.new()
	autofree(player_view)
	var build_mode := BuildMode.new()
	autofree(build_mode)
	var view := WorldView.new()
	add_child_autofree(view)
	_sounds = GameSounds.new()
	add_child_autofree(_sounds)
	_sounds.listen(_audio, _state, view, player_view, build_mode)
	_events.clear()


func test_the_warning_tolls_the_church_bell_three_times() -> void:
	_world.surge.bell_rung.emit(false)
	assert_eq(_events, [&"church_bell_alarm"], "the first stroke at once")
	_sounds._on_toll_timeout()
	_sounds._on_toll_timeout()
	assert_eq(_events.size(), 3)


func test_the_continuous_toll_goes_on_while_the_sea_runs_and_stops_after() -> void:
	var now := _state.clock.total_minutes()
	_world.surge.expect(3.0, now + 60, 240)
	_world.flood.begin(_world, 3.0, now, 1)
	_world.surge.bell_rung.emit(true)
	_sounds._on_toll_timeout()
	_sounds._on_toll_timeout()
	assert_eq(_events.size(), 3, "it tolls on")
	_world.surge.clear()
	var tolled := _events.size()
	_sounds._on_toll_timeout()
	assert_eq(_events.size(), tolled, "and falls silent once the surge is over")


func test_the_hourly_call_of_a_toll_that_goes_on_adds_no_stroke() -> void:
	var now := _state.clock.total_minutes()
	_world.surge.expect(3.0, now + 60, 240)
	_world.flood.begin(_world, 3.0, now, 1)
	_world.surge.bell_rung.emit(true)
	_world.surge.bell_rung.emit(true)
	assert_eq(_events.size(), 1)
