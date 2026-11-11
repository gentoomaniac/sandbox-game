extends GutTest
## The window that asks the player something: one button per answer, Escape gives the safe one.

var _dialog: ChoiceDialog
var _answers: Array[int] = []


func before_each() -> void:
	_dialog = ChoiceDialog.new()
	add_child_autofree(_dialog)
	_dialog.answered.connect(func(choice: int) -> void: _answers.append(choice))
	_answers = []


func after_each() -> void:
	get_tree().paused = false


func _ask() -> void:
	_dialog.ask("Title", "Text", ["Yes", "No"] as Array[String], 1)


func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(_dialog._buttons.get_children())
	return buttons


func test_asking_opens_it_with_a_button_for_each_answer_and_pauses_the_game() -> void:
	_ask()

	assert_true(_dialog.is_open())
	assert_true(get_tree().paused)
	assert_eq(_buttons().map(func(button: Button) -> String: return button.text), ["Yes", "No"])


func test_the_safe_answer_has_the_focus() -> void:
	_ask()

	assert_true(_buttons()[1].has_focus())


func test_pressing_a_button_answers_with_its_index_and_closes_it() -> void:
	_ask()

	_buttons()[0].pressed.emit()

	assert_eq(_answers, [0])
	assert_false(_dialog.is_open())
	assert_false(get_tree().paused)


func test_closing_it_in_another_way_answers_with_the_safe_choice() -> void:
	_ask()

	_dialog.close()

	assert_eq(_answers, [1])


func test_asking_again_replaces_the_buttons() -> void:
	_ask()
	_buttons()[0].pressed.emit()
	_dialog.ask("Other", "Text", ["Only"] as Array[String], 0)

	await wait_frames(1)

	assert_eq(_buttons().size(), 1)


func test_the_dialog_is_fixed_in_place() -> void:
	assert_false(_dialog.is_movable)
