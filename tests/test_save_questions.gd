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
