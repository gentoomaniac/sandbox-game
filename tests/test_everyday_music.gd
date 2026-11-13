extends GutTest
## EverydayMusic on tiny pieces (one row of silence, a loop of 0.12 s) in a folder of their own: it
## starts the first piece, goes on to the next after the loops the rules say, keeps to what the
## player was told to play, and stays quiet once stopped. Master is muted meanwhile.

const DIR := "user://test_everyday_music"
const CACHE_DIR := "user://test_everyday_music_cache"
const SETTINGS_PATH := DIR + "/settings.cfg"
const PATIENCE_SECONDS := 10.0
const HEADER_SIZE := 20 + TrackerModule.SAMPLE_SLOTS * 30
const BREAK_CELL := [0, 0, ModuleRenderer.EFFECT_BREAK, 0]
const SECTIONS := (
	"[piece]\nspeed=6\ntempo=125\nbeat_rows=4\nbar_beats=4\n"
	+ '[loop]\norder=0\nrows=1\nexits=["loop"]\n'
)
const RULES := {
	"everyday": {"pieces": ["first", "second"], "loops_before_switch": 2},
	"fades": {"crossfade_seconds": 0.05, "stop_seconds": 0.05},
	"cache": {"max_megabytes": 10},
}

var _audio: AudioService
var _music: MusicPlayer


func before_each() -> void:
	_audio = AudioService.new()
	_audio.is_muted = true
	add_child_autofree(_audio)
	_audio.apply_settings(GameSettings.new(SETTINGS_PATH))
	DirAccess.make_dir_recursive_absolute(DIR)
	for track in ["first", "second", "other"]:
		_write_piece(track)
	_music = MusicPlayer.new()
	_music.music_dir = DIR
	_music.cache = MusicCache.new(CACHE_DIR, 10 * 1000 * 1000)
	_music.crossfade_seconds = 0.05
	_music.stop_seconds = 0.05
	add_child_autofree(_music)
	watch_signals(_music)


func after_each() -> void:
	_music.stop()
	_audio.is_muted = false
	_audio.apply_settings(GameSettings.new(SETTINGS_PATH))
	for folder in [DIR, CACHE_DIR]:
		if DirAccess.dir_exists_absolute(folder):
			for file_name in DirAccess.get_files_at(folder):
				DirAccess.remove_absolute(folder.path_join(file_name))
			DirAccess.remove_absolute(folder)


## A one-row module that breaks at once, with a title of its own so that its render is its own.
func _write_piece(track: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + 2 + 128 + 4 + TrackerModule.PATTERN_ROWS * 16)
	bytes.encode_u8(0, track.unicode_at(0))
	bytes[HEADER_SIZE] = 1
	var magic := "M.K.".to_ascii_buffer()
	for index in 4:
		bytes[HEADER_SIZE + 2 + 128 + index] = magic[index]
	for index in 4:
		bytes[TrackerModule.PATTERNS_START + index] = BREAK_CELL[index]
	var file := FileAccess.open(DIR.path_join(track + ".mod"), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	file = FileAccess.open(DIR.path_join(track + ".cfg"), FileAccess.WRITE)
	file.store_string(SECTIONS)
	file.close()


func _start_everyday() -> void:
	add_child_autofree(EverydayMusic.new(_music, MusicRules.new(RULES)))


## Waits for the next piece to start; returns its name.
func _next_started() -> String:
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	return get_signal_parameters(_music, "started")[0]


func test_the_game_plays_music_by_itself_only_where_it_is_heard() -> void:
	assert_true(EverydayMusic.is_wanted(false, "PulseAudio"))
	assert_false(EverydayMusic.is_wanted(true, "PulseAudio"), "muted")
	assert_false(EverydayMusic.is_wanted(false, "Dummy"), "headless")


func test_it_starts_the_first_piece() -> void:
	_start_everyday()
	assert_eq(await _next_started(), "first")


func test_it_goes_on_to_the_next_piece_and_round_to_the_first() -> void:
	_start_everyday()
	var order: Array[String] = []
	for count in 4:
		order.append(await _next_started())
	assert_eq(order, ["first", "second", "first", "second"] as Array[String])


func test_it_switches_after_the_loops_and_not_before() -> void:
	_start_everyday()
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	var loop_seconds := _music.loop_seconds
	var started_at := Time.get_ticks_msec()
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	var seconds := (Time.get_ticks_msec() - started_at) / 1000.0
	assert_gte(seconds, 2 * loop_seconds, "two loops of the piece")


func test_a_piece_the_console_played_goes_on_with_the_first_everyday_piece() -> void:
	_start_everyday()
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	_music.play("other")
	assert_eq(await _next_started(), "other")
	assert_eq(await _next_started(), "first")


func test_a_stopped_player_stays_quiet() -> void:
	_start_everyday()
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	_music.stop()
	var started_before: int = get_signal_emit_count(_music, "started")
	await wait_seconds(1.0)
	assert_eq(get_signal_emit_count(_music, "started"), started_before)
	assert_false(_music.is_playing())
