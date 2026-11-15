extends GutTest
## The music's rules (data/music.cfg): the real file is valid and names pieces there are, and
## what is missing or out of range is reported.

const GOOD := {
	"everyday": {"pieces": ["a", "b"], "switch_seconds": 90.0},
	"piece.b": {"form": ["loop", "fill"]},
	"fades": {"crossfade_seconds": 4.0, "stop_seconds": 2.0},
	"cache": {"max_megabytes": 64},
}


func _with(section: String, key: String, value: Variant) -> MusicRules:
	var values := GOOD.duplicate(true)
	values[section][key] = value
	return MusicRules.new(values)


func test_the_data_file_is_valid() -> void:
	var rules := MusicRules.from_file(MusicRules.DEFAULT_PATH)
	assert_eq(rules.problems(), [] as Array[String])
	assert_true(rules.is_valid())


func test_the_everyday_pieces_are_pieces_of_the_game() -> void:
	for piece in MusicRules.default_rules().everyday_pieces():
		assert_true(FileAccess.file_exists("%s/%s.mod" % [MusicPlayer.MUSIC_DIR, piece]), piece)


func test_the_forms_fit_their_pieces() -> void:
	var rules := MusicRules.default_rules()
	for piece_name in rules.everyday_pieces():
		var piece := MusicPiece.read(MusicPlayer.MUSIC_DIR, piece_name)
		assert_eq(piece.form_problem(rules.form(piece_name)), "", piece_name)
	assert_has(rules.form("sketch_harbour"), "fill", "Harbour evening plays its fill")


func test_the_values_read_back() -> void:
	var rules := MusicRules.new(GOOD)
	assert_eq(rules.everyday_pieces(), ["a", "b"] as Array[String])
	assert_eq(rules.switch_seconds(), 90.0)
	assert_eq(rules.form("b"), ["loop", "fill"] as Array[String])
	assert_eq(rules.form("a"), [] as Array[String], "no section of its own: no form")
	assert_eq(rules.crossfade_seconds(), 4.0)
	assert_eq(rules.stop_seconds(), 2.0)
	assert_eq(rules.cache_bytes(), 64 * 1000 * 1000)


func test_a_missing_key_is_reported() -> void:
	var values := GOOD.duplicate(true)
	values["cache"].erase("max_megabytes")
	values.erase("fades")
	var rules := MusicRules.new(values)
	assert_has(rules.problems(), "[cache] no max_megabytes")
	assert_has(rules.problems(), "[fades] no crossfade_seconds")
	assert_false(rules.is_valid())


func test_values_out_of_range_are_reported() -> void:
	assert_has(_with("everyday", "pieces", []).problems(), "[everyday] pieces must name a piece")
	assert_has(
		_with("everyday", "switch_seconds", 0.0).problems(),
		"[everyday] switch_seconds must be above 0"
	)
	assert_has(
		_with("piece.b", "form", "loop").problems(),
		"[piece.b] form must be a list of section names"
	)
	assert_has(
		_with("fades", "crossfade_seconds", 0.0).problems(),
		"[fades] crossfade_seconds must be above 0"
	)
	assert_has(
		_with("fades", "stop_seconds", -1.0).problems(), "[fades] stop_seconds must be above 0"
	)
	assert_has(
		_with("cache", "max_megabytes", 0).problems(), "[cache] max_megabytes must be above 0"
	)
