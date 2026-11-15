extends MusicPlayerCase
## The MusicPlayer's two versions of a piece (#15): the fuller one with the 32 px art and the
## chiptune with the classic art, rendered when the art changes and blended in step on the bar.
## "tiny" has a fuller version of 8 channels here; "other" has none.

const CHIPTUNE := Vector2i(0, 0)
const FULL := Vector2i(1, 0)
const FULL_INDOORS := Vector2i(1, 1)


func before_each() -> void:
	super.before_each()
	_write_module("tiny" + MusicPiece.FULL_SUFFIX, 8)


func test_a_fuller_version_is_no_piece_of_its_own() -> void:
	assert_eq(_music.tracks(), ["other", "tiny"] as Array[String])


func test_with_the_32_px_art_the_fuller_version_plays() -> void:
	_music.play("tiny")
	assert_eq(_music._renders[0].renderer.module, _music._wanted_piece.full_module)
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_heard_stream(), _music._mixes[FULL])


func test_a_piece_asked_for_with_the_classic_art_starts_with_the_chiptune() -> void:
	_music.set_classic(true)
	_music.play("tiny")
	assert_eq(_music._renders[0].renderer.module, _music._wanted_piece.module)
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_heard_stream(), _music._mixes[CHIPTUNE])


func test_the_other_version_blends_in_on_the_bar_without_starting_the_piece_again() -> void:
	watch_signals(_music)
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	var full := _heard_stream()
	_music.set_classic(true)
	assert_false(_music._mixes.has(FULL), "the other version's mixes go")
	await wait_until(func() -> bool: return _music._crossfade._is_in_step, PATIENCE_SECONDS)
	assert_true(_music._crossfade._waits_for_bar, "on the bar")
	await wait_until(func() -> bool: return not _music._crossfade.is_crossfading(), 5.0)
	assert_eq(_heard_stream(), _music._mixes[CHIPTUNE])
	assert_ne(_heard_stream(), full)
	_music.set_classic(false)
	await wait_until(func() -> bool: return _music._mixes.has(FULL), PATIENCE_SECONDS)
	await wait_until(func() -> bool: return not _music._crossfade.is_crossfading(), 5.0)
	assert_eq(_heard_stream(), _music._mixes[FULL], "and back")
	assert_signal_emit_count(_music, "started", 1)


func test_the_mix_indoors_of_a_fuller_version_turns_its_channels_down_in_fours() -> void:
	_music.rules = MusicRules.new(RULES)
	_music.set_indoors(true)
	_music.play("tiny")
	assert_eq(_music._renders[0].mix, FULL_INDOORS)
	assert_eq(
		_music._renders[0].renderer.channel_levels,
		PackedFloat32Array([0.5, 0.7, 0.8, 0.0, 0.5, 0.7, 0.8, 0.0])
	)


func test_a_piece_without_a_fuller_version_plays_its_chiptune_and_the_art_changes_nothing() -> void:
	_music.play("other")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_heard_stream(), _music._mixes[CHIPTUNE])
	await wait_until(func() -> bool: return not _music.is_rendering(), PATIENCE_SECONDS)
	_music.set_classic(true)
	assert_false(_music.is_rendering(), "nothing to render")
	assert_false(_music._crossfade.is_crossfading(), "nothing to blend")
