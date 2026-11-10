extends GutTest
## MusicCrossfade (task 169) with the audio server mixing in real time: two click tracks of the
## same beat, the first with a click up on every beat, the second with a click down; what the bus
## mixes is captured (AudioEffectCapture). After a crossfade the second's clicks must fall on the
## first's beat grid, to the sample. Master is muted meanwhile; headless, nothing is heard anyway.

const BUS := &"MusicCrossfadeTest"
const BEAT_SECONDS := 0.4
const BEATS := 4
const FADE_SECONDS := 0.4
const CLICK := 0.5

var _crossfade: MusicCrossfade
var _capture := AudioEffectCapture.new()
var _mix_rate := 0
var _beat_frames := 0
var _was_master_muted := false


func before_all() -> void:
	_mix_rate = roundi(AudioServer.get_mix_rate())
	_beat_frames = roundi(BEAT_SECONDS * _mix_rate)
	_was_master_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, BUS)
	_capture.buffer_length = 10.0
	AudioServer.add_bus_effect(bus, _capture)


func after_all() -> void:
	AudioServer.remove_bus(AudioServer.get_bus_index(BUS))
	AudioServer.set_bus_mute(0, _was_master_muted)


func before_each() -> void:
	_crossfade = MusicCrossfade.new(BUS)
	add_child_autofree(_crossfade)
	_capture.clear_buffer()


## A looped bar of silence with a click of `level` on every beat.
func _clicks(level: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(_beat_frames * BEATS * 2)
	for beat in BEATS:
		data.encode_s16(beat * _beat_frames * 2, roundi(level * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _mix_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = _beat_frames * BEATS
	return stream


## What the bus mixed from now until `is_done` holds and then `beats` more beats: the left side.
func _record(is_done: Callable, beats: int) -> PackedFloat32Array:
	var mixed := PackedFloat32Array()
	var ends_at := -1
	while ends_at < 0 or Time.get_ticks_msec() < ends_at:
		await wait_process_frames(1)
		for frame in _capture.get_buffer(_capture.get_frames_available()):
			mixed.append(frame.x)
		if ends_at < 0 and is_done.call():
			ends_at = Time.get_ticks_msec() + roundi(beats * BEAT_SECONDS * 1000)
		if mixed.size() > 20 * _mix_rate:
			break
	return mixed


## The new clicks (`phases.y`) fall on the old beats (`phases.x`) within a frame: the start of the
## new stream is given in seconds, which may round to the frame beside.
func _assert_on_the_beats(phases: Vector2i) -> void:
	assert_ne(phases.y, -1, "the new clicks were mixed")
	var apart := posmod(phases.y - phases.x + _beat_frames / 2, _beat_frames) - _beat_frames / 2
	assert_between(apart, -1, 1, "the new clicks on the old beats")


## Where in the beat the clicks of each sign fall: Vector2i(up, down) in frames, or -1 for none;
## fails if the clicks of a sign fall at different places.
func _click_phases(mixed: PackedFloat32Array) -> Vector2i:
	var phases := Vector2i(-1, -1)
	for frame in mixed.size():
		var value := mixed[frame]
		if absf(value) < CLICK / 4:
			continue
		var phase := frame % _beat_frames
		var side := 0 if value > 0 else 1
		if phases[side] < 0:
			phases[side] = phase
		assert_eq(phase, phases[side], "every click of a sign falls at the same place in the beat")
	return phases


func test_the_new_stream_s_beats_fall_on_the_old_one_s() -> void:
	_crossfade.play(_clicks(CLICK), BEAT_SECONDS)
	await wait_seconds(0.5)
	_crossfade.crossfade(_clicks(-CLICK), BEAT_SECONDS, FADE_SECONDS)
	var mixed := await _record(func() -> bool: return not _crossfade.is_crossfading(), 2)
	var phases := _click_phases(mixed)
	assert_ne(phases.x, -1, "the old clicks were mixed")
	_assert_on_the_beats(phases)
	assert_between(_crossfade.lateness, 0.0, BEAT_SECONDS, "it began after its beat")


func test_a_crossfade_at_the_end_of_a_loop_begins_on_its_start() -> void:
	var first := _clicks(CLICK)
	_crossfade.play(first, BEAT_SECONDS)
	var playing := _crossfade._players[_crossfade._current]
	await wait_until(func() -> bool: return playing.get_playback_position() > 1.25, 5.0)
	_crossfade.crossfade(_clicks(-CLICK), BEAT_SECONDS, FADE_SECONDS)
	assert_eq(_crossfade._switch_seconds, 0.0, "the beat after the last is the loop's start")
	var mixed := await _record(func() -> bool: return not _crossfade.is_crossfading(), 2)
	var phases := _click_phases(mixed)
	_assert_on_the_beats(phases)
	assert_between(_crossfade.lateness, 0.0, BEAT_SECONDS, "it began after the wrap")


## The gain of each player (0 while it doesn't play), frame by frame until no crossfade runs, at
## most `seconds` long.
func _gains_until_still(seconds: float) -> Array[Vector2]:
	var gains: Array[Vector2] = []
	var ends_at := Time.get_ticks_msec() + roundi(seconds * 1000)
	while _crossfade.is_crossfading() and Time.get_ticks_msec() < ends_at:
		await wait_process_frames(1)
		var gain := Vector2.ZERO
		for index in 2:
			var player := _crossfade._players[index]
			gain[index] = db_to_linear(player.volume_db) if player.playing else 0.0
		gains.append(gain)
	return gains


func test_a_crossfade_asked_for_during_a_fade_waits_for_it_and_the_gains_never_jump() -> void:
	var last := _clicks(CLICK / 2)
	_crossfade.play(_clicks(CLICK), BEAT_SECONDS)
	await wait_seconds(0.2)
	_crossfade.crossfade(_clicks(-CLICK), BEAT_SECONDS, 2 * BEAT_SECONDS)
	await wait_until(func() -> bool: return _crossfade._is_fading, 5.0)
	await wait_seconds(0.3)
	_crossfade.crossfade(last, BEAT_SECONDS, BEAT_SECONDS)
	var gains := await _gains_until_still(10.0)
	assert_false(_crossfade.is_crossfading(), "both fades ended")
	var steepest := 0.0
	for index in range(1, gains.size()):
		var step := (gains[index] - gains[index - 1]).abs()
		steepest = maxf(steepest, maxf(step.x, step.y))
	# A mix block (about 93 ms on the Dummy driver) of a fade over a beat (400 ms): about 0.25.
	assert_lt(steepest, 0.4, "no gain jumps")
	var playing := _crossfade._players[_crossfade._current]
	assert_eq(playing.stream, last, "it ends on the last asked for")
	assert_almost_eq(db_to_linear(playing.volume_db), 1.0, 0.001)
	assert_false(_crossfade._players[1 - _crossfade._current].playing, "the other stopped")


## How long the fade to a silent loop of `loop_seconds` takes, from its start to its end, in
## seconds.
func _fade_duration(loop_seconds: float, fade_seconds: float) -> float:
	var frames := roundi(loop_seconds * _mix_rate)
	var loop := AudioStreamWAV.new()
	loop.format = AudioStreamWAV.FORMAT_16_BITS
	loop.mix_rate = _mix_rate
	var silence := PackedByteArray()
	silence.resize(frames * 2)
	loop.data = silence
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = frames
	_crossfade.play(_clicks(CLICK), BEAT_SECONDS)
	_crossfade.crossfade(loop, loop_seconds, fade_seconds)
	await wait_until(func() -> bool: return _crossfade._is_fading, 5.0)
	var started := Time.get_ticks_msec()
	var gives_up := started + 30000
	while _crossfade.is_crossfading() and Time.get_ticks_msec() < gives_up:
		await wait_process_frames(1)
	assert_false(_crossfade._players[1 - _crossfade._current].playing, "the old player stopped")
	return (Time.get_ticks_msec() - started) / 1000.0


func test_the_played_time_counts_the_loops_the_mix_time_calls_for() -> void:
	var played := MusicCrossfade.played_seconds
	assert_almost_eq(played.call(0.2, 0.5, 1.6, 0.3), 0.3, 1e-9, "no wrap")
	assert_almost_eq(played.call(1.5, 0.1, 1.6, 0.2), 0.2, 1e-9, "a wrap: the position went down")
	# A 0.16 s loop and a 93 ms mix block: from 0.10 to 0.033 is a wrap, not 67 ms backwards.
	assert_almost_eq(played.call(0.10, 0.033, 0.16, 0.093), 0.093, 1e-9, "a loop under a block")
	assert_almost_eq(played.call(0.10, 0.033, 0.16, 0.413), 0.413, 1e-9, "two more loops")
	# A frame stalled 0.4 s over a 1.6 s loop: one wrap. Over a 0.16 s loop: several.
	assert_almost_eq(played.call(1.4, 0.2, 1.6, 0.4), 0.4, 1e-9, "a stall, one wrap")
	assert_almost_eq(played.call(0.05, 0.13, 0.16, 0.56), 0.56, 1e-9, "a stall, three wraps")
	assert_almost_eq(played.call(0.5, 0.5, 1.6, 0.0), 0.0, 1e-9, "nothing mixed")


## The real thing, with a tolerance a busy machine can't break: the fade ends, and not before its
## length less a mix block (93 ms on the Dummy driver) and a frame of the new stream's play.
func test_a_fade_longer_than_its_loop_ends_and_takes_its_length() -> void:
	var duration := await _fade_duration(1.6, 2.0)
	assert_false(_crossfade.is_crossfading(), "the fade ended")
	assert_gt(duration, 2.0 - 0.2, "not faster than its length")
