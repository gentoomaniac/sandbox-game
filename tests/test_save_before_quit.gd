extends GutTest
## The save before quitting: the game quits after a failed save only when the player chooses to.

const DIR := "user://test_save_before_quit"
const PATH := DIR + "/world.json"

var _state: GameState
var _saves := SaveService.new()
var _dialog: ChoiceDialog
var _questions: Array[String] = []
var _quitting: SaveBeforeQuit


func before_each() -> void:
	_state = GameState.new_game(7)
	_dialog = ChoiceDialog.new()
	add_child_autofree(_dialog)
	_questions = []
	_dialog.opened.connect(func() -> void: _questions.append(_dialog._text.text))
	_quitting = SaveBeforeQuit.new(_saves, _state, PATH, _dialog)


func after_each() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(PATH + ".tmp")
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


## Makes the next question be answered by pressing the button `index`, once it is up.
func _answer_with(index: int) -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(index).pressed.emit.call_deferred(),
		CONNECT_ONE_SHOT
	)


## What `SaveBeforeQuit` says, once the test is out of the dialog's signal that the answer came
## in, so that the dialog can be freed afterwards.
func _is_quit_allowed() -> bool:
	var is_allowed: bool = await _quitting.is_quit_allowed()
	await get_tree().process_frame
	return is_allowed


## A good save is there, and a folder where the temporary file goes, so the next write fails.
func _break_saving() -> String:
	assert_true(_saves.save_and_wait(_state, PATH))
	var before := FileAccess.get_file_as_string(PATH)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	_state.player.position = Vector2(20.5, 20.5)
	return before


func test_a_save_that_works_lets_the_game_quit_without_a_question() -> void:
	var is_allowed: bool = await _is_quit_allowed()

	assert_true(is_allowed)
	assert_eq(_questions.size(), 0)
	assert_not_null(SaveFile.read(PATH))


func test_a_failed_save_asks_and_keeping_on_playing_does_not_quit() -> void:
	var before := _break_saving()
	_answer_with(SaveBeforeQuit.KEEP_PLAYING)

	var is_allowed: bool = await _is_quit_allowed()

	assert_false(is_allowed)
	assert_eq(_questions.size(), 1)
	assert_eq(FileAccess.get_file_as_string(PATH), before, "the previous save stays")
	assert_push_error_count(1)


func test_escape_on_the_question_does_not_quit_either() -> void:
	_break_saving()
	_dialog.opened.connect(_dialog.close.call_deferred, CONNECT_ONE_SHOT)

	var is_allowed: bool = await _is_quit_allowed()

	assert_false(is_allowed)
	assert_push_error_count(1)


func test_the_player_can_choose_to_quit_without_saving() -> void:
	var before := _break_saving()
	_answer_with(SaveBeforeQuit.QUIT_ANYWAY)

	var is_allowed: bool = await _is_quit_allowed()

	assert_true(is_allowed)
	assert_eq(FileAccess.get_file_as_string(PATH), before)
	assert_push_error_count(1)


func test_trying_again_saves_once_the_trouble_is_gone() -> void:
	_break_saving()
	_dialog.opened.connect(
		func() -> void:
			DirAccess.remove_absolute(PATH + ".tmp")
			_dialog._buttons.get_child(SaveBeforeQuit.TRY_AGAIN).pressed.emit.call_deferred(),
		CONNECT_ONE_SHOT
	)

	var is_allowed: bool = await _is_quit_allowed()

	assert_true(is_allowed)
	assert_eq(_questions.size(), 1)
	assert_eq(SaveFile.read(PATH).player.position, Vector2(20.5, 20.5))
	assert_push_error_count(1)


func test_the_question_says_what_went_wrong_and_that_progress_is_lost() -> void:
	_break_saving()
	_answer_with(SaveBeforeQuit.KEEP_PLAYING)

	await _is_quit_allowed()

	assert_string_contains(_questions[0], "Can't write")
	assert_string_contains(_questions[0], "that progress is lost")
	var quit_button: Button = _dialog._buttons.get_child(SaveBeforeQuit.QUIT_ANYWAY)
	assert_string_contains(quit_button.text, "lose the progress since the last save")
	assert_push_error_count(1)
