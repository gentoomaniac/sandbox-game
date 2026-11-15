class_name MusicPlayerCase
extends GutTest
## A MusicPlayer for the tests on tiny modules (one row of silence) in a folder of their own, so a
## render takes no time, with the renders in a cache folder of their own. Master is muted
## meanwhile.

const DIR := "user://test_music_player"
const CACHE_DIR := "user://test_music_player_cache"
const SETTINGS_PATH := DIR + "/settings.cfg"
const PATIENCE_SECONDS := 60.0
const HEADER_SIZE := 20 + TrackerModule.SAMPLE_SLOTS * 30
## Pattern break at row 0: the order list plays one row.
## The one-row module is a piece of a single looping section.
const SECTIONS := (
	"[piece]\nspeed=6\ntempo=125\nbeat_rows=6\nbar_beats=2\n"
	+ '[loop]\norder=0\nrows=1\nexits=["loop"]\n'
)
const BREAK_CELL := [0, 0, ModuleRenderer.EFFECT_BREAK, 0]
const RULES := {
	"everyday": {"pieces": ["tiny"], "switch_seconds": 90.0},
	"indoors": {"channel_levels": [0.5, 0.7, 0.8, 0.0], "fade_seconds": 0.05},
	"fades": {"crossfade_seconds": 0.05, "stop_seconds": 0.1},
	"cache": {"max_megabytes": 10},
}

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
	_music.cache = MusicCache.new(CACHE_DIR, 100 * 1000 * 1000)
	_music.stop_seconds = 0.1
	_music.mix_seconds = 0.05
	add_child_autofree(_music)


func after_each() -> void:
	_music.stop()
	_audio.is_muted = false
	_audio.apply_settings(GameSettings.new(SETTINGS_PATH))
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		for file_name in DirAccess.get_files_at(CACHE_DIR):
			DirAccess.remove_absolute(CACHE_DIR.path_join(file_name))
		DirAccess.remove_absolute(CACHE_DIR)


## A module of one pattern and no samples whose first row breaks at once.
func _write_module(track: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + 2 + 128 + 4 + TrackerModule.PATTERN_ROWS * 16)
	# The title, so that no two pieces are the same module (they would share a cached render).
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


## The rules of the test with the form `form` for the tiny piece.
func _rules_with_form(form: Array) -> MusicRules:
	var values := RULES.duplicate(true)
	values["piece.tiny"] = {"form": form}
	return MusicRules.new(values)


func _playing_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for node in _music.get_child(0).get_children():
		if node.playing:
			players.append(node)
	return players


func _heard_stream() -> AudioStreamWAV:
	return _music._crossfade._players[_music._crossfade._current].stream
