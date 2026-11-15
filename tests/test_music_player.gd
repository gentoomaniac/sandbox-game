extends MusicPlayerCase
## The MusicPlayer on the tiny modules of MusicPlayerCase, and once on a real piece.


func test_the_tracks_are_the_modules_of_the_folder() -> void:
	assert_eq(_music.tracks(), ["other", "tiny"] as Array[String])


func test_the_real_folder_has_the_known_pieces() -> void:
	_music.music_dir = MusicPlayer.MUSIC_DIR
	for track in ["sketch_harbour", "sketch_tide", "test_reel"]:
		assert_has(_music.tracks(), track)


func test_play_renders_the_track_and_loops_it_on_the_music_bus() -> void:
	watch_signals(_music)
	assert_eq(_music.play("tiny"), "Rendering tiny...")
	assert_true(_music.is_rendering())
	assert_true(_playing_players().is_empty(), "nothing plays before the render is done")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_signal_emitted_with_parameters(_music, "started", ["tiny"])
	var players := _playing_players()
	assert_eq(players.size(), 1)
	assert_eq(players[0].bus, AudioService.MUSIC)
	var stream := players[0].stream as AudioStreamWAV
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.loop_end, stream.data.size() / 4 - ModuleRenderer.WRAP_FRAMES)


func test_a_real_piece_renders_and_plays_its_first_section_in_a_loop() -> void:
	_music.music_dir = MusicPlayer.MUSIC_DIR
	_music.play("test_reel")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_playing_players().size(), 1)
	# 128 rows of 6 ticks of 1040 frames at 44.1 kHz: the loop, not the fill after it.
	assert_almost_eq(_music.loop_seconds, 128 * 6 * 1040 / 44100.0, 0.001)


func test_a_piece_switches_on_its_own_bar() -> void:
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	# Two beats of six rows of 6 ticks of 882 frames at 44.1 kHz, the bar the sections file gives.
	assert_almost_eq(_music._crossfade._beat_seconds, 2 * 6 * 6 * 882 / 44100.0, 0.0001)


func test_a_piece_plays_its_form_round_and_round() -> void:
	_music.rules = _rules_with_form(["loop", "loop", "loop"])
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_almost_eq(_music.loop_seconds, 3 * 6 * 882 / 44100.0, 0.0001, "three rows")


func test_a_form_the_piece_does_not_allow_is_not_played() -> void:
	_music.rules = _rules_with_form(["loop", "fill"])
	assert_eq(_music.play("tiny"), "Can't play tiny")
	assert_push_error_count(1)
	assert_eq(_music.wanted_track(), "")


func test_a_render_is_kept_in_the_cache() -> void:
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	var one := _music.cache.size_bytes()
	assert_gt(one, 0)
	_music.play("other")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	await wait_until(func() -> bool: return not _music.is_rendering(), PATIENCE_SECONDS)
	assert_eq(DirAccess.get_files_at(CACHE_DIR).size(), 4, "both mixes of both pieces")


func test_what_plays_goes_on_while_the_next_piece_renders() -> void:
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	_music.play("other")
	assert_true(_music.is_rendering())
	assert_eq(_playing_players().size(), 1)
	assert_true(_music.is_playing())
	assert_eq(_music.wanted_track(), "other")


func test_a_piece_that_cannot_be_read_is_not_played() -> void:
	assert_eq(_music.play("nowhere"), "Can't play nowhere")
	assert_push_error_count(1)
	assert_false(_music.is_rendering())
	assert_eq(_music.wanted_track(), "")


func test_asking_again_for_the_same_track_starts_nothing_new() -> void:
	_music.play("tiny")
	assert_eq(_music.play("tiny"), "Already rendering tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_music.play("tiny"), "Already playing tiny")


func test_another_track_crossfades_from_the_one_that_plays() -> void:
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	_music.play("other")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_true(_music._crossfade.is_crossfading())


func test_stop_fades_the_music_out() -> void:
	_music.play("tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	_music.stop()
	assert_eq(_playing_players().size(), 1, "still fading")
	await wait_seconds(0.3)
	assert_true(_playing_players().is_empty())


func test_stop_drops_a_track_that_is_still_rendering() -> void:
	watch_signals(_music)
	_music.play("tiny")
	_music.stop()
	await wait_until(func() -> bool: return not _music.is_rendering(), PATIENCE_SECONDS)
	await wait_frames(2)
	assert_signal_not_emitted(_music, "started")
	assert_true(_playing_players().is_empty())


func test_leaving_the_tree_takes_the_renders_still_running() -> void:
	_music.play("tiny")
	remove_child(_music)
	assert_false(_music.is_rendering())
	add_child(_music)
