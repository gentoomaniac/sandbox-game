extends GutTest
## The list of saves: newest first with their details, a row picked by mouse or keys, Load and
## Cancel, and a save that can't be loaded shown as such.

const DIR := "user://test_load_dialog"
const BASE := DIR + "/world.json"

var _dialog: LoadDialog
var _requested: Array[SaveEntry] = []


func before_each() -> void:
	_dialog = LoadDialog.new()
	add_child_autofree(_dialog)
	_requested = []
	_dialog.load_requested.connect(func(entry: SaveEntry) -> void: _requested.append(entry))


func after_each() -> void:
	get_tree().paused = false
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


## A save at game day `day`; its content is not a game.
func _store_stub(day: int, kind := SaveHeader.Kind.AUTOSAVE) -> void:
	var state := GameFactory.new_game(7)
	state.clock.day = day
	assert_eq(SaveFile.store("{}", SaveHeader.of(state, kind), BASE), "")


func _rows() -> Array[Button]:
	var rows: Array[Button] = []
	rows.assign(_dialog._rows.get_children())
	return rows


func test_the_saves_are_listed_newest_first_with_their_details() -> void:
	_store_stub(1, SaveHeader.Kind.SLEEP)
	_store_stub(2, SaveHeader.Kind.QUIT)
	_dialog.open_saves(BASE)

	var rows := _rows()
	assert_eq(rows.size(), 2)
	assert_string_contains(rows[0].text, "2nd day of Spring Year 1, 06:00")
	assert_string_contains(rows[0].text, "save and quit")
	assert_string_contains(rows[1].text, "1st day of Spring Year 1")
	assert_string_contains(rows[1].text, "sleep")


func test_the_dialog_pauses_the_game() -> void:
	_dialog.open_saves(BASE)
	assert_true(get_tree().paused)


func test_the_newest_save_is_picked_and_has_the_focus() -> void:
	_store_stub(1)
	_store_stub(2)
	_dialog.open_saves(BASE)

	assert_true(_rows()[0].button_pressed)
	assert_true(_rows()[0].has_focus())
	assert_false(_dialog._load_button.disabled)


func test_load_asks_for_the_picked_save_and_closes() -> void:
	_store_stub(1)
	_store_stub(2)
	_dialog.open_saves(BASE)

	_rows()[1].pressed.emit()
	_rows()[1].button_pressed = true
	assert_true(_dialog._load_button.has_focus(), "a picked row hands the keys on to Load")
	_dialog._load_button.pressed.emit()

	assert_eq(_requested.size(), 1)
	assert_eq(_requested[0].path, DIR + "/world.000001.json")
	assert_false(_dialog.is_open())


func test_cancel_closes_without_asking_for_a_load() -> void:
	_store_stub(1)
	_dialog.open_saves(BASE)

	_dialog._panel.find_children("*", "Button", true, false).back().pressed.emit()

	assert_false(_dialog.is_open())
	assert_eq(_requested.size(), 0)


func test_a_save_that_can_not_be_loaded_is_shown_as_such_and_can_not_be_picked() -> void:
	_store_stub(1)
	var broken := FileAccess.open(DIR + "/world.000002.json", FileAccess.WRITE)
	broken.store_string("not a save")
	broken.close()
	_dialog.open_saves(BASE)

	var rows := _rows()
	assert_true(rows[0].disabled)
	assert_string_contains(rows[0].text, "Can't be loaded: not a save file")
	assert_false(rows[1].disabled)
	assert_true(rows[1].button_pressed, "the newest save that can be loaded is picked")


func test_without_a_save_that_can_be_loaded_load_stays_off() -> void:
	var broken := FileAccess.open(DIR + "/world.000001.json", FileAccess.WRITE)
	broken.store_string("not a save")
	broken.close()
	_dialog.open_saves(BASE)

	assert_true(_dialog._load_button.disabled)


func test_without_saves_it_says_so() -> void:
	_dialog.open_saves(BASE)

	assert_eq((_dialog._rows.get_child(0) as Label).text, LoadDialog.NO_SAVES_TEXT)
	assert_true(_dialog._load_button.disabled)


func test_opening_again_lists_the_saves_afresh() -> void:
	_store_stub(1)
	_dialog.open_saves(BASE)
	_store_stub(2)
	_dialog.open_saves(BASE)

	assert_eq(_rows().size(), 2)
