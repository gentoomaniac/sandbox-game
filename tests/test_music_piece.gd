extends GutTest
## MusicPiece: the pieces of assets/music/ with their sections as tools/music/generate.py wrote
## them, and made-up ones for what a sections file may get wrong.

const DIR := "user://test_music_piece"
const HEADER_SIZE := 20 + TrackerModule.SAMPLE_SLOTS * 30


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


## A module of two patterns with no samples, and a sections file: a [piece] and `sections`.
func _write_piece(sections: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + 2 + 128 + 4 + 2 * TrackerModule.PATTERN_ROWS * 16)
	bytes[HEADER_SIZE] = 2
	bytes[HEADER_SIZE + 3] = 1
	var magic := "M.K.".to_ascii_buffer()
	for index in 4:
		bytes[HEADER_SIZE + 2 + 128 + index] = magic[index]
	var module := FileAccess.open(DIR.path_join("made_up.mod"), FileAccess.WRITE)
	module.store_buffer(bytes)
	module.close()
	var file := FileAccess.open(DIR.path_join("made_up.cfg"), FileAccess.WRITE)
	file.store_string("[piece]\nspeed=6\ntempo=90\nbeat_rows=6\nbar_beats=2\n" + sections)
	file.close()


func test_tide_is_a_6_8_sway_of_one_looping_section() -> void:
	var piece := MusicPiece.read(MusicPlayer.MUSIC_DIR, "sketch_tide")
	assert_eq([piece.speed, piece.tempo, piece.beat_rows, piece.bar_beats], [6, 90, 6, 2])
	assert_eq(piece.sections.size(), 1)
	var loop := piece.loop_section()
	assert_eq([loop.name, loop.order, loop.rows], ["loop", 0, 192])
	assert_eq(loop.exits, ["loop"] as Array[String])
	assert_eq(loop.part(), Vector2i(0, 192))


func test_harbour_loops_or_goes_to_its_fill_which_leads_back() -> void:
	var piece := MusicPiece.read(MusicPlayer.MUSIC_DIR, "sketch_harbour")
	assert_eq([piece.speed, piece.tempo, piece.beat_rows, piece.bar_beats], [6, 80, 4, 4])
	assert_eq(piece.loop_section().exits, ["loop", "fill"] as Array[String])
	var fill := piece.section_named("fill")
	assert_eq([fill.order, fill.rows], [2, 16], "after the loop's two patterns")
	assert_eq(fill.exits, ["loop"] as Array[String])
	assert_null(piece.section_named("bridge"))


func test_the_sections_come_in_the_order_of_the_file() -> void:
	_write_piece('[loop]\norder=0\nrows=64\nexits=["loop"]\n[fill]\norder=1\nrows=16\n')
	var piece := MusicPiece.read(DIR, "made_up")
	var names := piece.sections.map(
		func(section: MusicPiece.Section) -> String: return section.name
	)
	assert_eq(names, ["loop", "fill"])


func test_a_missing_file_is_refused() -> void:
	assert_null(MusicPiece.read(DIR, "made_up"))
	assert_push_error_count(1)
	_write_piece("[loop]\norder=0\nrows=64\n")
	DirAccess.remove_absolute(DIR.path_join("made_up.cfg"))
	assert_null(MusicPiece.read(DIR, "made_up"))
	assert_push_error_count(2)


func test_a_sections_file_that_does_not_fit_its_module_is_refused() -> void:
	var cases := {
		"": "no sections",
		"[loop]\norder=2\nrows=64\n": "past the order list",
		"[loop]\norder=0\nrows=0\n": "no rows",
		'[loop]\norder=0\nrows=64\nexits=["fill"]\n': "an exit that is none",
	}
	var errors := 0
	for sections in cases:
		_write_piece(sections)
		assert_null(MusicPiece.read(DIR, "made_up"), cases[sections])
		errors += 1
		assert_push_error_count(errors)
