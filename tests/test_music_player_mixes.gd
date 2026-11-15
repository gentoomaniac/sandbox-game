extends MusicPlayerCase
## The MusicPlayer's two mixes of a piece (task 171): the whole one and the quieter one indoors,
## rendered one after the other and blended in step at the door.


func test_the_other_mix_is_rendered_once_the_first_plays() -> void:
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_heard_stream(), _music._mixes[false], "the whole mix outdoors")
	await wait_until(func() -> bool: return _music._mixes.has(true), PATIENCE_SECONDS)
	assert_ne(_music._mixes[true], _music._mixes[false])


func test_indoors_the_quieter_mix_blends_in_without_starting_the_piece_again() -> void:
	watch_signals(_music)
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	await wait_until(func() -> bool: return _music._mixes.has(true), PATIENCE_SECONDS)
	_music.set_indoors(true)
	assert_true(_music._crossfade._is_in_step, "a blend, in step")
	await wait_until(func() -> bool: return not _music._crossfade.is_crossfading(), 5.0)
	assert_eq(_heard_stream(), _music._mixes[true])
	_music.set_indoors(false)
	await wait_until(func() -> bool: return not _music._crossfade.is_crossfading(), 5.0)
	assert_eq(_heard_stream(), _music._mixes[false], "and back outside")
	assert_signal_emit_count(_music, "started", 1)


func test_a_piece_asked_for_indoors_starts_with_the_quieter_mix() -> void:
	_music.set_indoors(true)
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_true(_music.is_indoors())
	assert_eq(_heard_stream(), _music._mixes[true])


func test_the_mix_indoors_turns_the_channels_down() -> void:
	_music.rules = MusicRules.new(RULES)
	_music.set_indoors(true)
	_music.play("tiny")
	assert_eq(_music._renders[0].renderer.channel_levels, PackedFloat32Array([0.5, 0.7, 0.8, 0.0]))
