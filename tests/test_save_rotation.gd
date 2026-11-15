extends GutTest
## The saves a world keeps: every save a new file, the newest ten kept, a header beside each, and
## the old single `world.json` as the oldest.

const DIR := "user://test_save_rotation"
const BASE := DIR + "/world.json"

var _state: GameState


func before_each() -> void:
	_state = GameState.new_game(7)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _header(kind := SaveHeader.Kind.AUTOSAVE) -> SaveHeader:
	return SaveHeader.of(_state, kind)


## A save the list takes for one; its content is not a game.
func _store_stub(kind := SaveHeader.Kind.AUTOSAVE) -> void:
	assert_eq(SaveFile.store("{}", _header(kind), BASE), "")


func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _file_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(DirAccess.get_files_at(DIR))
	names.sort()
	return names


func test_every_save_is_a_new_file_numbered_up() -> void:
	_store_stub()
	_store_stub()
	assert_eq(
		_file_names(),
		[
			"world.000001.json",
			"world.000001.json.info",
			"world.000002.json",
			"world.000002.json.info"
		]
	)


func test_the_data_file_keeps_ten() -> void:
	assert_eq(SaveList.kept_count(), 10)


func test_the_eleventh_save_drops_the_oldest_with_its_header() -> void:
	for i in 11:
		_store_stub()
	var paths := SaveList.paths_newest_first(BASE)
	assert_eq(paths.size(), 10)
	assert_eq(paths[0].get_file(), "world.000011.json")
	assert_eq(paths[9].get_file(), "world.000002.json")
	assert_false(FileAccess.file_exists(DIR + "/world.000001.json"))
	assert_false(FileAccess.file_exists(DIR + "/world.000001.json.info"))
	assert_eq(_file_names().size(), 20, "a save and a header each, nothing else")


func test_the_numbers_go_on_after_the_oldest_are_gone() -> void:
	for i in 12:
		_store_stub()
	assert_eq(SaveList.next_path(BASE).get_file(), "world.000013.json")


func test_a_failed_write_leaves_the_other_saves_as_they_were() -> void:
	_store_stub()
	var before := _file_names()
	# A folder where the next save's temporary file goes: it can't be opened for writing.
	DirAccess.make_dir_recursive_absolute(SaveList.next_path(BASE) + ".tmp")
	var error := SaveFile.store("{}", _header(), BASE)
	assert_string_contains(error, "Can't write")
	assert_push_error_count(1)
	DirAccess.remove_absolute(SaveList.next_path(BASE) + ".tmp")
	assert_eq(_file_names(), before, "no half save, and no header without its save")


func test_a_failed_write_does_not_delete_the_oldest_save() -> void:
	for i in 10:
		_store_stub()
	DirAccess.make_dir_recursive_absolute(SaveList.next_path(BASE) + ".tmp")
	SaveFile.store("{}", _header(), BASE)
	assert_push_error_count(1)
	DirAccess.remove_absolute(SaveList.next_path(BASE) + ".tmp")
	assert_eq(SaveList.paths_newest_first(BASE).size(), 10)
	assert_true(FileAccess.file_exists(DIR + "/world.000001.json"))


func test_the_list_has_the_newest_first_with_what_made_each_and_when_in_the_game() -> void:
	_state.clock.day = 3
	_store_stub(SaveHeader.Kind.SLEEP)
	_state.clock.day = 40
	_state.clock.minute_of_day = 14 * 60 + 30
	_store_stub(SaveHeader.Kind.QUICK_SAVE)
	var entries := SaveList.entries(BASE)
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].path.get_file(), "world.000002.json")
	assert_eq(entries[0].header.game_text(), "5th day of Summer Year 1, 14:30")
	assert_string_contains(entries[0].header.how_text(), "quick save, ")
	assert_eq(entries[1].header.game_text(), "3rd day of Spring Year 1, 06:00")
	assert_string_contains(entries[1].header.how_text(), "sleep, ")
	assert_true(entries[0].is_loadable())


func test_the_header_is_read_back_as_it_was_written() -> void:
	_state.clock.day = 99
	var header := SaveHeader.from_text(_header(SaveHeader.Kind.QUIT).to_text())
	assert_eq(header.kind, SaveHeader.Kind.QUIT)
	assert_eq(header.game_day, 99)
	assert_eq(header.version, SaveFile.VERSION)
	assert_gt(header.unix_time, 0)
	assert_null(SaveHeader.from_text("not a header"))
	assert_null(SaveHeader.from_text('{"kind": 0}'))
	var unknown_kind: Dictionary = JSON.parse_string(_header(SaveHeader.Kind.QUIT).to_text())
	unknown_kind["kind"] = 99
	assert_null(SaveHeader.from_text(JSON.stringify(unknown_kind)), "a kind the game has not")


func test_a_save_without_a_readable_header_or_content_is_listed_as_unusable() -> void:
	_write_file(DIR + "/world.000001.json", "not a save")
	var entry := SaveList.entries(BASE)[0]
	assert_false(entry.is_loadable())
	assert_eq(entry.problem, "not a save file")
	assert_null(entry.header)


func test_a_save_of_a_version_the_game_does_not_read_is_listed_as_unusable() -> void:
	var header := _header()
	header.version = SaveFile.VERSION + 1
	assert_eq(SaveFile.store("{}", header, BASE), "")
	var entry := SaveList.entries(BASE)[0]
	assert_false(entry.is_loadable())
	assert_string_contains(entry.problem, "save version")
	assert_not_null(entry.header, "its date is still shown")


func test_the_old_single_save_is_the_oldest_of_the_list_and_gets_a_header() -> void:
	_state.clock.day = 12
	assert_eq(SaveFile.write_text(SaveFile.encode(_state), BASE), "")
	_state.clock.day = 13
	assert_true(SaveFile.write(_state, BASE))
	var entries := SaveList.entries(BASE)
	assert_eq([entries[0].path, entries[1].path], [DIR + "/world.000001.json", BASE])
	assert_eq(entries[1].header.kind, SaveHeader.Kind.EARLIER)
	assert_eq(entries[1].header.game_day, 12)
	assert_true(entries[1].is_loadable())
	assert_true(FileAccess.file_exists(BASE + ".info"), "made once, kept")


func test_the_old_single_save_is_loaded_when_it_is_all_there_is() -> void:
	_state.clock.day = 12
	assert_eq(SaveFile.write_text(SaveFile.encode(_state), BASE), "")
	assert_eq(SaveFile.read(BASE).clock.day, 12)


func test_an_older_save_loads_as_it_was() -> void:
	_state.player.position = Vector2(12.5, 9.5)
	assert_true(SaveFile.write(_state, BASE))
	_state.player.position = Vector2(30.5, 30.5)
	assert_true(SaveFile.write(_state, BASE))
	var older := SaveList.entries(BASE)[1]
	assert_eq(SaveFile.load_game(older.path).state.player.position, Vector2(12.5, 9.5))
	assert_eq(SaveFile.read(BASE).player.position, Vector2(30.5, 30.5), "read takes the newest")


func test_reading_skips_a_newest_save_that_is_refused_and_moves_it_aside() -> void:
	_state.player.position = Vector2(12.5, 9.5)
	assert_true(SaveFile.write(_state, BASE))
	_write_file(DIR + "/world.000002.json", "not a save")
	assert_eq(SaveFile.read(BASE).player.position, Vector2(12.5, 9.5))
	assert_push_error_count(1)
	assert_eq(SaveList.paths_newest_first(BASE).size(), 1)
	assert_eq(SaveFile.backups_of(BASE).size(), 1)


func test_backups_are_not_in_the_list_and_do_not_count_as_saves() -> void:
	_store_stub()
	_write_file(DIR + "/world.000002.json", "not a save")
	SaveFile.move_aside(DIR + "/world.000002.json")
	assert_eq(SaveList.paths_newest_first(BASE).size(), 1)
	assert_eq(SaveFile.backups_of(BASE).size(), 1)
	assert_eq(SaveList.next_path(BASE).get_file(), "world.000002.json")
	for i in 11:
		_store_stub()
	assert_eq(SaveFile.backups_of(BASE).size(), 1, "pruning leaves the backup")


func test_no_saves_give_no_newest_path() -> void:
	assert_eq(SaveList.newest_path(BASE), "")
	assert_true(SaveList.entries(BASE).is_empty())
