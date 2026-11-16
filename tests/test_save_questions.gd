extends GutTest
## What the player is told about a save that is not loaded.

var _dialog: ChoiceDialog


func before_each() -> void:
	_dialog = ChoiceDialog.new()
	add_child_autofree(_dialog)


func after_each() -> void:
	get_tree().paused = false


func test_a_failed_copy_is_told_with_its_reason_and_one_way_on() -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(0).pressed.emit.call_deferred(), CONNECT_ONE_SHOT
	)
	var questions := SaveQuestions.new(_dialog)

	await questions.tell_copy_failed("disk full")
	await get_tree().process_frame

	assert_string_contains(_dialog._text.text, "disk full")
	assert_string_contains(_dialog._text.text, "so the save was not loaded")
	assert_eq(_dialog._buttons.get_child_count(), 1)


func test_a_refused_save_says_that_the_one_before_it_is_loaded_if_there_is_one() -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(0).pressed.emit.call_deferred(), CONNECT_ONE_SHOT
	)
	var questions := SaveQuestions.new(_dialog)

	await questions.tell_refused("not a save file", "world.bak", true)
	await get_tree().process_frame

	assert_string_contains(_dialog._text.text, "The save before it is loaded instead.")
	assert_eq(_dialog._buttons.get_child(0).text, "Load the save before it")


func test_a_refused_save_with_none_before_it_says_a_new_game_starts() -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(0).pressed.emit.call_deferred(), CONNECT_ONE_SHOT
	)
	var questions := SaveQuestions.new(_dialog)

	await questions.tell_refused("not a save file", "", false)
	await get_tree().process_frame

	assert_string_contains(_dialog._text.text, "A new game starts.")
	assert_eq(_dialog._buttons.get_child(0).text, "Start a new game")


func test_loading_a_save_asks_first_and_escape_keeps_the_game() -> void:
	var header := SaveHeader.of(GameFactory.new_game(7), SaveHeader.Kind.SLEEP)
	var questions := SaveQuestions.new(_dialog)
	_dialog.opened.connect(_dialog.close.call_deferred, CONNECT_ONE_SHOT)

	var is_confirmed: bool = await questions.is_load_confirmed(header)
	await get_tree().process_frame

	assert_false(is_confirmed)
	assert_string_contains(_dialog._text.text, header.game_text())
	assert_string_contains(_dialog._text.text, "is lost")


func test_pressing_load_it_confirms_the_load() -> void:
	var header := SaveHeader.of(GameFactory.new_game(7), SaveHeader.Kind.SLEEP)
	var questions := SaveQuestions.new(_dialog)
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(0).pressed.emit.call_deferred(), CONNECT_ONE_SHOT
	)

	var is_confirmed: bool = await questions.is_load_confirmed(header)
	await get_tree().process_frame

	assert_true(is_confirmed)


func test_a_new_game_is_asked_for_with_cancel_as_the_safe_button() -> void:
	_dialog.opened.connect(
		func() -> void: _dialog._buttons.get_child(1).pressed.emit.call_deferred(), CONNECT_ONE_SHOT
	)
	var questions := SaveQuestions.new(_dialog)

	assert_false(await questions.is_new_game_confirmed(), "Cancel")
	assert_string_contains(_dialog._text.text, "stays under Load")
	assert_eq(_dialog._buttons.get_child(0).text, "Start a new game")
