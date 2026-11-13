extends GutTest
## The MusicPlayer on a tiny module (one row of silence) in a folder of its own, so a render takes
## no time, and once on a real piece. Master is muted meanwhile.

const DIR := "user://test_music_player"
const SETTINGS_PATH := DIR + "/settings.cfg"
const PATIENCE_SECONDS := 60.0
const HEADER_SIZE := 20 + TrackerModule.SAMPLE_SLOTS * 30
## Pattern break at row 0: the order list plays one row.
const BREAK_CELL := [0, 0, ModuleRenderer.EFFECT_BREAK, 0]

var _music: MusicPlayer
var _audio: AudioService


func before_each() -> void:
	_audio = AudioService.new()
	_audio.is_muted = true
	add_child_autofree(_audio)
	_audio.apply_settings(GameSettings.new(SETTINGS_PATH))
	DirAccess.make_dir_recursive_absolute(DIR)
	_write_module("tiny")
	_write_module("other")
	_music = MusicPlayer.new()
	_music.music_dir = DIR
	_music.stop_seconds = 0.1
	add_child_autofree(_music)


func after_each() -> void:
	_music.stop()
	_audio.is_muted = false
	_audio.apply_settings(GameSettings.new(SETTINGS_PATH))
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


## A module of one pattern and no samples whose first row breaks at once.
func _write_module(track: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + 2 + 128 + 4 + TrackerModule.PATTERN_ROWS * 16)
	bytes[HEADER_SIZE] = 1
	var magic := "M.K.".to_ascii_buffer()
	for index in 4:
		bytes[HEADER_SIZE + 2 + 128 + index] = magic[index]
	for index in 4:
		bytes[TrackerModule.PATTERNS_START + index] = BREAK_CELL[index]
	var file := FileAccess.open(DIR.path_join(track + ".mod"), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _playing_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for node in _music.get_child(0).get_children():
		if node.playing:
			players.append(node)
	return players


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
	assert_eq(stream.loop_end, stream.data.size() / 4)


func test_a_real_piece_renders_and_plays() -> void:
	_music.music_dir = MusicPlayer.MUSIC_DIR
	_music.play("test_reel")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_playing_players().size(), 1)


func test_asking_again_for_the_same_track_starts_nothing_new() -> void:
	_music.play("tiny")
	assert_eq(_music.play("tiny"), "Already rendering tiny")
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	assert_eq(_music.play("tiny"), "Already playing tiny")
	assert_false(_music.is_rendering())


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
